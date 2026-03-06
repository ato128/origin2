//
//  LiveActivityScheduler.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 5.03.2026.
//

import Foundation
import SwiftData
import BackgroundTasks

@MainActor
final class LiveActivityScheduler {

    static let shared = LiveActivityScheduler()
    private init() {}

    private let taskID = "com.atakan.DailyTodo.liveactivity.refresh"
    private var timer: Timer?

    // App açılınca çağır
    func startForegroundLoop(context: ModelContext) {
        timer?.invalidate()
        tick(context: context)

        // 30 sn’de bir kontrol (pil dostu)
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.tick(context: context)
            }
        }
    }

    func stopForegroundLoop() {
        timer?.invalidate()
        timer = nil
    }

    /// Event ekle/edit/sil sonrası çağır
    func rescheduleBackgroundTask(context: ModelContext) {
        scheduleBGTaskForNextEvent(context: context)
    }

    // MARK: - Foreground tick

    private func tick(context: ModelContext) {
        guard let next = nextEventFromSwiftData(context: context) else { return }

        let startDate = dateForNextOccurrence(of: next, at: next.startMinute)
        let endDate = startDate.addingTimeInterval(TimeInterval(max(1, next.durationMinute) * 60))

        let now = Date()
        let tenMinBefore = startDate.addingTimeInterval(-10 * 60)

        // 10 dk kala başlat
        if now >= tenMinBefore && now < endDate {
            LiveActivityManager.shared.start(for: next)
        }

        // ders bittiyse kapat
        if now >= endDate {
            Task { await LiveActivityManager.shared.end() }
        }
    }

    // MARK: - Background

    func registerBGTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: nil) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            self.handleBGTask(task: task)
        }
    }

    private func handleBGTask(task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task { @MainActor in
            // Background’ta SwiftData okumak için container kuruyoruz
            let container = try? ModelContainer(
                for: DTTaskItem.self,
                EventItem.self
            )
            guard let container else {
                task.setTaskCompleted(success: false)
                return
            }
            let ctx = ModelContext(container)

            self.tick(context: ctx)
            self.scheduleBGTaskForNextEvent(context: ctx)

            task.setTaskCompleted(success: true)
        }
    }

    private func scheduleBGTaskForNextEvent(context: ModelContext) {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskID)

        guard let next = nextEventFromSwiftData(context: context) else { return }
        let startDate = dateForNextOccurrence(of: next, at: next.startMinute)
        let fire = startDate.addingTimeInterval(-10 * 60)

        let req = BGAppRefreshTaskRequest(identifier: taskID)
        // Apple kesin zaman vermez; “en erken bu” deriz
        req.earliestBeginDate = fire

        do {
            try BGTaskScheduler.shared.submit(req)
        } catch {
            // sessiz geç
        }
    }

    // MARK: - SwiftData read

    private func nextEventFromSwiftData(context: ModelContext) -> EventItem? {
        let descriptor = FetchDescriptor<EventItem>(
            sortBy: [SortDescriptor(\.weekday, order: .forward),
                     SortDescriptor(\.startMinute, order: .forward)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        guard !all.isEmpty else { return nil }

        // “şu andan itibaren” en yakın gerçekleşecek event’i bul
        let now = Date()
        var best: (EventItem, Date)?
        for ev in all {
            let d = dateForNextOccurrence(of: ev, at: ev.startMinute)
            if d <= now.addingTimeInterval(7 * 24 * 3600) { // 1 hafta içinde
                if best == nil || d < best!.1 {
                    best = (ev, d)
                }
            }
        }
        return best?.0
    }

    /// event.weekday: 0=Pzt ... 6=Paz
    private func dateForNextOccurrence(of event: EventItem, at startMinute: Int) -> Date {
        let cal = Calendar(identifier: .iso8601)
        let now = Date()

        let targetISOWeekday = event.weekday + 1 // 1=Mon ... 7=Sun
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
