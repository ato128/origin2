//
//  TypingPayload.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import Foundation

struct CrewTypingPayload: Codable {
    let crewID: UUID
    let userID: UUID
    let name: String
    let isTyping: Bool
}
