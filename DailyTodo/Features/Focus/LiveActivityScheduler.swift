//
//  LiveActivityScheduler.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 5.03.2026.
//

import Foundation
import SwiftData
import BackgroundTasks
import ActivityKit

@MainActor
final class LiveActivityScheduler {

    static let shared = LiveActivityScheduler()
    private init() {}

    private let taskID = "com.atakan.DailyTodo.liveactivity.refresh"
    private var timer: Timer?

    // Burayı SENİN gerçek App Group id'in ile birebir aynı yap
    private let appGroupID = "group.com.atakan.updo"

    private enum Keys {
        static let currentUserID = "liveactivity.currentUserID"
    }

    // MARK: - Public

    func setCurrentUserID(_ userID: String?) {
        sharedDefaults?.set(userID, forKey: Keys.currentUserID)
    }

    func clearCurrentUserID() {
        sharedDefaults?.removeObject(forKey: Keys.currentUserID)
    }

    func startForegroundLoop(container: ModelContainer) {
        timer?.invalidate()

        let context = ModelContext(container)
        tick(context: context)

        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }

            Task { @MainActor in
                let context = ModelContext(container)
                self.tick(context: context)
            }
        }
    }

    func stopForegroundLoop() {
        timer?.invalidate()
        timer = nil
    }

    func rescheduleBackgroundTask(container: ModelContainer) {
        let context = ModelContext(container)
        scheduleBGTaskForNextEvent(context: context)
    }

    func registerBGTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            self.handleBGTask(task: task)
        }
    }

    // MARK: - Foreground Tick

    private func tick(context: ModelContext) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        guard let target = currentRelevantEvent(context: context) else {
            Task {
                await LiveActivityManager.shared.end()
            }
            return
        }

        let now = Date()

        switch target.phase(at: now) {
        case .tooEarly:
            Task {
                await LiveActivityManager.shared.end()
            }

        case .upcomingWindow, .live:
            Task {
                await LiveActivityManager.shared.startIfNeeded(events: [target.event])
            }

        case .ended:
            Task {
                await LiveActivityManager.shared.end()
            }
        }
    }

    // MARK: - Background

    private func handleBGTask(task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task { @MainActor in
            guard let groupURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupID
            ) else {
                print("❌ App Group container bulunamadı")
                task.setTaskCompleted(success: false)
                return
            }

            let supportURL = groupURL.appendingPathComponent("Library/Application Support")

            do {
                try FileManager.default.createDirectory(
                    at: supportURL,
                    withIntermediateDirectories: true
                )
            } catch {
                print("❌ App Support create error:", error.localizedDescription)
            }

            let storeURL = supportURL.appendingPathComponent("default.store")

            let schema = Schema([
                DTTaskItem.self,
                EventItem.self,
                FocusSessionRecord.self
            ])

            let configuration = ModelConfiguration(
                schema: schema,
                url: storeURL
            )

            do {
                let container = try ModelContainer(
                    for: schema,
                    configurations: [configuration]
                )

                let context = ModelContext(container)

                self.tick(context: context)
                self.scheduleBGTaskForNextEvent(context: context)

                task.setTaskCompleted(success: true)
            } catch {
                print("❌ BG ModelContainer error:", error.localizedDescription)
                task.setTaskCompleted(success: false)
            }
        }
    }

    private func scheduleBGTaskForNextEvent(context: ModelContext) {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskID)

        guard let next = nextUpcomingEvent(context: context) else {
            print("ℹ️ BG schedule: uygun gelecek event yok")
            return
        }

        let fireDate = next.startDate.addingTimeInterval(-10 * 60)

        guard fireDate > Date() else {
            return
        }

        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = fireDate

        do {
            try BGTaskScheduler.shared.submit(request)
            print("🟢 BG task scheduled for:", fireDate)
        } catch {
            print("🔴 BG task schedule error:", error.localizedDescription)
        }
    }

    // MARK: - Event Selection

    private func currentRelevantEvent(context: ModelContext) -> ResolvedEvent? {
        let now = Date()
        let all = fetchOwnedEvents(context: context)

        guard !all.isEmpty else { return nil }

        let resolved = all.map { resolveEvent($0, now: now) }

        if let live = resolved.first(where: { $0.phase(at: now) == .live }) {
            return live
        }

        if let upcomingWindow = resolved
            .filter({ $0.phase(at: now) == .upcomingWindow })
            .sorted(by: { $0.startDate < $1.startDate })
            .first {
            return upcomingWindow
        }

        return nil
    }

    private func nextUpcomingEvent(context: ModelContext) -> ResolvedEvent? {
        let now = Date()
        let all = fetchOwnedEvents(context: context)

        let resolved = all
            .map { resolveEvent($0, now: now) }
            .filter { $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }

        return resolved.first
    }

    private func fetchOwnedEvents(context: ModelContext) -> [EventItem] {
        let descriptor = FetchDescriptor<EventItem>()
        let all = (try? context.fetch(descriptor)) ?? []

        guard let currentUserID = currentUserID else {
            return all
        }

        return all.filter { event in
            guard let owner = event.ownerUserID else { return false }
            return owner == currentUserID
        }
    }

    // MARK: - Helpers

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private var currentUserID: String? {
        sharedDefaults?.string(forKey: Keys.currentUserID)
    }

    private func resolveEvent(_ event: EventItem, now: Date) -> ResolvedEvent {
        let startDate = dateForNextOccurrence(of: event, at: event.startMinute, now: now)
        let endDate = startDate.addingTimeInterval(TimeInterval(max(1, event.durationMinute) * 60))

        return ResolvedEvent(
            event: event,
            startDate: startDate,
            endDate: endDate
        )
    }

    /// event.weekday: 0=Pzt ... 6=Paz
    private func dateForNextOccurrence(of event: EventItem, at startMinute: Int, now: Date = Date()) -> Date {
        let cal = Calendar.current

        let systemWeekday = cal.component(.weekday, from: now)   // 1=Paz ... 7=Cmt
        let todayIndex = (systemWeekday + 5) % 7                // 0=Pzt ... 6=Paz

        let daysUntil = (event.weekday - todayIndex + 7) % 7

        let hour = max(0, min(23, startMinute / 60))
        let minute = max(0, min(59, startMinute % 60))

        let startOfToday = cal.startOfDay(for: now)

        guard let targetDay = cal.date(byAdding: .day, value: daysUntil, to: startOfToday),
              let candidate = cal.date(bySettingHour: hour, minute: minute, second: 0, of: targetDay)
        else {
            return now
        }

        if daysUntil == 0 {
            let endCandidate = candidate.addingTimeInterval(TimeInterval(max(1, event.durationMinute) * 60))

            if now < endCandidate {
                return candidate
            } else {
                return cal.date(byAdding: .day, value: 7, to: candidate) ?? candidate
            }
        }

        return candidate
    }
}

// MARK: - ResolvedEvent

private struct ResolvedEvent {
    let event: EventItem
    let startDate: Date
    let endDate: Date

    enum Phase {
        case tooEarly
        case upcomingWindow
        case live
        case ended
    }

    func phase(at now: Date) -> Phase {
        let tenMinutesBefore = startDate.addingTimeInterval(-10 * 60)

        if now < tenMinutesBefore {
            return .tooEarly
        } else if now >= tenMinutesBefore && now < startDate {
            return .upcomingWindow
        } else if now >= startDate && now < endDate {
            return .live
        } else {
            return .ended
        }
    }
}
