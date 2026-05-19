//
//  ChatCachedConversationMessage.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.05.2026.
//

import Foundation
import SwiftData

@Model
final class ChatCachedConversationMessage {
    @Attribute(.unique)
    var cacheKey: String

    var ownerUserID: UUID
    var conversationID: UUID
    var supabaseCrewID: UUID?

    var id: UUID
    var serverID: UUID?
    var clientID: String?

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

    var seenAt: Date?

    var messageType: String
    var mediaURL: String?
    var fileName: String?
    var fileSizeBytes: Int64?
    var mimeType: String?
    var messageStatus: String

    init(
        ownerUserID: UUID,
        conversationID: UUID,
        supabaseCrewID: UUID? = nil,
        id: UUID,
        serverID: UUID? = nil,
        clientID: String? = nil,
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
        seenAt: Date? = nil,
        messageType: String = "text",
        mediaURL: String? = nil,
        fileName: String? = nil,
        fileSizeBytes: Int64? = nil,
        mimeType: String? = nil,
        messageStatus: String = "sent"
    ) {
        self.ownerUserID = ownerUserID
        self.conversationID = conversationID
        self.supabaseCrewID = supabaseCrewID

        self.id = id
        self.serverID = serverID
        self.clientID = clientID

        if let serverID {
            self.cacheKey = "\(ownerUserID.uuidString)-server-\(serverID.uuidString)"
        } else if let clientID, !clientID.isEmpty {
            self.cacheKey = "\(ownerUserID.uuidString)-client-\(clientID)"
        } else {
            self.cacheKey = "\(ownerUserID.uuidString)-local-\(id.uuidString)"
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

        self.seenAt = seenAt

        self.messageType = messageType
        self.mediaURL = mediaURL
        self.fileName = fileName
        self.fileSizeBytes = fileSizeBytes
        self.mimeType = mimeType
        self.messageStatus = messageStatus
    }
}

// MARK: - Crew Mapping

extension ChatCachedConversationMessage {
    func toCrewChatMessageItem() -> CrewChatMessageItem {
        CrewChatMessageItem(
            id: id,
            serverID: serverID,
            clientID: clientID,
            crewID: supabaseCrewID ?? UUID(),
            senderID: senderID,
            senderName: senderName,
            text: text,
            createdAt: createdAt,
            reaction: reaction,
            isSystemMessage: isSystemMessage,
            isFromMe: isFromMe,
            isPending: isPending,
            isFailed: isFailed
        )
    }

    func update(
        from message: CrewChatMessageItem,
        ownerUserID: UUID,
        conversationID: UUID
    ) {
        self.ownerUserID = ownerUserID
        self.conversationID = conversationID
        self.supabaseCrewID = message.crewID

        self.id = message.serverID ?? message.id
        self.serverID = message.serverID
        self.clientID = message.clientID

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

        if message.isFailed {
            self.messageStatus = "failed"
        } else if message.isPending {
            self.messageStatus = "pending"
        } else {
            self.messageStatus = "sent"
        }

        if let serverID = message.serverID {
            self.cacheKey = "\(ownerUserID.uuidString)-server-\(serverID.uuidString)"
        } else if let clientID = message.clientID, !clientID.isEmpty {
            self.cacheKey = "\(ownerUserID.uuidString)-client-\(clientID)"
        } else {
            self.cacheKey = "\(ownerUserID.uuidString)-local-\(message.id.uuidString)"
        }
    }
}
