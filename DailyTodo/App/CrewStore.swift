//
//  CrewStore.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import Foundation
import Supabase
import Combine

@MainActor
final class CrewStore: ObservableObject {
    @Published var crews: [CrewDTO] = []
    @Published var crewMembers: [CrewMemberDTO] = []
    @Published var isLoading = false
    @Published var memberProfiles: [ProfileDTO] = []
    @Published var crewTasks: [CrewTaskDTO] = []
    
    private var channel: RealtimeChannel?
    
    
    func subscribeToTasks(crewID: UUID) {
        let client = SupabaseManager.shared.client

        channel = client.realtime.channel("public:crew_tasks")

        channel?
            .on(
                "postgres_changes",
                filter: ChannelFilter(
                    event: "*",
                    schema: "public",
                    table: "crew_tasks"
                )
            ) { [weak self] _ in
                Task {
                    await self?.loadTasks(for: crewID)
                }
            }

        channel?.subscribe()
    }
    
    func unsubscribe() {
        channel?.unsubscribe()
        channel = nil
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
    
    struct CrewInviteDTO: Codable {
        let id: UUID
        let crew_id: UUID
        let code: String
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

    func toggleTask(_ task: CrewTaskDTO) async {
        do {
            try await SupabaseManager.shared.client
                .from("crew_tasks")
                .update([
                    "is_done": !task.is_done
                ])
                .eq("id", value: task.id.uuidString)
                .execute()

            await loadTasks(for: task.crew_id)
        } catch {
            print("TOGGLE ERROR:", error.localizedDescription)
        }
    }

    func createTask(
        title: String,
        crewID: UUID,
        userID: UUID,
        assignedTo: UUID?
    ) async throws {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)

        var payload: [String: String] = [
            "title": clean,
            "crew_id": crewID.uuidString,
            "created_by": userID.uuidString
        ]

        if let assignedTo {
            payload["assigned_to"] = assignedTo.uuidString
        }

        try await SupabaseManager.shared.client
            .from("crew_tasks")
            .insert(payload)
            .execute()

        await loadTasks(for: crewID)
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
}
