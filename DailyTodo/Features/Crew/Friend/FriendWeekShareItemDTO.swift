//
//  FriendWeekShareItemDTO.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 21.03.2026.
//


import Foundation

struct FriendWeekShareItemDTO: Codable, Identifiable {
    let id: UUID
    let friendship_id: UUID
    let owner_user_id: UUID
    let viewer_user_id: UUID

    let title: String
    let details: String?
    let weekday: Int
    let start_minute: Int
    let duration_minute: Int
}
