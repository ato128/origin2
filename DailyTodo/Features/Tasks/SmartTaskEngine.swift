//
//  SmartTaskEngine.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 14.03.2026.
//

import Foundation

struct SmartTaskSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let priorityScore: Int
}

struct SmartTaskEngine {
    static func suggestions(
        tasks: [DTTaskItem],
        events: [EventItem],
        now: Date = Date()
    ) -> [SmartTaskSuggestion] {
        let activeTasks = tasks.filter { !$0.isDone }
        var results: [SmartTaskSuggestion] = []

        let overdueTasks = activeTasks.filter {
            guard let due = $0.dueDate else { return false }
            return due < now
        }

        if !overdueTasks.isEmpty {
            results.append(
                SmartTaskSuggestion(
                    title: "Geciken görev var",
                    message: "Önce geciken görevlerden birini kapatman en doğru adım olabilir.",
                    priorityScore: 100
                )
            )
        }

        let todayTasks = activeTasks.filter {
            guard let due = $0.dueDate else { return false }
            return Calendar.current.isDateInToday(due)
        }

        if todayTasks.count >= 3 {
            results.append(
                SmartTaskSuggestion(
                    title: "Bugün yoğun görünüyorsun",
                    message: "Görevleri kısa bloklara bölerek ilerlemek daha verimli olabilir.",
                    priorityScore: 80
                )
            )
        }

        let todayWeekday = (Calendar.current.component(.weekday, from: now) + 5) % 7
        let todayEvents = events.filter { $0.weekday == todayWeekday }

        if !todayEvents.isEmpty && !todayTasks.isEmpty {
            results.append(
                SmartTaskSuggestion(
                    title: "Ders + görev dengesi",
                    message: "Ders aralarına küçük tasklar koymak bugünü daha kontrollü yapabilir.",
                    priorityScore: 70
                )
            )
        }

        if results.isEmpty {
            results.append(
                SmartTaskSuggestion(
                    title: "Ritim korunabilir",
                    message: "Küçük bir görevi tamamlayarak güne akış kazandırabilirsin.",
                    priorityScore: 50
                )
            )
        }

        return results.sorted { $0.priorityScore > $1.priorityScore }
    }
}
