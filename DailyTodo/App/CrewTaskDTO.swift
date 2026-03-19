//
//  CrewTaskDTO.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import Foundation

struct CrewTaskDTO: Codable, Identifiable {
    let id: UUID
    let crew_id: UUID
    let created_by: UUID
    let title: String
    let is_done: Bool
    let assigned_to: UUID?
    let created_at: String?

    let details: String?
    let priority: String
    let status: String
    let show_on_week: Bool
    let scheduled_weekday: Int?
    let scheduled_start_minute: Int?
    let scheduled_duration_minute: Int?
}
