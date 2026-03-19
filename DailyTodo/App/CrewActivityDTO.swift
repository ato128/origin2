//
//  CrewActivityDTO.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import Foundation

struct CrewActivityDTO: Codable, Identifiable {
    let id: UUID
    let crew_id: UUID
    let member_name: String
    let action_text: String
    let created_at: String?
}
