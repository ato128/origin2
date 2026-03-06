//
//  WidgetSync+App.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 3.03.2026.
//

import Foundation
import SwiftData
import WidgetKit

enum WidgetAppSync {
    static func refreshFromSwiftData(context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<EventItem>(
                sortBy: [SortDescriptor(\EventItem.startMinute, order: .forward)]
            )
            let all = try context.fetch(descriptor)
            writeTodayPayload(from: all)

            // ✅ Widget kind EXACT aynı olmalı:
            WidgetCenter.shared.reloadTimelines(ofKind: "ScheduleWidget")
        } catch {
            // sessiz geç
        }
    }

    static func writeTodayPayload(from allEvents: [EventItem]) {
        let todayIndex = weekdayIndexToday()      // ✅ 0=Pzt ... 6=Paz
        let nowMinute = currentMinuteOfDay()

        let today = allEvents
            .filter { $0.weekday == todayIndex }
            .sorted { $0.startMinute < $1.startMinute }

        let upcoming = today.filter { ($0.startMinute + $0.durationMinute) > nowMinute }
        let selected = Array((upcoming.isEmpty ? today : upcoming).prefix(3))

        let events = selected.map {
            WidgetEvent(
                id: $0.id.uuidString,
                title: $0.title,
                weekday: $0.weekday,
                startMinute: $0.startMinute,
                durationMinute: $0.durationMinute,
                location: $0.location,
                colorHex: ($0.colorHex.isEmpty ? "#3B82F6" : $0.colorHex)
            )
        }

        WidgetShared.writePayload(.init(weekday: todayIndex, events: events))
    }

    // ✅ 0=Pzt ... 6=Paz
    static func weekdayIndexToday() -> Int {
        let w = Calendar.current.component(.weekday, from: Date()) // 1=Paz ... 7=Cmt
        return (w + 5) % 7                                         // 0=Pzt ... 6=Paz
    }

    static func currentMinuteOfDay() -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}
