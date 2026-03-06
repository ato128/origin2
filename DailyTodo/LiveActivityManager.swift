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

    // MARK: - START

    func start(for event: EventItem) {
        print("🧩 bundle:", Bundle.main.bundleIdentifier ?? "nil")
        print("🟣 LiveActivity START called:", event.title)
        let enabled = ActivityAuthorizationInfo().areActivitiesEnabled
        print("🟣 activitiesEnabled:", enabled)
        guard enabled else { return }

        let startDate = dateForNextOccurrence(of: event, at: event.startMinute)
        let endDate = startDate.addingTimeInterval(TimeInterval(max(1, event.durationMinute) * 60))

        Task { await end() } // tek activity

        let attr = ScheduleAttributes(name: event.title)
        let state = ScheduleAttributes.ContentState(
            title: event.title,
            startDate: startDate,
            endDate: endDate,
            
        )

        do {
            let activity = try Activity.request(
                attributes: attr,
                contentState: state,
                pushType: nil
            )
            UserDefaults.standard.set(activity.id, forKey: currentIDKey)
            print("🟢 LiveActivity requested id:", activity.id)
        } catch {
            print("🔴 LiveActivity start error:", error)
        }
    }

    // MARK: - UPDATE

    func update(for event: EventItem) async {
        guard let activity = await currentActivity() else { return }

        let startDate = dateForNextOccurrence(of: event, at: event.startMinute)
        let endDate = startDate.addingTimeInterval(TimeInterval(max(1, event.durationMinute) * 60))

        let newState = ScheduleAttributes.ContentState(
            title: event.title,
            startDate: startDate,
            endDate: endDate,
            
        )

        await activity.update(using: newState)
        print("🟦 LiveActivity updated:", activity.id)
    }

    // MARK: - END

    func end() async {
        guard let activity = await currentActivity() else {
            UserDefaults.standard.removeObject(forKey: currentIDKey)
            return
        }

        // iOS 16.2+ doğru kullanım
        let finalState = activity.content.state
        await activity.end(using: finalState, dismissalPolicy: .immediate)

        UserDefaults.standard.removeObject(forKey: currentIDKey)
        print("🟡 LiveActivity ended:", activity.id)
    }

    // MARK: - AUTO SYSTEM (app açıkken çalışır)

    /// WeekView timer veya App scenePhase bunu çağıracak
    /// WeekView timer bunu çağıracak (her 60 saniye)
    func autoSyncIfNeeded(events: [EventItem]) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let now = Date()
        let calendar = Calendar.current

        // 0=Pzt ... 6=Paz formatına çevir (WeekView ile aynı)
        let w = calendar.component(.weekday, from: now) // 1=Paz ... 7=Cmt
        let todayIndex = (w + 5) % 7                    // 0=Pzt ... 6=Paz

        let todaysEvents = events
            .filter { $0.weekday == todayIndex }
            .sorted { $0.startMinute < $1.startMinute }

        guard !todaysEvents.isEmpty else {
            await end()
            return
        }

        let nowMinute =
            calendar.component(.hour, from: now) * 60 +
            calendar.component(.minute, from: now)

        // ✅ SADE: sadece "şu an ders var mı?"
        if let live = todaysEvents.first(where: {
            nowMinute >= $0.startMinute &&
            nowMinute < ($0.startMinute + $0.durationMinute)
        }) {
            if await currentActivity() == nil {
                start(for: live)
            } else {
                await update(for: live)
            }
            return
        }

        // ✅ ders yoksa: varsa activity bitmiş mi kontrol et, bittiyse kapat
        if let activity = await currentActivity() {
            let endDate = activity.content.state.endDate
            if endDate <= now {
                await self.end()
            }
        }
    }

    // MARK: - CURRENT

    private func currentActivity() async -> Activity<ScheduleAttributes>? {
        guard let id = UserDefaults.standard.string(forKey: currentIDKey) else { return nil }
        return Activity<ScheduleAttributes>.activities.first(where: { $0.id == id })
    }

    // MARK: - DATE CALC

    /// EventItem.weekday: 0=Pzt ... 6=Paz
    /// ISO weekday: 1=Mon ... 7=Sun
    private func dateForNextOccurrence(of event: EventItem, at startMinute: Int) -> Date {
        let cal = Calendar(identifier: .iso8601)
        let now = Date()

        let targetISOWeekday = event.weekday + 1 // 0->1 (Mon) ... 6->7 (Sun)
        let hour = max(0, min(23, startMinute / 60))
        let minute = max(0, min(59, startMinute % 60))

        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        comps.weekday = targetISOWeekday
        comps.hour = hour
        comps.minute = minute
        comps.second = 0

        let base = cal.date(from: comps) ?? now
        if base <= now {
            return cal.date(byAdding: .day, value: 7, to: base) ?? base
        } else {
            return base
        }
    }
}
