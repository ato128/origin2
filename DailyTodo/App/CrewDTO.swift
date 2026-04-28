//
//  CrewDTO.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import Foundation

struct CrewDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let created_at: String?
    let owner_id: UUID
    let name: String
    let icon: String
    let color_hex: String

    // Chat Metadata
    let last_message_text: String?
    let last_message_at: String?
    let last_sender_id: UUID?
}
