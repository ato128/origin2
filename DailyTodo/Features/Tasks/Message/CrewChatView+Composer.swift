//
//  CrewChatView+Composer.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//
import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import Supabase

extension CrewChatView {

    var composerBar: some View {
        VStack(spacing: 8) {
            if let currentReply = replyingTo {
                replyPreviewBar(currentReply)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let draftPhotoImage {
                photoAttachmentPreview(image: draftPhotoImage)
                    .padding(.horizontal, 16)
            }

            
            HStack(alignment: .center, spacing: 10) {
                Menu {
                    Button {
                        attachmentAlertText = tr("cc_file_soon")
                        showAttachmentAlert = true
                    } label: {
                        Label("Dosya", systemImage: "doc")
                    }

                    Button {
                        attachmentAlertText = tr("cc_camera_soon")
                        showAttachmentAlert = true
                    } label: {
                        Label("Kamera", systemImage: "camera")
                    }

                    Button {
                        showPhotoPicker = true
                    } label: {
                        Label(tr("fc_photo"), systemImage: "photo")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(.white.opacity(0.95))
                        .frame(width: 42, height: 42)
                        .background(crewChatCircleComposerBackground)
                }

                HStack(spacing: 10) {
                    TextField(
                        String(
                            format: NSLocalizedString("crew_chat_message_placeholder", comment: ""),
                            crew.name
                        ),
                        text: $draftMessage
                    )
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .tint(Color(crewChatComposerHex: "#2DD4FF"))
                    .focused($isComposerFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        sendMessage()
                    }
                    .onChange(of: draftMessage) { _, newValue in
                        handleTypingChange(newValue)
                    }

                    composerActionButton
                }
                .padding(.horizontal, 16)
                .frame(height: 46)
                .background(composerCapsuleBackground)
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 10)
        .animation(.easeOut(duration: 0.18), value: replyingTo?.id)
        .animation(.easeOut(duration: 0.18), value: draftPhotoImage != nil)
    }

    @ViewBuilder
    func replyPreviewBar(_ currentReply: CrewChatMessageItem) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color(crewChatComposerHex: "#2DD4FF"))
                .frame(width: 3, height: 30)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 3) {
                let replyingName = currentReply.isFromMe
                    ? NSLocalizedString("crew_chat_reply_yourself", comment: "")
                    : currentReply.senderName

                Text("crew_chat_replying_to \(replyingName)")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(crewChatComposerHex: "#2DD4FF"))
                    .lineLimit(1)

                Text(currentReply.displayText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Button {
                replyingTo = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.080))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(crewChatComposerHex: "#1593FF").opacity(0.070),
                            Color(crewChatComposerHex: "#7C3AED").opacity(0.055),
                            Color.white.opacity(0.045)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 12, y: 6)
        )
        .padding(.horizontal, 16)
    }

    var composerActionButton: some View {
        let hasText = !draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let canSend = hasText || draftPhotoImage != nil

        return Button {
            if canSend {
                sendMessage()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(canSend ? AnyShapeStyle(UpdoTheme.cyan) : AnyShapeStyle(Color.clear))
                    .frame(width: 31, height: 31)

                Image(systemName: canSend ? "arrow.up" : "mic.fill")
                    .font(.system(size: canSend ? 13 : 17, weight: .black))
                    .foregroundStyle(canSend ? .black : .white.opacity(0.72))
            }
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .animation(.easeOut(duration: 0.16), value: canSend)
    }

    // Birebir Updo AI composer kapsülü.
    var composerCapsuleBackground: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay(Capsule().strokeBorder(UpdoTheme.border, lineWidth: 1))
    }

    // Birebir Updo AI cam-daire aksiyon butonu.
    var crewChatCircleComposerBackground: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay(Circle().strokeBorder(UpdoTheme.border, lineWidth: 1))
    }

    func photoAttachmentPreview(image: UIImage) -> some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button {
                    draftPhotoImage = nil
                    selectedPhotoItem = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white, Color.black.opacity(0.45))
                        .background(Circle().fill(Color.black.opacity(0.18)))
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(tr("fc_photo_ready"))
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)

                Text(tr("fc_add_caption"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(crewChatComposerHex: "#1593FF").opacity(0.055),
                            Color(crewChatComposerHex: "#7C3AED").opacity(0.045),
                            Color.white.opacity(0.040)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
        )
    }

    func currentDisplayName() -> String {
        if let email = session.currentUser?.email, !email.isEmpty {
            let prefix = email.components(separatedBy: "@").first ?? email
            return prefix
        }

        return String(localized: "crew_chat_you")
    }

    func handleTypingChange(_ newValue: String) {
        guard let myID = session.currentUser?.id else { return }

        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldBeTyping = !trimmed.isEmpty

        typingStopTask?.cancel()

        if shouldBeTyping {
            if !isCurrentlyTyping {
                isCurrentlyTyping = true

                Task(priority: .utility) {
                    await crewStore.sendTypingEvent(
                        crewID: crew.id,
                        userID: myID,
                        name: currentDisplayName(),
                        isTyping: true
                    )
                }
            }

            typingStopTask = Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)

                if !Task.isCancelled {
                    isCurrentlyTyping = false

                    await crewStore.sendTypingEvent(
                        crewID: crew.id,
                        userID: myID,
                        name: currentDisplayName(),
                        isTyping: false
                    )
                }
            }
        } else {
            isCurrentlyTyping = false

            Task(priority: .utility) {
                await crewStore.sendTypingEvent(
                    crewID: crew.id,
                    userID: myID,
                    name: currentDisplayName(),
                    isTyping: false
                )
            }
        }
    }

    func sendMessage() {
        let clean = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let photoToSend = draftPhotoImage

        guard !clean.isEmpty || photoToSend != nil else { return }
        guard let senderID = session.currentUser?.id else { return }

        let senderName = currentDisplayName()

        typingStopTask?.cancel()
        isCurrentlyTyping = false

        if let myID = session.currentUser?.id {
            Task(priority: .utility) {
                await crewStore.sendTypingEvent(
                    crewID: crew.id,
                    userID: myID,
                    name: senderName,
                    isTyping: false
                )
            }
        }

        Haptics.impact(.light)

        if let photoToSend {
            draftMessage = ""
            draftPhotoImage = nil
            selectedPhotoItem = nil
            replyingTo = nil
            isComposerFocused = false

            guard let jpegData = photoToSend.jpegData(compressionQuality: 0.82) else {
                attachmentAlertText = tr("fc_photo_prep_failed")
                showAttachmentAlert = true
                return
            }

            Task(priority: .userInitiated) {
                await sendBackendPhotoMessage(
                    imageData: jpegData,
                    caption: clean.isEmpty ? nil : clean,
                    senderID: senderID
                )
            }

            return
        }

        let storedText = encodedMessageText(from: clean)
        let clientID = UUID().uuidString

        draftMessage = ""
        replyingTo = nil
        isComposerFocused = false

        let pendingMessage = makePendingBackendTextMessage(
            text: storedText,
            clientID: clientID,
            senderID: senderID
        )

        appendOrReplaceBackendMessage(pendingMessage)

        if let backendConversationID {
            upsertCachedMessage(
                pendingMessage,
                conversationID: backendConversationID
            )
        }

        Task(priority: .userInitiated) {
            let conversationID: UUID?

            if let existingID = backendConversationID {
                conversationID = existingID
            } else {
                conversationID = await ChatBackendClient.shared.syncCrew(
                    crewID: crew.id,
                    crewName: crew.name,
                    memberUserIDs: crewStore.crewMembers
                        .filter { $0.crew_id == crew.id }
                        .map(\.user_id)
                )?.id
            }

            guard let conversationID else {
                await MainActor.run {
                    markBackendMessageFailed(clientID: clientID)
                }
                return
            }

            await MainActor.run {
                backendConversationID = conversationID
                isSendingBackendMessage = true
            }

            let backendMessage = await ChatBackendClient.shared.sendMessage(
                conversationID: conversationID,
                text: storedText,
                clientID: clientID
            )

            if let backendMessage,
               let mappedMessage = mapBackendMessage(backendMessage) {
                await MainActor.run {
                    appendOrReplaceBackendMessage(mappedMessage)
                    upsertCachedMessage(
                        mappedMessage,
                        conversationID: conversationID
                    )
                    isSendingBackendMessage = false
                    ChatFeedbackManager.shared.playSent()
                }

                Log.debug("✅ CREW CHAT BACKEND SEND OK:", backendMessage.id.uuidString)
            } else {
                await MainActor.run {
                    markBackendMessageFailed(clientID: clientID)
                    updateCachedMessageFailed(clientID: clientID)
                    isSendingBackendMessage = false
                }

                Log.debug("❌ CREW CHAT BACKEND SEND FAILED")
            }
        }
    }

    func sendBackendPhotoMessage(
        imageData: Data,
        caption: String?,
        senderID: UUID,
        existingClientID: String? = nil
    ) async {
        let clientID = existingClientID ?? UUID().uuidString

        // Retry için içeriği sakla — başarıda silinir
        await MainActor.run {
            crewMediaRetryPayloads[clientID] = (data: imageData, caption: caption)
        }

        let fileName = "photo.jpg"
        let storagePath = "crew/\(crew.id.uuidString)/images/\(UUID().uuidString).jpg"

        let cleanCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackText = cleanCaption?.isEmpty == false
            ? cleanCaption!
            : tr("fc_photo_emoji")

        let conversationID: UUID?

        if let existingID = backendConversationID {
            conversationID = existingID
        } else {
            conversationID = await ChatBackendClient.shared.syncCrew(
                crewID: crew.id,
                crewName: crew.name,
                memberUserIDs: crewStore.crewMembers
                    .filter { $0.crew_id == crew.id }
                    .map(\.user_id)
            )?.id
        }

        guard let conversationID else {
            await MainActor.run {
                attachmentAlertText = tr("cc_chat_failed")
                showAttachmentAlert = true
            }
            return
        }

        await MainActor.run {
            backendConversationID = conversationID
            isSendingBackendMessage = true
        }

        let pending = CrewChatMessageItem(
            id: UUID(),
            serverID: nil,
            clientID: clientID,
            crewID: crew.id,
            senderID: senderID,
            senderName: currentDisplayName(),
            text: fallbackText,
            createdAt: Date(),
            reaction: nil,
            isSystemMessage: false,
            isFromMe: true,
            isPending: true,
            isFailed: false,
            messageType: "image",
            mediaURL: nil,
            fileName: fileName,
            fileSizeBytes: Int64(imageData.count),
            mimeType: "image/jpeg",
            messageStatus: "uploading"
        )

        await MainActor.run {
            appendOrReplaceBackendMessage(pending)
            upsertCachedMessage(pending, conversationID: conversationID)
        }

        do {
            try await SupabaseManager.shared.client.storage
                .from("friend-chat-media")
                .upload(
                    path: storagePath,
                    file: imageData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: false
                    )
                )

            let mediaURL = publicCrewBackendMediaURL(path: storagePath)

            guard !mediaURL.isEmpty else {
                throw NSError(
                    domain: "CrewChatView",
                    code: 1001,
                    userInfo: [NSLocalizedDescriptionKey: tr("fc_media_url_failed")]
                )
            }

            let backendMessage = await ChatBackendClient.shared.sendMessage(
                conversationID: conversationID,
                text: fallbackText,
                clientID: clientID,
                messageType: "image",
                mediaURL: mediaURL,
                fileName: fileName,
                fileSizeBytes: imageData.count,
                mimeType: "image/jpeg"
            )

            if let backendMessage,
               let mapped = mapBackendMessage(backendMessage) {
                await MainActor.run {
                    appendOrReplaceBackendMessage(mapped)
                    upsertCachedMessage(mapped, conversationID: conversationID)
                    crewMediaRetryPayloads.removeValue(forKey: clientID)
                    isSendingBackendMessage = false
                    ChatFeedbackManager.shared.playSent()
                }

                Log.debug("✅ CREW CHAT BACKEND PHOTO SEND OK:", backendMessage.id.uuidString)
            } else {
                await MainActor.run {
                    markBackendMessageFailed(clientID: clientID)
                    updateCachedMessageFailed(clientID: clientID)
                    isSendingBackendMessage = false
                }

                Log.debug("❌ CREW CHAT BACKEND PHOTO SEND FAILED")
            }
        } catch {
            Log.debug("❌ CREW BACKEND PHOTO SEND ERROR:", error.localizedDescription)

            await MainActor.run {
                markBackendMessageFailed(clientID: clientID)
                updateCachedMessageFailed(clientID: clientID)
                isSendingBackendMessage = false
                attachmentAlertText = tr("cc_photo_send_failed")
                showAttachmentAlert = true
            }
        }
    }

    /// Başarısız bir crew mesajını aynı clientID ile yeniden gönderir (Insta DM modeli).
    /// Backend `on conflict (conversation_id, client_id)` upsert'i çift mesajı engeller.
    func resendFailedCrewMessage(_ message: CrewChatMessageItem) {
        guard message.isFailed, message.isFromMe else { return }
        guard let senderID = session.currentUser?.id else { return }
        guard let clientID = message.clientID, !clientID.isEmpty else { return }

        // Foto: bellekteki payload ile tekrar yükle
        if message.messageType == "image" {
            guard let payload = crewMediaRetryPayloads[clientID] else {
                attachmentAlertText = tr("cc_photo_resend_failed")
                showAttachmentAlert = true
                return
            }

            Task {
                await sendBackendPhotoMessage(
                    imageData: payload.data,
                    caption: payload.caption,
                    senderID: senderID,
                    existingClientID: clientID
                )
            }
            return
        }

        // Metin: aynı clientID ile yeniden gönder (text zaten encode edilmiş halde saklı)
        let storedText = message.text
        guard !storedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let pendingMessage = makePendingBackendTextMessage(
            text: storedText,
            clientID: clientID,
            senderID: senderID
        )

        appendOrReplaceBackendMessage(pendingMessage)

        if let backendConversationID {
            upsertCachedMessage(pendingMessage, conversationID: backendConversationID)
        }

        Task(priority: .userInitiated) {
            let conversationID: UUID?

            if let existingID = backendConversationID {
                conversationID = existingID
            } else {
                conversationID = await ChatBackendClient.shared.syncCrew(
                    crewID: crew.id,
                    crewName: crew.name,
                    memberUserIDs: crewStore.crewMembers
                        .filter { $0.crew_id == crew.id }
                        .map(\.user_id)
                )?.id
            }

            guard let conversationID else {
                await MainActor.run {
                    markBackendMessageFailed(clientID: clientID)
                }
                return
            }

            await MainActor.run {
                backendConversationID = conversationID
            }

            let backendMessage = await ChatBackendClient.shared.sendMessage(
                conversationID: conversationID,
                text: storedText,
                clientID: clientID
            )

            if let backendMessage,
               let mappedMessage = mapBackendMessage(backendMessage) {
                await MainActor.run {
                    appendOrReplaceBackendMessage(mappedMessage)
                    upsertCachedMessage(mappedMessage, conversationID: conversationID)
                    ChatFeedbackManager.shared.playSent()
                }
            } else {
                await MainActor.run {
                    markBackendMessageFailed(clientID: clientID)
                    updateCachedMessageFailed(clientID: clientID)
                    HapticManager.shared.error()
                }
            }
        }
    }

    func publicCrewBackendMediaURL(path: String) -> String {
        do {
            return try SupabaseManager.shared.client.storage
                .from("friend-chat-media")
                .getPublicURL(path: path)
                .absoluteString
        } catch {
            Log.debug("❌ CREW PUBLIC MEDIA URL ERROR:", error.localizedDescription)
            return ""
        }
    }

    func loadCachedMessagesIfNeeded(conversationID: UUID? = nil) {
        guard !didLoadCachedMessages else { return }
        guard let ownerUserID = session.currentUser?.id else { return }

        didLoadCachedMessages = true

        do {
            let descriptor = FetchDescriptor<ChatCachedConversationMessage>(
                sortBy: [
                    SortDescriptor(\ChatCachedConversationMessage.createdAt, order: .forward)
                ]
            )

            let cached = try modelContext.fetch(descriptor)

            let items = cached
                .filter { cachedMessage in
                    guard cachedMessage.ownerUserID == ownerUserID else {
                        return false
                    }

                    if let conversationID {
                        return cachedMessage.conversationID == conversationID
                    }

                    return cachedMessage.supabaseCrewID == crew.id
                }
                .map { $0.toCrewChatMessageItem() }
                .filter { $0.crewID == crew.id }

            let cachedSeenIDs = Set(
                cached
                    .filter { cachedMessage in
                        cachedMessage.ownerUserID == ownerUserID &&
                        cachedMessage.supabaseCrewID == crew.id &&
                        cachedMessage.seenAt != nil
                    }
                    .map { $0.serverID ?? $0.id }
            )

            seenMessageIDs.formUnion(cachedSeenIDs)

            guard !items.isEmpty else {
                Log.debug("⚪️ CREW CHAT CACHE EMPTY:", crew.id.uuidString)
                return
            }

            mergeBackendMessages(items)
            didBootstrapBackendMessages = true

            if !hasCompletedBackendInitialSync {
                hasCompletedBackendInitialSync = true
            }

            Log.debug("🟢 CREW CHAT CACHE LOADED:", items.count)
        } catch {
            Log.debug("❌ CREW CHAT CACHE LOAD ERROR:", error.localizedDescription)
        }
    }

    func upsertCachedMessage(
        _ message: CrewChatMessageItem,
        conversationID: UUID
    ) {
        guard let ownerUserID = session.currentUser?.id else { return }

        let serverKey = message.serverID.map {
            "\(ownerUserID.uuidString)-server-\($0.uuidString)"
        }

        let clientKey = message.clientID.flatMap {
            $0.isEmpty ? nil : "\(ownerUserID.uuidString)-client-\($0)"
        }

        let localKey = "\(ownerUserID.uuidString)-local-\(message.id.uuidString)"

        do {
            var existing: ChatCachedConversationMessage?

            if let serverKey {
                var descriptor = FetchDescriptor<ChatCachedConversationMessage>(
                    predicate: #Predicate<ChatCachedConversationMessage> { cached in
                        cached.cacheKey == serverKey
                    }
                )
                descriptor.fetchLimit = 1
                existing = try modelContext.fetch(descriptor).first
            }

            if existing == nil, let clientKey {
                var descriptor = FetchDescriptor<ChatCachedConversationMessage>(
                    predicate: #Predicate<ChatCachedConversationMessage> { cached in
                        cached.cacheKey == clientKey
                    }
                )
                descriptor.fetchLimit = 1
                existing = try modelContext.fetch(descriptor).first
            }

            if let existing {
                existing.update(
                    from: message,
                    ownerUserID: ownerUserID,
                    conversationID: conversationID
                )
            } else {
                let created = ChatCachedConversationMessage(
                    ownerUserID: ownerUserID,
                    conversationID: conversationID,
                    supabaseCrewID: message.crewID,
                    id: message.serverID ?? message.id,
                    serverID: message.serverID,
                    clientID: message.clientID,
                    senderID: message.senderID,
                    senderName: message.senderName,
                    text: message.text,
                    createdAt: message.createdAt,
                    reaction: message.reaction,
                    isSystemMessage: message.isSystemMessage,
                    isFromMe: message.isFromMe,
                    isPending: message.isPending,
                    isFailed: message.isFailed,
                    messageType: message.messageType,
                    mediaURL: message.mediaURL,
                    fileName: message.fileName,
                    fileSizeBytes: message.fileSizeBytes,
                    mimeType: message.mimeType,
                    messageStatus: message.messageStatus
                )

                modelContext.insert(created)
            }

            try modelContext.save()
        } catch {
            Log.debug("❌ CREW CHAT CACHE UPSERT ERROR:", error.localizedDescription)
            Log.debug("❌ CREW CHAT CACHE FALLBACK KEY:", serverKey ?? clientKey ?? localKey)
        }
    }

    func upsertCachedMessages(
        _ messages: [CrewChatMessageItem],
        conversationID: UUID
    ) {
        for message in messages {
            upsertCachedMessage(
                message,
                conversationID: conversationID
            )
        }
    }

    func updateCachedMessageFailed(clientID: String) {
        guard let ownerUserID = session.currentUser?.id else { return }

        do {
            let key = "\(ownerUserID.uuidString)-client-\(clientID)"

            var descriptor = FetchDescriptor<ChatCachedConversationMessage>(
                predicate: #Predicate<ChatCachedConversationMessage> { cached in
                    cached.cacheKey == key
                }
            )
            descriptor.fetchLimit = 1

            guard let cached = try modelContext.fetch(descriptor).first else {
                return
            }

            cached.isPending = false
            cached.isFailed = true
            cached.messageStatus = "failed"
            cached.updatedAt = Date()

            try modelContext.save()
        } catch {
            Log.debug("❌ CREW CHAT CACHE FAILED UPDATE ERROR:", error.localizedDescription)
        }
    }

    func updateCachedMessagesSeen(
        ids: Set<UUID>,
        seenAt: Date,
        conversationID: UUID
    ) {
        guard !ids.isEmpty else { return }
        guard let ownerUserID = session.currentUser?.id else { return }

        do {
            let descriptor = FetchDescriptor<ChatCachedConversationMessage>(
                predicate: #Predicate<ChatCachedConversationMessage> { cached in
                    cached.ownerUserID == ownerUserID &&
                    cached.conversationID == conversationID
                }
            )

            let cachedMessages = try modelContext.fetch(descriptor)

            for cached in cachedMessages {
                let cachedID = cached.serverID ?? cached.id

                if ids.contains(cachedID) {
                    cached.seenAt = seenAt
                    cached.isPending = false
                    cached.isFailed = false
                    cached.messageStatus = "seen"
                    cached.updatedAt = Date()
                }
            }

            try modelContext.save()
        } catch {
            Log.debug("❌ CREW CHAT CACHE SEEN UPDATE ERROR:", error.localizedDescription)
        }
    }

    func encodedMessageText(from clean: String) -> String {
        guard let replyingTo else { return clean }

        let preview = replyingTo.displayText.replacingOccurrences(of: "\n", with: " ")
        return "\(replyMarker)\(preview)\(bodyMarker)\(clean)"
    }
}

// MARK: - Color Hex

private extension Color {
    init(crewChatComposerHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64

        switch cleaned.count {
        case 3:
            a = 255
            r = (int >> 8) * 17
            g = ((int >> 4) & 0xF) * 17
            b = (int & 0xF) * 17

        case 6:
            a = 255
            r = int >> 16
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        case 8:
            a = int >> 24
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        default:
            a = 255
            r = 255
            g = 255
            b = 255
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
