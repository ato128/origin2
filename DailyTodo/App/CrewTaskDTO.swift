//
//  CrewTaskDTO.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import Foundation

struct CrewTaskDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let crew_id: UUID
    let created_by: UUID
    var title: String
    var is_done: Bool
    var assigned_to: UUID?
    let created_at: String?

    var details: String?
    var priority: String
    var status: String
    var show_on_week: Bool
    var scheduled_weekday: Int?
    var scheduled_start_minute: Int?
    var scheduled_duration_minute: Int?
}
