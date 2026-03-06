//
//  SmartInsights.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 6.03.2026.
//


import Foundation

struct SmartInsights {

    static func bestDay(tasks: [DTTaskItem]) -> String {
        var counts: [Int: Int] = [:]

        for task in tasks where task.isDone {
            if let date = task.completedAt {
                let weekday = Calendar.current.component(.weekday, from: date)
                counts[weekday, default: 0] += 1
            }
        }

        let best = counts.max { $0.value < $1.value }
        let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        return days[(best?.key ?? 1) - 1]
    }
}
