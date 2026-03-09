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
    
    func start(for event: EventItem) async {
        print("🧩 bundle:", Bundle.main.bundleIdentifier ?? "nil")
        print("🟣 LiveActivity START called:", event.title)
        
        let enabled = ActivityAuthorizationInfo().areActivitiesEnabled
        print("🟣 activitiesEnabled:", enabled)
        guard enabled else { return }
        
        let startDate = dateForNextOccurrence(of: event, at: event.startMinute)
        let endDate = startDate.addingTimeInterval(TimeInterval(max(1, event.durationMinute) * 60))
        
        await end() // tek activity tut
        
        let attributes = ScheduleAttributes(name: event.title)
        let state = ScheduleAttributes.ContentState(
            title: event.title,
            startDate: startDate,
            endDate: endDate,
            colorHex: event.colorHex
        )
        
        let content = ActivityContent(state: state, staleDate: endDate)
        
        do {
            let activity = try Activity<ScheduleAttributes>.request(
                attributes: attributes,
                content: content,
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
        guard let activity = currentActivity() else { return }
        
        let startDate = dateForNextOccurrence(of: event, at: event.startMinute)
        let endDate = startDate.addingTimeInterval(TimeInterval(max(1, event.durationMinute) * 60))
        
        let newState = ScheduleAttributes.ContentState(
            title: event.title,
            startDate: startDate,
            endDate: endDate,
            colorHex: event.colorHex
        )
        
        let updatedContent = ActivityContent(state: newState, staleDate: endDate)
        await activity.update(updatedContent)
        
        print("🟦 LiveActivity updated:", activity.id)
    }
    
    // MARK: - END
    
    func end() async {
        guard let activity = currentActivity() else {
            UserDefaults.standard.removeObject(forKey: currentIDKey)
            return
        }
        
        let finalContent = ActivityContent(
            state: activity.content.state,
            staleDate: activity.content.staleDate
        )
        
        await activity.end(finalContent, dismissalPolicy: .immediate)
        
        UserDefaults.standard.removeObject(forKey: currentIDKey)
        print("🟡 LiveActivity ended:", activity.id)
    }
    
    // MARK: - AUTO SYSTEM
    
    func autoSyncIfNeeded(events: [EventItem]) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let now = Date()
        let calendar = Calendar.current
        
        let weekday = calendar.component(.weekday, from: now) // 1=Paz ... 7=Cmt
        let todayIndex = (weekday + 5) % 7                    // 0=Pzt ... 6=Paz
        
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
        
        if let live = todaysEvents.first(where: {
            nowMinute >= $0.startMinute &&
            nowMinute < ($0.startMinute + $0.durationMinute)
        }) {
            if currentActivity() == nil {
                await start(for: live)
            } else {
                await update(for: live)
            }
            return
        }
        
        if let activity = currentActivity() {
            let endDate = activity.content.state.endDate
            if endDate <= now {
                await end()
            }
        }
    }
    
    // MARK: - CURRENT
    
    private func currentActivity() -> Activity<ScheduleAttributes>? {
        guard let id = UserDefaults.standard.string(forKey: currentIDKey) else { return nil }
        return Activity<ScheduleAttributes>.activities.first(where: { $0.id == id })
    }
    
    // MARK: - DATE CALC
    
    /// event.weekday: 0=Pzt ... 6=Paz
    /// event.weekday: 0=Pzt ... 6=Paz
    private func dateForNextOccurrence(of event: EventItem, at startMinute: Int) -> Date {
        let cal = Calendar.current
        let now = Date()
        
        // system: 1=Paz ... 7=Cmt
        // app:    0=Pzt ... 6=Paz
        let systemWeekday = cal.component(.weekday, from: now)
        let todayIndex = (systemWeekday + 5) % 7
        
        let daysUntil = (event.weekday - todayIndex + 7) % 7
        
        let hour = max(0, min(23, startMinute / 60))
        let minute = max(0, min(59, startMinute % 60))
        
        let startOfToday = cal.startOfDay(for: now)
        
        guard let targetDay = cal.date(byAdding: .day, value: daysUntil, to: startOfToday),
              let candidate = cal.date(bySettingHour: hour, minute: minute, second: 0, of: targetDay)
        else {
            return now
        }
        
        // bugün ama saat geçtiyse gelecek haftaya at
        if daysUntil == 0 && candidate <= now {
            return cal.date(byAdding: .day, value: 7, to: candidate) ?? candidate
        }
        
        return candidate
    }
}
