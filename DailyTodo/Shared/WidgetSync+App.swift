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
        levelProgress: Double? = nil,
        weekFocusMinutes: [Int]? = nil,
        prevWeekFocusMinutes: Int? = nil,
        monthFullDays: [Int]? = nil,
        monthHalfDays: [Int]? = nil,
        peakHour: Int? = nil
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
        new.weekFocusMinutes = weekFocusMinutes
        new.prevWeekFocusMinutes = prevWeekFocusMinutes
        new.monthFullDays = monthFullDays
        new.monthHalfDays = monthHalfDays
        new.peakHour = peakHour

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
            old.levelProgress != new.levelProgress ||
            old.weekFocusMinutes != new.weekFocusMinutes ||
            old.prevWeekFocusMinutes != new.prevWeekFocusMinutes ||
            old.monthFullDays != new.monthFullDays ||
            old.monthHalfDays != new.monthHalfDays ||
            old.peakHour != new.peakHour {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Persists the picked "Focus Card" widget style and redraws widgets.
    static func updateWidgetStyle(_ raw: String) {
        guard WidgetShared.readWidgetStyle() != raw else { return }
        WidgetShared.writeWidgetStyle(raw)
        WidgetCenter.shared.reloadAllTimelines()
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
            // Redraw only when the programme really changed — this runs on
            // every save, and widgets advance through the day on their own.
            if writeSchedulePayload(from: all) {
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch {
            // sessiz geç
        }
    }

    /// Shares the signed-in student's whole programme — every weekly lesson
    /// and every one-off from today on — so the widgets always show what is
    /// in the Week right now: nothing removed, nothing from another account.
    /// Returns whether anything changed.
    @discardableResult
    static func writeSchedulePayload(from allEvents: [EventItem]) -> Bool {
        let userID = UserDefaults.standard.string(forKey: "current_user_id")
        let startOfToday = Calendar.current.startOfDay(for: Date())

        let events: [WidgetEvent] = allEvents
            .filter { event in
                guard let userID, event.ownerUserID == userID else { return false }
                if let date = event.scheduledDate { return date >= startOfToday }
                return true
            }
            .sorted { ($0.weekday, $0.startMinute) < ($1.weekday, $1.startMinute) }
            .map { event in
                WidgetEvent(
                    id: event.id.uuidString,
                    title: event.title,
                    weekday: event.weekday,
                    startMinute: event.startMinute,
                    durationMinute: event.durationMinute,
                    location: event.location,
                    colorHex: (event.colorHex.isEmpty ? "#3B82F6" : event.colorHex),
                    dateKey: event.scheduledDate.map { WidgetUserState.dayKey($0) }
                )
            }

        let payload = WidgetPayload(weekday: weekdayIndexToday(), events: events)
        let defaults = UserDefaults(suiteName: WidgetShared.appGroupID)
        let old = defaults?.data(forKey: WidgetShared.payloadKey)
        WidgetShared.writePayload(payload)
        return old != defaults?.data(forKey: WidgetShared.payloadKey)
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
