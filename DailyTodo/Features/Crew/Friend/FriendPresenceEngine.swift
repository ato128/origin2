//
//  FriendPresenceEngine.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 29.04.2026.
//

import Foundation

enum FriendPresenceEngine {
    static let onlineTTL: TimeInterval = 45

    static func isOnline(_ presence: FriendPresenceDTO?) -> Bool {
        guard let presence else { return false }
        guard presence.is_online else { return false }

        guard let lastSeen = CrewDateParser.parse(presence.last_seen_at) else {
            return false
        }

        return Date().timeIntervalSince(lastSeen) <= onlineTTL
    }

    static func statusText(
        presence: FriendPresenceDTO?,
        locale: Locale
    ) -> String {
        guard let presence else {
            return tr("chat_direct_chat")
        }

        if isOnline(presence) {
            return tr("chat_online")
        }

        let date = CrewDateParser.parse(presence.last_seen_at) ?? Date()
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = locale

        let relative = formatter.localizedString(for: date, relativeTo: Date())
        return tr("chat_last_seen_format", relative)
    }
}
