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

    /// Arkadaş şu an odak seansında mı (backend user_stats.is_focusing).
    static func isFocusing(_ presence: FriendPresenceDTO?) -> Bool {
        presence?.is_focusing == true
    }

    /// How long the friend has been focusing in this run (minutes, ≥ 1), from
    /// the effective start they published when the run began / resumed.
    static func focusMinutes(_ presence: FriendPresenceDTO?, now: Date = Date()) -> Int? {
        guard let presence, presence.is_focusing,
              let raw = presence.focusing_since,
              let since = CrewDateParser.parse(raw) else { return nil }
        let minutes = Int(now.timeIntervalSince(since) / 60)
        return minutes >= 0 ? max(1, minutes) : nil
    }

    /// "Odakta · 12 dk" — or plain "Odakta" when the start isn't known yet.
    static func focusingText(_ presence: FriendPresenceDTO?) -> String {
        if let minutes = focusMinutes(presence) { return tr("chat_in_focus_min", minutes) }
        return tr("chat_in_focus")
    }

    static func statusText(
        presence: FriendPresenceDTO?,
        locale: Locale
    ) -> String {
        guard let presence else {
            return tr("chat_direct_chat")
        }

        // "Odakta" online'ın önüne geçer — arkadaş çalışıyorsa en anlamlı sinyal bu.
        if presence.is_focusing {
            return focusingText(presence)
        }

        if isOnline(presence) {
            return tr("chat_online")
        }

        // Son görülme bilinmiyorsa yanıltıcı "az önce" ÜRETME — jenerik çevrimdışı.
        guard let date = CrewDateParser.parse(presence.last_seen_at) else {
            return offlineFallback(locale: locale)
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = locale

        let relative = formatter.localizedString(for: date, relativeTo: Date())
        return tr("chat_last_seen_format", relative)
    }

    private static func offlineFallback(locale: Locale) -> String {
        let code = locale.language.languageCode?.identifier ?? "en"
        return code == "tr" ? "Çevrimdışı" : "Offline"
    }
}
