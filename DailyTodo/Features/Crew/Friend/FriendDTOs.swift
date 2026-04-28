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
    let last_message_text: String?
    let last_message_at: String?
    let last_sender_id: UUID?

    let requester_unread_count: Int?
    let addressee_unread_count: Int?

    let requester_pinned: Bool?
    let addressee_pinned: Bool?

    let requester_muted: Bool?
    let addressee_muted: Bool?

    let requester_archived: Bool?
    let addressee_archived: Bool?
}

struct FriendProfileDTO: Codable, Identifiable {
    let id: UUID
    let username: String?
    let full_name: String?
    let email: String?
}


