//
//  FriendChatThreadSummary.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 28.04.2026.
//

import Foundation
import SwiftUI

struct FriendChatThreadSummary: Identifiable, Equatable {
    let id: UUID
    let friendshipID: UUID
    let friendUserID: UUID?
    let title: String
    let subtitle: String
    let avatarSymbol: String
    let colorHex: String?
    let lastMessageText: String
    let lastMessageAt: Date?
    let unreadCount: Int
    let isPinned: Bool
    let isMuted: Bool
    let isArchived: Bool
    let isOnline: Bool
    let typingText: String?

    var sortDate: Date {
        lastMessageAt ?? .distantPast
    }
}
