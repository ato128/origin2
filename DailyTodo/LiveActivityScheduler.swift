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
    
    // App açılınca çağır
    func startForegroundLoop(container: ModelContainer) {
        timer?.invalidate()
        
        let context = ModelContext(container)
        tick(context: context)
        
        // 30 sn’de bir kontrol
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
    
    /// Event ekle/edit/sil sonrası çağır
    func rescheduleBackgroundTask(container: ModelContainer) {
        let context = ModelContext(container)
        scheduleBGTaskForNextEvent(context: context)
    }
    
    // MARK: - Foreground tick
    
    private func tick(context: ModelContext) {
        guard let next = nextEventFromSwiftData(context: context) else {
            print("❌ LiveActivityScheduler: next event yok")
            return
        }
        
        let startDate = dateForNextOccurrence(of: next, at: next.startMinute)
        let endDate = startDate.addingTimeInterval(TimeInterval(max(1, next.durationMinute) * 60))
        
        let now = Date()
        let tenMinBefore = startDate.addingTimeInterval(-10 * 60)
        
        print("🕒 now:", now)
        print("📚 next event:", next.title)
        print("▶️ startDate:", startDate)
        print("⏹ endDate:", endDate)
        print("⏰ tenMinBefore:", tenMinBefore)
        
        // 10 dk kala başlat
        if now >= tenMinBefore && now < endDate {
            print("✅ start koşulu sağlandı")
            
            if Activity<ScheduleAttributes>.activities.isEmpty {
                Task {
                    await LiveActivityManager.shared.start(for: next)
                }
            } else {
                print("🟡 zaten aktif bir Live Activity var")
            }
        } else {
            print("❌ start koşulu sağlanmadı")
        }
        
        // ders bittiyse kapat
        if now >= endDate {
            print("🟠 end koşulu sağlandı")
            Task {
                await LiveActivityManager.shared.end()
            }
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
            let container = try? ModelContainer(
                for: DTTaskItem.self,
                EventItem.self,
                FocusSessionRecord.self
            )
            
            guard let container else {
                task.setTaskCompleted(success: false)
                return
            }
            
            let context = ModelContext(container)
            
            self.tick(context: context)
            self.scheduleBGTaskForNextEvent(context: context)
            
            task.setTaskCompleted(success: true)
        }
    }
    
    private func scheduleBGTaskForNextEvent(context: ModelContext) {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskID)
        
        guard let next = nextEventFromSwiftData(context: context) else {
            print("❌ BG schedule: next event yok")
            return
        }
        
        let startDate = dateForNextOccurrence(of: next, at: next.startMinute)
        let fire = startDate.addingTimeInterval(-10 * 60)
        
        let req = BGAppRefreshTaskRequest(identifier: taskID)
        req.earliestBeginDate = fire
        
        do {
            try BGTaskScheduler.shared.submit(req)
            print("🟢 BG task scheduled for:", fire)
        } catch {
            print("🔴 BG task schedule error:", error)
        }
    }
    
    // MARK: - SwiftData read
    
    private func nextEventFromSwiftData(context: ModelContext) -> EventItem? {
        let descriptor = FetchDescriptor<EventItem>()
        let all = (try? context.fetch(descriptor)) ?? []
        
        guard !all.isEmpty else {
            print("❌ hiç event yok")
            return nil
        }
        
        let now = Date()
        var bestEvent: EventItem?
        var bestDate: Date?
        
        for event in all {
            let candidate = dateForNextOccurrence(of: event, at: event.startMinute)
            
            print("📚 event:", event.title, "weekday:", event.weekday, "startMinute:", event.startMinute)
            print("📅 candidate:", candidate)
            
            if bestDate == nil || candidate < bestDate! {
                bestEvent = event
                bestDate = candidate
            }
        }
        
        if let bestEvent, let bestDate {
            print("✅ seçilen event:", bestEvent.title)
            print("✅ seçilen tarih:", bestDate)
        }
        
        return bestEvent
    }
    
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
