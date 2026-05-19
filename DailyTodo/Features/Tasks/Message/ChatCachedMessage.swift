//
//  ChatCachedMessage.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.05.2026.
//

import Foundation
import SwiftData

@Model
final class ChatCachedMessage {
    @Attribute(.unique)
    var cacheKey: String

    var id: UUID
    var serverID: UUID?
    var clientID: String?
    var conversationID: UUID?
    var friendshipID: UUID

    var senderID: UUID?
    var senderName: String
    var text: String
    var createdAt: Date
    var updatedAt: Date

    var reaction: String?
    var isSystemMessage: Bool
    var isFromMe: Bool
    var isPending: Bool
    var isFailed: Bool

    var deliveredAt: Date?
    var seenAt: Date?

    var messageType: String
    var mediaURL: String?
    var fileName: String?
    var fileSizeBytes: Int64?
    var mimeType: String?
    var messageStatus: String

    init(
        id: UUID,
        serverID: UUID? = nil,
        clientID: String? = nil,
        conversationID: UUID? = nil,
        friendshipID: UUID,
        senderID: UUID? = nil,
        senderName: String,
        text: String,
        createdAt: Date,
        updatedAt: Date = Date(),
        reaction: String? = nil,
        isSystemMessage: Bool = false,
        isFromMe: Bool,
        isPending: Bool = false,
        isFailed: Bool = false,
        deliveredAt: Date? = nil,
        seenAt: Date? = nil,
        messageType: String = "text",
        mediaURL: String? = nil,
        fileName: String? = nil,
        fileSizeBytes: Int64? = nil,
        mimeType: String? = nil,
        messageStatus: String = "sent"
    ) {
        self.id = id
        self.serverID = serverID
        self.clientID = clientID
        self.conversationID = conversationID
        self.friendshipID = friendshipID

        if let serverID {
            self.cacheKey = "server-\(serverID.uuidString)"
        } else if let clientID, !clientID.isEmpty {
            self.cacheKey = "client-\(clientID)"
        } else {
            self.cacheKey = "local-\(id.uuidString)"
        }

        self.senderID = senderID
        self.senderName = senderName
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt

        self.reaction = reaction
        self.isSystemMessage = isSystemMessage
        self.isFromMe = isFromMe
        self.isPending = isPending
        self.isFailed = isFailed

        self.deliveredAt = deliveredAt
        self.seenAt = seenAt

        self.messageType = messageType
        self.mediaURL = mediaURL
        self.fileName = fileName
        self.fileSizeBytes = fileSizeBytes
        self.mimeType = mimeType
        self.messageStatus = messageStatus
    }
}

// MARK: - Mapping

extension ChatCachedMessage {
    func toFriendChatMessageItem() -> FriendChatMessageItem {
        FriendChatMessageItem(
            id: id,
            serverID: serverID,
            clientID: clientID,
            friendshipID: friendshipID,
            senderID: senderID,
            senderName: senderName,
            text: text,
            createdAt: createdAt,
            reaction: reaction,
            isSystemMessage: isSystemMessage,
            isFromMe: isFromMe,
            isPending: isPending,
            isFailed: isFailed,
            deliveredAt: deliveredAt,
            seenAt: seenAt,
            messageType: messageType,
            mediaURL: mediaURL,
            fileName: fileName,
            fileSizeBytes: fileSizeBytes,
            mimeType: mimeType,
            messageStatus: messageStatus
        )
    }

    func update(from message: FriendChatMessageItem, conversationID: UUID?) {
        self.id = message.serverID ?? message.id
        self.serverID = message.serverID
        self.clientID = message.clientID
        self.conversationID = conversationID
        self.friendshipID = message.friendshipID
        self.senderID = message.senderID
        self.senderName = message.senderName
        self.text = message.text
        self.createdAt = message.createdAt
        self.updatedAt = Date()

        self.reaction = message.reaction
        self.isSystemMessage = message.isSystemMessage
        self.isFromMe = message.isFromMe
        self.isPending = message.isPending
        self.isFailed = message.isFailed

        self.deliveredAt = message.deliveredAt
        self.seenAt = message.seenAt

        self.messageType = message.messageType
        self.mediaURL = message.mediaURL
        self.fileName = message.fileName
        self.fileSizeBytes = message.fileSizeBytes
        self.mimeType = message.mimeType
        self.messageStatus = message.messageStatus

        if let serverID = message.serverID {
            self.cacheKey = "server-\(serverID.uuidString)"
        } else if let clientID = message.clientID, !clientID.isEmpty {
            self.cacheKey = "client-\(clientID)"
        } else {
            self.cacheKey = "local-\(message.id.uuidString)"
        }
    }
}
