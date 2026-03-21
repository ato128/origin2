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
    @Published var typingStatusByFriendship: [UUID: Bool] = [:]
    @Published var typingUsers: [UUID: String] = [:]
    @Published var presenceByUserID: [UUID: FriendPresenceDTO] = [:]
    @Published var incomingWeekSharesByFriendship: [UUID: FriendWeekShareDTO] = [:]
    @Published var outgoingWeekSharesByFriendship: [UUID: FriendWeekShareDTO] = [:]
    @Published var weekShareEnabledByUserID: [UUID: Bool] = [:]
    @Published var sharedWeekItemsByFriendship: [UUID: [FriendWeekShareItemDTO]] = [:]
    
    private var friendPresenceChannel: RealtimeChannelV2?
    
    private var friendTypingChannel: RealtimeChannelV2?
    private var typingResetTask: Task<Void, Never>?
    
    private var friendMessagesChannel: RealtimeChannelV2?
    private var subscribedFriendshipID: UUID?
    
    // MARK: - Friendships
    
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
    
    // MARK: - Profiles
    
    func loadProfiles(for userIDs: [UUID]) async {
        let uniqueIDs = Array(Set(userIDs))
        guard !uniqueIDs.isEmpty else { return }
        
        do {
            print("LOADING PROFILES FOR:", uniqueIDs)
            
            let response = try await SupabaseManager.shared.client
                .from("profiles")
                .select()
                .in("id", values: uniqueIDs.map(\.uuidString))
                .execute()
            
            print("RAW PROFILE RESPONSE:", String(data: response.data, encoding: .utf8) ?? "nil")
            
            let decoded = try JSONDecoder().decode([FriendProfileDTO].self, from: response.data)
            print("DECODED PROFILES COUNT:", decoded.count)
            
            var dict: [UUID: FriendProfileDTO] = [:]
            for item in decoded {
                dict[item.id] = item
            }
            
            profiles = dict
            print("PROFILES DICTIONARY FINAL:", profiles)
        } catch {
            print("LOAD FRIEND PROFILES ERROR:", error.localizedDescription)
        }
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
    
    func acceptFriendRequest(friendshipID: UUID) async throws {
        struct Payload: Encodable {
            let status: String
        }
        
        try await SupabaseManager.shared.client
            .from("friendships")
            .update(Payload(status: "accepted"))
            .eq("id", value: friendshipID.uuidString)
            .execute()
    }
    
    // MARK: - Friend Week Share
    
    func loadWeekShareStatus(
        friendshipID: UUID,
        currentUserID: UUID,
        friendUserID: UUID
    ) async {
        do {
            let response = try await SupabaseManager.shared.client
                .from("friend_week_shares")
                .select()
                .eq("friendship_id", value: friendshipID.uuidString)
                .or(
                    "and(owner_user_id.eq.\(currentUserID.uuidString),viewer_user_id.eq.\(friendUserID.uuidString)),and(owner_user_id.eq.\(friendUserID.uuidString),viewer_user_id.eq.\(currentUserID.uuidString))"
                )
                .execute()
            print("WEEK SHARE RAW:", String(data: response.data, encoding: .utf8) ?? "nil")

            let decoded = try JSONDecoder().decode([FriendWeekShareDTO].self, from: response.data)

            var outgoing: FriendWeekShareDTO?
            var incoming: FriendWeekShareDTO?

            for item in decoded {
                if item.owner_user_id == currentUserID &&
                    item.viewer_user_id == friendUserID {
                    outgoing = item
                }

                if item.owner_user_id == friendUserID &&
                    item.viewer_user_id == currentUserID {
                    incoming = item
                }
            }

            if let outgoing {
                outgoingWeekSharesByFriendship[friendshipID] = outgoing
            } else {
                outgoingWeekSharesByFriendship.removeValue(forKey: friendshipID)
            }

            if let incoming {
                incomingWeekSharesByFriendship[friendshipID] = incoming
            } else {
                incomingWeekSharesByFriendship.removeValue(forKey: friendshipID)
            }

        } catch {
            print("LOAD WEEK SHARE STATUS ERROR:", error.localizedDescription)
        }
    }
    
    func setWeekShareEnabled(
        friendshipID: UUID,
        currentUserID: UUID,
        friendUserID: UUID,
        isEnabled: Bool,
        events: [EventItem]
    ) async {
        struct SharePayload: Encodable {
            let friendship_id: UUID
            let owner_user_id: UUID
            let viewer_user_id: UUID
            let is_enabled: Bool
        }

        struct ItemPayload: Encodable {
            let friendship_id: UUID
            let owner_user_id: UUID
            let viewer_user_id: UUID
            let title: String
            let details: String?
            let weekday: Int
            let start_minute: Int
            let duration_minute: Int
        }

        do {
            // 1) toggle kaydını upsert et
            let sharePayload = SharePayload(
                friendship_id: friendshipID,
                owner_user_id: currentUserID,
                viewer_user_id: friendUserID,
                is_enabled: isEnabled
            )

            try await SupabaseManager.shared.client
                .from("friend_week_shares")
                .upsert(sharePayload, onConflict: "friendship_id,owner_user_id,viewer_user_id")
                .execute()

            // 2) bu owner-viewer için eski paylaşılan itemları sil
            try await SupabaseManager.shared.client
                .from("friend_week_share_items")
                .delete()
                .eq("friendship_id", value: friendshipID.uuidString)
                .eq("owner_user_id", value: currentUserID.uuidString)
                .eq("viewer_user_id", value: friendUserID.uuidString)
                .execute()

            // 3) açıksa eventleri tekrar insert et
            if isEnabled {
                let validEvents = events.filter { !$0.isCompleted }

                let payloads = validEvents.map { event in
                    ItemPayload(
                        friendship_id: friendshipID,
                        owner_user_id: currentUserID,
                        viewer_user_id: friendUserID,
                        title: event.title,
                        details: event.notes,
                        weekday: event.weekday,
                        start_minute: event.startMinute,
                        duration_minute: event.durationMinute
                    )
                }

                if !payloads.isEmpty {
                    try await SupabaseManager.shared.client
                        .from("friend_week_share_items")
                        .insert(payloads)
                        .execute()
                }
            }

            await loadWeekShareStatus(
                friendshipID: friendshipID,
                currentUserID: currentUserID,
                friendUserID: friendUserID
            )

            await loadSharedWeekItems(
                friendshipID: friendshipID,
                ownerUserID: friendUserID,
                viewerUserID: currentUserID
            )

        } catch {
            print("SET WEEK SHARE ENABLED ERROR:", error.localizedDescription)
        }
    }
    
    func loadWeekShareState(for userID: UUID) async {
        do {
            let response = try await SupabaseManager.shared.client
                .from("friend_week_shares")
                .select()
                .eq("user_id", value: userID.uuidString)
                .eq("is_enabled", value: true)
                .limit(1)
                .execute()

            let decoded = try JSONDecoder().decode([FriendWeekShareDTO].self, from: response.data)
            weekShareEnabledByUserID[userID] = !decoded.isEmpty
        } catch {
            print("LOAD WEEK SHARE STATE ERROR:", error.localizedDescription)
            weekShareEnabledByUserID[userID] = false
        }
    }

    func loadSharedWeekItems(
        friendshipID: UUID,
        ownerUserID: UUID,
        viewerUserID: UUID
    ) async {
        do {
            let response = try await SupabaseManager.shared.client
                .from("friend_week_share_items")
                .select()
                .eq("friendship_id", value: friendshipID.uuidString)
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .eq("viewer_user_id", value: viewerUserID.uuidString)
                .order("weekday", ascending: true)
                .order("start_minute", ascending: true)
                .execute()

            let decoded = try JSONDecoder().decode([FriendWeekShareItemDTO].self, from: response.data)
            sharedWeekItemsByFriendship[friendshipID] = decoded
        } catch {
            print("LOAD SHARED WEEK ITEMS ERROR:", error.localizedDescription)
            sharedWeekItemsByFriendship[friendshipID] = []
        }
    }

    // MARK: - Local Sync

    func syncAcceptedFriendsToLocal(
        currentUserID: UUID,
        modelContext: ModelContext
    ) {
        for friendship in friendships where friendship.status == "accepted" {
            print("SYNCING FRIENDSHIP:", friendship.id)
            print("STATUS:", friendship.status)
            print("REQUESTER:", friendship.requester_id)
            print("ADDRESSEE:", friendship.addressee_id)

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
                existing.ownerUserID = currentUserID.uuidString
            } else {
                let newFriend = Friend(
                    ownerUserID: currentUserID.uuidString,
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

    // MARK: - Messages

    private func mapDTOToFriendItem(
        _ dto: FriendMessageDTO,
        currentUserID: UUID?
    ) -> FriendChatMessageItem {
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
            isFailed: false,
            seenAt: dto.seen_at.flatMap { CrewDateParser.parse($0) }
        )
    }
    func userDidType(
        friendshipID: UUID,
        currentUserID: UUID?,
        currentUserName: String
    ) {
        typingResetTask?.cancel()

        Task {
            await setTyping(
                friendshipID: friendshipID,
                currentUserID: currentUserID,
                currentUserName: currentUserName,
                isTyping: true
            )
        }

        typingResetTask = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)

            await setTyping(
                friendshipID: friendshipID,
                currentUserID: currentUserID,
                currentUserName: currentUserName,
                isTyping: false
            )
        }
    }
    
    func unsubscribeTypingRealtime() {
        Task {
            await friendTypingChannel?.unsubscribe()
        }
        friendTypingChannel = nil
    }
    
    func subscribeToTypingRealtime(
        friendshipID: UUID,
        currentUserID: UUID?
    ) {
        Task {
            await friendTypingChannel?.unsubscribe()
        }
        friendTypingChannel = nil

        let channel = SupabaseManager.shared.client
            .realtimeV2
            .channel("friend-typing-\(friendshipID.uuidString)")

        channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "friend_typing_status",
            filter: "friendship_id=eq.\(friendshipID.uuidString)"
        ) { [weak self] action in
            Task { @MainActor in
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: action.record)
                    let dto = try JSONDecoder().decode(FriendTypingStatusDTO.self, from: jsonData)

                    guard dto.user_id != currentUserID else { return }
                    self?.typingStatusByFriendship[friendshipID] = dto.is_typing
                } catch {
                    print("TYPING INSERT DECODE ERROR:", error.localizedDescription)
                }
            }
        }

        channel.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "friend_typing_status",
            filter: "friendship_id=eq.\(friendshipID.uuidString)"
        ) { [weak self] action in
            Task { @MainActor in
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: action.record)
                    let dto = try JSONDecoder().decode(FriendTypingStatusDTO.self, from: jsonData)

                    guard dto.user_id != currentUserID else { return }
                    self?.typingStatusByFriendship[friendshipID] = dto.is_typing
                } catch {
                    print("TYPING UPDATE DECODE ERROR:", error.localizedDescription)
                }
            }
        }

        Task {
            await channel.subscribe()
        }

        friendTypingChannel = channel
    }
    
    func setTyping(
        friendshipID: UUID,
        currentUserID: UUID?,
        currentUserName: String,
        isTyping: Bool
    ) async {
        guard let currentUserID else { return }

        struct Payload: Encodable {
            let friendship_id: UUID
            let user_id: UUID
            let user_name: String
            let is_typing: Bool
            let updated_at: String
        }

        let payload = Payload(
            friendship_id: friendshipID,
            user_id: currentUserID,
            user_name: currentUserName,
            is_typing: isTyping,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )

        do {
            try await SupabaseManager.shared.client
                .from("friend_typing_status")
                .upsert(payload)
                .execute()
        } catch {
            print("SET TYPING ERROR:", error.localizedDescription)
        }
    }
    
    private func appendFriendMessage(
        _ item: FriendChatMessageItem,
        friendshipID: UUID
    ) {
        var items = friendMessagesByFriendship[friendshipID] ?? []

        if let existingIndex = items.firstIndex(where: { $0.serverID == item.serverID }) {
            items[existingIndex] = item
        } else if let clientID = item.clientID,
                  let pendingIndex = items.firstIndex(where: {
                      $0.serverID == nil && $0.clientID == clientID
                  }) {
            items[pendingIndex] = item
        } else {
            items.append(item)
        }

        items.sort { $0.createdAt < $1.createdAt }
        friendMessagesByFriendship[friendshipID] = Array(items.suffix(100))
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
                .limit(100)
                .execute()

            let decoded = try JSONDecoder().decode([FriendMessageDTO].self, from: response.data)

            let items = decoded.map {
                mapDTOToFriendItem($0, currentUserID: currentUserID)
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
            isFailed: false,
            seenAt: nil
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

            // Realtime gelmezse fallback
            await loadMessages(for: friendshipID, currentUserID: senderID)
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
                    isFailed: true,
                    seenAt: old.seenAt
                )
            }
            friendMessagesByFriendship[friendshipID] = failed
        }
    }
    
    func markMessagesSeen(
        friendshipID: UUID,
        currentUserID: UUID?
    ) async {
        guard let currentUserID else { return }

        do {
            try await SupabaseManager.shared.client
                .from("friend_messages")
                .update(["seen_at": ISO8601DateFormatter().string(from: Date())])
                .eq("friendship_id", value: friendshipID.uuidString)
                .neq("sender_id", value: currentUserID.uuidString)
                .is("seen_at", value: nil)
                .execute()

            await loadMessages(for: friendshipID, currentUserID: currentUserID)
        } catch {
            print("MARK MESSAGES SEEN ERROR:", error.localizedDescription)
        }
    }
    
    func unsubscribePresenceRealtime() {
        Task {
            await friendPresenceChannel?.unsubscribe()
        }
        friendPresenceChannel = nil
    }
    
    func subscribeToPresenceRealtime(for userIDs: [UUID]) {
        Task {
            await friendPresenceChannel?.unsubscribe()
        }
        friendPresenceChannel = nil

        let channel = SupabaseManager.shared.client
            .realtimeV2
            .channel("friend-presence")

        channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "friend_presence"
        ) { [weak self] action in
            Task { @MainActor in
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: action.record)
                    let dto = try JSONDecoder().decode(FriendPresenceDTO.self, from: jsonData)
                    self?.presenceByUserID[dto.user_id] = dto
                } catch {
                    print("PRESENCE INSERT DECODE ERROR:", error.localizedDescription)
                }
            }
        }

        channel.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "friend_presence"
        ) { [weak self] action in
            Task { @MainActor in
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: action.record)
                    let dto = try JSONDecoder().decode(FriendPresenceDTO.self, from: jsonData)
                    self?.presenceByUserID[dto.user_id] = dto
                } catch {
                    print("PRESENCE UPDATE DECODE ERROR:", error.localizedDescription)
                }
            }
        }

        Task {
            await channel.subscribe()
        }

        friendPresenceChannel = channel
    }
    
    func loadPresence(for userIDs: [UUID]) async {
        let uniqueIDs = Array(Set(userIDs))
        guard !uniqueIDs.isEmpty else { return }

        do {
            let response = try await SupabaseManager.shared.client
                .from("friend_presence")
                .select()
                .in("user_id", values: uniqueIDs.map(\.uuidString))
                .execute()

            let decoded = try JSONDecoder().decode([FriendPresenceDTO].self, from: response.data)

            var dict: [UUID: FriendPresenceDTO] = [:]
            for item in decoded {
                dict[item.user_id] = item
                
            }
            presenceByUserID = dict
        } catch {
            print("LOAD PRESENCE ERROR:", error.localizedDescription)
        }
    }
    
    func setPresence(
        currentUserID: UUID?,
        isOnline: Bool
    ) async {
        guard let currentUserID else { return }

        struct Payload: Encodable {
            let user_id: UUID
            let is_online: Bool
            let last_seen_at: String
            let updated_at: String
        }

        let now = ISO8601DateFormatter().string(from: Date())

        let payload = Payload(
            user_id: currentUserID,
            is_online: isOnline,
            last_seen_at: now,
            updated_at: now
        )

        do {
            try await SupabaseManager.shared.client
                .from("friend_presence")
                .upsert(payload)
                .execute()
        } catch {
            print("SET PRESENCE ERROR:", error.localizedDescription)
        }
    }

    // MARK: - Realtime

    func subscribeToFriendMessagesRealtime(
        friendshipID: UUID,
        currentUserID: UUID?
    ) {
        

        let currentUserIDCopy = currentUserID

        Task {
            await friendMessagesChannel?.unsubscribe()
        }
        friendMessagesChannel = nil

        let client = SupabaseManager.shared.client
        let channel = client.realtimeV2.channel("friend-messages-\(friendshipID.uuidString)")

        channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "friend_messages",
            filter: "friendship_id=eq.\(friendshipID.uuidString)"
        ) { [weak self] action in
            Task { @MainActor in
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: action.record)
                    let dto = try JSONDecoder().decode(FriendMessageDTO.self, from: jsonData)

                    guard let self else { return }
                    let item = self.mapDTOToFriendItem(dto, currentUserID: currentUserIDCopy)
                    self.appendFriendMessage(item, friendshipID: friendshipID)
                    if dto.sender_id != currentUserIDCopy {
                        Task {
                            await self.markMessagesSeen(
                                friendshipID: friendshipID,
                                currentUserID: currentUserIDCopy
                            )
                        }
                    }
                } catch {
                    print("REALTIME DECODE ERROR:", error.localizedDescription)
                }
            }
        }
        channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "friend_typing_status"
        ) { [weak self] action in
            Task { @MainActor in
                guard let self else { return }

                if let userIDString = action.record["user_id"] as? String,
                   let userID = UUID(uuidString: userIDString),
                   let name = action.record["user_name"] as? String {

                    self.typingUsers[userID] = name

                    // 2 saniye sonra sil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.typingUsers.removeValue(forKey: userID)
                    }
                }
            }
        }

        Task {
            await channel.subscribe()
        }

        friendMessagesChannel = channel
        subscribedFriendshipID = friendshipID
    }
    

    func unsubscribeFriendMessagesRealtime() {
        Task {
            await friendMessagesChannel?.unsubscribe()
        }
        friendMessagesChannel = nil
        subscribedFriendshipID = nil
    }
}
