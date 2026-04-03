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
