//
//  CrewChatMessageItem.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 20.03.2026.
//

import Foundation

struct CrewChatMessageItem: Identifiable, Equatable {
    let id: UUID
    let serverID: UUID?
    let clientID: String?
    let crewID: UUID
    let senderID: UUID?
    let senderName: String
    let text: String
    let createdAt: Date
    let reaction: String?
    let isSystemMessage: Bool
    let isFromMe: Bool
    let isPending: Bool
    let isFailed: Bool

    let messageType: String
    let mediaURL: String?
    let fileName: String?
    let fileSizeBytes: Int64?
    let mimeType: String?
    let messageStatus: String

    let displayText: String
    let replyPreview: String?

    init(
        id: UUID = UUID(),
        serverID: UUID?,
        clientID: String?,
        crewID: UUID,
        senderID: UUID?,
        senderName: String,
        text: String,
        createdAt: Date,
        reaction: String?,
        isSystemMessage: Bool,
        isFromMe: Bool,
        isPending: Bool,
        isFailed: Bool,
        messageType: String = "text",
        mediaURL: String? = nil,
        fileName: String? = nil,
        fileSizeBytes: Int64? = nil,
        mimeType: String? = nil,
        messageStatus: String = "sent",
        replyMarker: String = "[[reply]]",
        bodyMarker: String = "[[body]]"
    ) {
        self.id = id
        self.serverID = serverID
        self.clientID = clientID
        self.crewID = crewID
        self.senderID = senderID
        self.senderName = senderName
        self.text = text
        self.createdAt = createdAt
        self.reaction = reaction
        self.isSystemMessage = isSystemMessage
        self.isFromMe = isFromMe
        self.isPending = isPending
        self.isFailed = isFailed

        self.messageType = messageType
        self.mediaURL = mediaURL
        self.fileName = fileName
        self.fileSizeBytes = fileSizeBytes
        self.mimeType = mimeType
        self.messageStatus = messageStatus

        if text.hasPrefix(replyMarker), let bodyRange = text.range(of: bodyMarker) {
            let previewStart = text.index(text.startIndex, offsetBy: replyMarker.count)
            let preview = String(text[previewStart..<bodyRange.lowerBound])
            let body = String(text[bodyRange.upperBound...])

            self.replyPreview = preview.isEmpty ? nil : preview
            self.displayText = body
        } else {
            self.replyPreview = nil
            self.displayText = text
        }
    }
}
