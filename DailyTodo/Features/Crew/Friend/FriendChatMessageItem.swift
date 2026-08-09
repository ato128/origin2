//
//  FriendChatMessageItem.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 20.03.2026.
//

import Foundation

/// Toplu emoji reaksiyon (iMessage tapback): bir emoji, kaç kişi verdi, ben verdim mi.
/// Backend `chat_message_reactions`'tan toplanır; friend + crew ortak kullanır.
struct ChatReactionSummary: Codable, Equatable, Hashable, Identifiable {
    let emoji: String
    let count: Int
    let mine: Bool

    var id: String { emoji }
}

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
    let deliveredAt: Date?
    let seenAt: Date?

    let messageType: String
    let mediaURL: String?
    let fileName: String?
    let fileSizeBytes: Int64?
    let mimeType: String?
    let messageStatus: String

    /// iMessage-style reply: alıntılanan mesajın kısa önizlemesi (varsa).
    let replyPreview: String?
    /// Baloncukta gösterilecek gerçek metin (reply marker'ı ayıklanmış).
    let displayText: String

    /// Per-user emoji reaksiyonlar (toplu). Backend'den gelir / realtime güncellenir.
    var reactions: [ChatReactionSummary]

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
        deliveredAt: Date? = nil,
        seenAt: Date? = nil,
        messageType: String = "text",
        mediaURL: String? = nil,
        fileName: String? = nil,
        fileSizeBytes: Int64? = nil,
        mimeType: String? = nil,
        messageStatus: String = "sent_to_server",
        reactions: [ChatReactionSummary] = [],
        replyMarker: String = "[[reply]]",
        bodyMarker: String = "[[body]]"
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
        self.deliveredAt = deliveredAt
        self.seenAt = seenAt
        self.messageType = messageType
        self.mediaURL = mediaURL
        self.fileName = fileName
        self.fileSizeBytes = fileSizeBytes
        self.mimeType = mimeType
        self.messageStatus = messageStatus
        self.reactions = reactions

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
