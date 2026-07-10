//
//  DailyFlowEngine.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 3.04.2026.
//

import Foundation


struct SuggestedTaskAction: Equatable {
    let title: String
    let subtitle: String
    let ctaTitle: String
    let taskUUID: String?
    let style: SuggestedTaskStyle
    let score: Int
    
    var normalizedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum SuggestedTaskStyle: String {
    case overdueRecovery
    case quickWin
    case startFocus
    case beforeClass
    case lightenLoad
    case planTomorrow
    case keepMomentum
}

struct DailyFlowSnapshot {
    let suggestedAction: SuggestedTaskAction?
}

enum DailyFlowEngine {
    static func makeSnapshot(
        tasks: [DTTaskItem],
        events: [EventItem],
        now: Date = Date()
    ) -> DailyFlowSnapshot {
        let action = resolveSuggestedAction(
            tasks: tasks,
            events: events,
            now: now
        )

        return DailyFlowSnapshot(
            suggestedAction: action
        )
    }

    static func resolveSuggestedAction(
        tasks: [DTTaskItem],
        events: [EventItem],
        now: Date = Date()
    ) -> SuggestedTaskAction? {
        let openTasks = tasks.filter { !$0.isDone }

        if openTasks.isEmpty {
            let hour = Calendar.current.component(.hour, from: now)

            // "Plan tomorrow" belongs to the end of the day — earlier hours
            // should keep pushing today's own program instead.
            if hour >= 21 {
                return SuggestedTaskAction(
                    title: tr("hd_lighten_tomorrow"),
                    subtitle: tr("df_calm_plan"),
                    ctaTitle: tr("hd_plan_tomorrow"),
                    taskUUID: nil,
                    style: .planTomorrow,
                    score: 40
                )
            } else {
                return SuggestedTaskAction(
                    title: tr("hd_make_small_start"),
                    subtitle: tr("df_no_open"),
                    ctaTitle: tr("common_add_task"),
                    taskUUID: nil,
                    style: .keepMomentum,
                    score: 30
                )
            }
        }

        if let overdue = highestPriorityOverdueTask(in: openTasks, now: now) {
            return SuggestedTaskAction(
                title: overdue.title,
                subtitle: tr("df_overdue"),
                ctaTitle: tr("hd_start"),
                taskUUID: overdue.taskUUID,
                style: .overdueRecovery,
                score: 100
            )
        }

        if let beforeClassTask = bestTaskBeforeNextEvent(
            tasks: openTasks,
            events: events,
            now: now
        ) {
            return SuggestedTaskAction(
                title: beforeClassTask.title,
                subtitle: tr("df_before_event"),
                ctaTitle: tr("df_do_now"),
                taskUUID: beforeClassTask.taskUUID,
                style: .beforeClass,
                score: 90
            )
        }

        if let quickWin = bestQuickWinTask(in: openTasks, now: now) {
            return SuggestedTaskAction(
                title: quickWin.title,
                subtitle: tr("df_manageable"),
                ctaTitle: tr("hd_start"),
                taskUUID: quickWin.taskUUID,
                style: .quickWin,
                score: 80
            )
        }

        let hour = Calendar.current.component(.hour, from: now)
        if hour >= 21 {
            return SuggestedTaskAction(
                title: tr("df_close_calm"),
                subtitle: tr("df_review_plan"),
                ctaTitle: tr("hd_plan_tomorrow"),
                taskUUID: nil,
                style: .planTomorrow,
                score: 60
            )
        }

        if let focusCandidate = highestPriorityTask(in: openTasks, now: now) {
            return SuggestedTaskAction(
                title: focusCandidate.title,
                subtitle: tr("df_most_logical"),
                ctaTitle: tr("df_open_focus"),
                taskUUID: focusCandidate.taskUUID,
                style: .startFocus,
                score: 70
            )
        }

        return SuggestedTaskAction(
            title: tr("df_keep_simple"),
            subtitle: tr("df_pick_small"),
            ctaTitle: tr("hd_open_tasks"),
            taskUUID: nil,
            style: .lightenLoad,
            score: 50
        )
    }

    private static func highestPriorityOverdueTask(
        in tasks: [DTTaskItem],
        now: Date
    ) -> DTTaskItem? {
        tasks
            .filter { task in
                guard let due = task.dueDate ?? task.scheduledWeekDate else { return false }
                return due < now
            }
            .sorted { lhs, rhs in
                let lhsDate = lhs.dueDate ?? lhs.scheduledWeekDate ?? .distantFuture
                let rhsDate = rhs.dueDate ?? rhs.scheduledWeekDate ?? .distantFuture
                return lhsDate < rhsDate
            }
            .first
    }

    private static func bestQuickWinTask(
        in tasks: [DTTaskItem],
        now: Date
    ) -> DTTaskItem? {
        tasks
            .filter { task in
                let type = task.taskType.lowercased()
                if type == "workout" { return false }
                if let duration = task.workoutDurationMinutes {
                    return duration <= 25
                }
                return true
            }
            .sorted { lhs, rhs in
                scoreForTask(lhs, now: now) > scoreForTask(rhs, now: now)
            }
            .first
    }

    private static func highestPriorityTask(
        in tasks: [DTTaskItem],
        now: Date
    ) -> DTTaskItem? {
        tasks
            .sorted { lhs, rhs in
                scoreForTask(lhs, now: now) > scoreForTask(rhs, now: now)
            }
            .first
    }

    private static func bestTaskBeforeNextEvent(
        tasks: [DTTaskItem],
        events: [EventItem],
        now: Date
    ) -> DTTaskItem? {
        guard let minutesUntilNextEvent = minutesUntilNearestEvent(events: events, now: now) else {
            return nil
        }

        guard minutesUntilNextEvent >= 15 && minutesUntilNextEvent <= 60 else {
            return nil
        }

        return tasks
            .filter { task in
                if let duration = task.workoutDurationMinutes {
                    return duration <= minutesUntilNextEvent
                }
                return true
            }
            .sorted { lhs, rhs in
                scoreForTask(lhs, now: now) > scoreForTask(rhs, now: now)
            }
            .first
    }

    private static func minutesUntilNearestEvent(
        events: [EventItem],
        now: Date
    ) -> Int? {
        let calendar = Calendar.current
        let weekdayIndex = (calendar.component(.weekday, from: now) + 5) % 7
        let currentMinute = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)

        let todaysEvents = events
            .filter { $0.weekday == weekdayIndex && $0.startMinute > currentMinute }
            .sorted { $0.startMinute < $1.startMinute }

        guard let next = todaysEvents.first else { return nil }
        return next.startMinute - currentMinute
    }

    private static func scoreForTask(
        _ task: DTTaskItem,
        now: Date
    ) -> Int {
        var score = 0

        let type = task.taskType.lowercased()

        if type == "exam" {
            score += 30
        } else if type == "homework" {
            score += 20
        } else if type == "study" {
            score += 15
        } else if type == "project" {
            score += 18
        }

        if let due = task.dueDate ?? task.scheduledWeekDate {
            let minutes = Int(due.timeIntervalSince(now) / 60)

            if minutes < 0 {
                score += 100
            } else if minutes <= 60 {
                score += 50
            } else if minutes <= 180 {
                score += 35
            } else if Calendar.current.isDateInToday(due) {
                score += 20
            }
        }

        if let note = Optional(task.notes.trimmingCharacters(in: .whitespacesAndNewlines)),
           !note.isEmpty {
            score += 5
        }

        return score
    }
}
