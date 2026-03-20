//
//  FriendMessageDTO.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 20.03.2026.
//

import Foundation

struct FriendMessageDTO: Codable, Identifiable {
    let id: UUID
    let friendship_id: UUID
    let sender_id: UUID?
    let sender_name: String
    let text: String
    let created_at: String?
    let reaction: String?
    let is_system_message: Bool?
    let client_id: String?
}
