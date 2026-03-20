//
//  CrewFocusParticipantDTO.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 20.03.2026.
//

import Foundation

struct CrewFocusParticipantDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let session_id: UUID
    let crew_id: UUID
    let user_id: UUID?
    let member_name: String
    let is_active: Bool
    let joined_at: String
    let left_at: String?
}
