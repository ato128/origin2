//
//  FriendMessage.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import Foundation
import SwiftData

@Model
final class FriendMessage {
    var id: UUID
    var friendID: UUID
    var senderName: String
    var text: String
    var isFromMe: Bool
    var createdAt: Date
    var isRead: Bool
    var reaction: String?

    var messageType: String
    var mediaURL: String?
    var fileName: String?
    var fileSizeBytes: Int64?
    var mimeType: String?

    init(
        id: UUID = UUID(),
        friendID: UUID,
        senderName: String,
        text: String,
        isFromMe: Bool,
        createdAt: Date = Date(),
        isRead: Bool = false,
        reaction: String? = nil,
        messageType: String = "text",
        mediaURL: String? = nil,
        fileName: String? = nil,
        fileSizeBytes: Int64? = nil,
        mimeType: String? = nil
    ) {
        self.id = id
        self.friendID = friendID
        self.senderName = senderName
        self.text = text
        self.isFromMe = isFromMe
        self.createdAt = createdAt
        self.isRead = isRead
        self.reaction = reaction
        self.messageType = messageType
        self.mediaURL = mediaURL
        self.fileName = fileName
        self.fileSizeBytes = fileSizeBytes
        self.mimeType = mimeType
    }
}
