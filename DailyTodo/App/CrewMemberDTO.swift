//
//  CrewMemberDTO.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import Foundation

struct CrewMemberDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let crew_id: UUID
    let user_id: UUID
    let role: String
    let created_at: String?

    enum CodingKeys: String, CodingKey {
        case id
        case crew_id
        case user_id
        case role
        case created_at
    }
}
