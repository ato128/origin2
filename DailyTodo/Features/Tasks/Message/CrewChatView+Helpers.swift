//
//  CrewChatView+Helpers.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//
import SwiftUI
import SwiftData

extension CrewChatView {

    var typingNames: [String] {
        guard let myID = session.currentUser?.id else { return [] }

        return socketTypingUserIDs
            .filter { $0 != myID }
            .map { crewMemberDisplayName(for: $0) }
    }

    func crewMemberDisplayName(for userID: UUID) -> String {
        if let profile = crewStore.memberProfiles.first(where: { $0.id == userID }) {
            if let fullName = profile.full_name?.trimmingCharacters(in: .whitespacesAndNewlines),
               !fullName.isEmpty {
                return fullName
            }
            if let username = profile.username?.trimmingCharacters(in: .whitespacesAndNewlines),
               !username.isEmpty {
                return username
            }
        }
        return appLanguageIsEnglish() ? "Someone" : "Biri"
    }

    /// Backend socket'ten gelen "yazıyor" eventini işle (crew konuşması).
    func handleIncomingCrewTyping(_ note: Notification) {
        guard let backendConversationID else { return }

        let convMatches: Bool
        if let objID = note.object as? UUID {
            convMatches = objID == backendConversationID
        } else if let convStr = note.userInfo?["conversationID"] as? String {
            convMatches = convStr == backendConversationID.uuidString
        } else {
            convMatches = false
        }
        guard convMatches else { return }

        guard let uidStr = note.userInfo?["userID"] as? String,
              let uid = UUID(uuidString: uidStr),
              uid != session.currentUser?.id else { return }

        let isTyping = (note.userInfo?["isTyping"] as? Bool) ?? false

        socketTypingClearTasks[uid]?.cancel()
        socketTypingClearTasks[uid] = nil

        if isTyping {
            socketTypingUserIDs.insert(uid)
            // Güvenlik ağı: "durdu" kaçarsa 6sn sonra otomatik düş.
            socketTypingClearTasks[uid] = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                guard !Task.isCancelled else { return }
                socketTypingUserIDs.remove(uid)
                socketTypingClearTasks[uid] = nil
            }
        } else {
            socketTypingUserIDs.remove(uid)
        }
    }

    var typingText: String? {
        guard !typingNames.isEmpty else { return nil }

        let isTurkish = !appLanguageIsEnglish()

        if typingNames.count == 1 {
            return isTurkish
            ? tr("cc_typing_one", typingNames[0])
            : "\(typingNames[0]) is typing..."
        }

        if typingNames.count == 2 {
            return isTurkish
            ? tr("cc_typing_two", typingNames[0], typingNames[1])
            : "\(typingNames[0]) and \(typingNames[1]) are typing..."
        }

        return isTurkish
        ? tr("cc_typing_some")
        : "Some people are typing..."
    }

    func loadChatData() async {
        await MainActor.run {
            loadCachedMessagesIfNeeded()
        }

        await crewStore.loadMembers(for: crew.id)

        await crewStore.loadMemberProfiles(
            for: crewStore.crewMembers.filter { $0.crew_id == crew.id }
        )

        await crewStore.loadCrewTypingStatuses(for: crew.id)
        crewStore.subscribeToCrewAuxRealtime(crewID: crew.id)

        await syncChatBackendCrewIfNeeded()
    }

    func syncChatBackendCrewIfNeeded() async {
        await MainActor.run {
            isSyncingBackendConversation = true
            backendSyncError = nil

            if backendConversationID == nil {
                hasCompletedBackendInitialSync = false
            }
        }

        Log.debug("🟡 CREW CHAT BACKEND SYNC START:", crew.id.uuidString)

        let conversation = await ChatBackendClient.shared.syncCrew(
            crewID: crew.id,
            crewName: crew.name,
            memberUserIDs: crewStore.crewMembers
                .filter { $0.crew_id == crew.id }
                .map(\.user_id)
        )

        guard let conversationID = conversation?.id else {
            await MainActor.run {
                isSyncingBackendConversation = false
                backendSyncError = "Crew conversation sync failed"
            }

            Log.debug("❌ CREW CHAT BACKEND CONVERSATION ID NIL")
            return
        }

        await MainActor.run {
            backendConversationID = conversationID

            loadCachedMessagesIfNeeded(
                conversationID: conversationID
            )

            if !backendMessages.isEmpty {
                didBootstrapBackendMessages = true
                hasCompletedBackendInitialSync = true
            }
        }

        let fetchedMessages = await ChatBackendClient.shared.fetchMessages(
            conversationID: conversationID
        )

        let mappedMessages = fetchedMessages.compactMap { dto in
            mapBackendMessage(dto)
        }

        await MainActor.run {
            upsertCachedMessages(
                mappedMessages,
                conversationID: conversationID
            )

            if didBootstrapBackendMessages {
                mergeBackendMessages(mappedMessages)
            } else if backendMessages.isEmpty {
                backendMessages = mappedMessages.sorted { $0.createdAt < $1.createdAt }
                didBootstrapBackendMessages = true
            } else {
                mergeBackendMessages(mappedMessages)
                didBootstrapBackendMessages = true
            }

            hasCompletedBackendInitialSync = true
            isSyncingBackendConversation = false
            backendSyncError = nil
        }

        await ChatBackendClient.shared.markConversationRead(
            conversationID: conversationID
        )

        await ChatBackendSocketClient.shared.connect(
            conversationID: conversationID,
            onMessageCreated: { dto in
                guard let mappedMessage = mapBackendMessage(dto) else {
                    return
                }

                appendOrReplaceBackendMessage(mappedMessage)

                upsertCachedMessage(
                    mappedMessage,
                    conversationID: conversationID
                )

                Task {
                    await ChatBackendClient.shared.markConversationRead(
                        conversationID: conversationID
                    )
                }

                Log.debug("🟢 CREW WS MESSAGE UPSERTED:", mappedMessage.id.uuidString)
            },
            onMessageSeen: { payload in
                guard payload.readerID != session.currentUser?.id else {
                    return
                }

                let seenIDs = Set(payload.messages.map { $0.id })
                let seenDate = Date()

                seenMessageIDs.formUnion(seenIDs)

                updateCachedMessagesSeen(
                    ids: seenIDs,
                    seenAt: seenDate,
                    conversationID: conversationID
                )

                backendMessages = backendMessages.map { message in
                    let messageID = message.serverID ?? message.id

                    guard seenIDs.contains(messageID) else {
                        return message
                    }

                    return CrewChatMessageItem(
                        id: message.id,
                        serverID: message.serverID,
                        clientID: message.clientID,
                        crewID: message.crewID,
                        senderID: message.senderID,
                        senderName: message.senderName,
                        text: message.text,
                        createdAt: message.createdAt,
                        reaction: message.reaction,
                        isSystemMessage: message.isSystemMessage,
                        isFromMe: message.isFromMe,
                        isPending: false,
                        isFailed: false,
                        messageType: message.messageType,
                        mediaURL: message.mediaURL,
                        fileName: message.fileName,
                        fileSizeBytes: message.fileSizeBytes,
                        mimeType: message.mimeType,
                        messageStatus: "seen"
                    )
                }

                Log.debug("🟢 CREW WS MESSAGE SEEN UPDATED:", seenIDs.count)
            }
        )

        Log.debug("🟢 CREW CHAT BACKEND READY:", conversationID.uuidString)
        Log.debug("🟢 CREW CHAT BACKEND UI MESSAGES COUNT:", mappedMessages.count)
    }

    func mapBackendMessage(_ dto: ChatBackendMessageDTO) -> CrewChatMessageItem? {
        let currentUserID = session.currentUser?.id
        let isFromMe = dto.senderID == currentUserID

        return CrewChatMessageItem(
            id: dto.id,
            serverID: dto.id,
            clientID: dto.clientID,
            crewID: crew.id,
            senderID: dto.senderID,
            senderName: senderName(for: dto.senderID, isFromMe: isFromMe),
            text: dto.text ?? "",
            createdAt: parseBackendDate(dto.createdAt),
            reaction: nil,
            isSystemMessage: false,
            isFromMe: isFromMe,
            isPending: false,
            isFailed: false,
            messageType: dto.messageType,
            mediaURL: dto.mediaURL,
            fileName: dto.fileName,
            fileSizeBytes: dto.fileSizeBytes.map { Int64($0) },
            mimeType: dto.mimeType,
            messageStatus: dto.deletedAt == nil ? "sent" : "deleted",
            reactions: dto.reactions
        )
    }

    func senderName(for senderID: UUID?, isFromMe: Bool) -> String {
        if isFromMe {
            return currentDisplayName()
        }

        guard let senderID else {
            return String(localized: "crew_chat_unknown_user")
        }

        if let profile = crewStore.memberProfiles.first(where: { $0.id == senderID }) {
            if let fullName = profile.full_name?.trimmingCharacters(in: .whitespacesAndNewlines),
               !fullName.isEmpty {
                return fullName
            }

            if let username = profile.username?.trimmingCharacters(in: .whitespacesAndNewlines),
               !username.isEmpty {
                return username
            }

            if let email = profile.email?.trimmingCharacters(in: .whitespacesAndNewlines),
               !email.isEmpty {
                return email.components(separatedBy: "@").first ?? email
            }
        }

        return String(localized: "crew_chat_unknown_user")
    }

    func parseBackendDate(_ value: String) -> Date {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        if let date = isoFormatter.date(from: value) {
            return date
        }

        let fallbackFormatter = ISO8601DateFormatter()

        if let date = fallbackFormatter.date(from: value) {
            return date
        }

        return Date()
    }

    func appendOrReplaceBackendMessage(_ message: CrewChatMessageItem) {
        if let index = backendMessages.firstIndex(where: { existing in
            if existing.id == message.id {
                return true
            }

            guard
                let existingClientID = existing.clientID,
                let newClientID = message.clientID,
                !existingClientID.isEmpty,
                !newClientID.isEmpty
            else {
                return false
            }

            return existingClientID == newClientID
        }) {
            backendMessages[index] = message
            return
        }

        backendMessages.append(message)
        backendMessages.sort { $0.createdAt < $1.createdAt }
    }

    func mergeBackendMessages(_ incoming: [CrewChatMessageItem]) {
        var merged = backendMessages

        for message in incoming {
            if let index = merged.firstIndex(where: { existing in
                if existing.id == message.id {
                    return true
                }

                guard
                    let existingClientID = existing.clientID,
                    let newClientID = message.clientID,
                    !existingClientID.isEmpty,
                    !newClientID.isEmpty
                else {
                    return false
                }

                return existingClientID == newClientID
            }) {
                merged[index] = message
            } else {
                merged.append(message)
            }
        }

        backendMessages = merged.sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - Emoji reaksiyon (tapback)

    /// Bir mesajın toplu reaksiyon listesini (server / realtime kaynaklı) uygular.
    func applyReactions(messageID: UUID, reactions: [ChatReactionSummary]) {
        guard let index = backendMessages.firstIndex(where: { $0.serverID == messageID || $0.id == messageID }) else {
            return
        }
        backendMessages[index].reactions = reactions
    }

    /// Uzun-basma tapback: aynı emoji tekrar → kaldır, farklı → değiştir/ekle.
    /// Önce iyimser günceller, sonra backend'e yazıp toplu sonucu uygular.
    func toggleReaction(_ message: CrewChatMessageItem, emoji: String) {
        guard let conversationID = backendConversationID,
              let messageID = message.serverID else { return }

        Haptics.impact(.light)

        let mine = message.reactions.first(where: { $0.mine })?.emoji
        let newEmoji: String? = (mine == emoji) ? nil : emoji

        applyReactions(
            messageID: messageID,
            reactions: chatOptimisticReactions(message.reactions, newEmoji: newEmoji)
        )

        Task {
            let updated = await ChatBackendClient.shared.setReaction(
                conversationID: conversationID,
                messageID: messageID,
                emoji: newEmoji
            )
            if let updated {
                await MainActor.run { applyReactions(messageID: messageID, reactions: updated) }
            }
        }
    }

    func markBackendMessageFailed(clientID: String) {
        guard let index = backendMessages.firstIndex(where: { $0.clientID == clientID }) else {
            return
        }

        let old = backendMessages[index]

        backendMessages[index] = CrewChatMessageItem(
            id: old.id,
            serverID: old.serverID,
            clientID: old.clientID,
            crewID: old.crewID,
            senderID: old.senderID,
            senderName: old.senderName,
            text: old.text,
            createdAt: old.createdAt,
            reaction: old.reaction,
            isSystemMessage: old.isSystemMessage,
            isFromMe: old.isFromMe,
            isPending: false,
            isFailed: true,
            messageType: old.messageType,
            mediaURL: old.mediaURL,
            fileName: old.fileName,
            fileSizeBytes: old.fileSizeBytes,
            mimeType: old.mimeType,
            messageStatus: "failed"
        )
    }

    func makePendingBackendTextMessage(
        text: String,
        clientID: String,
        senderID: UUID
    ) -> CrewChatMessageItem {
        CrewChatMessageItem(
            id: UUID(),
            serverID: nil,
            clientID: clientID,
            crewID: crew.id,
            senderID: senderID,
            senderName: currentDisplayName(),
            text: text,
            createdAt: Date(),
            reaction: nil,
            isSystemMessage: false,
            isFromMe: true,
            isPending: true,
            isFailed: false,
            messageType: "text",
            mediaURL: nil,
            fileName: nil,
            fileSizeBytes: nil,
            mimeType: nil,
            messageStatus: "pending"
        )
    }
}
