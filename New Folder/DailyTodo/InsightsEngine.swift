//
//  InsightsEngine.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 5.03.2026.
//

import Foundation

struct DayMinutes: Identifiable {
    let id = UUID()
    let dayIndex: Int   // 0 = Pzt ... 6 = Paz
    let minutes: Int
}

struct DayCount: Identifiable {
    let id = UUID()
    let dayIndex: Int   // 0 = Pzt ... 6 = Paz
    let count: Int
}

enum InsightsEngine {

    static func weeklyMinutes(events: [EventItem]) -> [DayMinutes] {
        var totals = Array(repeating: 0, count: 7)

        for event in events {
            if (0...6).contains(event.weekday) {
                totals[event.weekday] += event.durationMinute
            }
        }

        return totals.enumerated().map {
            DayMinutes(dayIndex: $0.offset, minutes: $0.element)
        }
    }

    static func totalWeeklyMinutes(events: [EventItem]) -> Int {
        events.reduce(0) { $0 + $1.durationMinute }
    }

    static func busiestDay(events: [EventItem]) -> (dayIndex: Int, minutes: Int) {
        let weekly = weeklyMinutes(events: events)
        let best = weekly.max(by: { $0.minutes < $1.minutes }) ?? DayMinutes(dayIndex: 0, minutes: 0)
        return (best.dayIndex, best.minutes)
    }

    static func weeklyCompletedTasks(tasks: [DTTaskItem], calendar: Calendar = .current) -> [DayCount] {
        var totals = Array(repeating: 0, count: 7)

        for task in tasks where task.isDone {
            guard let completedAt = task.completedAt else { continue }

            let weekday = calendar.component(.weekday, from: completedAt)

            let dayIndex: Int
            switch weekday {
            case 2: dayIndex = 0 // Pzt
            case 3: dayIndex = 1 // Sal
            case 4: dayIndex = 2 // Çar
            case 5: dayIndex = 3 // Per
            case 6: dayIndex = 4 // Cum
            case 7: dayIndex = 5 // Cmt
            case 1: dayIndex = 6 // Paz
            default: dayIndex = 0
            }

            totals[dayIndex] += 1
        }

        return totals.enumerated().map {
            DayCount(dayIndex: $0.offset, count: $0.element)
        }
    }

    static func completionRate(tasks: [DTTaskItem]) -> Int {
        guard !tasks.isEmpty else { return 0 }
        let completed = tasks.filter(\.isDone).count
        return Int((Double(completed) / Double(tasks.count)) * 100)
    }

    static func completedTodayCount(tasks: [DTTaskItem], calendar: Calendar = .current) -> Int {
        tasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return calendar.isDateInToday(completedAt)
        }.count
    }

    static func activeTaskCount(tasks: [DTTaskItem]) -> Int {
        tasks.filter { !$0.isDone }.count
    }

    static func overdueTaskCount(tasks: [DTTaskItem], now: Date = Date()) -> Int {
        tasks.filter { task in
            guard let due = task.dueDate else { return false }
            return !task.isDone && due < now
        }.count
    }

    static func streakDays(tasks: [DTTaskItem], calendar: Calendar = .current) -> Int {
        let completedDates = tasks.compactMap(\.completedAt)
        guard !completedDates.isEmpty else { return 0 }

        let uniqueDays = Set(completedDates.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: Date())

        var streak = 0

        for offset in 0..<365 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { break }

            if uniqueDays.contains(day) {
                streak += 1
            } else {
                if offset == 0 { continue }
                break
            }
        }

        return streak
    }

    static func productivityScore(tasks: [DTTaskItem]) -> Int {
        let completion = completionRate(tasks: tasks)
        let completedToday = completedTodayCount(tasks: tasks)
        let overdue = overdueTaskCount(tasks: tasks)

        var score = completion
        score += min(completedToday * 6, 18)
        score -= min(overdue * 8, 24)

        return max(0, min(score, 100))
    }

    static func dayName(_ i: Int) -> String {
        ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"][max(0, min(6, i))]
    }

    static func durationText(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60

        if h == 0 { return "\(m) dk" }
        if m == 0 { return "\(h)s" }
        return "\(h)s \(m)dk"
    }
    static func consistencyScore(tasks: [DTTaskItem], calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: Date())

        let completedDays = Set(
            tasks
                .filter { $0.isDone }
                .compactMap { $0.completedAt }
                .map { calendar.startOfDay(for: $0) }
        )

        var activeDays = 0

        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            if completedDays.contains(day) {
                activeDays += 1
            }
        }

        return Int((Double(activeDays) / 7.0) * 100.0)
    }
}
