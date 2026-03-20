//
//  CrewFocusSessionDTO.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 20.03.2026.
//

import Foundation

struct CrewFocusSessionDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let crew_id: UUID
    let host_user_id: UUID?
    let host_name: String
    let title: String
    let task_id: UUID?
    let task_title: String?
    let duration_minutes: Int
    let started_at: String
    let is_active: Bool
    let is_paused: Bool
    let paused_remaining_seconds: Int?
    let ended_at: String?
    let created_at: String?
}
