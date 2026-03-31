//
//  FriendChatMessageItem.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 20.03.2026.
//

import Foundation

struct FriendChatMessageItem: Identifiable, Equatable {
    let id: UUID
    let serverID: UUID?
    let clientID: String?
    let friendshipID: UUID
    let senderID: UUID?
    let senderName: String
    let text: String
    let createdAt: Date
    let reaction: String?
    let isSystemMessage: Bool
    let isFromMe: Bool
    let isPending: Bool
    let isFailed: Bool
    let seenAt: Date?

    let messageType: String
    let mediaURL: String?
    let fileName: String?
    let fileSizeBytes: Int64?
    let mimeType: String?
    let messageStatus: String

    init(
        id: UUID,
        serverID: UUID? = nil,
        clientID: String? = nil,
        friendshipID: UUID,
        senderID: UUID? = nil,
        senderName: String,
        text: String,
        createdAt: Date,
        reaction: String? = nil,
        isSystemMessage: Bool = false,
        isFromMe: Bool,
        isPending: Bool = false,
        isFailed: Bool = false,
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
        self.friendshipID = friendshipID
        self.senderID = senderID
        self.senderName = senderName
        self.text = text
        self.createdAt = createdAt
        self.reaction = reaction
        self.isSystemMessage = isSystemMessage
        self.isFromMe = isFromMe
        self.isPending = isPending
        self.isFailed = isFailed
        self.seenAt = seenAt
        self.messageType = messageType
        self.mediaURL = mediaURL
        self.fileName = fileName
        self.fileSizeBytes = fileSizeBytes
        self.mimeType = mimeType
        self.messageStatus = messageStatus
    }
}
