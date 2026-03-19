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
    @Published var crewMessages: [CrewMessageDTO] = []
    @Published var crewMessageReads: [CrewMessageReadDTO] = []
    @Published var crewTypingStatuses: [CrewTypingStatusDTO] = []

    private var taskChannel: RealtimeChannel?
    private var memberChannel: RealtimeChannel?
    private var activityChannel: RealtimeChannel?
    private var focusChannel: RealtimeChannel?
    private var commentChannel: RealtimeChannel?

    private var crewMessageChannel: RealtimeChannel?
    private var crewReadsChannel: RealtimeChannel?
    private var crewTypingChannel: RealtimeChannel?

    private var subscribedCrewMessageID: UUID?
    private var subscribedCrewReadsID: UUID?
    private var subscribedCrewTypingID: UUID?

    private var lastTypingStateByCrew: [UUID: Bool] = [:]

    // MARK: - Loads

    func loadCrews() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await SupabaseManager.shared.client
                .from("crews")
                .select()
                .order("created_at", ascending: false)
                .execute()

            let decoded = try JSONDecoder().decode([CrewDTO].self, from: response.data)
            crews = decoded
        } catch {
            print("LOAD CREWS ERROR:", error.localizedDescription)
        }
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
        let ids = members.map { $0.user_id.uuidString }

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

    func loadCrewMessages(for crewID: UUID) async {
        do {
            let response = try await SupabaseManager.shared.client
                .from("crew_messages")
                .select()
                .eq("crew_id", value: crewID.uuidString)
                .order("created_at", ascending: true)
                .limit(80)
                .execute()

            let decoded = try JSONDecoder().decode([CrewMessageDTO].self, from: response.data)

            crewMessages.removeAll { $0.crew_id == crewID }
            crewMessages.append(contentsOf: decoded)
            crewMessages.sort { $0.created_at < $1.created_at }
        } catch {
            print("LOAD CREW MESSAGES ERROR:", error.localizedDescription)
            crewMessages.removeAll { $0.crew_id == crewID }
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
            crewMessageReads.removeAll { $0.crew_id == crewID }
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
            crewTypingStatuses.removeAll { $0.crew_id == crewID }
        }
    }

    // MARK: - Counts / Stats

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

    // MARK: - Helpers

    private func upsertCrewMessage(_ message: CrewMessageDTO) {
        if let index = crewMessages.firstIndex(where: { $0.id == message.id }) {
            crewMessages[index] = message
        } else {
            crewMessages.append(message)
        }

        crewMessages.sort { $0.created_at < $1.created_at }

        let crewSpecific = crewMessages.filter { $0.crew_id == message.crew_id }
        if crewSpecific.count > 80 {
            let idsToKeep = Set(crewSpecific.suffix(80).map(\.id))
            crewMessages.removeAll { item in
                item.crew_id == message.crew_id && !idsToKeep.contains(item.id)
            }
        }
    }

    private func removeCrewMessage(messageID: UUID) {
        crewMessages.removeAll { $0.id == messageID }
    }

    private func upsertCrewMessageRead(_ read: CrewMessageReadDTO) {
        if let index = crewMessageReads.firstIndex(where: {
            $0.crew_id == read.crew_id && $0.user_id == read.user_id
        }) {
            crewMessageReads[index] = read
        } else {
            crewMessageReads.append(read)
        }
    }

    private func upsertCrewTypingStatus(_ status: CrewTypingStatusDTO) {
        if let index = crewTypingStatuses.firstIndex(where: {
            $0.crew_id == status.crew_id && $0.user_id == status.user_id
        }) {
            crewTypingStatuses[index] = status
        } else {
            crewTypingStatuses.append(status)
        }
    }

    private func removeCrewTypingStatus(crewID: UUID, userID: UUID) {
        crewTypingStatuses.removeAll {
            $0.crew_id == crewID && $0.user_id == userID
        }
    }

    // MARK: - Actions

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

            await loadActivities(for: crewID)
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

            await loadFocusRecords(for: crewID)
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

            let actorName = memberProfiles.first(where: { $0.id == task.created_by })?.full_name
                ?? memberProfiles.first(where: { $0.id == task.created_by })?.username
                ?? "You"

            await createActivity(
                crewID: task.crew_id,
                memberName: actorName,
                actionText: !task.is_done ? "completed task \(task.title)" : "reopened task \(task.title)"
            )

            await loadTasks(for: task.crew_id)
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

        await loadTasks(for: crewID)
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

        await loadTasks(for: crewID)
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

    func createCrew(name: String, icon: String, colorHex: String, ownerID: UUID) async throws {
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

        await loadCrews()
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

        await loadCrews()
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

    // MARK: - Chat

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
        }

        let payload = Payload(
            crew_id: crewID,
            sender_id: senderID,
            sender_name: senderName,
            text: text,
            is_read: isSystemMessage,
            is_system_message: isSystemMessage,
            reaction: nil
        )

        try await SupabaseManager.shared.client
            .from("crew_messages")
            .insert(payload)
            .execute()
    }

    func sendCrewMessage(
        crewID: UUID,
        senderID: UUID?,
        senderName: String,
        text: String
    ) async throws {
        struct Payload: Encodable {
            let crew_id: UUID
            let sender_id: UUID?
            let sender_name: String
            let text: String
            let is_read: Bool
            let reaction: String?
        }

        let payload = Payload(
            crew_id: crewID,
            sender_id: senderID,
            sender_name: senderName,
            text: text,
            is_read: false,
            reaction: nil
        )

        try await SupabaseManager.shared.client
            .from("crew_messages")
            .insert(payload)
            .execute()
    }

    func updateCrewMessageReaction(
        messageID: UUID,
        reaction: String?
    ) async throws {
        struct ReactionPayload: Encodable {
            let reaction: String?
        }

        try await SupabaseManager.shared.client
            .from("crew_messages")
            .update(ReactionPayload(reaction: reaction))
            .eq("id", value: messageID.uuidString)
            .execute()
    }

    func markCrewMessagesAsRead(
        crewID: UUID,
        excludingUserID: UUID?
    ) async {
        do {
            if let excludingUserID {
                try await SupabaseManager.shared.client
                    .from("crew_messages")
                    .update(["is_read": true])
                    .eq("crew_id", value: crewID.uuidString)
                    .neq("sender_id", value: excludingUserID.uuidString)
                    .eq("is_read", value: false)
                    .execute()
            } else {
                try await SupabaseManager.shared.client
                    .from("crew_messages")
                    .update(["is_read": true])
                    .eq("crew_id", value: crewID.uuidString)
                    .eq("is_read", value: false)
                    .execute()
            }

            if let userID = excludingUserID {
                struct ReadPayload: Encodable {
                    let crew_id: UUID
                    let user_id: UUID
                    let last_read_at: String
                }

                let payload = ReadPayload(
                    crew_id: crewID,
                    user_id: userID,
                    last_read_at: ISO8601DateFormatter().string(from: Date())
                )

                try await SupabaseManager.shared.client
                    .from("crew_message_reads")
                    .upsert(payload, onConflict: "crew_id,user_id")
                    .execute()
            }

            await loadCrewMessageReads(for: crewID)
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
            updated_at: ISO8601DateFormatter().string(from: Date())
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

    // MARK: - Realtime (Chat)

    func subscribeToCrewMessagesRealtime(crewID: UUID) {
        if subscribedCrewMessageID == crewID,
           subscribedCrewReadsID == crewID,
           subscribedCrewTypingID == crewID {
            return
        }

        let client = SupabaseManager.shared.client

        crewMessageChannel?.unsubscribe()
        crewReadsChannel?.unsubscribe()
        crewTypingChannel?.unsubscribe()

        crewMessageChannel = client.realtime.channel("crew-messages-\(crewID.uuidString)")
        crewReadsChannel = client.realtime.channel("crew-reads-\(crewID.uuidString)")
        crewTypingChannel = client.realtime.channel("crew-typing-\(crewID.uuidString)")

        subscribedCrewMessageID = crewID
        subscribedCrewReadsID = crewID
        subscribedCrewTypingID = crewID

        print("SUBSCRIBED CREW CHAT:", crewID)

        crewMessageChannel?
            .on(
                "postgres_changes",
                filter: ChannelFilter(
                    event: "*",
                    schema: "public",
                    table: "crew_messages",
                    filter: "crew_id=eq.\(crewID.uuidString)"
                )
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.loadCrewMessages(for: crewID)
                }
            }

        crewReadsChannel?
            .on(
                "postgres_changes",
                filter: ChannelFilter(
                    event: "*",
                    schema: "public",
                    table: "crew_message_reads",
                    filter: "crew_id=eq.\(crewID.uuidString)"
                )
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.loadCrewMessageReads(for: crewID)
                }
            }

        crewTypingChannel?
            .on(
                "postgres_changes",
                filter: ChannelFilter(
                    event: "*",
                    schema: "public",
                    table: "crew_typing_status",
                    filter: "crew_id=eq.\(crewID.uuidString)"
                )
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.loadCrewTypingStatuses(for: crewID)
                }
            }

        crewMessageChannel?.subscribe()
        crewReadsChannel?.subscribe()
        crewTypingChannel?.subscribe()
    }

    func unsubscribeCrewChat() {
        crewMessageChannel?.unsubscribe()
        crewReadsChannel?.unsubscribe()
        crewTypingChannel?.unsubscribe()

        crewMessageChannel = nil
        crewReadsChannel = nil
        crewTypingChannel = nil

        subscribedCrewMessageID = nil
        subscribedCrewReadsID = nil
        subscribedCrewTypingID = nil
    }

    // MARK: - Realtime (General Crew)

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

    // MARK: - Invite DTO

    struct CrewInviteDTO: Codable {
        let id: UUID
        let crew_id: UUID
        let code: String
    }
}
