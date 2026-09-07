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
    /// Arkadaş şu an odak (focus) seansında mı — backend user_stats.is_focusing'ten.
    /// "Çevrimiçi" yerine "Odakta" göstermek için (varsayılan false → geriye dönük uyumlu).
    var is_focusing: Bool = false

    var id: UUID { user_id }
}
