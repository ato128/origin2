//
//  CrewMessageDTO.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import Foundation

struct CrewMessageDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let crew_id: UUID
    let sender_id: UUID?
    let sender_name: String
    let text: String
    let created_at: String
    let is_read: Bool
    let reaction: String?
    let is_system_message: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case crew_id
        case sender_id
        case sender_name
        case text
        case created_at
        case is_read
        case reaction
        case is_system_message
    }
}
