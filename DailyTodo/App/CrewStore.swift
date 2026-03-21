//
//  CrewStore.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import Foundation
import Supabase
import Combine


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
    @Published var crewTaskComments: [CrewTaskCommentDTO] = []
    @Published var crewMessageReads: [CrewMessageReadDTO] = []
    @Published var crewTypingStatuses: [CrewTypingStatusDTO] = []

    @Published var chatMessagesByCrew: [UUID: [CrewChatMessageItem]] = [:]
    @Published var activeFocusSessionByCrew: [UUID: CrewFocusSessionDTO] = [:]
    @Published var focusParticipantsBySession: [UUID: [CrewFocusParticipantDTO]] = [:]
    @Published private(set) var currentUserID: UUID?

    private var activeFocusChannel: RealtimeChannel?
    private var focusParticipantsChannel: RealtimeChannel?
    private var subscribedFocusCrewID: UUID?

    private var taskChannel: RealtimeChannel?
    private var memberChannel: RealtimeChannel?
    private var activityChannel: RealtimeChannel?
    private var focusChannel: RealtimeChannel?
    private var commentChannel: RealtimeChannel?
    private var lastTypingStateByCrew: [UUID: Bool] = [:]
    
    private var crewMessagesChannel: RealtimeChannel?
    private var subscribedCrewMessageID: UUID?
    private var hasLoadedCrews = false
    
    func setCurrentUser(_ userID: UUID?) {
        currentUserID = userID
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

    private func setChatMessages(
        _ items: [CrewChatMessageItem],
        for crewID: UUID
    ) {
        chatMessagesByCrew[crewID] = items.sorted { $0.createdAt < $1.createdAt }
    }

    private func appendChatMessage(
        _ item: CrewChatMessageItem,
        for crewID: UUID
    ) {
        var items = chatMessagesByCrew[crewID] ?? []
        items.append(item)
        items.sort { $0.createdAt < $1.createdAt }
        chatMessagesByCrew[crewID] = Array(items.suffix(30))
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

        chatMessagesByCrew[crewID] = items
    }
    private func replacePendingMessageByClientID(
        crewID: UUID,
        clientID: String,
        with item: CrewChatMessageItem
    ) {
        var items = chatMessagesByCrew[crewID] ?? []

        if let index = items.firstIndex(where: { $0.clientID == clientID && $0.serverID == nil }) {
            items[index] = item
        } else if let existingIndex = items.firstIndex(where: { $0.serverID == item.serverID }) {
            items[existingIndex] = item
        } else {
            items.append(item)
        }

        items.sort { $0.createdAt < $1.createdAt }
        chatMessagesByCrew[crewID] = Array(items.suffix(30))
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

    func handleIncomingMessage(
        _ dto: CrewMessageDTO,
        currentUserID: UUID?
    ) {
        let item = mapDTOToChatItem(dto, currentUserID: currentUserID)
        var items = chatMessagesByCrew[dto.crew_id] ?? []

        if let existingIndex = items.firstIndex(where: { $0.serverID == dto.id }) {
            items[existingIndex] = item
        } else if let clientID = dto.client_id,
                  let pendingIndex = items.firstIndex(where: {
                      $0.serverID == nil &&
                      $0.clientID == clientID
                  }) {
            items[pendingIndex] = item
        } else {
            items.append(item)
        }

        items.sort { $0.createdAt < $1.createdAt }
        chatMessagesByCrew[dto.crew_id] = Array(items.suffix(30))
    }

    // MARK: - Chat Load

    func loadInitialChatMessages(
        for crewID: UUID,
        currentUserID: UUID?
    ) async {
        do {
            let response = try await SupabaseManager.shared.client
                .from("crew_messages")
                .select()
                .eq("crew_id", value: crewID.uuidString)
                .order("created_at", ascending: true)
                .limit(30)
                .execute()

            let decoded = try JSONDecoder().decode([CrewMessageDTO].self, from: response.data)
            let items = decoded.map { mapDTOToChatItem($0, currentUserID: currentUserID) }
            setChatMessages(items, for: crewID)
        } catch {
            print("LOAD INITIAL CHAT MESSAGES ERROR:", error.localizedDescription)
            setChatMessages([], for: crewID)
        }
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
        if subscribedCrewMessageID == crewID {
            return
        }

        let client = SupabaseManager.shared.client

        crewMessagesChannel?.unsubscribe()

        crewMessagesChannel = client.realtime.channel("crew-messages-\(crewID.uuidString)")
        subscribedCrewMessageID = crewID

        crewMessagesChannel?
            .on(
                "postgres_changes",
                filter: ChannelFilter(
                    event: "*",
                    schema: "public",
                    table: "crew_messages",
                    filter: "crew_id=eq.\(crewID.uuidString)"
                )
            ) { payload in

                let dict = payload.payload

                guard
                    let record = dict["record"],
                    let data = try? JSONSerialization.data(withJSONObject: record),
                    let dto = try? JSONDecoder().decode(CrewMessageDTO.self, from: data)
                else {
                    return
                }

                Task { @MainActor in
                    self.handleIncomingMessage(dto, currentUserID: currentUserID)
                }
            }

        crewMessagesChannel?.subscribe()
    }

    func unsubscribeCrewChat() {
        crewMessagesChannel?.unsubscribe()
        crewMessagesChannel = nil
        subscribedCrewMessageID = nil
    }

    // MARK: - General Crew Realtime

    func subscribeToCrewRealtime(crewID: UUID) {
        let client = SupabaseManager.shared.client

        commentChannel?.unsubscribe()
        taskChannel?.unsubscribe()
        memberChannel?.unsubscribe()
        activityChannel?.unsubscribe()
        focusChannel?.unsubscribe()

        commentChannel = client.realtime.channel("public:crew_task_comments:\(crewID.uuidString)")
        taskChannel = client.realtime.channel("public:crew_tasks:\(crewID.uuidString)")
        memberChannel = client.realtime.channel("public:crew_members:\(crewID.uuidString)")
        activityChannel = client.realtime.channel("public:crew_activities:\(crewID.uuidString)")
        focusChannel = client.realtime.channel("public:crew_focus_records:\(crewID.uuidString)")

        commentChannel?
            .on(
                "postgres_changes",
                filter: ChannelFilter(
                    event: "*",
                    schema: "public",
                    table: "crew_task_comments",
                    filter: "crew_id=eq.\(crewID.uuidString)"
                )
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.loadComments(for: crewID)
                }
            }

        taskChannel?
            .on(
                "postgres_changes",
                filter: ChannelFilter(
                    event: "*",
                    schema: "public",
                    table: "crew_tasks",
                    filter: "crew_id=eq.\(crewID.uuidString)"
                )
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.loadTasks(for: crewID)
                }
            }

        memberChannel?
            .on(
                "postgres_changes",
                filter: ChannelFilter(
                    event: "*",
                    schema: "public",
                    table: "crew_members",
                    filter: "crew_id=eq.\(crewID.uuidString)"
                )
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    await self.loadMembers(for: crewID)
                    await self.loadMemberProfiles(for: self.crewMembers)
                    await self.loadMemberCount(for: crewID)
                }
            }

        activityChannel?
            .on(
                "postgres_changes",
                filter: ChannelFilter(
                    event: "*",
                    schema: "public",
                    table: "crew_activities",
                    filter: "crew_id=eq.\(crewID.uuidString)"
                )
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.loadActivities(for: crewID)
                }
            }

        focusChannel?
            .on(
                "postgres_changes",
                filter: ChannelFilter(
                    event: "*",
                    schema: "public",
                    table: "crew_focus_records",
                    filter: "crew_id=eq.\(crewID.uuidString)"
                )
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.loadFocusRecords(for: crewID)
                }
            }

        commentChannel?.subscribe()
        taskChannel?.subscribe()
        memberChannel?.subscribe()
        activityChannel?.subscribe()
        focusChannel?.subscribe()
    }

    func unsubscribe() {
        commentChannel?.unsubscribe()
        taskChannel?.unsubscribe()
        memberChannel?.unsubscribe()
        activityChannel?.unsubscribe()
        focusChannel?.unsubscribe()

        commentChannel = nil
        taskChannel = nil
        memberChannel = nil
        activityChannel = nil
        focusChannel = nil
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
        crewTaskComments = []
        crewMessageReads = []
        crewTypingStatuses = []
        chatMessagesByCrew = [:]
        activeFocusSessionByCrew = [:]
        focusParticipantsBySession = [:]
        hasLoadedCrews = false

        unsubscribe()
        unsubscribeCrewChat()
        unsubscribeCrewFocusRealtime()
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

    func loadComments(for crewID: UUID) async {
        do {
            let response = try await SupabaseManager.shared.client
                .from("crew_task_comments")
                .select()
                .eq("crew_id", value: crewID.uuidString)
                .order("created_at", ascending: false)
                .execute()

            let decoded = try JSONDecoder().decode([CrewTaskCommentDTO].self, from: response.data)
            crewTaskComments = decoded
        } catch {
            print("LOAD COMMENTS ERROR:", error.localizedDescription)
            crewTaskComments = []
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

    func toggleTask(_ task: CrewTaskDTO) async {
        do {
            try await SupabaseManager.shared.client
                .from("crew_tasks")
                .update([
                    "is_done": !task.is_done
                ])
                .eq("id", value: task.id.uuidString)
                .execute()

            let profile = memberProfiles.first(where: { $0.id == task.created_by })
            let actorName = profile?.full_name ?? profile?.username ?? "You"

            await createActivity(
                crewID: task.crew_id,
                memberName: actorName,
                actionText: !task.is_done ? "completed task \(task.title)" : "reopened task \(task.title)"
            )
        } catch {
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

        try await SupabaseManager.shared.client
            .from("crew_tasks")
            .insert(payload)
            .execute()

        let profile = memberProfiles.first(where: { $0.id == userID })
        let actorName = profile?.full_name ?? profile?.username ?? "You"

        await createActivity(
            crewID: crewID,
            memberName: actorName,
            actionText: "created task \(clean)"
        )

        
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
    }

    func deleteTask(taskID: UUID, crewID: UUID, title: String? = nil) async throws {
        try await SupabaseManager.shared.client
            .from("crew_tasks")
            .delete()
            .eq("id", value: taskID.uuidString)
            .execute()

        await createActivity(
            crewID: crewID,
            memberName: "You",
            actionText: "deleted task \(title ?? "")"
        )

       
    }

    func addMember(by username: String, to crewID: UUID) async throws {
        let cleanUsername = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let userResponse = try await SupabaseManager.shared.client
            .from("profiles")
            .select()
            .eq("username", value: cleanUsername)
            .single()
            .execute()

        let profile = try JSONDecoder().decode(ProfileDTO.self, from: userResponse.data)

        try await SupabaseManager.shared.client
            .from("crew_members")
            .insert([
                "crew_id": crewID.uuidString,
                "user_id": profile.id.uuidString,
                "role": "member"
            ])
            .execute()

        await loadMembers(for: crewID)
        await loadMemberProfiles(for: crewMembers)
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
                .limit(1)
                .execute()

            let decoded = try JSONDecoder().decode([CrewFocusSessionDTO].self, from: response.data)
            activeFocusSessionByCrew[crewID] = decoded.first
        } catch {
            print("LOAD ACTIVE FOCUS SESSION ERROR:", error.localizedDescription)
            activeFocusSessionByCrew[crewID] = nil
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
            .insert(payload)
            .execute()

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

        activeFocusChannel?.unsubscribe()
        focusParticipantsChannel?.unsubscribe()

        activeFocusChannel = client.realtime.channel("crew-focus-session-\(crewID.uuidString)")
        focusParticipantsChannel = client.realtime.channel("crew-focus-participants-\(crewID.uuidString)")
        subscribedFocusCrewID = crewID

        activeFocusChannel?
            .on(
                "postgres_changes",
                filter: ChannelFilter(
                    event: "*",
                    schema: "public",
                    table: "crew_focus_sessions",
                    filter: "crew_id=eq.\(crewID.uuidString)"
                )
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.loadActiveFocusSession(for: crewID)
                }
            }

        focusParticipantsChannel?
            .on(
                "postgres_changes",
                filter: ChannelFilter(
                    event: "*",
                    schema: "public",
                    table: "crew_focus_participants",
                    filter: "crew_id=eq.\(crewID.uuidString)"
                )
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    if let session = self.activeFocusSessionByCrew[crewID] {
                        await self.loadFocusParticipants(sessionID: session.id)
                    }
                }
            }

        activeFocusChannel?.subscribe()
        focusParticipantsChannel?.subscribe()
    }
    func unsubscribeCrewFocusRealtime() {
        activeFocusChannel?.unsubscribe()
        focusParticipantsChannel?.unsubscribe()

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

