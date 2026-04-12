//
//  CrewStore.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//
import Foundation
import Supabase
import Combine
import SwiftUI


struct CreateFocusRecordPayload: Encodable {
    let crew_id: String
    let user_id: String?
    let member_name: String
    let minutes: Int
}

@MainActor
final class CrewStore: ObservableObject {
    @Published var crews: [CrewDTO] = []
    @Published var crewMembers: [CrewMemberDTO] = []
    @Published var isLoading = false
    @Published var memberProfiles: [ProfileDTO] = []
    @Published var crewTasks: [CrewTaskDTO] = []
    @Published var memberCountByCrew: [UUID: Int] = [:]
    @Published var taskCountByCrew: [UUID: Int] = [:]
    @Published var completedTaskCountByCrew: [UUID: Int] = [:]
    @Published var crewActivities: [CrewActivityDTO] = []
    @Published var crewFocusRecords: [CrewFocusRecordDTO] = []
    @Published var crewMessageReads: [CrewMessageReadDTO] = []
    @Published var crewTypingStatuses: [CrewTypingStatusDTO] = []

    @Published var chatMessagesByCrew: [UUID: [CrewChatMessageItem]] = [:]
    @Published var activeFocusSessionByCrew: [UUID: CrewFocusSessionDTO] = [:]
    @Published var focusParticipantsBySession: [UUID: [CrewFocusParticipantDTO]] = [:]
    @Published private(set) var currentUserID: UUID?
    
    @Published var chatLastLoadedAtByCrew: [UUID: Date] = [:]
    @Published var hasLoadedChatInitiallyByCrew: [UUID: Bool] = [:]
    @Published var chatLoadingByCrew: [UUID: Bool] = [:]

    private var activeFocusChannel: RealtimeChannelV2?
    private var focusParticipantsChannel: RealtimeChannelV2?
    private var subscribedFocusCrewID: UUID?

    private var taskChannel: RealtimeChannelV2?
    private var memberChannel: RealtimeChannelV2?
    private var activityChannel: RealtimeChannelV2?
    private var focusChannel: RealtimeChannelV2?
    private var lastTypingStateByCrew: [UUID: Bool] = [:]

    private var crewMessagesChannel: RealtimeChannelV2?
    private var subscribedCrewMessageID: UUID?
    private var hasLoadedCrews = false
    private var crewsListChannel: RealtimeChannelV2?
    private var crewsMemberListChannel: RealtimeChannelV2?
    private var subscribedCrewsListUserID: UUID?
    
    private var crewTypingChannel: RealtimeChannelV2?
    private var crewReadsChannel: RealtimeChannelV2?
    private var subscribedCrewAuxRealtimeID: UUID?
    private var subscribedAuxCrewID: UUID?
    
    private var isSubscribingCrewMessages = false
    private var isSubscribingCrewAux = false
    
    
   
    private var crewsStatsTaskChannel: RealtimeChannelV2?
    private var crewsStatsMemberChannel: RealtimeChannelV2?
    
    private var subscribedCrewRealtimeID: UUID?
    
    func setCurrentUser(_ userID: UUID?) {
        currentUserID = userID
    }
    private func refreshCrewStats(for crewID: UUID) async {
        await loadMemberCount(for: crewID)
        await loadTaskCount(for: crewID)
        await loadCompletedTaskCount(for: crewID)
    }
    
    func removeMember(_ member: CrewMemberDTO, from crewID: UUID) async throws {
        let oldMembers = crewMembers

        // optimistic local remove
        crewMembers.removeAll { $0.id == member.id }

        do {
            try await SupabaseManager.shared.client
                .from("crew_members")
                .delete()
                .eq("id", value: member.id.uuidString)
                .eq("crew_id", value: crewID.uuidString)
                .execute()

            await loadMembers(for: crewID)
            await loadMemberProfiles(for: crewMembers)
            await refreshCrewStats(for: crewID)

        } catch {
            crewMembers = oldMembers
            print("REMOVE MEMBER ERROR:", error.localizedDescription)
            throw error
        }
    }
    func deleteCrew(
        crewID: UUID,
        currentUserID: UUID
    ) async throws {
        guard let crew = crews.first(where: { $0.id == crewID }) else {
            throw NSError(
                domain: "CrewStore",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Crew not found."]
            )
        }

        guard crew.owner_id == currentUserID else {
            throw NSError(
                domain: "CrewStore",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Only the crew owner can delete this crew."]
            )
        }

        let oldCrews = crews
        let oldMembers = crewMembers
        let oldTasks = crewTasks
        let oldActivities = crewActivities
        let oldFocusRecords = crewFocusRecords
        let oldMessageReads = crewMessageReads
        let oldTypingStatuses = crewTypingStatuses
        let oldChatMessagesByCrew = chatMessagesByCrew
        let oldActiveFocusSessionByCrew = activeFocusSessionByCrew
        let oldFocusParticipantsBySession = focusParticipantsBySession
        let oldMemberCountByCrew = memberCountByCrew
        let oldTaskCountByCrew = taskCountByCrew
        let oldCompletedTaskCountByCrew = completedTaskCountByCrew

        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            crews.removeAll { $0.id == crewID }
            crewMembers.removeAll { $0.crew_id == crewID }
            crewTasks.removeAll { $0.crew_id == crewID }
            crewActivities.removeAll { $0.crew_id == crewID }
            crewFocusRecords.removeAll { $0.crew_id == crewID }
            crewMessageReads.removeAll { $0.crew_id == crewID }
            crewTypingStatuses.removeAll { $0.crew_id == crewID }
            chatMessagesByCrew.removeValue(forKey: crewID)
            activeFocusSessionByCrew.removeValue(forKey: crewID)
            memberCountByCrew.removeValue(forKey: crewID)
            taskCountByCrew.removeValue(forKey: crewID)
            completedTaskCountByCrew.removeValue(forKey: crewID)
        }

