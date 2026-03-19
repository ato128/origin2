//
//  CrewTypingStatusDTO.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import Foundation

struct CrewTypingStatusDTO: Codable, Identifiable, Equatable {
    let crew_id: UUID
    let user_id: UUID
    let name: String
    let is_typing: Bool
    let updated_at: String?

    var id: String {
        "\(crew_id.uuidString)-\(user_id.uuidString)"
    }

    enum CodingKeys: String, CodingKey {
        case crew_id
        case user_id
        case name
        case is_typing
        case updated_at
    }
}
