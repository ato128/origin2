//
//  FriendTypingStatusDTO.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 21.03.2026.
//

import Foundation

struct FriendTypingStatusDTO: Codable, Identifiable {
    let friendship_id: UUID
    let user_id: UUID
    let user_name: String?
    let is_typing: Bool
    let updated_at: String?

    var id: UUID { friendship_id }
}
