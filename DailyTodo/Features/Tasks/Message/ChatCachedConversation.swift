//
//  ChatCachedConversation.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.05.2026.
//

import Foundation
import SwiftData

@Model
final class ChatCachedConversation {
    @Attribute(.unique)
    var cacheKey: String

    var ownerUserID: UUID
    var id: UUID
    var type: String

    var supabaseFriendshipId: UUID?
    var supabaseCrewId: UUID?

    var title: String?
    var lastMessageText: String?
    var lastMessageAt: String?
    var unreadCount: Int

    var isMuted: Bool
    var isArchived: Bool
    var isPinned: Bool

    var updatedAt: String?
    var cachedAt: Date

    init(
        ownerUserID: UUID,
        id: UUID,
        type: String,
        supabaseFriendshipId: UUID? = nil,
        supabaseCrewId: UUID? = nil,
        title: String? = nil,
        lastMessageText: String? = nil,
        lastMessageAt: String? = nil,
        unreadCount: Int = 0,
        isMuted: Bool = false,
        isArchived: Bool = false,
        isPinned: Bool = false,
        updatedAt: String? = nil,
        cachedAt: Date = Date()
    ) {
        self.ownerUserID = ownerUserID
        self.id = id
        self.type = type
        self.supabaseFriendshipId = supabaseFriendshipId
        self.supabaseCrewId = supabaseCrewId
        self.title = title
        self.lastMessageText = lastMessageText
        self.lastMessageAt = lastMessageAt
        self.unreadCount = unreadCount
        self.isMuted = isMuted
        self.isArchived = isArchived
        self.isPinned = isPinned
        self.updatedAt = updatedAt
        self.cachedAt = cachedAt
        self.cacheKey = "\(ownerUserID.uuidString)-\(id.uuidString)"
    }
}

extension ChatCachedConversation {
    convenience init(
        ownerUserID: UUID,
        conversation: ChatBackendConversationDTO
    ) {
        self.init(
            ownerUserID: ownerUserID,
            id: conversation.id,
            type: conversation.type,
            supabaseFriendshipId: conversation.supabaseFriendshipId,
            supabaseCrewId: conversation.supabaseCrewId,
            title: conversation.title,
            lastMessageText: conversation.lastMessageText,
            lastMessageAt: conversation.lastMessageAt,
            unreadCount: conversation.unreadCount,
            isMuted: conversation.isMuted,
            isArchived: conversation.isArchived,
            isPinned: conversation.isPinned,
            updatedAt: conversation.updatedAt
        )
    }

    func update(from conversation: ChatBackendConversationDTO) {
        id = conversation.id
        type = conversation.type
        supabaseFriendshipId = conversation.supabaseFriendshipId
        supabaseCrewId = conversation.supabaseCrewId
        title = conversation.title
        lastMessageText = conversation.lastMessageText
        lastMessageAt = conversation.lastMessageAt
        unreadCount = conversation.unreadCount
        isMuted = conversation.isMuted
        isArchived = conversation.isArchived
        isPinned = conversation.isPinned
        updatedAt = conversation.updatedAt
        cachedAt = Date()
        cacheKey = "\(ownerUserID.uuidString)-\(id.uuidString)"
    }

    func toDTO() -> ChatBackendConversationDTO {
        ChatBackendConversationDTO(
            id: id,
            type: type,
            supabaseFriendshipId: supabaseFriendshipId,
            supabaseCrewId: supabaseCrewId,
            title: title,
            lastMessageText: lastMessageText,
            lastMessageAt: lastMessageAt,
            unreadCount: unreadCount,
            isMuted: isMuted,
            isArchived: isArchived,
            isPinned: isPinned,
            updatedAt: updatedAt
        )
    }
}
