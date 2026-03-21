//
//  FriendPresenceDTO.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 21.03.2026.
//

import Foundation

struct FriendPresenceDTO: Codable, Identifiable {
    let user_id: UUID
    let is_online: Bool
    let last_seen_at: String
    let updated_at: String?

    var id: UUID { user_id }
}
