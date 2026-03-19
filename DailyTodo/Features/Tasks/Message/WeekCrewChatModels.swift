//
//  WeekCrewChatModels.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import Foundation

struct WeekCrewMessageItem: Identifiable, Hashable {
    let id: UUID
    let crewID: UUID
    let senderID: UUID?
    let senderName: String
    let text: String
    let isFromMe: Bool
    let createdAt: Date
    let isRead: Bool
    let reaction: String?
}

