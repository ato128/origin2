//
//  FriendWeekShareDTO.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 21.03.2026.
//

import Foundation

struct FriendWeekShareDTO: Codable, Identifiable {
    let id: UUID
    let friendship_id: UUID
    let owner_user_id: UUID
    let viewer_user_id: UUID
    let is_enabled: Bool
    let updated_at: String
}
