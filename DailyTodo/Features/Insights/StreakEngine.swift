//
//  StreakEngine.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 6.03.2026.
//

import Foundation

struct StreakEngine {

    static func currentStreak(tasks: [DTTaskItem]) -> Int {
        let calendar = Calendar.current

        let completedDates = tasks
            .filter { $0.isDone }
            .compactMap { $0.completedAt }
            .map { calendar.startOfDay(for: $0) }

        let uniqueDays = Set(completedDates).sorted(by: >)

        var streak = 0
        var current = calendar.startOfDay(for: Date())

        for day in uniqueDays {
            if day == current {
                streak += 1
                current = calendar.date(byAdding: .day, value: -1, to: current)!
            } else {
                break
            }
        }

        return streak
    }
}
