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
    @Published var crewHomeSnapshotByCrew: [UUID: CrewHomeSnapshotCrewDTO] = [:]
    @Published var totalFocusMinutesByCrew: [UUID: Int] = [:]
    @Published var weeklyFocusMinutesByCrew: [UUID: Int] = [:]
    @Published var activeParticipantCountByCrew: [UUID: Int] = [:]
    @Published var isLoadingCrewHomeSnapshot: Bool = false
    @Published var focusParticipantsBySession: [UUID: [CrewFocusParticipantDTO]] = [:]
    @Published private(set) var currentUserID: UUID?
    
    @Published var chatLastLoadedAtByCrew: [UUID: Date] = [:]
    @Published var hasLoadedChatInitiallyByCrew: [UUID: Bool] = [:]
    @Published var chatLoadingByCrew: [UUID: Bool] = [:]
    
    private var activeFocusChannel: RealtimeChannelV2?
    private var focusParticipantsChannel: RealtimeChannelV2?
    private var subscribedFocusCrewID: UUID?
    
    private var globalFocusChannel: RealtimeChannelV2?
    private var isSubscribingGlobalFocus = false
    private var didStartObservingFocusSocketEvents = false
    private var focusHomeRefreshTask: Task<Void, Never>?
    
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
        
        // Optimistic local remove
        crewMembers.removeAll { $0.id == member.id }
        
        let success = await CrewBackendClient.shared.removeMember(
            crewID: crewID,
            memberID: member.id
        )
        
        guard success else {
            // Rollback
            crewMembers = oldMembers
            Log.debug("REMOVE MEMBER ERROR: backend failed")
            throw NSError(
                domain: "CrewStore",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Failed to remove member."]
            )
        }
        
        await loadMembers(for: crewID)
        await loadMemberProfiles(for: crewMembers)
        await refreshCrewStats(for: crewID)
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
        
        // Optimistic update için yedek
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
        
        // Optimistic UI update
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
        
        // Realtime subscription'ları kapat (Supabase realtime için)
        if subscribedCrewRealtimeID == crewID {
            unsubscribe()
        }
        
        if subscribedCrewMessageID == crewID {
            unsubscribeCrewChat()
        }
        
        if subscribedFocusCrewID == crewID {
            unsubscribeCrewFocusRealtime()
        }
        
        // Backend ÇAĞRISI — CASCADE FK ile tüm bağımlı kayıtlar otomatik silinir
        let success = await CrewBackendClient.shared.deleteCrew(crewID: crewID)
        
        if success {
            Log.debug("✅ CREW DELETED:", crewID.uuidString)
            return
        }
        
        // Backend hatası → rollback
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
        
        throw NSError(
            domain: "CrewStore",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "Failed to delete crew."]
        )
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
            Log.debug("FETCH INSERTED MESSAGE ERROR:", error.localizedDescription)
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
            Log.debug("LOAD NEWER CREW MESSAGES ERROR:", error.localizedDescription)
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
                Log.debug("SUBSCRIBE CREW AUX CHANNEL ERROR:", error.localizedDescription)
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
            Log.debug("LOAD INITIAL CHAT MESSAGES ERROR:", error.localizedDescription)
            
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
            
            await incrementUnreadCountsForOthers(
                crewID: crewID,
                senderID: senderID
            )
            
            await fetchInsertedMessage(
                crewID: crewID,
                clientID: clientID,
                currentUserID: senderID
            )
            
            await updateCrewLastMessageMetadata(
                crewID: crewID,
                text: text,
                senderID: senderID
            )
            
            await incrementUnreadForOthers(
                crewID: crewID,
                senderID: senderID
            )
            
        } catch {
            Log.debug("SEND CREW MESSAGE OPTIMISTIC ERROR:", error.localizedDescription)
            markPendingMessageFailed(crewID: crewID, localID: localID)
        }
    }
    
    func incrementUnreadCountsForOthers(
        crewID: UUID,
        senderID: UUID?
    ) async {
        guard let senderID else { return }
        
        do {
            try await SupabaseManager.shared.client.rpc(
                "increment_crew_unread_counts",
                params: [
                    "p_crew_id": crewID.uuidString,
                    "p_sender_id": senderID.uuidString
                ]
            ).execute()
        } catch {
            Log.debug("INCREMENT CREW UNREAD ERROR:", error.localizedDescription)
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
            Log.debug("MARK CREW MESSAGES AS READ ERROR:", error.localizedDescription)
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
            Log.debug("SEND TYPING EVENT ERROR:", error.localizedDescription)
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
            Log.debug("LOAD CREW TYPING STATUS ERROR:", error.localizedDescription)
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
            Log.debug("LOAD CREW MESSAGE READS ERROR:", error.localizedDescription)
        }
    }
    
    func completeCrewTaskAfterFocus(taskID: UUID, crewID: UUID) async throws {
        _ = try await CrewBackendClient.shared.completeTaskAfterFocus(
            taskID: taskID,
            crewID: crewID
        )
        
        await loadTasks(for: crewID)
        await loadTaskCount(for: crewID)
        // loadCompletedTaskCount loadTaskCount içinde dolduruluyor, ekstra çağrıya gerek yok
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
        
        await updateCrewLastMessageMetadata(
            crewID: crewID,
            text: text,
            senderID: senderID
        )
        
        await incrementUnreadForOthers(
            crewID: crewID,
            senderID: senderID
        )
        
        guard !isSystemMessage else { return }
        
        let crewName = crews.first(where: { $0.id == crewID })?.name ?? "Crew"
        
        let targetMembers = crewMembers.filter {
            $0.crew_id == crewID &&
            $0.user_id != senderID &&
            $0.is_muted != true
        }
        
        for member in targetMembers {
            PushService.shared.sendCrewMessagePush(
                toUserId: member.user_id.uuidString,
                crewID: crewID.uuidString,
                crewName: crewName,
                message: "\(senderName): \(text)",
                badge: max(1, (member.unread_count ?? 0) + 1)
            )
        }
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
                        Log.debug("CREW MESSAGE INSERT REALTIME DECODE ERROR:", error.localizedDescription)
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
                        Log.debug("CREW MESSAGE UPDATE REALTIME DECODE ERROR:", error.localizedDescription)
                    }
                }
            }
            
            crewMessagesChannel = channel
            subscribedCrewMessageID = crewID
            
            do {
                try await channel.subscribeWithError()
            } catch {
                Log.debug("SUBSCRIBE CREW MESSAGE CHANNEL ERROR:", error.localizedDescription)
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
        if subscribedCrewRealtimeID == crewID,
           taskChannel != nil,
           memberChannel != nil,
           activityChannel != nil,
           focusChannel != nil {
            return
        }
        
        let oldTaskChannel = taskChannel
        let oldMemberChannel = memberChannel
        let oldActivityChannel = activityChannel
        let oldFocusChannel = focusChannel
        
        taskChannel = nil
        memberChannel = nil
        activityChannel = nil
        focusChannel = nil
        subscribedCrewRealtimeID = nil
        
        Task { @MainActor in
            await oldTaskChannel?.unsubscribe()
            await oldMemberChannel?.unsubscribe()
            await oldActivityChannel?.unsubscribe()
            await oldFocusChannel?.unsubscribe()
            
            let client = SupabaseManager.shared.client
            
            let newTaskChannel = client.realtimeV2.channel("crew-tasks-\(crewID.uuidString)")
            let newMemberChannel = client.realtimeV2.channel("crew-members-\(crewID.uuidString)")
            let newActivityChannel = client.realtimeV2.channel("crew-activities-\(crewID.uuidString)")
            let newFocusChannel = client.realtimeV2.channel("crew-focus-records-\(crewID.uuidString)")
            
            _ = newTaskChannel.onPostgresChange(
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
                        Log.debug("CREW TASK INSERT REALTIME DECODE ERROR:", error.localizedDescription)
                        await self.loadTasks(for: crewID)
                    }
                }
            }
            
            _ = newTaskChannel.onPostgresChange(
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
                        Log.debug("CREW TASK UPDATE REALTIME DECODE ERROR:", error.localizedDescription)
                        await self.loadTasks(for: crewID)
                    }
                }
            }
            
            _ = newTaskChannel.onPostgresChange(
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
                        Log.debug("CREW TASK DELETE REALTIME: task id not found in oldRecord")
                        await self.loadTasks(for: crewID)
                    }
                }
            }
            
            _ = newMemberChannel.onPostgresChange(
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
            
            _ = newMemberChannel.onPostgresChange(
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
            
            _ = newMemberChannel.onPostgresChange(
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
            
            _ = newActivityChannel.onPostgresChange(
                InsertAction.self,
                schema: "public",
                table: "crew_activities",
                filter: "crew_id=eq.\(crewID.uuidString)"
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.loadActivities(for: crewID)
                }
            }
            
            _ = newActivityChannel.onPostgresChange(
                UpdateAction.self,
                schema: "public",
                table: "crew_activities",
                filter: "crew_id=eq.\(crewID.uuidString)"
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.loadActivities(for: crewID)
                }
            }
            
            _ = newActivityChannel.onPostgresChange(
                DeleteAction.self,
                schema: "public",
                table: "crew_activities",
                filter: "crew_id=eq.\(crewID.uuidString)"
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.loadActivities(for: crewID)
                }
            }
            
            _ = newFocusChannel.onPostgresChange(
                InsertAction.self,
                schema: "public",
                table: "crew_focus_records",
                filter: "crew_id=eq.\(crewID.uuidString)"
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.loadFocusRecords(for: crewID)
                }
            }
            
            _ = newFocusChannel.onPostgresChange(
                UpdateAction.self,
                schema: "public",
                table: "crew_focus_records",
                filter: "crew_id=eq.\(crewID.uuidString)"
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.loadFocusRecords(for: crewID)
                }
            }
            
            _ = newFocusChannel.onPostgresChange(
                DeleteAction.self,
                schema: "public",
                table: "crew_focus_records",
                filter: "crew_id=eq.\(crewID.uuidString)"
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.loadFocusRecords(for: crewID)
                }
            }
            
            taskChannel = newTaskChannel
            memberChannel = newMemberChannel
            activityChannel = newActivityChannel
            focusChannel = newFocusChannel
            subscribedCrewRealtimeID = crewID
            
            do {
                try await newTaskChannel.subscribeWithError()
                try await newMemberChannel.subscribeWithError()
                try await newActivityChannel.subscribeWithError()
                try await newFocusChannel.subscribeWithError()
                
                Log.debug("✅ CREW REALTIME SUBSCRIBED:", crewID.uuidString)
            } catch {
                Log.debug("CREW REALTIME SUBSCRIBE ERROR:", error.localizedDescription)
                
                await newTaskChannel.unsubscribe()
                await newMemberChannel.unsubscribe()
                await newActivityChannel.unsubscribe()
                await newFocusChannel.unsubscribe()
                
                if subscribedCrewRealtimeID == crewID {
                    taskChannel = nil
                    memberChannel = nil
                    activityChannel = nil
                    focusChannel = nil
                    subscribedCrewRealtimeID = nil
                }
            }
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
    
    func subscribeToGlobalFocusRealtime() {
        if globalFocusChannel != nil || isSubscribingGlobalFocus {
            return
        }

        isSubscribingGlobalFocus = true

        let client = SupabaseManager.shared.client
        let channel = client.realtimeV2.channel("global-focus-home")

        _ = channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "crew_focus_sessions"
        ) { [weak self] action in
            guard let self else { return }

            Task { @MainActor in
                do {
                    let session = try self.decodeRealtimeRecord(
                        action.record,
                        as: CrewFocusSessionDTO.self
                    )

                    self.upsertActiveFocusSessionForHome(session)

                    if self.focusParticipantsBySession[session.id] == nil {
                        await self.loadFocusParticipants(sessionID: session.id)
                    }
                } catch {
                    Log.debug("GLOBAL FOCUS SESSION INSERT DECODE ERROR:", error.localizedDescription)
                    self.scheduleCrewHomeFocusRefresh()
                }
            }
        }

        _ = channel.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "crew_focus_sessions"
        ) { [weak self] action in
            guard let self else { return }

            Task { @MainActor in
                do {
                    let session = try self.decodeRealtimeRecord(
                        action.record,
                        as: CrewFocusSessionDTO.self
                    )

                    self.upsertActiveFocusSessionForHome(session)

                    if self.focusParticipantsBySession[session.id] == nil,
                       self.activeFocusSessionByCrew[session.crew_id] != nil {
                        await self.loadFocusParticipants(sessionID: session.id)
                    }

                    if session.ended_at != nil || session.is_active == false {
                        await self.loadFocusRecords(for: session.crew_id)
                    }
                } catch {
                    Log.debug("GLOBAL FOCUS SESSION UPDATE DECODE ERROR:", error.localizedDescription)
                    self.scheduleCrewHomeFocusRefresh()
                }
            }
        }

        _ = channel.onPostgresChange(
            DeleteAction.self,
            schema: "public",
            table: "crew_focus_sessions"
        ) { [weak self] action in
            guard let self else { return }

            Task { @MainActor in
                do {
                    let session = try self.decodeRealtimeRecord(
                        action.oldRecord,
                        as: CrewFocusSessionDTO.self
                    )

                    self.removeActiveFocusSessionForHome(session)
                } catch {
                    Log.debug("GLOBAL FOCUS SESSION DELETE DECODE ERROR:", error.localizedDescription)
                    self.scheduleCrewHomeFocusRefresh()
                }
            }
        }

        _ = channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "crew_focus_participants"
        ) { [weak self] action in
            guard let self else { return }

            Task { @MainActor in
                do {
                    let participant = try self.decodeRealtimeRecord(
                        action.record,
                        as: CrewFocusParticipantDTO.self
                    )

                    self.upsertFocusParticipantForHome(participant)
                } catch {
                    Log.debug("GLOBAL FOCUS PARTICIPANT INSERT DECODE ERROR:", error.localizedDescription)
                    self.scheduleCrewHomeFocusRefresh()
                }
            }
        }

        _ = channel.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "crew_focus_participants"
        ) { [weak self] action in
            guard let self else { return }

            Task { @MainActor in
                do {
                    let participant = try self.decodeRealtimeRecord(
                        action.record,
                        as: CrewFocusParticipantDTO.self
                    )

                    self.upsertFocusParticipantForHome(participant)
                } catch {
                    Log.debug("GLOBAL FOCUS PARTICIPANT UPDATE DECODE ERROR:", error.localizedDescription)
                    self.scheduleCrewHomeFocusRefresh()
                }
            }
        }

        _ = channel.onPostgresChange(
            DeleteAction.self,
            schema: "public",
            table: "crew_focus_participants"
        ) { [weak self] action in
            guard let self else { return }

            Task { @MainActor in
                do {
                    let participant = try self.decodeRealtimeRecord(
                        action.oldRecord,
                        as: CrewFocusParticipantDTO.self
                    )

                    self.removeFocusParticipantForHome(
                        sessionID: participant.session_id,
                        userID: participant.user_id
                    )
                } catch {
                    Log.debug("GLOBAL FOCUS PARTICIPANT DELETE DECODE ERROR:", error.localizedDescription)
                    self.scheduleCrewHomeFocusRefresh()
                }
            }
        }

        globalFocusChannel = channel

        Task { @MainActor in
            do {
                try await channel.subscribeWithError()
                Log.debug("✅ GLOBAL FOCUS HOME REALTIME SUBSCRIBED")
            } catch {
                Log.debug("GLOBAL FOCUS HOME REALTIME SUBSCRIBE ERROR:", error.localizedDescription)
                globalFocusChannel = nil
            }

            isSubscribingGlobalFocus = false
        }
    }
    
    func reloadAllActiveSessions() async {
        for crew in crews {
            await loadActiveFocusSession(for: crew.id)
        }
    }
    
    func reloadAllParticipants() async {
        for (_, session) in activeFocusSessionByCrew {
            await loadFocusParticipants(sessionID: session.id)
        }
    }
    // MARK: - Crew Home Realtime Optimization

    private func isValidActiveFocusSession(_ session: CrewFocusSessionDTO) -> Bool {
        guard session.is_active else { return false }
        guard session.ended_at == nil else { return false }

        if session.is_paused {
            return (session.paused_remaining_seconds ?? 0) > 0
        }

        guard let startedAt = CrewDateParser.parse(session.started_at) else {
            return false
        }

        let endDate = startedAt.addingTimeInterval(
            TimeInterval(session.duration_minutes * 60)
        )

        return endDate > Date()
    }

    private func upsertActiveFocusSessionForHome(_ session: CrewFocusSessionDTO) {
        if isValidActiveFocusSession(session) {
            activeFocusSessionByCrew[session.crew_id] = session
        } else {
            activeFocusSessionByCrew.removeValue(forKey: session.crew_id)
            focusParticipantsBySession.removeValue(forKey: session.id)
        }
    }

    private func removeActiveFocusSessionForHome(_ session: CrewFocusSessionDTO) {
        activeFocusSessionByCrew.removeValue(forKey: session.crew_id)
        focusParticipantsBySession.removeValue(forKey: session.id)
    }

    private func upsertFocusParticipantForHome(_ participant: CrewFocusParticipantDTO) {
        guard participant.is_active else {
            removeFocusParticipantForHome(
                sessionID: participant.session_id,
                userID: participant.user_id
            )
            return
        }

        var participants = focusParticipantsBySession[participant.session_id] ?? []

        if let userID = participant.user_id,
           let index = participants.firstIndex(where: { $0.user_id == userID }) {
            participants[index] = participant
        } else if let index = participants.firstIndex(where: { $0.id == participant.id }) {
            participants[index] = participant
        } else {
            participants.append(participant)
        }

        focusParticipantsBySession[participant.session_id] = participants
    }

    private func removeFocusParticipantForHome(
        sessionID: UUID,
        userID: UUID?
    ) {
        guard var participants = focusParticipantsBySession[sessionID] else { return }

        if let userID {
            participants.removeAll { $0.user_id == userID }
        } else {
            participants.removeAll { !$0.is_active }
        }

        focusParticipantsBySession[sessionID] = participants
    }

    private func decodeRealtimeRecord<T: Decodable>(
        _ record: [String: Any],
        as type: T.Type
    ) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: record)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func scheduleCrewHomeFocusRefresh(
        crewID: UUID? = nil,
        delayNanoseconds: UInt64 = 350_000_000
    ) {
        focusHomeRefreshTask?.cancel()

        focusHomeRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self else { return }

                Task { @MainActor in
                    if let crewID {
                        await self.loadActiveFocusSession(for: crewID)

                        if let session = self.activeFocusSessionByCrew[crewID] {
                            await self.loadFocusParticipants(sessionID: session.id)
                        }

                        await self.loadFocusRecords(for: crewID)
                    } else {
                        await self.loadFocusStateForAllCrews()
                    }
                }
            }
        }
    }
    // MARK: - Crew Home Snapshot

    func loadCrewHomeSnapshot() async {
        guard !isLoadingCrewHomeSnapshot else { return }

        isLoadingCrewHomeSnapshot = true
        defer { isLoadingCrewHomeSnapshot = false }

        guard let snapshot = await CrewBackendClient.shared.getCrewHomeSnapshot() else {
            return
        }

        applyCrewHomeSnapshot(snapshot)
    }

    private func applyCrewHomeSnapshot(_ snapshot: CrewHomeSnapshotDTO) {
        var nextSnapshotByCrew: [UUID: CrewHomeSnapshotCrewDTO] = [:]
        var nextTotalFocus: [UUID: Int] = totalFocusMinutesByCrew
        var nextWeeklyFocus: [UUID: Int] = weeklyFocusMinutesByCrew
        var nextActiveParticipantCount: [UUID: Int] = activeParticipantCountByCrew

        for item in snapshot.crews {
            let crewID = item.crew_id

            nextSnapshotByCrew[crewID] = item

            memberCountByCrew[crewID] = max(item.member_count, 0)
            taskCountByCrew[crewID] = max(item.task_count, 0)
            completedTaskCountByCrew[crewID] = max(item.completed_task_count, 0)

            nextTotalFocus[crewID] = max(item.total_focus_minutes, 0)
            nextWeeklyFocus[crewID] = max(item.weekly_focus_minutes, 0)
            nextActiveParticipantCount[crewID] = max(item.active_participant_count, 0)

            if let activeSession = item.active_session {
                activeFocusSessionByCrew[crewID] = activeSession
            } else {
                if let oldSession = activeFocusSessionByCrew[crewID] {
                    focusParticipantsBySession.removeValue(forKey: oldSession.id)
                }

                activeFocusSessionByCrew.removeValue(forKey: crewID)
            }

            if let currentUserID,
               let index = crewMembers.firstIndex(where: {
                   $0.crew_id == crewID && $0.user_id == currentUserID
               }) {
                crewMembers[index].unread_count = item.unread_count
                crewMembers[index].is_pinned = item.is_pinned
                crewMembers[index].is_muted = item.is_muted
                crewMembers[index].is_archived = item.is_archived
            }
        }

        crewHomeSnapshotByCrew = nextSnapshotByCrew
        totalFocusMinutesByCrew = nextTotalFocus
        weeklyFocusMinutesByCrew = nextWeeklyFocus
        activeParticipantCountByCrew = nextActiveParticipantCount
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
        
        let backendCrews = await CrewBackendClient.shared.listCrews()
        crews = backendCrews
        hasLoadedCrews = true
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
                    Log.debug("CREWS LIST INSERT REALTIME ERROR:", error.localizedDescription)
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
                    Log.debug("CREWS LIST UPDATE REALTIME ERROR:", error.localizedDescription)
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
                    Log.debug("CREWS LIST DELETE REALTIME ERROR:", error.localizedDescription)
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
                    Log.debug("CREWS STATS TASK INSERT ERROR:", error.localizedDescription)
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
                    Log.debug("CREWS STATS TASK UPDATE ERROR:", error.localizedDescription)
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
                    Log.debug("CREWS STATS TASK DELETE ERROR:", error.localizedDescription)
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
                    Log.debug("CREWS STATS MEMBER INSERT ERROR:", error.localizedDescription)
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
                    Log.debug("CREWS STATS MEMBER UPDATE ERROR:", error.localizedDescription)
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
                    Log.debug("CREWS STATS MEMBER DELETE ERROR:", error.localizedDescription)
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
        crewHomeSnapshotByCrew = [:]
        totalFocusMinutesByCrew = [:]
        weeklyFocusMinutesByCrew = [:]
        activeParticipantCountByCrew = [:]
        isLoadingCrewHomeSnapshot = false
        chatMessagesByCrew = [:]
        chatLastLoadedAtByCrew = [:]
        hasLoadedChatInitiallyByCrew = [:]
        chatLoadingByCrew = [:]
        hasLoadedCrews = false

        unsubscribe()
        unsubscribeCrewChat()
        unsubscribeCrewAuxRealtime()
        unsubscribeCrewFocusRealtime()
        unsubscribeGlobalFocusRealtime()
        unsubscribeCrewsListRealtime()
    }
    
    func loadMembers(for crewID: UUID) async {
        let members = await CrewBackendClient.shared.listMembers(crewID: crewID)
        
        crewMembers.removeAll { $0.crew_id == crewID }
        crewMembers.append(contentsOf: members)
        
        memberCountByCrew[crewID] = members.count
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
            Log.debug("LOAD MEMBER PROFILES ERROR:", error.localizedDescription)
        }
    }
    
    func loadTasks(for crewID: UUID) async {
        let tasks = await CrewBackendClient.shared.listTasks(crewID: crewID)
        
        crewTasks.removeAll { $0.crew_id == crewID }
        crewTasks.append(contentsOf: tasks)
        
        taskCountByCrew[crewID] = tasks.count
        completedTaskCountByCrew[crewID] = tasks.filter { $0.is_done }.count
    }
    
    func loadActivities(for crewID: UUID) async {
        let activities = await CrewBackendClient.shared.listActivities(crewID: crewID)
        
        crewActivities.removeAll { $0.crew_id == crewID }
        crewActivities.append(contentsOf: activities)
    }
    
    func loadFocusRecords(for crewID: UUID) async {
        let records = await CrewBackendClient.shared.listFocusRecords(crewID: crewID)
        
        crewFocusRecords.removeAll { $0.crew_id == crewID }
        crewFocusRecords.append(contentsOf: records)
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
            Log.debug("LOAD MEMBER COUNT ERROR:", error.localizedDescription)
            memberCountByCrew[crewID] = 0
        }
    }
    
    func loadTaskCount(for crewID: UUID) async {
        let counts = await CrewBackendClient.shared.taskCounts(crewID: crewID)
        taskCountByCrew[crewID] = counts.total
        completedTaskCountByCrew[crewID] = counts.completed
    }
    
    func loadCompletedTaskCount(for crewID: UUID) async {
        // loadTaskCount zaten hem total hem completed dolduruyor (tek query)
        // Bu fonksiyon eski API uyumluluğu için duruyor — aynı işi yapar
        let counts = await CrewBackendClient.shared.taskCounts(crewID: crewID)
        taskCountByCrew[crewID] = counts.total
        completedTaskCountByCrew[crewID] = counts.completed
    }
    
    func loadHomeCacheForAllCrews() async {
        let targetCrews = crews

        guard !targetCrews.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            for crew in targetCrews {
                group.addTask { [weak self] in
                    guard let self else { return }

                    await self.loadMembers(for: crew.id)
                    await self.loadTaskCount(for: crew.id)
                    await self.loadFocusRecords(for: crew.id)
                    await self.loadActiveFocusSession(for: crew.id)

                    if let session = await MainActor.run(body: {
                        self.activeFocusSessionByCrew[crew.id]
                    }) {
                        await self.loadFocusParticipants(sessionID: session.id)
                    }
                }
            }
        }
    }
    
    func loadStatsForAllCrews() async {
        let targetCrews = crews

        guard !targetCrews.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            for crew in targetCrews {
                group.addTask { [weak self] in
                    guard let self else { return }

                    await self.loadMemberCount(for: crew.id)
                    await self.loadTaskCount(for: crew.id)
                }
            }
        }
    }
    
    
    
    func loadFocusStateForAllCrews() async {
        for crew in crews {
            await loadActiveFocusSession(for: crew.id)
            
            if let session = activeFocusSessionByCrew[crew.id] {
                await loadFocusParticipants(sessionID: session.id)
            }
            
            await loadFocusRecords(for: crew.id)
        }
    }
    
    func reconcileFocusCompletionFromNotification(
        payload: [AnyHashable: Any]
    ) async {
        let rawCrewID =
            payload["crew_id"] as? String ??
            payload["crewID"] as? String

        guard let rawCrewID,
              let crewID = UUID(uuidString: rawCrewID) else {
            await loadCrewHomeSnapshot()
            await loadFocusStateForAllCrews()
            return
        }

        let rawSessionID =
            payload["session_id"] as? String ??
            payload["sessionID"] as? String

        let sessionID = rawSessionID.flatMap { UUID(uuidString: $0) }

        if let sessionID {
            focusParticipantsBySession.removeValue(forKey: sessionID)
        }

        activeFocusSessionByCrew.removeValue(forKey: crewID)

        await loadActiveFocusSession(for: crewID)

        if let activeSession = activeFocusSessionByCrew[crewID] {
            await loadFocusParticipants(sessionID: activeSession.id)
        }

        await loadFocusRecords(for: crewID)
        await loadCrewHomeSnapshot()
    }
    
    func loadCurrentUserMembershipsForHome() async {
        guard let currentUserID else { return }
        
        let crewIDs = crews.map(\.id.uuidString)
        
        guard !crewIDs.isEmpty else {
            crewMembers = []
            return
        }
        
        do {
            let response = try await SupabaseManager.shared.client
                .from("crew_members")
                .select()
                .eq("user_id", value: currentUserID.uuidString)
                .in("crew_id", values: crewIDs)
                .execute()
            
            let decoded = try JSONDecoder().decode([CrewMemberDTO].self, from: response.data)
            
            let otherCrewMembers = crewMembers.filter { member in
                !crewIDs.contains(member.crew_id.uuidString) || member.user_id != currentUserID
            }
            
            crewMembers = otherCrewMembers + decoded
        } catch {
            Log.debug("LOAD CURRENT USER MEMBERSHIPS FOR HOME ERROR:", error.localizedDescription)
        }
    }
    
    func createActivity(
        crewID: UUID,
        memberName: String,
        actionText: String
    ) async {
        _ = await CrewBackendClient.shared.createActivity(
            crewID: crewID,
            memberName: memberName,
            actionText: actionText
        )
    }
    
    func createFocusRecord(
        crewID: UUID,
        userID: UUID?,
        memberName: String,
        minutes: Int
    ) async {
        _ = await CrewBackendClient.shared.createFocusRecord(
            crewID: crewID,
            userID: userID,
            memberName: memberName,
            minutes: minutes
        )
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
        
        // 1) Animasyonlu optimistic local update
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            crewTasks[index].is_done = newIsDone
            crewTasks[index].status = newStatus
        }
        
        do {
            // Backend toggle — server otomatik flip yapar (atomic)
            let updatedTask = try await CrewBackendClient.shared.toggleTask(taskID: task.id)
            
            // Server'dan dönen kesin değer ile senkronize et
            if let i = crewTasks.firstIndex(where: { $0.id == updatedTask.id }) {
                crewTasks[i] = updatedTask
            }
            
            // Activity log
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
            Log.debug("TOGGLE ERROR:", error.localizedDescription)
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
        
        let createdTask = try await CrewBackendClient.shared.createTask(
            crewID: crewID,
            title: clean,
            assignedTo: assignedTo,
            details: details,
            priority: priority,
            status: status,
            showOnWeek: showOnWeek,
            scheduledWeekday: scheduledWeekday,
            scheduledStartMinute: scheduledStartMinute,
            scheduledDurationMinute: scheduledDurationMinute
        )
        
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
        _ = try await CrewBackendClient.shared.updateTask(
            taskID: taskID,
            title: title,
            assignedTo: assignedTo,
            isDone: isDone,
            details: details,
            priority: priority,
            status: status,
            showOnWeek: showOnWeek,
            scheduledWeekday: scheduledWeekday,
            scheduledStartMinute: scheduledStartMinute,
            scheduledDurationMinute: scheduledDurationMinute
        )
        
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
        let success = await CrewBackendClient.shared.deleteTask(taskID: taskID)
        
        guard success else {
            throw NSError(
                domain: "CrewStore",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Failed to delete task."]
            )
        }
        
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
                userInfo: [NSLocalizedDescriptionKey: tr("cs_username_empty")]
            )
        }
        
        do {
            _ = try await CrewBackendClient.shared.addMember(
                crewID: crewID,
                username: cleanUsername
            )
            
            // Refresh
            await loadMembers(for: crewID)
            await loadMemberProfiles(for: crewMembers)
            await refreshCrewStats(for: crewID)
            
        } catch let error as CrewBackendClientError {
            // Türkçe hata mesajları (backend İngilizce dönüyor)
            let message: String
            switch error {
            case .apiError(let raw):
                if raw.contains("no user with this username") {
                    message = tr("cs_user_not_found")
                } else if raw.contains("already a member") {
                    message = tr("cs_already_member")
                } else if raw.contains("Unauthorized") {
                    message = tr("cs_no_permission")
                } else {
                    message = raw
                }
            default:
                message = error.localizedDescription
            }
            
            throw NSError(
                domain: "CrewStore",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        } catch {
            Log.debug("ADD MEMBER ERROR:", error.localizedDescription)
            throw error
        }
    }
    func createCrew(name: String, icon: String, colorHex: String, ownerID: UUID) async throws -> CrewDTO {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let createdCrew = await CrewBackendClient.shared.createCrew(
            name: cleanName,
            icon: icon,
            colorHex: colorHex
        ) else {
            throw NSError(
                domain: "CrewStore",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create crew."]
            )
        }
        
        await loadCrews(force: true)
        await refreshCrewStats(for: createdCrew.id)
        
        return createdCrew
    }
    
    func joinCrew(with code: String, userID: UUID) async throws {
        let crewID = try await CrewBackendClient.shared.acceptInvite(code: code)
        
        await loadCrews(force: true)
        await refreshCrewStats(for: crewID)
    }
    
    func createInvite(for crewID: UUID, userID: UUID) async throws -> String {
        let code = try await CrewBackendClient.shared.createInvite(crewID: crewID)
        return code
    }
    
    struct CrewInviteDTO: Codable {
        let id: UUID
        let crew_id: UUID
        let code: String
    }
    func loadActiveFocusSession(for crewID: UUID) async {
        let session = await CrewBackendClient.shared.getActiveFocusSession(crewID: crewID)
     
        if let session {
            // Backend zaten "validity" kontrollerini yapıyor (paused remaining > 0,
            // ended_at null, vs.). Yine de iOS tarafı için ek validity kontrolü:
            let now = Date()
     
            let isStillValid: Bool = {
                guard session.is_active else { return false }
                guard session.ended_at == nil else { return false }
     
                if session.is_paused {
                    return (session.paused_remaining_seconds ?? 0) > 0
                }
     
                guard let startedAt = CrewDateParser.parse(session.started_at) else { return false }
                let endDate = startedAt.addingTimeInterval(
                    TimeInterval(session.duration_minutes * 60)
                )
                return endDate > now
            }()
     
            if isStillValid {
                activeFocusSessionByCrew[crewID] = session
            } else {
                activeFocusSessionByCrew.removeValue(forKey: crewID)
                // İlişkili participant cache'i de temizle
                for (key, value) in focusParticipantsBySession {
                    if value.first?.crew_id == crewID {
                        focusParticipantsBySession.removeValue(forKey: key)
                    }
                }
            }
        } else {
            activeFocusSessionByCrew.removeValue(forKey: crewID)
            for (key, value) in focusParticipantsBySession {
                if value.first?.crew_id == crewID {
                    focusParticipantsBySession.removeValue(forKey: key)
                }
            }
        }
    }
    func loadFocusParticipants(sessionID: UUID) async {
        let participants = await CrewBackendClient.shared.listFocusParticipants(sessionID: sessionID)
        focusParticipantsBySession[sessionID] = participants
    }
    
    func startCrewFocusSession(
        crewID: UUID,
        hostUserID: UUID?,
        hostName: String,
        title: String,
        taskID: UUID?,
        taskTitle: String?,
        durationMinutes: Int,
        participantCount: Int
    ) async throws -> CrewFocusSessionDTO {
        let session = try await CrewBackendClient.shared.startFocusSession(
            crewID: crewID,
            hostName: hostName,
            title: title,
            taskID: taskID,
            taskTitle: taskTitle,
            durationMinutes: durationMinutes,
            participantCount: participantCount
        )
     
        // Local state update (broadcast da gelecek ama anlık ihtiyaç için)
        activeFocusSessionByCrew[crewID] = session
        await loadFocusParticipants(sessionID: session.id)
     
       
     
        // Activity (Railway)
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
        do {
            _ = try await CrewBackendClient.shared.joinFocusSession(
                sessionID: sessionID,
                crewID: crewID,
                memberName: memberName
            )
        } catch let error as CrewBackendClientError {
            if case .apiError(let message) = error,
               message.contains("session has ended") || message.contains("does not exist") {
                activeFocusSessionByCrew.removeValue(forKey: crewID)
                focusParticipantsBySession.removeValue(forKey: sessionID)

                throw NSError(
                    domain: "CrewStore",
                    code: 410,
                    userInfo: [NSLocalizedDescriptionKey: tr("cs_session_ended")]
                )
            }

            throw error
        }

        await loadActiveFocusSession(for: crewID)
        await loadFocusParticipants(sessionID: sessionID)

        let participants = focusParticipantsBySession[sessionID] ?? []
        let activeParticipantIDs = participants.compactMap { dto -> UUID? in
            guard dto.is_active else { return nil }
            return dto.user_id
        }

        let crewName = crews.first(where: { $0.id == crewID })?.name ?? "Crew"

        await FocusInviteService.shared.sendJoinedNotifications(
            crewID: crewID,
            crewName: crewName,
            sessionID: sessionID,
            joinedUserID: userID,
            joinedName: memberName,
            activeParticipantIDs: activeParticipantIDs
        )

        await createActivity(
            crewID: crewID,
            memberName: memberName,
            actionText: "joined the shared focus session"
        )
    }
    func leaveCrewFocusSession(
        sessionID: UUID,
        crewID: UUID,
        userID: UUID?,
        memberName: String
    ) async throws {
        let success = await CrewBackendClient.shared.leaveFocusSession(
            sessionID: sessionID,
            crewID: crewID
        )
     
        guard success else {
            throw NSError(
                domain: "CrewStore",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Failed to leave focus session."]
            )
        }
     
        await loadFocusParticipants(sessionID: sessionID)
    }
    func beginWaitingCrewFocusSession(
        sessionID: UUID,
        crewID: UUID
    ) async throws {
        let session = try await CrewBackendClient.shared.beginWaitingFocusSession(
            sessionID: sessionID,
            crewID: crewID
        )
     
        activeFocusSessionByCrew[crewID] = session
        await loadFocusParticipants(sessionID: session.id)
    }
    
    func pauseCrewFocusSession(
        sessionID: UUID,
        crewID: UUID,
        hostUserID: UUID?,
        hostName: String,
        pausedRemainingSeconds: Int
    ) async throws {
        let session = try await CrewBackendClient.shared.pauseFocusSession(
            sessionID: sessionID,
            crewID: crewID,
            pausedRemainingSeconds: pausedRemainingSeconds
        )
     
        activeFocusSessionByCrew[crewID] = session
     
       
    }
    func resumeCrewFocusSession(
        sessionID: UUID,
        crewID: UUID,
        hostUserID: UUID?,
        hostName: String,
        durationMinutes: Int,
        pausedRemainingSeconds: Int
    ) async throws {
        let session = try await CrewBackendClient.shared.resumeFocusSession(
            sessionID: sessionID,
            crewID: crewID,
            durationMinutes: durationMinutes,
            pausedRemainingSeconds: pausedRemainingSeconds
        )
     
        activeFocusSessionByCrew[crewID] = session
     
      
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
        // Eski cached participant'lar — eğer participantNames boşsa fallback
        let cachedParticipants = focusParticipantsBySession[sessionID] ?? []
     
        let cleanedNames = participantNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
     
        let finalNames = cleanedNames.isEmpty
            ? cachedParticipants.map(\.member_name)
            : cleanedNames
     
        // Backend ATOMİK transaction:
        //   1) session.is_active = false, ended_at set
        //   2) tüm aktif participant'ları kapat
        //   3) her participant için focus_record yaz
        _ = try await CrewBackendClient.shared.endFocusSession(
            sessionID: sessionID,
            crewID: crewID,
            hostUserID: hostUserID,
            hostName: hostName,
            completedMinutes: completedMinutes,
            participantNames: finalNames
        )
     
        // Task tamamlama (eğer focus bir task ile başlatılmışsa)
        if let taskID {
            do {
                try await completeCrewTaskAfterFocus(taskID: taskID, crewID: crewID)
     
                await createActivity(
                    crewID: crewID,
                    memberName: hostName,
                    actionText: "completed the focus task"
                )
            } catch {
                Log.debug("END SESSION / COMPLETE TASK ERROR:", error.localizedDescription)
            }
        }
     
       
     
        // Activity
        await createActivity(
            crewID: crewID,
            memberName: hostName,
            actionText: "completed a shared focus session"
        )
     
        // Local cleanup
        activeFocusSessionByCrew.removeValue(forKey: crewID)
        focusParticipantsBySession.removeValue(forKey: sessionID)
     
        // Final refresh
        await loadActiveFocusSession(for: crewID)
        await loadFocusRecords(for: crewID)
        await loadCrewHomeSnapshot()
    }
    func updateCrewLastMessageMetadata(
        crewID: UUID,
        text: String,
        senderID: UUID?
    ) async {
        struct Payload: Encodable {
            let last_message_text: String
            let last_message_at: String
            let last_sender_id: UUID?
        }
        
        let payload = Payload(
            last_message_text: text,
            last_message_at: CrewDateParser.string(from: Date()),
            last_sender_id: senderID
        )
        
        do {
            try await SupabaseManager.shared.client
                .from("crews")
                .update(payload)
                .eq("id", value: crewID.uuidString)
                .execute()
            
            await loadCrews(force: true)
            
        } catch {
            Log.debug("UPDATE LAST MESSAGE ERROR:", error.localizedDescription)
        }
    }
    
    func startObservingFocusSocketEvents() {
        guard !didStartObservingFocusSocketEvents else { return }
        didStartObservingFocusSocketEvents = true

        let nc = NotificationCenter.default
     
        // Session lifecycle events
        nc.addObserver(
            forName: .crewFocusSessionStarted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleFocusSessionEvent(notification: notification)
            }
        }
     
        nc.addObserver(
            forName: .crewFocusSessionBegun,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleFocusSessionEvent(notification: notification)
            }
        }
     
        nc.addObserver(
            forName: .crewFocusSessionPaused,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleFocusSessionEvent(notification: notification)
            }
        }
     
        nc.addObserver(
            forName: .crewFocusSessionResumed,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleFocusSessionEvent(notification: notification)
            }
        }
     
        nc.addObserver(
            forName: .crewFocusSessionEnded,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleFocusSessionEndedEvent(notification: notification)
            }
        }
     
        // Participant events
        nc.addObserver(
            forName: .crewFocusParticipantJoined,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleFocusParticipantJoinedEvent(notification: notification)
            }
        }
     
        nc.addObserver(
            forName: .crewFocusParticipantLeft,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleFocusParticipantLeftEvent(notification: notification)
            }
        }
        
        nc.addObserver(
               forName: .crewTaskCreated,
               object: nil,
               queue: .main
           ) { [weak self] notification in
               Task { @MainActor in
                   self?.handleTaskCreatedEvent(notification: notification)
               }
           }
        
           nc.addObserver(
               forName: .crewTaskUpdated,
               object: nil,
               queue: .main
           ) { [weak self] notification in
               Task { @MainActor in
                   self?.handleTaskUpdatedEvent(notification: notification)
               }
           }
        
           nc.addObserver(
               forName: .crewTaskToggled,
               object: nil,
               queue: .main
           ) { [weak self] notification in
               Task { @MainActor in
                   self?.handleTaskUpdatedEvent(notification: notification)
               }
           }
        
           nc.addObserver(
               forName: .crewTaskCompletedAfterFocus,
               object: nil,
               queue: .main
           ) { [weak self] notification in
               Task { @MainActor in
                   self?.handleTaskUpdatedEvent(notification: notification)
               }
           }
        
           nc.addObserver(
               forName: .crewTaskDeleted,
               object: nil,
               queue: .main
           ) { [weak self] notification in
               Task { @MainActor in
                   self?.handleTaskDeletedEvent(notification: notification)
               }
           }
        nc.addObserver(
               forName: .crewActivityCreated,
               object: nil,
               queue: .main
           ) { [weak self] notification in
               Task { @MainActor in
                   self?.handleActivityCreatedEvent(notification: notification)
               }
           }
        
           // ─────────────────────────────────────────────────────────────────
           // Members (REFRESH)
           // ─────────────────────────────────────────────────────────────────
        
           nc.addObserver(
               forName: .crewMemberAdded,
               object: nil,
               queue: .main
           ) { [weak self] notification in
               Task { @MainActor in
                   self?.handleMemberChangedEvent(notification: notification)
               }
           }
        
           nc.addObserver(
               forName: .crewMemberRemoved,
               object: nil,
               queue: .main
           ) { [weak self] notification in
               Task { @MainActor in
                   self?.handleMemberChangedEvent(notification: notification)
               }
           }
        
           nc.addObserver(
               forName: .crewMemberUpdated,
               object: nil,
               queue: .main
           ) { [weak self] notification in
               Task { @MainActor in
                   self?.handleMemberUpdatedEvent(notification: notification)
               }
           }
        
           // ─────────────────────────────────────────────────────────────────
           // Focus Records (REFRESH)
           // ─────────────────────────────────────────────────────────────────
        
           nc.addObserver(
               forName: .crewFocusRecordCreated,
               object: nil,
               queue: .main
           ) { [weak self] notification in
               Task { @MainActor in
                   self?.handleFocusRecordCreatedEvent(notification: notification)
               }
           }
    }
     
    // MARK: - Event Handlers
     
    @MainActor
    private func handleFocusSessionEvent(notification: Notification) {
        guard
            let session = notification.userInfo?["session"] as? CrewFocusSessionDTO
        else { return }
     
        activeFocusSessionByCrew[session.crew_id] = session
     
        // Participants'ı da yenile
        Task { @MainActor in
            await self.loadFocusParticipants(sessionID: session.id)
        }
    }
     
    @MainActor
    private func handleFocusSessionEndedEvent(notification: Notification) {
        guard
            let session = notification.userInfo?["session"] as? CrewFocusSessionDTO
        else { return }
     
        // End event'i — local cleanup
        activeFocusSessionByCrew.removeValue(forKey: session.crew_id)
        focusParticipantsBySession.removeValue(forKey: session.id)
     
        // Focus records yenile
        Task { @MainActor in
            await self.loadFocusRecords(for: session.crew_id)
            await self.loadCrewHomeSnapshot()
        }
    }
     
    @MainActor
    private func handleFocusParticipantJoinedEvent(notification: Notification) {
        guard
            let sessionID = notification.userInfo?["sessionID"] as? UUID,
            let participant = notification.userInfo?["participant"] as? CrewFocusParticipantDTO
        else { return }
     
        var participants = focusParticipantsBySession[sessionID] ?? []
     
        // Idempotent: aynı user_id varsa güncelle, yoksa ekle
        if let index = participants.firstIndex(where: {
            $0.user_id == participant.user_id && $0.user_id != nil
        }) {
            participants[index] = participant
        } else {
            participants.append(participant)
        }
     
        focusParticipantsBySession[sessionID] = participants
    }
     
    @MainActor
    private func handleFocusParticipantLeftEvent(notification: Notification) {
        guard
            let sessionID = notification.userInfo?["sessionID"] as? UUID,
            let userID = notification.userInfo?["userID"] as? UUID
        else { return }

        // Participant'ı kaldır (DTO immutable olduğu için soft remove yapamayız)
        if var participants = focusParticipantsBySession[sessionID] {
            participants.removeAll { $0.user_id == userID }
            focusParticipantsBySession[sessionID] = participants
        }
    }
    
    // MARK: - Task Event Handlers (Granular)
     
    @MainActor
    private func handleTaskCreatedEvent(notification: Notification) {
        guard let task = notification.userInfo?["task"] as? CrewTaskDTO else { return }
     
        // Idempotent: zaten varsa güncelle, yoksa ekle
        upsertLocalTask(task)
     
        // Sayımları senkron et (kendi local listenin sayımı)
        let tasksInCrew = crewTasks.filter { $0.crew_id == task.crew_id }
        taskCountByCrew[task.crew_id] = tasksInCrew.count
        completedTaskCountByCrew[task.crew_id] = tasksInCrew.filter { $0.is_done }.count
    }
     
    @MainActor
    private func handleTaskUpdatedEvent(notification: Notification) {
        guard let task = notification.userInfo?["task"] as? CrewTaskDTO else { return }
     
        upsertLocalTask(task)
     
        // Sayımları senkron et (is_done değişmiş olabilir)
        let tasksInCrew = crewTasks.filter { $0.crew_id == task.crew_id }
        completedTaskCountByCrew[task.crew_id] = tasksInCrew.filter { $0.is_done }.count
    }
     
    @MainActor
    private func handleTaskDeletedEvent(notification: Notification) {
        guard
            let taskID = notification.userInfo?["taskID"] as? UUID,
            let crewID = notification.userInfo?["crewID"] as? UUID
        else { return }
     
        removeLocalTask(taskID: taskID)
     
        // Sayımları senkron et
        let tasksInCrew = crewTasks.filter { $0.crew_id == crewID }
        taskCountByCrew[crewID] = tasksInCrew.count
        completedTaskCountByCrew[crewID] = tasksInCrew.filter { $0.is_done }.count
    }
     
    // MARK: - Activity Event Handlers (Refresh)
     
    @MainActor
    private func handleActivityCreatedEvent(notification: Notification) {
        guard let activity = notification.userInfo?["activity"] as? CrewActivityDTO else { return }
     
        // Granular ekle: aynı id varsa atla
        if !crewActivities.contains(where: { $0.id == activity.id }) {
            // En başa ekle (yeni → eski sırada)
            crewActivities.insert(activity, at: 0)
        }
    }
     
    // MARK: - Member Event Handlers (Refresh)
     
    @MainActor
    private func handleMemberChangedEvent(notification: Notification) {
        // Add veya Remove — her ikisi de refresh ile basitçe halloluyor
        // Member event'leri öyle sık olmaz, ekstra HTTP zararsız.
     
        // Hangi crew'a ait?
        var targetCrewID: UUID?
     
        if let member = notification.userInfo?["member"] as? CrewMemberDTO {
            targetCrewID = member.crew_id
        } else if let crewID = notification.userInfo?["crewID"] as? UUID {
            targetCrewID = crewID
        }
     
        guard let crewID = targetCrewID else { return }
     
        Task { @MainActor in
            await self.loadMembers(for: crewID)
            await self.loadMemberProfiles(for: self.crewMembers)
            await self.loadMemberCount(for: crewID)
        }
    }
     
    @MainActor
    private func handleMemberUpdatedEvent(notification: Notification) {
        guard let member = notification.userInfo?["member"] as? CrewMemberDTO else { return }
     
        // Sadece kendi state'imiz değiştiyse lokal güncelle
        // (Diğer kullanıcıların pin/mute/archive durumu bizi ilgilendirmez)
        guard let currentUserID, member.user_id == currentUserID else { return }
     
        if let index = crewMembers.firstIndex(where: {
            $0.crew_id == member.crew_id && $0.user_id == currentUserID
        }) {
            crewMembers[index] = member
        }
    }
     
    // MARK: - Focus Record Event Handlers (Refresh)
     
    @MainActor
    private func handleFocusRecordCreatedEvent(notification: Notification) {
        guard let record = notification.userInfo?["record"] as? CrewFocusRecordDTO else { return }

        if !crewFocusRecords.contains(where: { $0.id == record.id }) {
            crewFocusRecords.insert(record, at: 0)

            totalFocusMinutesByCrew[record.crew_id, default: 0] += max(record.minutes, 0)
            weeklyFocusMinutesByCrew[record.crew_id, default: 0] += max(record.minutes, 0)
        }
    }
    
    func incrementUnreadForOthers(
        crewID: UUID,
        senderID: UUID?
    ) async {
        guard let senderID else { return }
        
        let others = crewMembers.filter {
            $0.crew_id == crewID && $0.user_id != senderID
        }
        
        for member in others {
            let current = member.unread_count ?? 0
            
            do {
                try await SupabaseManager.shared.client
                    .from("crew_members")
                    .update(["unread_count": current + 1])
                    .eq("id", value: member.id.uuidString)
                    .execute()
            } catch {
                Log.debug("UNREAD INCREMENT ERROR:", error.localizedDescription)
            }
        }
    }
    
    func resetUnreadCount(
        crewID: UUID,
        userID: UUID
    ) async {
        
        struct Payload: Encodable {
            let unread_count: Int
            let last_read_at: String
        }
        
        do {
            try await SupabaseManager.shared.client
                .from("crew_members")
                .update(
                    Payload(
                        unread_count: 0,
                        last_read_at: CrewDateParser.string(from: Date())
                    )
                )
                .eq("crew_id", value: crewID.uuidString)
                .eq("user_id", value: userID.uuidString)
                .execute()
            
        } catch {
            Log.debug("RESET UNREAD ERROR:", error.localizedDescription)
        }
    }
    
    struct EndCrewFocusParticipantPayload: Encodable {
        let is_active: Bool
        let left_at: String
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
    func unsubscribeGlobalFocusRealtime() {
        let channelToUnsub = globalFocusChannel
        globalFocusChannel = nil
        isSubscribingGlobalFocus = false
        
        Task {
            await channelToUnsub?.unsubscribe()
        }
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
        let started_live_at: String?
        let is_active: Bool
        let is_waiting: Bool
        let is_paused: Bool
        let paused_remaining_seconds: Int?
        let invited_count: Int
        let required_count: Int
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
    // MARK: - Crew Chat Personal State
    
    private struct CrewMemberPersonalStatePatch: Encodable {
        let is_pinned: Bool?
        let is_muted: Bool?
        let is_archived: Bool?
        
        enum CodingKeys: String, CodingKey {
            case is_pinned
            case is_muted
            case is_archived
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            if let is_pinned {
                try container.encode(is_pinned, forKey: .is_pinned)
            }
            
            if let is_muted {
                try container.encode(is_muted, forKey: .is_muted)
            }
            
            if let is_archived {
                try container.encode(is_archived, forKey: .is_archived)
            }
        }
    }
    
    func setCrewChatPinned(
        crewID: UUID,
        userID: UUID,
        isPinned: Bool
    ) async {
        await updateCrewMemberPersonalState(
            crewID: crewID,
            userID: userID,
            patch: CrewMemberPersonalStatePatch(
                is_pinned: isPinned,
                is_muted: nil,
                is_archived: nil
            )
        )
    }
    
    func setCrewChatMuted(
        crewID: UUID,
        userID: UUID,
        isMuted: Bool
    ) async {
        await updateCrewMemberPersonalState(
            crewID: crewID,
            userID: userID,
            patch: CrewMemberPersonalStatePatch(
                is_pinned: nil,
                is_muted: isMuted,
                is_archived: nil
            )
        )
    }
    
    func setCrewChatArchived(
        crewID: UUID,
        userID: UUID,
        isArchived: Bool
    ) async {
        await updateCrewMemberPersonalState(
            crewID: crewID,
            userID: userID,
            patch: CrewMemberPersonalStatePatch(
                is_pinned: nil,
                is_muted: nil,
                is_archived: isArchived
            )
        )
    }
    
    private func updateCrewMemberPersonalState(
        crewID: UUID,
        userID: UUID,
        patch: CrewMemberPersonalStatePatch
    ) async {
        _ = await CrewBackendClient.shared.updateMyMemberState(
            crewID: crewID,
            isPinned: patch.is_pinned,
            isMuted: patch.is_muted,
            isArchived: patch.is_archived
        )
        
        // Lokal state'i de güncelle (optimistic değil, server'dan gelmiş gibi)
        // Eski Supabase versiyonunda bu yoktu çünkü realtime hallediyordu.
        // Realtime hâlâ çalışıyor (henüz kaldırmadık) ama backend'e gittikten
        // sonra Supabase realtime tetiklenmediği için lokal state'i kendimiz
        // güncelliyoruz.
        if let i = crewMembers.firstIndex(where: {
            $0.crew_id == crewID && $0.user_id == userID
        }) {
            if let isPinned = patch.is_pinned {
                crewMembers[i].is_pinned = isPinned
            }
            if let isMuted = patch.is_muted {
                crewMembers[i].is_muted = isMuted
            }
            if let isArchived = patch.is_archived {
                crewMembers[i].is_archived = isArchived
            }
        }
    }
}
// MARK: - Crew Home Adapter

extension CrewStore {
    var crewHomeSummary: CrewHomeSummary {
        let visibleCrews = crews.filter { crew in
            if let snapshot = crewHomeSnapshotByCrew[crew.id] {
                return snapshot.is_archived == false
            }

            guard let currentUserID else { return true }

            let myMemberState = crewMembers.first {
                $0.crew_id == crew.id && $0.user_id == currentUserID
            }

            return myMemberState?.is_archived != true
        }

        let liveCount = visibleCrews.filter { crew in
            activeFocusSessionByCrew[crew.id] != nil ||
            crewHomeSnapshotByCrew[crew.id]?.active_session != nil
        }.count

        return CrewHomeSummary(
            crewCount: visibleCrews.count,
            friendCount: 0,
            requestCount: 0,
            liveCount: liveCount
        )
    }

    var crewHomeCrewCards: [CrewSocialCrewCardData] {
        let visibleCrews = crews.filter { crew in
            if let snapshot = crewHomeSnapshotByCrew[crew.id] {
                return snapshot.is_archived == false
            }

            guard let currentUserID else { return true }

            let myMemberState = crewMembers.first {
                $0.crew_id == crew.id && $0.user_id == currentUserID
            }

            return myMemberState?.is_archived != true
        }

        return visibleCrews.enumerated().map { index, crew in
            let snapshot = crewHomeSnapshotByCrew[crew.id]

            let memberCount = snapshot?.member_count
                ?? memberCountByCrew[crew.id]
                ?? crewMembers.filter { $0.crew_id == crew.id }.count

            let taskCount = snapshot?.task_count
                ?? taskCountByCrew[crew.id]
                ?? crewTasks.filter { $0.crew_id == crew.id }.count

            let completedTaskCount = snapshot?.completed_task_count
                ?? completedTaskCountByCrew[crew.id]
                ?? crewTasks.filter {
                    $0.crew_id == crew.id && $0.is_done
                }.count

            let realFocusMinutes = snapshot?.total_focus_minutes
                ?? totalFocusMinutesByCrew[crew.id]
                ?? crewFocusRecords
                    .filter { $0.crew_id == crew.id }
                    .map(\.minutes)
                    .reduce(0, +)

            let hasActiveSession = snapshot?.active_session != nil
                || activeFocusSessionByCrew[crew.id] != nil

            let myMemberState = currentUserID.flatMap { userID in
                crewMembers.first {
                    $0.crew_id == crew.id && $0.user_id == userID
                }
            }

            let unreadCount = snapshot?.unread_count
                ?? myMemberState?.unread_count
                ?? 0

            let isPinned = snapshot?.is_pinned
                ?? myMemberState?.is_pinned
                ?? false

            let isMuted = snapshot?.is_muted
                ?? myMemberState?.is_muted
                ?? false

            let isArchived = snapshot?.is_archived
                ?? myMemberState?.is_archived
                ?? false

            return CrewSocialCrewCardData(
                id: crew.id,
                name: crew.name,
                icon: crew.icon,
                colorHex: crew.color_hex,
                memberCount: max(memberCount, 1),
                taskCount: taskCount,
                completedTaskCount: completedTaskCount,
                isLive: hasActiveSession,
                weeklyFocusMinutes: max(realFocusMinutes, 0),
                rankText: nil,
                streakDays: 0,
                lastMessageText: crew.last_message_text,
                unreadCount: unreadCount,
                isPinned: isPinned,
                isMuted: isMuted,
                isArchived: isArchived
            )
        }
    }
}

 
