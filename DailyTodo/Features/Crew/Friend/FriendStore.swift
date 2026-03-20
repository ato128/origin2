//
//  FriendStore.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 20.03.2026.
//

import Foundation
import Supabase
import SwiftData
import Combine

@MainActor
final class FriendStore: ObservableObject {
    @Published var friendships: [FriendshipDTO] = []
    @Published var profiles: [UUID: FriendProfileDTO] = [:]
    @Published var isLoading = false
    @Published var friendMessagesByFriendship: [UUID: [FriendChatMessageItem]] = [:]

    func loadAcceptedFriendships(currentUserID: UUID) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await SupabaseManager.shared.client
                .from("friendships")
                .select()
                .eq("status", value: "accepted")
                .or("requester_id.eq.\(currentUserID.uuidString),addressee_id.eq.\(currentUserID.uuidString)")
                .execute()

            let decoded = try JSONDecoder().decode([FriendshipDTO].self, from: response.data)
            friendships = decoded
        } catch {
            print("LOAD ACCEPTED FRIENDSHIPS ERROR:", error.localizedDescription)
        }
    }

    func loadPendingRequests(currentUserID: UUID) async {
        do {
            let response = try await SupabaseManager.shared.client
                .from("friendships")
                .select()
                .eq("status", value: "pending")
                .or("requester_id.eq.\(currentUserID.uuidString),addressee_id.eq.\(currentUserID.uuidString)")
                .execute()

            let decoded = try JSONDecoder().decode([FriendshipDTO].self, from: response.data)
            friendships = decoded
        } catch {
            print("LOAD PENDING FRIEND REQUESTS ERROR:", error.localizedDescription)
        }
    }

    func loadProfiles(for userIDs: [UUID]) async {
        let uniqueIDs = Array(Set(userIDs))
        guard !uniqueIDs.isEmpty else { return }

        do {
            let response = try await SupabaseManager.shared.client
                .from("profiles")
                .select()
                .in("id", values: uniqueIDs.map(\.uuidString))
                .execute()

            let decoded = try JSONDecoder().decode([FriendProfileDTO].self, from: response.data)

            var dict: [UUID: FriendProfileDTO] = [:]
            for item in decoded {
                dict[item.id] = item
            }
            profiles = dict
        } catch {
            print("LOAD FRIEND PROFILES ERROR:", error.localizedDescription)
        }
    }
    func sendFriendRequest(
        to targetUserID: UUID,
        currentUserID: UUID
    ) async throws {
        struct Payload: Encodable {
            let requester_id: UUID
            let addressee_id: UUID
            let status: String
        }

        let payload = Payload(
            requester_id: currentUserID,
            addressee_id: targetUserID,
            status: "pending"
        )

        try await SupabaseManager.shared.client
            .from("friendships")
            .insert(payload)
            .execute()
    }
    func findUserByUsername(_ username: String) async throws -> FriendProfileDTO {
        let clean = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let response = try await SupabaseManager.shared.client
            .from("profiles")
            .select()
            .eq("username", value: clean)
            .single()
            .execute()

        return try JSONDecoder().decode(FriendProfileDTO.self, from: response.data)
    }

    func syncAcceptedFriendsToLocal(
        currentUserID: UUID,
        modelContext: ModelContext
    ) {
        for friendship in friendships where friendship.status == "accepted" {
            let otherUserID =
                friendship.requester_id == currentUserID
                ? friendship.addressee_id
                : friendship.requester_id

            guard let profile = profiles[otherUserID] else { continue }

            let descriptor = FetchDescriptor<Friend>()
            let existing = try? modelContext.fetch(descriptor).first(where: {
                $0.backendFriendshipID == friendship.id
            })

            let displayName: String
            if let fullName = profile.full_name,
               !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                displayName = fullName
            } else if let username = profile.username,
                      !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                displayName = username
            } else {
                displayName = profile.email ?? "Unknown"
            }

            if let existing {
                existing.backendFriendshipID = friendship.id
                existing.backendUserID = otherUserID
                existing.name = displayName
                existing.subtitle = "Friend"
                existing.isOnline = true
            } else {
                let newFriend = Friend(
                    backendFriendshipID: friendship.id,
                    backendUserID: otherUserID,
                    name: displayName,
                    subtitle: "Friend",
                    avatarSymbol: "person.fill",
                    colorHex: "#3B82F6",
                    isOnline: true
                )
                modelContext.insert(newFriend)
            }
        }

        do {
            try modelContext.save()
        } catch {
            print("SYNC ACCEPTED FRIENDS LOCAL SAVE ERROR:", error.localizedDescription)
        }
    }

    func loadMessages(
        for friendshipID: UUID,
        currentUserID: UUID?
    ) async {
        do {
            let response = try await SupabaseManager.shared.client
                .from("friend_messages")
                .select()
                .eq("friendship_id", value: friendshipID.uuidString)
                .order("created_at", ascending: true)
                .execute()

            let decoded = try JSONDecoder().decode([FriendMessageDTO].self, from: response.data)

            let items = decoded.map { dto in
                FriendChatMessageItem(
                    id: dto.id,
                    serverID: dto.id,
                    clientID: dto.client_id,
                    friendshipID: dto.friendship_id,
                    senderID: dto.sender_id,
                    senderName: dto.sender_name,
                    text: dto.text,
                    createdAt: CrewDateParser.parse(dto.created_at) ?? Date(),
                    reaction: dto.reaction,
                    isSystemMessage: dto.is_system_message ?? false,
                    isFromMe: dto.sender_id == currentUserID,
                    isPending: false,
                    isFailed: false
                )
            }

            friendMessagesByFriendship[friendshipID] = items
        } catch {
            print("LOAD FRIEND MESSAGES ERROR:", error.localizedDescription)
            friendMessagesByFriendship[friendshipID] = []
        }
    }

    func sendMessage(
        text: String,
        friendshipID: UUID,
        senderID: UUID?,
        senderName: String
    ) async {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        let localItem = FriendChatMessageItem(
            id: UUID(),
            serverID: nil,
            clientID: UUID().uuidString,
            friendshipID: friendshipID,
            senderID: senderID,
            senderName: senderName,
            text: clean,
            createdAt: Date(),
            reaction: nil,
            isSystemMessage: false,
            isFromMe: true,
            isPending: true,
            isFailed: false
        )

        var current = friendMessagesByFriendship[friendshipID] ?? []
        current.append(localItem)
        current.sort { $0.createdAt < $1.createdAt }
        friendMessagesByFriendship[friendshipID] = current

        do {
            struct Payload: Encodable {
                let friendship_id: UUID
                let sender_id: UUID?
                let sender_name: String
                let text: String
                let reaction: String?
                let is_system_message: Bool
                let client_id: String
            }

            let payload = Payload(
                friendship_id: friendshipID,
                sender_id: senderID,
                sender_name: senderName,
                text: clean,
                reaction: nil,
                is_system_message: false,
                client_id: localItem.clientID ?? UUID().uuidString
            )

            try await SupabaseManager.shared.client
                .from("friend_messages")
                .insert(payload)
                .execute()

            await loadMessages(
                for: friendshipID,
                currentUserID: senderID
            )
        } catch {
            print("SEND FRIEND MESSAGE ERROR:", error.localizedDescription)

            var failed = friendMessagesByFriendship[friendshipID] ?? []
            if let index = failed.firstIndex(where: { $0.id == localItem.id }) {
                let old = failed[index]
                failed[index] = FriendChatMessageItem(
                    id: old.id,
                    serverID: old.serverID,
                    clientID: old.clientID,
                    friendshipID: old.friendshipID,
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
            }
            friendMessagesByFriendship[friendshipID] = failed
        }
    }
}
