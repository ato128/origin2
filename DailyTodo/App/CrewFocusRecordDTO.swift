//
//  CrewFocusRecordDTO.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import Foundation

struct CrewFocusRecordDTO: Codable, Identifiable {
    let id: UUID
    let crew_id: UUID
    let user_id: UUID?
    let member_name: String
    let minutes: Int
    let created_at: String?
}
