//
//  LiveActivityManager.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 4.03.2026.
//

import Foundation
import ActivityKit

@MainActor
final class LiveActivityManager {

    static let shared = LiveActivityManager()
    private init() {}

    private let currentIDKey = "liveActivity.currentID"

    // MARK: - Public API

    func start(for event: EventItem) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = makeState(for: event)

        await end()

        do {
            let activity = try Activity<ScheduleAttributes>.request(
                attributes: ScheduleAttributes(scheduleName: event.title),
                content: ActivityContent(
                    state: state,
                    staleDate: state.endDate
                ),
                pushType: nil
            )

            UserDefaults.standard.set(activity.id, forKey: currentIDKey)
            print("🟢 LiveActivity started:", activity.id, event.title)
        } catch {
            print("🔴 LiveActivity start error:", error)
        }
    }

    func update(for event: EventItem) async {
        guard let activity = currentActivity() else {
            await start(for: event)
            return
        }

        let newState = makeState(for: event)

        if activity.content.state == newState {
            return
        }

        await activity.update(
            ActivityContent(
                state: newState,
                staleDate: newState.endDate
            )
        )

        print("🔵 LiveActivity updated:", activity.id, event.title)
    }

    func end() async {
        guard let activity = currentActivity() else {
            UserDefaults.standard.removeObject(forKey: currentIDKey)
            return
        }

        await activity.end(
            ActivityContent(
                state: activity.content.state,
                staleDate: activity.content.staleDate
            ),
            dismissalPolicy: .immediate
        )

        UserDefaults.standard.removeObject(forKey: currentIDKey)
        print("🟡 LiveActivity ended:", activity.id)
    }

    func startIfNeeded(events: [EventItem]) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let now = Date()

        if let target = bestCandidateEvent(from: events, now: now) {
            if currentActivity() == nil {
                await start(for: target)
            } else {
                await update(for: target)
            }
        } else {
            await end()
        }
    }

    func autoSyncIfNeeded(events: [EventItem]) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let now = Date()

        guard let target = bestCandidateEvent(from: events, now: now) else {
            await end()
            return
        }

        guard let activity = currentActivity() else {
            await start(for: target)
            return
        }

        let newState = makeState(for: target)

        if activity.content.state != newState {
            await activity.update(
                ActivityContent(
                    state: newState,
                    staleDate: newState.endDate
                )
            )
            print("🟣 LiveActivity autoSynced:", target.title)
        }
    }

    // MARK: - Internal helpers

    private func currentActivity() -> Activity<ScheduleAttributes>? {
        guard let id = UserDefaults.standard.string(forKey: currentIDKey) else { return nil }

        if let activity = Activity<ScheduleAttributes>.activities.first(where: { $0.id == id }) {
            return activity
        }

        UserDefaults.standard.removeObject(forKey: currentIDKey)
        return nil
    }

    private func makeState(for event: EventItem) -> ScheduleAttributes.ContentState {
        let startDate = resolvedStartDate(for: event)
        let endDate = startDate.addingTimeInterval(TimeInterval(max(1, event.durationMinute) * 60))

        return ScheduleAttributes.ContentState(
            title: event.title,
            startDate: startDate,
            endDate: endDate,
            colorHex: event.colorHex
        )
    }

    private func bestCandidateEvent(from events: [EventItem], now: Date) -> EventItem? {
        let validEvents = events
            .filter { !$0.isCompleted }
            .sorted { lhs, rhs in
                resolvedStartDate(for: lhs) < resolvedStartDate(for: rhs)
            }

        guard !validEvents.isEmpty else { return nil }

        // 1) Şu an aktif olan event varsa onu seç
        if let live = validEvents.first(where: { event in
            let start = resolvedStartDate(for: event)
            let end = start.addingTimeInterval(TimeInterval(max(1, event.durationMinute) * 60))
            return now >= start && now < end
        }) {
            return live
        }

        // 2) 10 dk içinde başlayacak event varsa onu seç
        if let upcomingSoon = validEvents.first(where: { event in
            let start = resolvedStartDate(for: event)
            let diff = start.timeIntervalSince(now)
            return diff > 0 && diff <= 600
        }) {
            return upcomingSoon
        }

        // 3) Eğer mevcut activity geçmişte kaldıysa kapatılacak, yeni bir şey göstermiyoruz
        return nil
    }

    private func resolvedStartDate(for event: EventItem) -> Date {
        if let scheduledDate = event.scheduledDate {
            let calendar = Calendar.current
            let baseDay = calendar.startOfDay(for: scheduledDate)
            let hour = max(0, min(23, event.startMinute / 60))
            let minute = max(0, min(59, event.startMinute % 60))

            return calendar.date(
                bySettingHour: hour,
                minute: minute,
                second: 0,
                of: baseDay
            ) ?? scheduledDate
        }

        return dateForNextOccurrence(of: event, at: event.startMinute)
    }

    /// event.weekday: 0=Pzt ... 6=Paz
    private func dateForNextOccurrence(of event: EventItem, at startMinute: Int) -> Date {
        let cal = Calendar.current
        let now = Date()

        let systemWeekday = cal.component(.weekday, from: now)   // 1=Paz ... 7=Cmt
        let todayIndex = (systemWeekday + 5) % 7                 // 0=Pzt ... 6=Paz
        let daysUntil = (event.weekday - todayIndex + 7) % 7

        let hour = max(0, min(23, startMinute / 60))
        let minute = max(0, min(59, startMinute % 60))
        let startOfToday = cal.startOfDay(for: now)

        guard let targetDay = cal.date(byAdding: .day, value: daysUntil, to: startOfToday),
              let candidate = cal.date(bySettingHour: hour, minute: minute, second: 0, of: targetDay) else {
            return now
        }

        if daysUntil == 0 && candidate <= now {
            return cal.date(byAdding: .day, value: 7, to: candidate) ?? candidate
        }

        return candidate
    }
}
