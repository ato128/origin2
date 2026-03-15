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

    init(
        id: UUID = UUID(),
        friendID: UUID,
        senderName: String,
        text: String,
        isFromMe: Bool,
        createdAt: Date = Date(),
        isRead: Bool = false
    ) {
        self.id = id
        self.friendID = friendID
        self.senderName = senderName
        self.text = text
        self.isFromMe = isFromMe
        self.createdAt = createdAt
        self.isRead = isRead
    }
}
