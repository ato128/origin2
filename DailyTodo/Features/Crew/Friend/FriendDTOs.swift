//
//  FriendDTOs.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 20.03.2026.
//

import Foundation

struct FriendshipDTO: Codable, Identifiable {
    let id: UUID
    let requester_id: UUID
    let addressee_id: UUID
    let status: String
    let created_at: String?
}

struct FriendProfileDTO: Codable, Identifiable {
    let id: UUID
    let username: String?
    let full_name: String?
    let email: String?
}


