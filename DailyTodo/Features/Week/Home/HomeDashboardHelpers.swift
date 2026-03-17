//
//  HomeDashboardHelpers.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI
import SwiftData
import Combine

extension HomeDashboardView {

    func currentMinuteOfDay() -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    func targetDateFor(day: Int) -> Date {
        let calendar = Calendar.current
        let today = Date()

        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let targetDate = calendar.date(byAdding: .day, value: day, to: startOfWeek)
        else {
            return today
        }

        return targetDate
    }

    func weekdayIndexToday() -> Int {
        let w = Calendar.current.component(.weekday, from: Date())
        return (w + 5) % 7
    }

   

    

    func saveFocusRecordFromHomeIfNeeded() {
        guard activeFocusTotalSeconds > 0 else { return }

        let endedAt = Date()
        let startedAt = activeFocusStartedAt ?? endedAt
        let completedSeconds = activeFocusTotalSeconds

        let record = FocusSessionRecord(
            title: activeFocusTaskTitle.isEmpty ? "Deep Work Session" : activeFocusTaskTitle,
            startedAt: startedAt,
            endedAt: endedAt,
            totalSeconds: activeFocusTotalSeconds,
            completedSeconds: completedSeconds,
            isCompleted: true
        )

        modelContext.insert(record)

        do {
            try modelContext.save()
            print("✅ Focus saved from HomeDashboardView")
        } catch {
            print("❌ Focus save error from HomeDashboardView:", error)
        }

        NotificationCenter.default.post(
            name: .focusSessionCompleted,
            object: nil
        )
    }

    func hm(_ minute: Int) -> String {
        let m = max(0, min(1439, minute))
        let h = m / 60
        let mm = m % 60
        return String(format: "%02d:%02d", h, mm)
    }

    var activeFocusProgress: Double {
        guard activeFocusTotalSeconds > 0 else { return 0 }
        return Double(activeFocusTotalSeconds - activeFocusRemainingSeconds) / Double(activeFocusTotalSeconds)
    }

    func smoothActiveFocusProgressBar(at date: Date) -> some View {
        let progress = liveFocusProgress(at: date)

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue,
                                Color.cyan
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, geo.size.width * progress))
                    .animation(.linear(duration: 1), value: progress)

                // ✨ glow efekti
                Capsule()
                    .fill(Color.blue.opacity(0.25))
                    .frame(width: max(8, geo.size.width * progress))
                    .blur(radius: 8)
                    .animation(.linear(duration: 1), value: progress)
            }
        }
    }

    func liveFocusProgress(at date: Date) -> Double {
        guard activeFocusTotalSeconds > 0 else { return 0 }

        guard let timestamp = UserDefaults.standard.object(forKey: "focus_end_date") as? Double else {
            return activeFocusProgress
        }

        let endDate = Date(timeIntervalSince1970: timestamp)
        let remaining = max(0, endDate.timeIntervalSince(date))
        let elapsed = Double(activeFocusTotalSeconds) - remaining

        return min(1, max(0, elapsed / Double(activeFocusTotalSeconds)))
    }

    func liveFocusRemaining(at date: Date) -> Int {
        guard let timestamp = UserDefaults.standard.object(forKey: "focus_end_date") as? Double else {
            return activeFocusRemainingSeconds
        }

        let endDate = Date(timeIntervalSince1970: timestamp)
        return max(0, Int(endDate.timeIntervalSince(date).rounded(.down)))
    }

    func liveFocusTimeText(at date: Date) -> String {
        let remaining = liveFocusRemaining(at: date)
        let m = remaining / 60
        let s = remaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    func activeFocusUrgencyColor(for remaining: Int) -> Color {
        if remaining <= 10 && remaining > 0 {
            return .red
        } else if remaining <= 30 && remaining > 0 {
            return .orange
        } else {
            return .blue
        }
    }
}

extension Notification.Name {
    static let focusSessionCompleted =
        Notification.Name("focusSessionCompleted")
}
