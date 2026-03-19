//
//  ProfileDTO.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import Foundation

struct ProfileDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let email: String
    let username: String?
    let full_name: String?
}
