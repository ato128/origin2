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
                    title: tr("smart_suggestion_overdue_title"),
                    message: tr("smart_suggestion_overdue_message"),
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
                    title: tr("smart_suggestion_busy_title"),
                    message: tr("smart_suggestion_busy_message"),
                    priorityScore: 80
                )
            )
        }

        let todayWeekday = (Calendar.current.component(.weekday, from: now) + 5) % 7
        let todayEvents = events.filter { $0.weekday == todayWeekday }

        if !todayEvents.isEmpty && !todayTasks.isEmpty {
            results.append(
                SmartTaskSuggestion(
                    title: tr("smart_suggestion_balance_title"),
                    message: tr("smart_suggestion_balance_message"),
                    priorityScore: 70
                )
            )
        }

        if results.isEmpty {
            results.append(
                SmartTaskSuggestion(
                    title: tr("smart_suggestion_default_title"),
                    message: tr("smart_suggestion_default_message"),
                    priorityScore: 50
                )
            )
        }

        return results.sorted { $0.priorityScore > $1.priorityScore }
    }
}