        do {
            if subscribedCrewRealtimeID == crewID {
                unsubscribe()
            }

            if subscribedCrewMessageID == crewID {
                unsubscribeCrewChat()
            }

            if subscribedFocusCrewID == crewID {
                unsubscribeCrewFocusRealtime()
            }

            try await SupabaseManager.shared.client
                .from("crew_focus_participants")
                .delete()
                .eq("crew_id", value: crewID.uuidString)
                .execute()

            try await SupabaseManager.shared.client
                .from("crew_focus_sessions")
                .delete()
                .eq("crew_id", value: crewID.uuidString)
                .execute()

            try await SupabaseManager.shared.client
                .from("crew_messages")
                .delete()
                .eq("crew_id", value: crewID.uuidString)
                .execute()

            try await SupabaseManager.shared.client
                .from("crew_message_reads")
                .delete()
                .eq("crew_id", value: crewID.uuidString)
                .execute()

            try await SupabaseManager.shared.client
                .from("crew_typing_status")
                .delete()
                .eq("crew_id", value: crewID.uuidString)
                .execute()

            try await SupabaseManager.shared.client
                .from("crew_tasks")
                .delete()
                .eq("crew_id", value: crewID.uuidString)
                .execute()

            try await SupabaseManager.shared.client
                .from("crew_activities")
                .delete()
                .eq("crew_id", value: crewID.uuidString)
                .execute()

            try await SupabaseManager.shared.client
                .from("crew_focus_records")
                .delete()
                .eq("crew_id", value: crewID.uuidString)
                .execute()

            try await SupabaseManager.shared.client
                .from("crew_invites")
                .delete()
                .eq("crew_id", value: crewID.uuidString)
                .execute()

            try await SupabaseManager.shared.client
                .from("crew_members")
                .delete()
                .eq("crew_id", value: crewID.uuidString)
                .execute()

            try await SupabaseManager.shared.client
                .from("crews")
                .delete()
                .eq("id", value: crewID.uuidString)
                .eq("owner_id", value: currentUserID.uuidString)
                .execute()

            print("✅ CREW DELETED:", crewID.uuidString)
        } catch {
            crews = oldCrews
            crewMembers = oldMembers
            crewTasks = oldTasks
            crewActivities = oldActivities
            crewFocusRecords = oldFocusRecords
            crewMessageReads = oldMessageReads
            crewTypingStatuses = oldTypingStatuses
            chatMessagesByCrew = oldChatMessagesByCrew
            activeFocusSessionByCrew = oldActiveFocusSessionByCrew
            focusParticipantsBySession = oldFocusParticipantsBySession
            memberCountByCrew = oldMemberCountByCrew
            taskCountByCrew = oldTaskCountByCrew
            completedTaskCountByCrew = oldCompletedTaskCountByCrew

            print("DELETE CREW ERROR:", error.localizedDescription)
            throw error
        }
    }

    // MARK: - Chat Helpers

    
    
    
    private func isoDate(_ raw: String?) -> Date {
        CrewDateParser.parse(raw) ?? Date()
    }

    private func mapDTOToChatItem(
        _ dto: CrewMessageDTO,
        currentUserID: UUID?
    ) -> CrewChatMessageItem {
        CrewChatMessageItem(
            id: dto.id,
            serverID: dto.id,
            clientID: dto.client_id,
            crewID: dto.crew_id,
            senderID: dto.sender_id,
            senderName: dto.sender_name,
            text: dto.text,
            createdAt: isoDate(dto.created_at),
            reaction: dto.reaction,
            isSystemMessage: dto.is_system_message ?? false,
            isFromMe: dto.sender_id == currentUserID,
            isPending: false,
            isFailed: false
        )
    }

    private func sortAndTrimChatItems(_ items: [CrewChatMessageItem]) -> [CrewChatMessageItem] {
        let sorted = items.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.createdAt < rhs.createdAt
        }

        return Array(sorted.suffix(100))
    }

    private func mergeChatItem(_ item: CrewChatMessageItem, into crewID: UUID) {
        var items = chatMessagesByCrew[crewID] ?? []

        if let serverID = item.serverID,
           let existingIndex = items.firstIndex(where: { $0.serverID == serverID }) {
            items[existingIndex] = item
        } else if let clientID = item.clientID,
                  let pendingIndex = items.firstIndex(where: {
                      $0.serverID == nil && $0.clientID == clientID
                  }) {
            items[pendingIndex] = item
        } else {
            items.append(item)
        }

        chatMessagesByCrew[crewID] = sortAndTrimChatItems(items)
    }

    private func setChatMessages(
        _ items: [CrewChatMessageItem],
        for crewID: UUID,
        preserveExistingIfIncomingEmpty: Bool = true
    ) {
        if preserveExistingIfIncomingEmpty,
           items.isEmpty,
           let existing = chatMessagesByCrew[crewID],
           !existing.isEmpty {
            return
        }

        chatMessagesByCrew[crewID] = sortAndTrimChatItems(items)
    }

    private func appendChatMessage(
        _ item: CrewChatMessageItem,
        for crewID: UUID
    ) {
        mergeChatItem(item, into: crewID)
    }

    private func replacePendingMessageByClientID(
        crewID: UUID,
        clientID: String,
        with item: CrewChatMessageItem
    ) {
        mergeChatItem(item, into: crewID)
    }

    func handleIncomingMessage(
        _ dto: CrewMessageDTO,
        currentUserID: UUID?
    ) {
        let item = mapDTOToChatItem(dto, currentUserID: currentUserID)
        mergeChatItem(item, into: dto.crew_id)
    }

    private func markPendingMessageFailed(
        crewID: UUID,
        localID: UUID
    ) {
        var items = chatMessagesByCrew[crewID] ?? []

        guard let index = items.firstIndex(where: { $0.id == localID }) else { return }

        let old = items[index]
        items[index] = CrewChatMessageItem(
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
            isFailed: true
        )

        chatMessagesByCrew[crewID] = sortAndTrimChatItems(items)
    }
    
    
    private func fetchInsertedMessage(
        crewID: UUID,
        clientID: String,
        currentUserID: UUID?
    ) async {
        do {
            let response = try await SupabaseManager.shared.client
                .from("crew_messages")
                .select()
                .eq("crew_id", value: crewID.uuidString)
                .eq("client_id", value: clientID)
                .order("created_at", ascending: false)
                .limit(1)
                .single()
                .execute()

            let dto = try JSONDecoder().decode(CrewMessageDTO.self, from: response.data)
            let item = mapDTOToChatItem(dto, currentUserID: currentUserID)

            replacePendingMessageByClientID(
                crewID: crewID,
                clientID: clientID,
                with: item
            )
        } catch {
            print("FETCH INSERTED MESSAGE ERROR:", error.localizedDescription)
        }
    }
    
    func shouldRefreshChat(for crewID: UUID, maxAge: TimeInterval = 60) -> Bool {
        guard let last = chatLastLoadedAtByCrew[crewID] else { return true }
        return Date().timeIntervalSince(last) > maxAge
    }

    
    // MARK: - Chat Load
    
    func loadNewerMessages(
        for crewID: UUID,
        currentUserID: UUID?
    ) async {
        guard let latest = chatMessagesByCrew[crewID]?.last?.createdAt else {
            await loadInitialChatMessages(for: crewID, currentUserID: currentUserID)
            return
        }

        do {
            let iso = CrewDateParser.string(from: latest)

            let response = try await SupabaseManager.shared.client
                .from("crew_messages")
                .select()
                .eq("crew_id", value: crewID.uuidString)
                .gt("created_at", value: iso)
                .order("created_at", ascending: true)
                .execute()

            let decoded = try JSONDecoder().decode([CrewMessageDTO].self, from: response.data)

            for dto in decoded {
                handleIncomingMessage(dto, currentUserID: currentUserID)
            }

            if !decoded.isEmpty {
                chatLastLoadedAtByCrew[crewID] = Date()
            }
        } catch {
            print("LOAD NEWER CREW MESSAGES ERROR:", error.localizedDescription)
        }
    }
    
    func subscribeToCrewAuxRealtime(crewID: UUID) {
        if subscribedAuxCrewID == crewID,
           crewTypingChannel != nil,
           crewReadsChannel != nil {
            return
        }

        if isSubscribingCrewAux {
            return
        }

        isSubscribingCrewAux = true

        let client = SupabaseManager.shared.client

        Task { @MainActor in
            if let existingTyping = crewTypingChannel {
                await existingTyping.unsubscribe()
            }

            if let existingReads = crewReadsChannel {
                await existingReads.unsubscribe()
            }

            crewTypingChannel = nil
            crewReadsChannel = nil
            subscribedAuxCrewID = nil

            let typingChannel = client.realtimeV2.channel("crew-typing-\(crewID.uuidString)")
            let readsChannel = client.realtimeV2.channel("crew-reads-\(crewID.uuidString)")

            _ = typingChannel.onPostgresChange(
                InsertAction.self,
                schema: "public",
                table: "crew_typing_status",
                filter: "crew_id=eq.\(crewID.uuidString)"
            ) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    await self.loadCrewTypingStatuses(for: crewID)
                }
            }

            _ = typingChannel.onPostgresChange(
                UpdateAction.self,
                schema: "public",
                table: "crew_typing_status",
                filter: "crew_id=eq.\(crewID.uuidString)"
            ) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    await self.loadCrewTypingStatuses(for: crewID)
                }
            }

            _ = readsChannel.onPostgresChange(
                InsertAction.self,
                schema: "public",
                table: "crew_message_reads",
                filter: "crew_id=eq.\(crewID.uuidString)"
            ) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    await self.loadCrewMessageReads(for: crewID)
                }
            }

            _ = readsChannel.onPostgresChange(
                UpdateAction.self,
                schema: "public",
                table: "crew_message_reads",
                filter: "crew_id=eq.\(crewID.uuidString)"
            ) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    await self.loadCrewMessageReads(for: crewID)
                }
            }

            crewTypingChannel = typingChannel
            crewReadsChannel = readsChannel
            subscribedAuxCrewID = crewID

            do {
                try await typingChannel.subscribeWithError()
                try await readsChannel.subscribeWithError()
            } catch {
                print("SUBSCRIBE CREW AUX CHANNEL ERROR:", error.localizedDescription)
                crewTypingChannel = nil
                crewReadsChannel = nil
                subscribedAuxCrewID = nil
            }

            isSubscribingCrewAux = false
        }
    }

    func unsubscribeCrewAuxRealtime() {
        let typingToUnsub = crewTypingChannel
        let readsToUnsub = crewReadsChannel
        crewTypingChannel = nil
        crewReadsChannel = nil
        subscribedAuxCrewID = nil
        isSubscribingCrewAux = false

        Task {
            await typingToUnsub?.unsubscribe()
            await readsToUnsub?.unsubscribe()
        }
    }

    func loadInitialChatMessages(
        for crewID: UUID,
        currentUserID: UUID?
    ) async {
        chatLoadingByCrew[crewID] = true
        defer { chatLoadingByCrew[crewID] = false }

        do {
            let response = try await SupabaseManager.shared.client
                .from("crew_messages")
                .select()
                .eq("crew_id", value: crewID.uuidString)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()

            let decoded = try JSONDecoder().decode([CrewMessageDTO].self, from: response.data)
            let items = decoded.reversed().map { mapDTOToChatItem($0, currentUserID: currentUserID) }

            setChatMessages(items, for: crewID, preserveExistingIfIncomingEmpty: true)
            chatLastLoadedAtByCrew[crewID] = Date()
            hasLoadedChatInitiallyByCrew[crewID] = true
        } catch {
            print("LOAD INITIAL CHAT MESSAGES ERROR:", error.localizedDescription)

            if chatMessagesByCrew[crewID] == nil {
                setChatMessages([], for: crewID, preserveExistingIfIncomingEmpty: false)
            }
        }
    }
    
    func loadInitialChatMessagesIfNeeded(
        for crewID: UUID,
        currentUserID: UUID?,
        force: Bool = false
    ) async {
        if !force,
           hasLoadedChatInitiallyByCrew[crewID] == true,
           shouldRefreshChat(for: crewID) == false,
           let cached = chatMessagesByCrew[crewID],
           !cached.isEmpty {
            return
        }

        await loadInitialChatMessages(for: crewID, currentUserID: currentUserID)
    }

    // MARK: - Chat Send

    func sendCrewMessageOptimistic(
        crewID: UUID,
        senderID: UUID?,
        senderName: String,
        text: String
    ) async {
        let localID = UUID()
        let clientID = UUID().uuidString

        let pendingItem = CrewChatMessageItem(
            id: localID,
            serverID: nil,
            clientID: clientID,
            crewID: crewID,
            senderID: senderID,
            senderName: senderName,
            text: text,
            createdAt: Date(),
            reaction: nil,
            isSystemMessage: false,
            isFromMe: true,
            isPending: true,
            isFailed: false
        )

        appendChatMessage(pendingItem, for: crewID)

        do {
            struct Payload: Encodable {
                let crew_id: UUID
                let sender_id: UUID?
                let sender_name: String
                let text: String
                let is_read: Bool
                let reaction: String?
                let client_id: String
            }

            let payload = Payload(
                crew_id: crewID,
                sender_id: senderID,
                sender_name: senderName,
                text: text,
                is_read: false,
                reaction: nil,
                client_id: clientID
            )

            try await SupabaseManager.shared.client
                .from("crew_messages")
                .insert(payload)
                .execute()

            await fetchInsertedMessage(
                crewID: crewID,
                clientID: clientID,
                currentUserID: senderID
            )

        } catch {
            print("SEND CREW MESSAGE OPTIMISTIC ERROR:", error.localizedDescription)
            markPendingMessageFailed(crewID: crewID, localID: localID)
        }
    }
    
    func markCrewMessagesAsRead(
        crewID: UUID,
        userID: UUID
    ) async {
        do {
            struct ReadPayload: Encodable {
                let crew_id: UUID
                let user_id: UUID
                let last_read_at: String
            }

            let payload = ReadPayload(
                crew_id: crewID,
                user_id: userID,
                last_read_at: CrewDateParser.string(from: Date())
            )

            try await SupabaseManager.shared.client
                .from("crew_message_reads")
                .upsert(payload, onConflict: "crew_id,user_id")
                .execute()
        } catch {
            print("MARK CREW MESSAGES AS READ ERROR:", error.localizedDescription)
        }
    }
    
    func sendTypingEvent(
        crewID: UUID,
        userID: UUID,
        name: String,
        isTyping: Bool
    ) async {
        if lastTypingStateByCrew[crewID] == isTyping {
            return
        }

        lastTypingStateByCrew[crewID] = isTyping

        struct TypingPayload: Encodable {
            let crew_id: UUID
            let user_id: UUID
            let name: String
            let is_typing: Bool
            let updated_at: String
        }

        let payload = TypingPayload(
            crew_id: crewID,
            user_id: userID,
            name: name,
            is_typing: isTyping,
            updated_at: CrewDateParser.string(from: Date())
        )

        do {
            try await SupabaseManager.shared.client
                .from("crew_typing_status")
                .upsert(payload, onConflict: "crew_id,user_id")
                .execute()
        } catch {
            print("SEND TYPING EVENT ERROR:", error.localizedDescription)
        }
    }
    
    func loadCrewTypingStatuses(for crewID: UUID) async {
        do {
            let response = try await SupabaseManager.shared.client
                .from("crew_typing_status")
                .select()
                .eq("crew_id", value: crewID.uuidString)
                .execute()

            let decoded = try JSONDecoder().decode([CrewTypingStatusDTO].self, from: response.data)

            crewTypingStatuses.removeAll { $0.crew_id == crewID }
            crewTypingStatuses.append(contentsOf: decoded)
        } catch {
            print("LOAD CREW TYPING STATUS ERROR:", error.localizedDescription)
        }
    }
    
    func loadCrewMessageReads(for crewID: UUID) async {
        do {
            let response = try await SupabaseManager.shared.client
                .from("crew_message_reads")
                .select()
                .eq("crew_id", value: crewID.uuidString)
                .execute()

            let decoded = try JSONDecoder().decode([CrewMessageReadDTO].self, from: response.data)
            crewMessageReads.removeAll { $0.crew_id == crewID }
            crewMessageReads.append(contentsOf: decoded)
        } catch {
            print("LOAD CREW MESSAGE READS ERROR:", error.localizedDescription)
        }
    }
    
    func completeCrewTaskAfterFocus(taskID: UUID, crewID: UUID) async throws {
        struct Payload: Encodable {
            let is_done: Bool
            let status: String
        }

        try await SupabaseManager.shared.client
            .from("crew_tasks")
            .update(
                Payload(
                    is_done: true,
                    status: "done"
                )
            )
            .eq("id", value: taskID.uuidString)
            .eq("crew_id", value: crewID.uuidString)
            .execute()

        await loadTasks(for: crewID)
        await loadTaskCount(for: crewID)
        await loadCompletedTaskCount(for: crewID)
    }

    func createCrewMessage(
        crewID: UUID,
        senderID: UUID?,
        senderName: String,
        text: String,
        isSystemMessage: Bool = false
    ) async throws {
        struct Payload: Encodable {
            let crew_id: UUID
            let sender_id: UUID?
            let sender_name: String
            let text: String
            let is_read: Bool
            let is_system_message: Bool
            let reaction: String?
            let client_id: String
        }

        let payload = Payload(
            crew_id: crewID,
            sender_id: senderID,
            sender_name: senderName,
            text: text,
            is_read: isSystemMessage,
            is_system_message: isSystemMessage,
            reaction: nil,
            client_id: UUID().uuidString
        )

        try await SupabaseManager.shared.client
            .from("crew_messages")
            .insert(payload)
            .execute()
    }

    // MARK: - Chat Realtime

    func subscribeToCrewMessagesRealtime(
        crewID: UUID,
        currentUserID: UUID?
    ) {
        if subscribedCrewMessageID == crewID, crewMessagesChannel != nil {
            return
        }

        if isSubscribingCrewMessages {
            return
        }

        isSubscribingCrewMessages = true

        let client = SupabaseManager.shared.client

        Task { @MainActor in
            // Race condition guard
            guard subscribedCrewMessageID != crewID else {
                isSubscribingCrewMessages = false
                return
            }

            if let existing = crewMessagesChannel {
                await existing.unsubscribe()
                crewMessagesChannel = nil
                subscribedCrewMessageID = nil
            }

            let channel = client.realtimeV2.channel("crew-messages-\(crewID.uuidString)")

            _ = channel.onPostgresChange(
                InsertAction.self,
                schema: "public",
                table: "crew_messages",
                filter: "crew_id=eq.\(crewID.uuidString)"
            ) { [weak self] action in
                guard let self else { return }
                Task { @MainActor in
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: action.record)
                        let dto = try JSONDecoder().decode(CrewMessageDTO.self, from: jsonData)
                        self.handleIncomingMessage(dto, currentUserID: currentUserID)
                    } catch {
                        print("CREW MESSAGE INSERT REALTIME DECODE ERROR:", error.localizedDescription)
                    }
                }
            }

            _ = channel.onPostgresChange(
                UpdateAction.self,
                schema: "public",
                table: "crew_messages",
                filter: "crew_id=eq.\(crewID.uuidString)"
            ) { [weak self] action in
                guard let self else { return }
                Task { @MainActor in
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: action.record)
                        let dto = try JSONDecoder().decode(CrewMessageDTO.self, from: jsonData)
                        self.handleIncomingMessage(dto, currentUserID: currentUserID)
                    } catch {
                        print("CREW MESSAGE UPDATE REALTIME DECODE ERROR:", error.localizedDescription)
                    }
                }
            }

            crewMessagesChannel = channel
            subscribedCrewMessageID = crewID

            do {
                try await channel.subscribeWithError()
            } catch {
                print("SUBSCRIBE CREW MESSAGE CHANNEL ERROR:", error.localizedDescription)
                crewMessagesChannel = nil
                subscribedCrewMessageID = nil
            }

            isSubscribingCrewMessages = false
        }
    }
    func unsubscribeCrewChat() {
        let channelToUnsub = crewMessagesChannel
        crewMessagesChannel = nil
        subscribedCrewMessageID = nil
        isSubscribingCrewMessages = false

        Task {
            await channelToUnsub?.unsubscribe()
        }
    }

    // MARK: - General Crew Realtime

    private func upsertLocalTask(_ task: CrewTaskDTO) {
        if let index = crewTasks.firstIndex(where: { $0.id == task.id }) {
            crewTasks[index] = task
        } else {
            crewTasks.insert(task, at: 0)
        }
    }

    private func removeLocalTask(taskID: UUID) {
        crewTasks.removeAll { $0.id == taskID }
    }
    
    func subscribeToCrewRealtime(crewID: UUID) {
        if subscribedCrewRealtimeID == crewID {
            return
        }

        let client = SupabaseManager.shared.client
        Task {
            await taskChannel?.unsubscribe()
            await memberChannel?.unsubscribe()
            await activityChannel?.unsubscribe()
            await focusChannel?.unsubscribe()
        }

        taskChannel = nil
        memberChannel = nil
        activityChannel = nil
        focusChannel = nil

        taskChannel = client.realtimeV2.channel("crew-tasks-\(crewID.uuidString)")
        memberChannel = client.realtimeV2.channel("crew-members-\(crewID.uuidString)")
        activityChannel = client.realtimeV2.channel("crew-activities-\(crewID.uuidString)")
        focusChannel = client.realtimeV2.channel("crew-focus-records-\(crewID.uuidString)")
        subscribedCrewRealtimeID = crewID

    

        _ = taskChannel?.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "crew_tasks",
            filter: "crew_id=eq.\(crewID.uuidString)"
        ) { [weak self] action in
            guard let self else { return }
            Task { @MainActor in
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: action.record)
                    let dto = try JSONDecoder().decode(CrewTaskDTO.self, from: jsonData)
                    self.upsertLocalTask(dto)
                    await self.refreshCrewStats(for: crewID)
                } catch {
                    print("CREW TASK INSERT REALTIME DECODE ERROR:", error.localizedDescription)
                    await self.loadTasks(for: crewID)
                }
            }
        }

        _ = taskChannel?.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "crew_tasks",
            filter: "crew_id=eq.\(crewID.uuidString)"
        ) { [weak self] action in
            guard let self else { return }
            Task { @MainActor in
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: action.record)
                    let dto = try JSONDecoder().decode(CrewTaskDTO.self, from: jsonData)
                    self.upsertLocalTask(dto)
                    await self.refreshCrewStats(for: crewID)
                } catch {
                    print("CREW TASK UPDATE REALTIME DECODE ERROR:", error.localizedDescription)
                    await self.loadTasks(for: crewID)
                }
            }
        }

        _ = taskChannel?.onPostgresChange(
            DeleteAction.self,
            schema: "public",
            table: "crew_tasks",
            filter: "crew_id=eq.\(crewID.uuidString)"
        ) { [weak self] action in
            guard let self else { return }
            Task { @MainActor in
                if let idString = action.oldRecord["id"] as? String,
                   let taskID = UUID(uuidString: idString) {
                    self.removeLocalTask(taskID: taskID)
                    await self.refreshCrewStats(for: crewID)
                } else {
                    print("CREW TASK DELETE REALTIME: task id not found in oldRecord")
                    await self.loadTasks(for: crewID)
                }
            }
        }

     _ =   memberChannel?.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "crew_members",
            filter: "crew_id=eq.\(crewID.uuidString)"
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                await self.loadMembers(for: crewID)
                await self.loadMemberProfiles(for: self.crewMembers)
                await self.loadMemberCount(for: crewID)
            }
        }

     _ =   memberChannel?.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "crew_members",
            filter: "crew_id=eq.\(crewID.uuidString)"
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                await self.loadMembers(for: crewID)
                await self.loadMemberProfiles(for: self.crewMembers)
                await self.loadMemberCount(for: crewID)
            }
        }

        _ =    memberChannel?.onPostgresChange(
            DeleteAction.self,
            schema: "public",
            table: "crew_members",
            filter: "crew_id=eq.\(crewID.uuidString)"
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                await self.loadMembers(for: crewID)
                await self.loadMemberProfiles(for: self.crewMembers)
                await self.loadMemberCount(for: crewID)
            }
        }

        _ =     activityChannel?.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "crew_activities",
            filter: "crew_id=eq.\(crewID.uuidString)"
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.loadActivities(for: crewID)
            }
        }

        _ =     activityChannel?.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "crew_activities",
            filter: "crew_id=eq.\(crewID.uuidString)"
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.loadActivities(for: crewID)
            }
        }

        _ =     activityChannel?.onPostgresChange(
            DeleteAction.self,
            schema: "public",
            table: "crew_activities",
            filter: "crew_id=eq.\(crewID.uuidString)"
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.loadActivities(for: crewID)
            }
        }

        _ =         focusChannel?.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "crew_focus_records",
            filter: "crew_id=eq.\(crewID.uuidString)"
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.loadFocusRecords(for: crewID)
            }
        }

        _ =      focusChannel?.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "crew_focus_records",
            filter: "crew_id=eq.\(crewID.uuidString)"
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.loadFocusRecords(for: crewID)
            }
        }

        _ =      focusChannel?.onPostgresChange(
            DeleteAction.self,
            schema: "public",
            table: "crew_focus_records",
            filter: "crew_id=eq.\(crewID.uuidString)"
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.loadFocusRecords(for: crewID)
            }
        }

        Task {
            
            try? await taskChannel?.subscribeWithError()
            try? await memberChannel?.subscribeWithError()
            try? await activityChannel?.subscribeWithError()
            try? await focusChannel?.subscribeWithError()
        }
    }

    func unsubscribe() {
        Task {
            
            await taskChannel?.unsubscribe()
            await memberChannel?.unsubscribe()
            await activityChannel?.unsubscribe()
            await focusChannel?.unsubscribe()
        }

        
        taskChannel = nil
        memberChannel = nil
        activityChannel = nil
        focusChannel = nil
        subscribedCrewRealtimeID = nil
    }

    // MARK: - Existing Loads / Actions

    func loadCrews(force: Bool = false) async {
        guard let currentUserID else {
            crews = []
            return
        }

        if hasLoadedCrews && !force {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Önce kullanıcının üye olduğu crew id'lerini al
            let memberResponse = try await SupabaseManager.shared.client
                .from("crew_members")
                .select("crew_id")
                .eq("user_id", value: currentUserID.uuidString)
                .execute()

            struct CrewMemberCrewIDDTO: Codable {
                let crew_id: UUID
            }

            let memberDecoded = try JSONDecoder().decode([CrewMemberCrewIDDTO].self, from: memberResponse.data)
            let crewIDs = memberDecoded.map(\.crew_id.uuidString)

            guard !crewIDs.isEmpty else {
                crews = []
                hasLoadedCrews = true
                return
            }

            let response = try await SupabaseManager.shared.client
                .from("crews")
                .select()
                .in("id", values: crewIDs)
                .order("created_at", ascending: false)
                .execute()

            let decoded = try JSONDecoder().decode([CrewDTO].self, from: response.data)
            crews = decoded
            hasLoadedCrews = true
        } catch {
            print("LOAD CREWS ERROR:", error.localizedDescription)
            crews = []
        }
    }
    func subscribeToCrewsListRealtime(for userID: UUID) {
        if subscribedCrewsListUserID == userID {
            return
        }

        let client = SupabaseManager.shared.client

        Task {
            await crewsListChannel?.unsubscribe()
            await crewsMemberListChannel?.unsubscribe()
            await crewsStatsTaskChannel?.unsubscribe()
            await crewsStatsMemberChannel?.unsubscribe()
        }

        crewsListChannel = nil
        crewsMemberListChannel = nil
        crewsStatsTaskChannel = nil
        crewsStatsMemberChannel = nil

        crewsListChannel = client.realtimeV2.channel("crews-list-\(userID.uuidString)")
        crewsMemberListChannel = client.realtimeV2.channel("crew-members-list-\(userID.uuidString)")
        crewsStatsTaskChannel = client.realtimeV2.channel("crews-stats-tasks-\(userID.uuidString)")
        crewsStatsMemberChannel = client.realtimeV2.channel("crews-stats-members-\(userID.uuidString)")
        subscribedCrewsListUserID = userID

        _ = crewsListChannel?.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "crews"
        ) { [weak self] action in
            guard let self else { return }
            Task { @MainActor in
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: action.record)
                    let dto = try JSONDecoder().decode(CrewDTO.self, from: jsonData)

                    if dto.owner_id == userID {
                        self.upsertLocalCrew(dto)
                        await self.refreshCrewStats(for: dto.id)
                    } else {
                        await self.loadCrews(force: true)
                        await self.loadStatsForAllCrews()
                    }
                } catch {
                    print("CREWS LIST INSERT REALTIME ERROR:", error.localizedDescription)
                }
            }
        }

        _ = crewsListChannel?.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "crews"
        ) { [weak self] action in
            guard let self else { return }
            Task { @MainActor in
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: action.record)
                    let dto = try JSONDecoder().decode(CrewDTO.self, from: jsonData)

                    if self.crews.contains(where: { $0.id == dto.id }) || dto.owner_id == userID {
                        self.upsertLocalCrew(dto)
                    }
                } catch {
                    print("CREWS LIST UPDATE REALTIME ERROR:", error.localizedDescription)
                }
            }
        }

        _ = crewsListChannel?.onPostgresChange(
            DeleteAction.self,
            schema: "public",
            table: "crews"
        ) { [weak self] action in
            guard let self else { return }
            Task { @MainActor in
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: action.oldRecord)
                    let dto = try JSONDecoder().decode(CrewDTO.self, from: jsonData)
                    self.removeLocalCrew(id: dto.id)
                } catch {
                    print("CREWS LIST DELETE REALTIME ERROR:", error.localizedDescription)
                }
            }
        }

        _ = crewsMemberListChannel?.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "crew_members",
            filter: "user_id=eq.\(userID.uuidString)"
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.loadCrews(force: true)
                await self.loadStatsForAllCrews()
            }
        }

        _ = crewsMemberListChannel?.onPostgresChange(
            DeleteAction.self,
            schema: "public",
            table: "crew_members",
            filter: "user_id=eq.\(userID.uuidString)"
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.loadCrews(force: true)
                await self.loadStatsForAllCrews()
            }
        }

        _ = crewsStatsTaskChannel?.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "crew_tasks"
        ) { [weak self] action in
            guard let self else { return }
            Task { @MainActor in
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: action.record)
                    let dto = try JSONDecoder().decode(CrewTaskDTO.self, from: jsonData)
                    await self.refreshStatsIfNeeded(for: dto.crew_id)
                } catch {
                    print("CREWS STATS TASK INSERT ERROR:", error.localizedDescription)
                }
            }
        }

        _ = crewsStatsTaskChannel?.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "crew_tasks"
        ) { [weak self] action in
            guard let self else { return }
            Task { @MainActor in
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: action.record)
                    let dto = try JSONDecoder().decode(CrewTaskDTO.self, from: jsonData)
                    await self.refreshStatsIfNeeded(for: dto.crew_id)
                } catch {
                    print("CREWS STATS TASK UPDATE ERROR:", error.localizedDescription)
                }
            }
        }

        _ = crewsStatsTaskChannel?.onPostgresChange(
            DeleteAction.self,
            schema: "public",
            table: "crew_tasks"
        ) { [weak self] action in
            guard let self else { return }
            Task { @MainActor in
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: action.oldRecord)
                    let dto = try JSONDecoder().decode(CrewTaskDTO.self, from: jsonData)
                    await self.refreshStatsIfNeeded(for: dto.crew_id)
                } catch {
                    print("CREWS STATS TASK DELETE ERROR:", error.localizedDescription)
                }
            }
        }

        _ = crewsStatsMemberChannel?.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "crew_members"
        ) { [weak self] action in
            guard let self else { return }
            Task { @MainActor in
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: action.record)
                    let dto = try JSONDecoder().decode(CrewMemberDTO.self, from: jsonData)
                    await self.refreshStatsIfNeeded(for: dto.crew_id)
                } catch {
                    print("CREWS STATS MEMBER INSERT ERROR:", error.localizedDescription)
                }
            }
        }

        _ = crewsStatsMemberChannel?.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "crew_members"
        ) { [weak self] action in
            guard let self else { return }
            Task { @MainActor in
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: action.record)
                    let dto = try JSONDecoder().decode(CrewMemberDTO.self, from: jsonData)
                    await self.refreshStatsIfNeeded(for: dto.crew_id)
                } catch {
                    print("CREWS STATS MEMBER UPDATE ERROR:", error.localizedDescription)
                }
            }
        }

        _ = crewsStatsMemberChannel?.onPostgresChange(
            DeleteAction.self,
            schema: "public",
            table: "crew_members"
        ) { [weak self] action in
            guard let self else { return }
            Task { @MainActor in
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: action.oldRecord)
                    let dto = try JSONDecoder().decode(CrewMemberDTO.self, from: jsonData)
                    await self.refreshStatsIfNeeded(for: dto.crew_id)
                } catch {
                    print("CREWS STATS MEMBER DELETE ERROR:", error.localizedDescription)
                }
            }
        }

        Task {
            try? await crewsListChannel?.subscribeWithError()
            try? await crewsMemberListChannel?.subscribeWithError()
            try? await crewsStatsTaskChannel?.subscribeWithError()
            try? await crewsStatsMemberChannel?.subscribeWithError()
        }
    }
    
    
    func unsubscribeCrewsListRealtime() {
        Task {
            await crewsListChannel?.unsubscribe()
            await crewsMemberListChannel?.unsubscribe()
            await crewsStatsTaskChannel?.unsubscribe()
            await crewsStatsMemberChannel?.unsubscribe()
        }

        crewsListChannel = nil
        crewsMemberListChannel = nil
        crewsStatsTaskChannel = nil
        crewsStatsMemberChannel = nil
        subscribedCrewsListUserID = nil
    }
    
    private func upsertLocalCrew(_ crew: CrewDTO) {
        if let index = crews.firstIndex(where: { $0.id == crew.id }) {
            crews[index] = crew
        } else {
            crews.insert(crew, at: 0)
        }
    }

    private func removeLocalCrew(id: UUID) {
        crews.removeAll { $0.id == id }
        memberCountByCrew[id] = nil
        taskCountByCrew[id] = nil
        completedTaskCountByCrew[id] = nil
    }
    
    private func refreshStatsIfNeeded(for crewID: UUID) async {
        guard crews.contains(where: { $0.id == crewID }) else { return }
        await refreshCrewStats(for: crewID)
    }
    
    func resetForUserChange() {
        crews = []
        crewMembers = []
        memberProfiles = []
        crewTasks = []
        memberCountByCrew = [:]
        taskCountByCrew = [:]
        completedTaskCountByCrew = [:]
        crewActivities = []
        crewFocusRecords = []
        crewMessageReads = []
        crewTypingStatuses = []
        chatMessagesByCrew = [:]
        activeFocusSessionByCrew = [:]
        focusParticipantsBySession = [:]
        chatMessagesByCrew = [:]
        chatLastLoadedAtByCrew = [:]
        hasLoadedChatInitiallyByCrew = [:]
        chatLoadingByCrew = [:]
        hasLoadedCrews = false

        unsubscribe()
        unsubscribeCrewChat()
        unsubscribeCrewAuxRealtime()
        unsubscribeCrewFocusRealtime()
        unsubscribeCrewsListRealtime()
    }

    func loadMembers(for crewID: UUID) async {
        do {
            let response = try await SupabaseManager.shared.client
                .from("crew_members")
                .select()
                .eq("crew_id", value: crewID.uuidString)
                .execute()

            let decoded = try JSONDecoder().decode([CrewMemberDTO].self, from: response.data)
            crewMembers = decoded
        } catch {
            print("LOAD MEMBERS ERROR:", error.localizedDescription)
        }
    }

    func loadMemberProfiles(for members: [CrewMemberDTO]) async {
        let ids = Array(Set(members.map { $0.user_id.uuidString }))

        guard !ids.isEmpty else {
            memberProfiles = []
            return
        }

        do {
            let response = try await SupabaseManager.shared.client
                .from("profiles")
                .select()
                .in("id", values: ids)
                .execute()

            let decoded = try JSONDecoder().decode([ProfileDTO].self, from: response.data)
            memberProfiles = decoded
        } catch {
            print("LOAD MEMBER PROFILES ERROR:", error.localizedDescription)
        }
    }

    func loadTasks(for crewID: UUID) async {
        do {
            let response = try await SupabaseManager.shared.client
                .from("crew_tasks")
                .select()
                .eq("crew_id", value: crewID.uuidString)
                .order("created_at", ascending: false)
                .execute()

            let decoded = try JSONDecoder().decode([CrewTaskDTO].self, from: response.data)
            crewTasks = decoded
        } catch {
            print("LOAD TASKS ERROR:", error.localizedDescription)
        }
    }

    func loadActivities(for crewID: UUID) async {
        do {
            let response = try await SupabaseManager.shared.client
                .from("crew_activities")
                .select()
                .eq("crew_id", value: crewID.uuidString)
                .order("created_at", ascending: false)
                .execute()

            let decoded = try JSONDecoder().decode([CrewActivityDTO].self, from: response.data)
            crewActivities = decoded
        } catch {
            print("LOAD ACTIVITIES ERROR:", error.localizedDescription)
        }
    }

    func loadFocusRecords(for crewID: UUID) async {
        do {
            let response = try await SupabaseManager.shared.client
                .from("crew_focus_records")
                .select()
                .eq("crew_id", value: crewID.uuidString)
                .order("created_at", ascending: false)
                .execute()

            let decoded = try JSONDecoder().decode([CrewFocusRecordDTO].self, from: response.data)
            crewFocusRecords = decoded
        } catch {
            print("LOAD FOCUS RECORDS ERROR:", error.localizedDescription)
        }
    }

    func loadMemberCount(for crewID: UUID) async {
        do {
            let response = try await SupabaseManager.shared.client
                .from("crew_members")
                .select("id", head: false, count: .exact)
                .eq("crew_id", value: crewID.uuidString)
                .execute()

            memberCountByCrew[crewID] = response.count ?? 0
        } catch {
            print("LOAD MEMBER COUNT ERROR:", error.localizedDescription)
            memberCountByCrew[crewID] = 0
        }
    }

    func loadTaskCount(for crewID: UUID) async {
        do {
            let response = try await SupabaseManager.shared.client
                .from("crew_tasks")
                .select("id", head: false, count: .exact)
                .eq("crew_id", value: crewID.uuidString)
                .execute()

            taskCountByCrew[crewID] = response.count ?? 0
        } catch {
            print("LOAD TASK COUNT ERROR:", error.localizedDescription)
            taskCountByCrew[crewID] = 0
        }
    }

    func loadCompletedTaskCount(for crewID: UUID) async {
        do {
            let response = try await SupabaseManager.shared.client
                .from("crew_tasks")
                .select("id", head: false, count: .exact)
                .eq("crew_id", value: crewID.uuidString)
                .eq("is_done", value: true)
                .execute()

            completedTaskCountByCrew[crewID] = response.count ?? 0
        } catch {
            print("LOAD COMPLETED TASK COUNT ERROR:", error.localizedDescription)
            completedTaskCountByCrew[crewID] = 0
        }
    }

    func loadStatsForAllCrews() async {
        for crew in crews {
            await loadMemberCount(for: crew.id)
            await loadTaskCount(for: crew.id)
            await loadCompletedTaskCount(for: crew.id)
        }
    }

    func createActivity(
        crewID: UUID,
        memberName: String,
        actionText: String
    ) async {
        do {
            try await SupabaseManager.shared.client
                .from("crew_activities")
                .insert([
                    "crew_id": crewID.uuidString,
                    "member_name": memberName,
                    "action_text": actionText
                ])
                .execute()
        } catch {
            print("CREATE ACTIVITY ERROR:", error.localizedDescription)
        }
    }

    func createFocusRecord(
        crewID: UUID,
        userID: UUID?,
        memberName: String,
        minutes: Int
    ) async {
        do {
            let payload = CreateFocusRecordPayload(
                crew_id: crewID.uuidString,
                user_id: userID?.uuidString,
                member_name: memberName,
                minutes: minutes
            )

            try await SupabaseManager.shared.client
                .from("crew_focus_records")
                .insert(payload)
                .execute()
        } catch {
            print("CREATE FOCUS RECORD ERROR:", error.localizedDescription)
        }
    }
    
    private func updateLocalTask(_ taskID: UUID, mutate: (inout CrewTaskDTO) -> Void) {
        guard let index = crewTasks.firstIndex(where: { $0.id == taskID }) else { return }
        mutate(&crewTasks[index])
    }

    func toggleTask(_ task: CrewTaskDTO) async {
        guard let index = crewTasks.firstIndex(where: { $0.id == task.id }) else { return }

        let oldTask = crewTasks[index]
        let newIsDone = !oldTask.is_done
        let newStatus = newIsDone ? "done" : "todo"

        struct ToggleTaskPayload: Encodable {
            let is_done: Bool
            let status: String
        }

        // 1) Animasyonlu optimistic local update
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            crewTasks[index].is_done = newIsDone
            crewTasks[index].status = newStatus
        }

        do {
            try await SupabaseManager.shared.client
                .from("crew_tasks")
                .update(
                    ToggleTaskPayload(
                        is_done: newIsDone,
                        status: newStatus
                    )
                )
                .eq("id", value: task.id.uuidString)
                .execute()

            let profile = memberProfiles.first(where: { $0.id == task.created_by })
            let actorName = profile?.full_name ?? profile?.username ?? "You"

            await createActivity(
                crewID: task.crew_id,
                memberName: actorName,
                actionText: newIsDone
                    ? "completed task \(task.title)"
                    : "reopened task \(task.title)"
            )

            await refreshCrewStats(for: task.crew_id)

        } catch {
            // 2) Hata olursa animasyonlu rollback
            withAnimation(.spring(response: 0.30, dampingFraction: 0.90)) {
                crewTasks[index] = oldTask
            }
            print("TOGGLE ERROR:", error.localizedDescription)
        }
    }
    func createTask(
        title: String,
        crewID: UUID,
        userID: UUID,
        assignedTo: UUID?,
        details: String = "",
        priority: String = "medium",
        status: String = "todo",
        showOnWeek: Bool = false,
        scheduledWeekday: Int? = nil,
        scheduledStartMinute: Int? = nil,
        scheduledDurationMinute: Int? = nil
    ) async throws {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)

        struct CreateTaskPayload: Encodable {
            let title: String
            let crew_id: UUID
            let created_by: UUID
            let assigned_to: UUID?
            let details: String
            let priority: String
            let status: String
            let show_on_week: Bool
            let scheduled_weekday: Int?
            let scheduled_start_minute: Int?
            let scheduled_duration_minute: Int?
        }

        let payload = CreateTaskPayload(
            title: clean,
            crew_id: crewID,
            created_by: userID,
            assigned_to: assignedTo,
            details: details,
            priority: priority,
            status: status,
            show_on_week: showOnWeek,
            scheduled_weekday: scheduledWeekday,
            scheduled_start_minute: scheduledStartMinute,
            scheduled_duration_minute: scheduledDurationMinute
        )

        let response = try await SupabaseManager.shared.client
            .from("crew_tasks")
            .insert(payload)
            .select()
            .single()
            .execute()

        let createdTask = try JSONDecoder().decode(CrewTaskDTO.self, from: response.data)
        upsertLocalTask(createdTask)

        let profile = memberProfiles.first(where: { $0.id == userID })
        let actorName = profile?.full_name ?? profile?.username ?? "You"

        await createActivity(
            crewID: crewID,
            memberName: actorName,
            actionText: "created task \(clean)"
        )

        await refreshCrewStats(for: crewID)
    }
    func updateTask(
        taskID: UUID,
        title: String,
        assignedTo: UUID?,
        isDone: Bool,
        details: String,
        priority: String,
        status: String,
        showOnWeek: Bool,
        scheduledWeekday: Int?,
        scheduledStartMinute: Int?,
        scheduledDurationMinute: Int?
    ) async throws {
        struct TaskUpdatePayload: Encodable {
            let title: String
            let assigned_to: UUID?
            let is_done: Bool
            let details: String
            let priority: String
            let status: String
            let show_on_week: Bool
            let scheduled_weekday: Int?
            let scheduled_start_minute: Int?
            let scheduled_duration_minute: Int?
        }

        try await SupabaseManager.shared.client
            .from("crew_tasks")
            .update(
                TaskUpdatePayload(
                    title: title,
                    assigned_to: assignedTo,
                    is_done: isDone,
                    details: details,
                    priority: priority,
                    status: status,
                    show_on_week: showOnWeek,
                    scheduled_weekday: scheduledWeekday,
                    scheduled_start_minute: scheduledStartMinute,
                    scheduled_duration_minute: scheduledDurationMinute
                )
            )
            .eq("id", value: taskID.uuidString)
            .execute()

        updateLocalTask(taskID) { task in
            task.title = title
            task.assigned_to = assignedTo
            task.is_done = isDone
            task.details = details
            task.priority = priority
            task.status = status
            task.show_on_week = showOnWeek
            task.scheduled_weekday = scheduledWeekday
            task.scheduled_start_minute = scheduledStartMinute
            task.scheduled_duration_minute = scheduledDurationMinute
        }

        if let crewID = crewTasks.first(where: { $0.id == taskID })?.crew_id {
            await refreshCrewStats(for: crewID)
        }
    }

    func deleteTask(taskID: UUID, crewID: UUID, title: String? = nil) async throws {
        try await SupabaseManager.shared.client
            .from("crew_tasks")
            .delete()
            .eq("id", value: taskID.uuidString)
            .execute()

        removeLocalTask(taskID: taskID)

        await createActivity(
            crewID: crewID,
            memberName: "You",
            actionText: "deleted task \(title ?? "")"
        )

        await refreshCrewStats(for: crewID)
    }

    func addMember(by username: String, to crewID: UUID) async throws {
        let cleanUsername = username
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanUsername.isEmpty else {
            throw NSError(
                domain: "CrewStore",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Username boş olamaz."]
            )
        }

        do {
            // 1) Username ile kullanıcıyı bul
            let userResponse = try await SupabaseManager.shared.client
                .from("profiles")
                .select("id, email, username, full_name")
                .eq("username", value: cleanUsername)
                .execute()

            let profiles = try JSONDecoder().decode([ProfileDTO].self, from: userResponse.data)

            guard let profile = profiles.first else {
                throw NSError(
                    domain: "CrewStore",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Bu username ile kullanıcı bulunamadı."]
                )
            }

            // 2) Zaten crew içinde mi kontrol et
            let existingResponse = try await SupabaseManager.shared.client
                .from("crew_members")
                .select()
                .eq("crew_id", value: crewID.uuidString)
                .eq("user_id", value: profile.id.uuidString)
                .execute()

            let existingMembers = try JSONDecoder().decode([CrewMemberDTO].self, from: existingResponse.data)

            if !existingMembers.isEmpty {
                throw NSError(
                    domain: "CrewStore",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Bu kullanıcı zaten crew içinde."]
                )
            }

            // 3) Üyeyi ekle
            try await SupabaseManager.shared.client
                .from("crew_members")
                .insert([
                    "crew_id": crewID.uuidString,
                    "user_id": profile.id.uuidString,
                    "role": "member"
                ])
                .execute()

            // 4) Refresh
            await loadMembers(for: crewID)
            await loadMemberProfiles(for: crewMembers)
            await refreshCrewStats(for: crewID)

        } catch {
            print("ADD MEMBER ERROR:", error.localizedDescription)
            throw error
        }
    }
    func createCrew(name: String, icon: String, colorHex: String, ownerID: UUID) async throws -> CrewDTO {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        let crewResponse = try await SupabaseManager.shared.client
            .from("crews")
            .insert([
                "owner_id": ownerID.uuidString,
                "name": cleanName,
                "icon": icon,
                "color_hex": colorHex
            ])
            .select()
            .single()
            .execute()

        let createdCrew = try JSONDecoder().decode(CrewDTO.self, from: crewResponse.data)

        try await SupabaseManager.shared.client
            .from("crew_members")
            .insert([
                "crew_id": createdCrew.id.uuidString,
                "user_id": ownerID.uuidString,
                "role": "owner"
            ])
            .execute()

        await loadCrews(force: true)
        await refreshCrewStats(for: createdCrew.id)

        return createdCrew
    }

    func joinCrew(with code: String, userID: UUID) async throws {
        let response = try await SupabaseManager.shared.client
            .from("crew_invites")
            .select()
            .eq("code", value: code.uppercased())
            .single()
            .execute()

        let invite = try JSONDecoder().decode(CrewInviteDTO.self, from: response.data)

        try await SupabaseManager.shared.client
            .from("crew_members")
            .insert([
                "crew_id": invite.crew_id.uuidString,
                "user_id": userID.uuidString,
                "role": "member"
            ])
            .execute()

        await loadCrews(force: true)
        await refreshCrewStats(for: invite.crew_id)
    }

    func createInvite(for crewID: UUID, userID: UUID) async throws -> String {
        let code = UUID().uuidString.prefix(6).uppercased()

        try await SupabaseManager.shared.client
            .from("crew_invites")
            .insert([
                "crew_id": crewID.uuidString,
                "code": String(code),
                "created_by": userID.uuidString
            ])
            .execute()

        return String(code)
    }

    struct CrewInviteDTO: Codable {
        let id: UUID
        let crew_id: UUID
        let code: String
    }
    func loadActiveFocusSession(for crewID: UUID) async {
        do {
            let response = try await SupabaseManager.shared.client
                .from("crew_focus_sessions")
                .select()
                .eq("crew_id", value: crewID.uuidString)
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .limit(3)
                .execute()

            let decoded = try JSONDecoder().decode([CrewFocusSessionDTO].self, from: response.data)

            let now = Date()

            let validSession = decoded.first(where: { session in
                guard session.is_active else { return false }
                if session.ended_at != nil { return false }

                if session.is_paused {
                    return (session.paused_remaining_seconds ?? 0) > 0
                }

                guard let startedAt = CrewDateParser.parse(session.started_at) else { return false }
                let endDate = startedAt.addingTimeInterval(TimeInterval(session.duration_minutes * 60))
                return endDate > now
            })

            if let validSession {
                activeFocusSessionByCrew[crewID] = validSession
            } else {
                activeFocusSessionByCrew.removeValue(forKey: crewID)
            }
        } catch {
            print("LOAD ACTIVE FOCUS SESSION ERROR:", error.localizedDescription)
            activeFocusSessionByCrew.removeValue(forKey: crewID)
        }
    }
    func loadFocusParticipants(sessionID: UUID) async {
        do {
            let response = try await SupabaseManager.shared.client
                .from("crew_focus_participants")
                .select()
                .eq("session_id", value: sessionID.uuidString)
                .eq("is_active", value: true)
                .order("joined_at", ascending: true)
                .execute()

            let decoded = try JSONDecoder().decode([CrewFocusParticipantDTO].self, from: response.data)
            focusParticipantsBySession[sessionID] = decoded
        } catch {
            print("LOAD FOCUS PARTICIPANTS ERROR:", error.localizedDescription)
            focusParticipantsBySession[sessionID] = []
        }
    }
    func startCrewFocusSession(
        crewID: UUID,
        hostUserID: UUID?,
        hostName: String,
        title: String,
        taskID: UUID?,
        taskTitle: String?,
        durationMinutes: Int
    ) async throws -> CrewFocusSessionDTO {
        let startedAt = Date()

        let payload = CreateCrewFocusSessionPayload(
            crew_id: crewID,
            host_user_id: hostUserID,
            host_name: hostName,
            title: title,
            task_id: taskID,
            task_title: taskTitle,
            duration_minutes: durationMinutes,
            started_at: CrewDateParser.string(from: startedAt),
            is_active: true,
            is_paused: false,
            paused_remaining_seconds: nil
        )

        let response = try await SupabaseManager.shared.client
            .from("crew_focus_sessions")
            .insert(payload)
            .select()
            .single()
            .execute()

        let session = try JSONDecoder().decode(CrewFocusSessionDTO.self, from: response.data)

        let participantPayload = CreateCrewFocusParticipantPayload(
            session_id: session.id,
            crew_id: crewID,
            user_id: hostUserID,
            member_name: hostName,
            joined_at: CrewDateParser.string(from: Date()),
            is_active: true
        )

        try await SupabaseManager.shared.client
            .from("crew_focus_participants")
            .insert(participantPayload)
            .execute()

        await loadActiveFocusSession(for: crewID)
        await loadFocusParticipants(sessionID: session.id)

        try await createCrewMessage(
            crewID: crewID,
            senderID: hostUserID,
            senderName: hostName,
            text: "started a \(durationMinutes) min shared focus session",
            isSystemMessage: true
        )

        await createActivity(
            crewID: crewID,
            memberName: hostName,
            actionText: "started a \(durationMinutes) min shared focus session"
        )

        return session
    }
    func joinCrewFocusSession(
        sessionID: UUID,
        crewID: UUID,
        userID: UUID?,
        memberName: String
    ) async throws {
        let response = try await SupabaseManager.shared.client
            .from("crew_focus_sessions")
            .select()
            .eq("id", value: sessionID.uuidString)
            .eq("crew_id", value: crewID.uuidString)
            .limit(1)
            .execute()

        let sessions = try JSONDecoder().decode([CrewFocusSessionDTO].self, from: response.data)

        guard let session = sessions.first else {
            activeFocusSessionByCrew.removeValue(forKey: crewID)
            throw NSError(
                domain: "CrewStore",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Focus session bulunamadı."]
            )
        }

        let now = Date()

        let isStillValid: Bool = {
            guard session.is_active else { return false }
            if session.ended_at != nil { return false }

            if session.is_paused {
                return (session.paused_remaining_seconds ?? 0) > 0
            }

            guard let startedAt = CrewDateParser.parse(session.started_at) else { return false }
            let endDate = startedAt.addingTimeInterval(TimeInterval(session.duration_minutes * 60))
            return endDate > now
        }()

        guard isStillValid else {
            activeFocusSessionByCrew.removeValue(forKey: crewID)
            focusParticipantsBySession.removeValue(forKey: sessionID)

            throw NSError(
                domain: "CrewStore",
                code: 410,
                userInfo: [NSLocalizedDescriptionKey: "Bu focus oturumu sona ermiş."]
            )
        }

        struct Payload: Encodable {
            let session_id: UUID
            let crew_id: UUID
            let user_id: UUID?
            let member_name: String
            let is_active: Bool
        }

        let payload = Payload(
            session_id: sessionID,
            crew_id: crewID,
            user_id: userID,
            member_name: memberName,
            is_active: true
        )

        try await SupabaseManager.shared.client
            .from("crew_focus_participants")
            .upsert(payload, onConflict: "session_id,crew_id,user_id")
            .execute()

        await loadActiveFocusSession(for: crewID)
        await loadFocusParticipants(sessionID: sessionID)

        try await createCrewMessage(
            crewID: crewID,
            senderID: userID,
            senderName: memberName,
            text: "joined the shared focus session",
            isSystemMessage: true
        )
    }
    func leaveCrewFocusSession(
        sessionID: UUID,
        crewID: UUID,
        userID: UUID?,
        memberName: String
    ) async throws {
        struct LeavePayload: Encodable {
            let is_active: Bool
            let left_at: String
        }

        let payload = LeavePayload(
            is_active: false,
            left_at: CrewDateParser.string(from: Date())
            )
        

        try await SupabaseManager.shared.client
            .from("crew_focus_participants")
            .update(payload)
            .eq("session_id", value: sessionID.uuidString)
            .eq("crew_id", value: crewID.uuidString)
            .eq("member_name", value: memberName)
            .eq("is_active", value: true)
            .execute()

        await loadFocusParticipants(sessionID: sessionID)
    }
    func pauseCrewFocusSession(
        sessionID: UUID,
        crewID: UUID,
        hostUserID: UUID?,
        hostName: String,
        pausedRemainingSeconds: Int
    ) async throws {
        struct PausePayload: Encodable {
            let is_paused: Bool
            let paused_remaining_seconds: Int
        }

        let payload = PausePayload(
            is_paused: true,
            paused_remaining_seconds: pausedRemainingSeconds
        )

        try await SupabaseManager.shared.client
            .from("crew_focus_sessions")
            .update(payload)
            .eq("id", value: sessionID.uuidString)
            .execute()

        await loadActiveFocusSession(for: crewID)

        try await createCrewMessage(
            crewID: crewID,
            senderID: hostUserID,
            senderName: hostName,
            text: "paused the shared focus session",
            isSystemMessage: true
        )
    }
    func resumeCrewFocusSession(
        sessionID: UUID,
        crewID: UUID,
        hostUserID: UUID?,
        hostName: String,
        durationMinutes: Int,
        pausedRemainingSeconds: Int
    ) async throws {
        struct ResumePayload: Encodable {
            let is_paused: Bool
            let paused_remaining_seconds: Int?
            let started_at: String
        }

        let totalSeconds = durationMinutes * 60
        let elapsedSeconds = max(0, totalSeconds - pausedRemainingSeconds)
        let newStartedAt = Date().addingTimeInterval(-TimeInterval(elapsedSeconds))

        let payload = ResumePayload(
            is_paused: false,
            paused_remaining_seconds: nil,
            started_at: CrewDateParser.string(from: newStartedAt)
        )

        try await SupabaseManager.shared.client
            .from("crew_focus_sessions")
            .update(payload)
            .eq("id", value: sessionID.uuidString)
            .execute()

        await loadActiveFocusSession(for: crewID)

        try await createCrewMessage(
            crewID: crewID,
            senderID: hostUserID,
            senderName: hostName,
            text: "resumed the shared focus session",
            isSystemMessage: true
        )
    }
    func endCrewFocusSession(
        sessionID: UUID,
        crewID: UUID,
        hostUserID: UUID?,
        hostName: String,
        completedMinutes: Int,
        participantNames: [String],
        taskID: UUID?
    ) async throws {
        struct EndPayload: Encodable {
            let is_active: Bool
            let is_paused: Bool
            let paused_remaining_seconds: Int?
            let ended_at: String
        }

        let nowString = CrewDateParser.string(from: Date())

        let endPayload = EndPayload(
            is_active: false,
            is_paused: false,
            paused_remaining_seconds: nil,
            ended_at: nowString
        )

        // 1) Önce session'ı kesin kapat
        try await SupabaseManager.shared.client
            .from("crew_focus_sessions")
            .update(endPayload)
            .eq("id", value: sessionID.uuidString)
            .execute()

        // 2) Önce local state'i yenile
        await loadActiveFocusSession(for: crewID)

        let endParticipantsPayload = EndCrewFocusParticipantPayload(
            is_active: false,
            left_at: nowString
        )

        // 3) Geri kalanları ayrı ayrı dene
        do {
            for participantName in participantNames {
                let matchingParticipant = focusParticipantsBySession[sessionID]?.first(where: {
                    $0.member_name == participantName
                })

                let recordPayload = CreateCrewFocusRecordPayloadV2(
                    crew_id: crewID,
                    user_id: matchingParticipant?.user_id,
                    member_name: participantName,
                    minutes: max(1, completedMinutes)
                )

                try await SupabaseManager.shared.client
                    .from("crew_focus_records")
                    .insert(recordPayload)
                    .execute()
            }
        } catch {
            print("END SESSION / FOCUS RECORD ERROR:", error.localizedDescription)
        }

        do {
            try await SupabaseManager.shared.client
                .from("crew_focus_participants")
                .update(endParticipantsPayload)
                .eq("session_id", value: sessionID.uuidString)
                .eq("crew_id", value: crewID.uuidString)
                .execute()
        } catch {
            print("END SESSION / PARTICIPANTS UPDATE ERROR:", error.localizedDescription)
        }

        if let taskID {
            do {
                try await completeCrewTaskAfterFocus(taskID: taskID, crewID: crewID)

                await createActivity(
                    crewID: crewID,
                    memberName: hostName,
                    actionText: "completed the focus task"
                )
            } catch {
                print("END SESSION / COMPLETE TASK ERROR:", error.localizedDescription)
            }
        }

        do {
            try await createCrewMessage(
                crewID: crewID,
                senderID: hostUserID,
                senderName: hostName,
                text: "ended the shared focus session",
                isSystemMessage: true
            )
        } catch {
            print("END SESSION / MESSAGE ERROR:", error.localizedDescription)
        }

        await createActivity(
            crewID: crewID,
            memberName: hostName,
            actionText: "completed a shared focus session"
        )

        activeFocusSessionByCrew.removeValue(forKey: crewID)
        focusParticipantsBySession.removeValue(forKey: sessionID)

        await loadActiveFocusSession(for: crewID)
        await loadFocusParticipants(sessionID: sessionID)
        await loadFocusRecords(for: crewID)
    }
    
    struct EndCrewFocusParticipantPayload: Encodable {
        let is_active: Bool
        let left_at: String
    }
    func subscribeToActiveFocusRealtime(crewID: UUID) {
        if subscribedFocusCrewID == crewID {
            return
        }

        let client = SupabaseManager.shared.client

        Task {
            await activeFocusChannel?.unsubscribe()
            await focusParticipantsChannel?.unsubscribe()
        }

        activeFocusChannel = nil
        focusParticipantsChannel = nil

        activeFocusChannel = client.realtimeV2.channel("crew-focus-session-\(crewID.uuidString)")
        focusParticipantsChannel = client.realtimeV2.channel("crew-focus-participants-\(crewID.uuidString)")
        subscribedFocusCrewID = crewID

       _ = activeFocusChannel?.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "crew_focus_sessions",
            filter: "crew_id=eq.\(crewID.uuidString)"
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.loadActiveFocusSession(for: crewID)
            }
        }

        _ =  activeFocusChannel?.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "crew_focus_sessions",
            filter: "crew_id=eq.\(crewID.uuidString)"
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.loadActiveFocusSession(for: crewID)
            }
        }

        _ =     activeFocusChannel?.onPostgresChange(
            DeleteAction.self,
            schema: "public",
            table: "crew_focus_sessions",
            filter: "crew_id=eq.\(crewID.uuidString)"
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.loadActiveFocusSession(for: crewID)
            }
        }

        _ =  focusParticipantsChannel?.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "crew_focus_participants",
            filter: "crew_id=eq.\(crewID.uuidString)"
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let session = self.activeFocusSessionByCrew[crewID] {
                    await self.loadFocusParticipants(sessionID: session.id)
                }
            }
        }

        _ =   focusParticipantsChannel?.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "crew_focus_participants",
            filter: "crew_id=eq.\(crewID.uuidString)"
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let session = self.activeFocusSessionByCrew[crewID] {
                    await self.loadFocusParticipants(sessionID: session.id)
                }
            }
        }

        _ =  focusParticipantsChannel?.onPostgresChange(
            DeleteAction.self,
            schema: "public",
            table: "crew_focus_participants",
            filter: "crew_id=eq.\(crewID.uuidString)"
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let session = self.activeFocusSessionByCrew[crewID] {
                    await self.loadFocusParticipants(sessionID: session.id)
                }
            }
        }

        Task {
          try? await activeFocusChannel?.subscribeWithError()
           try? await focusParticipantsChannel?.subscribeWithError()
        }
    }
    func unsubscribeCrewFocusRealtime() {
        Task {
            await activeFocusChannel?.unsubscribe()
            await focusParticipantsChannel?.unsubscribe()
        }

        activeFocusChannel = nil
        focusParticipantsChannel = nil
        subscribedFocusCrewID = nil
    }
    struct CreateCrewFocusSessionPayload: Encodable {
        let crew_id: UUID
        let host_user_id: UUID?
        let host_name: String
        let title: String
        let task_id: UUID?
        let task_title: String?
        let duration_minutes: Int
        let started_at: String
        let is_active: Bool
        let is_paused: Bool
        let paused_remaining_seconds: Int?
    }

    struct CreateCrewFocusParticipantPayload: Encodable {
        let session_id: UUID
        let crew_id: UUID
        let user_id: UUID?
        let member_name: String
        let joined_at: String
        let is_active: Bool
    }

    struct CreateCrewFocusRecordPayloadV2: Encodable {
        let crew_id: UUID
        let user_id: UUID?
        let member_name: String
        let minutes: Int
    }
}
