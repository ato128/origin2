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

    func syncActiveFocusCountdown() {
        guard let timestamp =
            UserDefaults.standard.object(forKey: "focus_end_date") as? Double else {
            return
        }

        let savedEnd = Date(timeIntervalSince1970: timestamp)
        let remaining = max(0, Int(savedEnd.timeIntervalSinceNow.rounded(.down)))

        if remaining > 0 {
            activeFocusRemainingSeconds = remaining
            isFocusActive = true

            if let savedTotal =
                UserDefaults.standard.object(forKey: "focus_total_seconds") as? Int,
               savedTotal > 0 {
                activeFocusTotalSeconds = savedTotal
            }

            if let savedTitle =
                UserDefaults.standard.string(forKey: "focus_task_title"),
               !savedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                activeFocusTaskTitle = savedTitle
            }

        } else {
            saveFocusRecordFromHomeIfNeeded()

            UserDefaults.standard.removeObject(forKey: "focus_end_date")
            UserDefaults.standard.removeObject(forKey: "focus_total_seconds")
            UserDefaults.standard.removeObject(forKey: "focus_selected_minutes")
            UserDefaults.standard.removeObject(forKey: "focus_task_title")

            withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                isFocusActive = false
                pulseActiveFocus = false
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                activeFocusTaskTitle = ""
                activeFocusRemainingSeconds = 25 * 60
                activeFocusTotalSeconds = 25 * 60
                activeFocusStartedAt = nil
            }
        }
    }

    func stopActiveFocus() {
        UserDefaults.standard.removeObject(forKey: "focus_end_date")
        UserDefaults.standard.removeObject(forKey: "focus_total_seconds")
        UserDefaults.standard.removeObject(forKey: "focus_selected_minutes")
        UserDefaults.standard.removeObject(forKey: "focus_task_title")

        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
            pulseActiveFocus = false
            isFocusActive = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            activeFocusTaskTitle = ""
            activeFocusRemainingSeconds = 25 * 60
            activeFocusTotalSeconds = 25 * 60
        }
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
        let remaining = liveFocusRemaining(at: date)
        let progress = liveFocusProgress(at: date)
        let urgencyColor = activeFocusUrgencyColor(for: remaining)

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.10))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                urgencyColor,
                                urgencyColor.opacity(0.85)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: urgencyColor.opacity(0.5), radius: 6)
                    .frame(width: max(8, geo.size.width * progress))
            }
        }
        .frame(height: 12)
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
