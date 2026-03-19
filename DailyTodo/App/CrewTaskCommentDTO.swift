//
//  CrewTaskCommentDTO.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import Foundation

struct CrewTaskCommentDTO: Codable, Identifiable, Hashable {
    let id: UUID
    let task_id: UUID
    let author_name: String
    let message: String
    let created_at: String
    let crew_id: UUID?
}
