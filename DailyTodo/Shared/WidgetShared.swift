//
//  WidgetShared.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 3.03.2026.
//

import Foundation

// ✅ TEK KAYNAK: Hem App hem Widget bunu kullanacak
enum WidgetShared {
    // SENİN ID (bunu zaten yazdın)
    static let appGroupID = "group.com.atakan.updo"

    // ✅ Tek key — HER YERDE AYNI
    static let payloadKey = "schedule_payload_v1"

    static func writePayload(_ payload: WidgetPayload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults(suiteName: appGroupID)?.set(data, forKey: payloadKey)
    }

    static func readPayload() -> WidgetPayload? {
        guard let data = UserDefaults(suiteName: appGroupID)?.data(forKey: payloadKey) else { return nil }
        return try? JSONDecoder().decode(WidgetPayload.self, from: data)
    }

    // MARK: - User state (icon theme + Pro stats) for widgets / live activities

    static let userStateKey = "widget_user_state_v1"

    static func writeUserState(_ state: WidgetUserState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults(suiteName: appGroupID)?.set(data, forKey: userStateKey)
    }

    static func readUserState() -> WidgetUserState {
        guard let data = UserDefaults(suiteName: appGroupID)?.data(forKey: userStateKey),
              let state = try? JSONDecoder().decode(WidgetUserState.self, from: data)
        else { return .placeholder }
        return state
    }
}

// MARK: - Models written to App Group

struct WidgetPayload: Codable {
    var weekday: Int
    var events: [WidgetEvent]
}

struct WidgetEvent: Codable, Identifiable {
    var id: String
    var title: String
    var weekday: Int
    var startMinute: Int
    var durationMinute: Int
    var location: String?
    var colorHex: String
}

/// Shared snapshot the app pushes for widget/live-activity theming and Pro extras.
struct WidgetUserState: Codable {
    /// Selected alternate app-icon name (nil = default "Steel"). Drives the logo
    /// + accent color so widgets mirror the chosen icon.
    var iconName: String?
    var isPro: Bool
    var streak: Int
    var level: Int
    var todayFocusMinutes: Int
    var statsShared: Bool
    var longestStreak: Int = 0

    // Today's two streak requirements (optional so old snapshots still decode).
    // `statusDayKey` ("yyyy-MM-dd") lets widgets ignore yesterday's stale flags.
    var todayTaskDone: Bool?
    var todayFocusDone: Bool?
    var statusDayKey: String?

    static let placeholder = WidgetUserState(
        iconName: nil,
        isPro: false,
        streak: 0,
        level: 1,
        todayFocusMinutes: 0,
        statsShared: true,
        longestStreak: 0
    )

    static func dayKey(_ date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// True only if the day-status flags were written today.
    var statusIsFresh: Bool {
        statusDayKey == WidgetUserState.dayKey()
    }
}
