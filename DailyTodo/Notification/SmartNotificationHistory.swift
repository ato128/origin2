//
//  SmartNotificationHistory.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 4.06.2026.
//

import Foundation

struct SmartNotificationHistoryRecord: Codable, Identifiable {
    let id: String
    let category: String
    let scheduledAt: Date
    let triggerAt: Date
}

@MainActor
final class SmartNotificationHistory {
    static let shared = SmartNotificationHistory()

    private init() {}

    private let storageKey = "updo.smart_notification_history.v1"

    private var calendar: Calendar {
        Calendar.current
    }

    func canSchedule(
        id: String,
        category: SmartNotificationCategory,
        triggerAt: Date,
        now: Date = Date()
    ) -> Bool {
        cleanupOldRecords(now: now)

        let records = loadRecords()

        if records.contains(where: { $0.id == id }) {
            return false
        }

        let todayRecords = records.filter {
            calendar.isDate($0.triggerAt, inSameDayAs: triggerAt)
        }

        if todayRecords.count >= 2 {
            return false
        }

        let weekRecords = records.filter {
            calendar.isDate($0.triggerAt, equalTo: triggerAt, toGranularity: .weekOfYear)
        }

        if weekRecords.count >= 8 {
            return false
        }

        let sameCategoryToday = todayRecords.contains {
            $0.category == category.rawValue
        }

        if sameCategoryToday {
            return false
        }

        let tooCloseToAnotherNotification = records.contains { record in
            abs(record.triggerAt.timeIntervalSince(triggerAt)) < 4 * 60 * 60
        }

        if tooCloseToAnotherNotification {
            return false
        }

        return true
    }

    func recordScheduled(
        id: String,
        category: SmartNotificationCategory,
        triggerAt: Date,
        now: Date = Date()
    ) {
        var records = loadRecords()

        records.removeAll { $0.id == id }

        records.append(
            SmartNotificationHistoryRecord(
                id: id,
                category: category.rawValue,
                scheduledAt: now,
                triggerAt: triggerAt
            )
        )

        saveRecords(records)
    }

    func reset() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private func cleanupOldRecords(now: Date) {
        let cutoff = calendar.date(byAdding: .day, value: -10, to: now) ?? now
        let records = loadRecords().filter { $0.triggerAt >= cutoff }
        saveRecords(records)
    }

    private func loadRecords() -> [SmartNotificationHistoryRecord] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([SmartNotificationHistoryRecord].self, from: data)
        } catch {
            Log.debug("SMART NOTIFICATION HISTORY DECODE ERROR:", error.localizedDescription)
            return []
        }
    }

    private func saveRecords(_ records: [SmartNotificationHistoryRecord]) {
        do {
            let data = try JSONEncoder().encode(records)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            Log.debug("SMART NOTIFICATION HISTORY SAVE ERROR:", error.localizedDescription)
        }
    }
}
