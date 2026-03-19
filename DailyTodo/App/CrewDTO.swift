//
//  CrewDTO.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import Foundation

struct CrewDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let created_at: String?
    let owner_id: UUID
    let name: String
    let icon: String
    let color_hex: String
}
