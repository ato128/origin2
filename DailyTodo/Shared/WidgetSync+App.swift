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

    // MARK: - User state (icon theme + Pro stats)

    /// Pushes the full user snapshot used by widgets / live activities.
    static func writeUserState(
        iconName: String?,
        isPro: Bool,
        streak: Int,
        level: Int,
        todayFocusMinutes: Int,
        statsShared: Bool,
        longestStreak: Int = 0,
        todayTaskDone: Bool? = nil,
        todayFocusDone: Bool? = nil,
        levelProgress: Double? = nil
    ) {
        var new = WidgetUserState(
            iconName: iconName,
            isPro: isPro,
            streak: streak,
            level: level,
            todayFocusMinutes: todayFocusMinutes,
            statsShared: statsShared,
            longestStreak: longestStreak
        )
        new.todayTaskDone = todayTaskDone
        new.todayFocusDone = todayFocusDone
        new.statusDayKey = WidgetUserState.dayKey()
        new.levelProgress = levelProgress

        // Only reload timelines when something actually changed (cheap dedupe).
        let old = WidgetShared.readUserState()
        WidgetShared.writeUserState(new)
        if old.iconName != new.iconName || old.isPro != new.isPro ||
            old.streak != new.streak || old.level != new.level ||
            old.todayFocusMinutes != new.todayFocusMinutes ||
            old.longestStreak != new.longestStreak ||
            old.todayTaskDone != new.todayTaskDone ||
            old.todayFocusDone != new.todayFocusDone ||
            old.statusDayKey != new.statusDayKey ||
            old.levelProgress != new.levelProgress {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Updates just the icon (keeps the rest of the snapshot intact).
    static func updateIcon(_ iconName: String?) {
        var state = WidgetShared.readUserState()
        guard state.iconName != iconName else { return }
        state.iconName = iconName
        WidgetShared.writeUserState(state)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func refreshFromSwiftData(context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<EventItem>(
                sortBy: [SortDescriptor(\EventItem.startMinute, order: .forward)]
            )
            let all = try context.fetch(descriptor)
            writeTodayPayload(from: all)

            // ✅ Widget kind EXACT aynı olmalı:
            WidgetCenter.shared.reloadAllTimelines()
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
