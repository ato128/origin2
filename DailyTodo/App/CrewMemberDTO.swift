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

    // Personal chat state
    let unread_count: Int?
    let is_pinned: Bool?
    let is_muted: Bool?
    let is_archived: Bool?
    let last_read_at: String?

    enum CodingKeys: String, CodingKey {
        case id
        case crew_id
        case user_id
        case role
        case created_at

        case unread_count
        case is_pinned
        case is_muted
        case is_archived
        case last_read_at
    }
}
