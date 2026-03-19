//
//  CrewMemberDTO.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import Foundation

struct CrewMemberDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let created_at: String?
    let crew_id: UUID
    let user_id: UUID
    let role: String
}
