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
}
