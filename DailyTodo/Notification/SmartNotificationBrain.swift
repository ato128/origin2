//
//  SmartNotificationBrain.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 4.06.2026.
//

import Foundation

enum SmartNotificationCategory: String, Codable {
    case exam
    case streakProtection
    case dailyFocus
    case todayTasks
}

struct SmartNotificationPreferences {
    let enabled: Bool
    let examEnabled: Bool
    let streakEnabled: Bool
    let dailyFocusEnabled: Bool
    let taskEnabled: Bool

    static var current: SmartNotificationPreferences {
        let defaults = UserDefaults.standard

        return SmartNotificationPreferences(
            enabled: defaults.object(forKey: "smartNotificationsEnabled") as? Bool ?? true,
            examEnabled: defaults.object(forKey: "smartExamNotificationsEnabled") as? Bool ?? true,
            streakEnabled: defaults.object(forKey: "smartStreakNotificationsEnabled") as? Bool ?? true,
            dailyFocusEnabled: defaults.object(forKey: "smartDailyFocusNotificationsEnabled") as? Bool ?? true,
            taskEnabled: defaults.object(forKey: "smartTaskNotificationsEnabled") as? Bool ?? true
        )
    }
}

struct SmartNotificationCandidate: Identifiable {
    let id: String
    let category: SmartNotificationCategory
    let title: String
    let body: String
    let triggerDate: Date
    let deepLink: String
    let priority: Int
}

struct SmartNotificationBrain {

    static func makeCandidates(
        tasks: [DTTaskItem],
        exams: [ExamItem],
        focusRecords: [FocusSessionRecord],
        now: Date = Date()
    ) -> [SmartNotificationCandidate] {
        let preferences = SmartNotificationPreferences.current

        guard preferences.enabled else {
            return []
        }

        var candidates: [SmartNotificationCandidate] = []

        if preferences.examEnabled {
            candidates.append(
                contentsOf: examCandidates(
                    exams: exams,
                    tasks: tasks,
                    now: now
                )
            )
        }

        if preferences.streakEnabled {
            candidates.append(
                contentsOf: streakCandidates(
                    tasks: tasks,
                    focusRecords: focusRecords,
                    now: now
                )
            )
        }

        if preferences.taskEnabled {
            candidates.append(
                contentsOf: todayTaskCandidates(
                    tasks: tasks,
                    now: now
                )
            )
        }

        if preferences.dailyFocusEnabled {
            candidates.append(
                contentsOf: dailyFocusCandidates(
                    tasks: tasks,
                    focusRecords: focusRecords,
                    now: now
                )
            )
        }

        return candidates
            .filter { $0.triggerDate > now.addingTimeInterval(60) }
            .sorted {
                if $0.priority != $1.priority {
                    return $0.priority > $1.priority
                }

                return $0.triggerDate < $1.triggerDate
            }
    }

    // MARK: - Exams

    private static func examCandidates(
        exams: [ExamItem],
        tasks: [DTTaskItem],
        now: Date
    ) -> [SmartNotificationCandidate] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        let activeExams = exams
            .filter { !$0.isCompleted }
            .filter { $0.examDate >= today }
            .sorted { $0.examDate < $1.examDate }

        var result: [SmartNotificationCandidate] = []

        for exam in activeExams.prefix(4) {
            let examDay = calendar.startOfDay(for: exam.examDate)

            guard let days = calendar.dateComponents([.day], from: today, to: examDay).day else {
                continue
            }

            guard [14, 7, 3, 1, 0].contains(days) else {
                continue
            }

            guard let trigger = triggerDateToday(
                hour: examTriggerHour(for: days),
                minute: 20,
                now: now
            ) else {
                continue
            }

            let linkedPendingTasks = tasks.filter {
                !$0.isDone && $0.linkedExamID == exam.id
            }

            let course = exam.courseName.trimmingCharacters(in: .whitespacesAndNewlines)
            let courseText = course.isEmpty ? exam.title : course

            let title: String
            let body: String

            switch days {
            case 14:
                title = tr("snb_plan_time", courseText)
                body = tr("snb_14days")

            case 7:
                title = tr("snb_7days", courseText)
                body = linkedPendingTasks.isEmpty
                    ? tr("snb_review_plan")
                    : tr("snb_pending", linkedPendingTasks.count)

            case 3:
                title = tr("snb_last3", courseText)
                body = tr("snb_35min")

            case 1:
                title = tr("snb_tomorrow", courseText)
                body = tr("snb_last_review")

            default:
                title = tr("snb_today", courseText)
                body = tr("snb_stay_calm")
            }

            result.append(
                SmartNotificationCandidate(
                    id: "smart.exam.\(exam.id.uuidString).d\(days).\(dayKey(now))",
                    category: .exam,
                    title: title,
                    body: body,
                    triggerDate: trigger,
                    deepLink: "dailytodo://focus",
                    priority: days <= 1 ? 100 : 82
                )
            )
        }

        return result
    }

    private static func examTriggerHour(for days: Int) -> Int {
        switch days {
        case 0:
            return 8
        case 1:
            return 19
        default:
            return 18
        }
    }

    // MARK: - Streak

    private static func streakCandidates(
        tasks: [DTTaskItem],
        focusRecords: [FocusSessionRecord],
        now: Date
    ) -> [SmartNotificationCandidate] {
        let taskStreak = StreakEngine.currentStreak(tasks: tasks)
        let focusStreak = focusCurrentStreak(records: focusRecords, now: now)
        let hasFocusToday = didCompleteFocusToday(records: focusRecords, now: now)

        guard !hasFocusToday else { return [] }

        let strongestStreak = max(taskStreak, focusStreak)

        guard strongestStreak >= 2 else { return [] }

        guard let trigger = triggerDateToday(hour: 20, minute: 45, now: now) else {
            return []
        }

        return [
            SmartNotificationCandidate(
                id: "smart.streak.protect.\(dayKey(now))",
                category: .streakProtection,
                title: tr("snb_streak_end"),
                body: tr("snb_keep_rhythm"),
                triggerDate: trigger,
                deepLink: "dailytodo://focus",
                priority: 92
            )
        ]
    }

    // MARK: - Tasks

    private static func todayTaskCandidates(
        tasks: [DTTaskItem],
        now: Date
    ) -> [SmartNotificationCandidate] {
        let calendar = Calendar.current

        let pendingToday = tasks.filter { task in
            guard !task.isDone else { return false }
            guard let due = task.dueDate else { return false }
            return calendar.isDateInToday(due)
        }

        let overdue = tasks.filter { task in
            guard !task.isDone else { return false }
            guard let due = task.dueDate else { return false }
            return due < calendar.startOfDay(for: now)
        }

        let count = pendingToday.count + overdue.count

        guard count > 0 else { return [] }

        guard let trigger = triggerDateToday(hour: 19, minute: 35, now: now) else {
            return []
        }

        let title = count == 1
            ? tr("snb_one_left")
            : tr("snb_tasks_left", count)

        let body = overdue.isEmpty
            ? tr("snb_recover_flow")
            : tr("snb_overdue", overdue.count)

        return [
            SmartNotificationCandidate(
                id: "smart.tasks.today.\(dayKey(now))",
                category: .todayTasks,
                title: title,
                body: body,
                triggerDate: trigger,
                deepLink: "dailytodo://week",
                priority: 72
            )
        ]
    }

    // MARK: - Daily Focus

    private static func dailyFocusCandidates(
        tasks: [DTTaskItem],
        focusRecords: [FocusSessionRecord],
        now: Date
    ) -> [SmartNotificationCandidate] {
        let hasFocusToday = didCompleteFocusToday(records: focusRecords, now: now)

        guard !hasFocusToday else { return [] }

        let activeTasks = tasks.filter { !$0.isDone }

        guard !activeTasks.isEmpty else { return [] }

        guard let trigger = triggerDateToday(hour: 17, minute: 30, now: now) else {
            return []
        }

        return [
            SmartNotificationCandidate(
                id: "smart.daily.focus.\(dayKey(now))",
                category: .dailyFocus,
                title: tr("snb_recover_today"),
                body: tr("snb_one_session"),
                triggerDate: trigger,
                deepLink: "dailytodo://focus",
                priority: 58
            )
        ]
    }

    // MARK: - Focus Streak Helpers

    private static func didCompleteFocusToday(
        records: [FocusSessionRecord],
        now: Date
    ) -> Bool {
        let calendar = Calendar.current

        return records.contains { record in
            record.isCompleted &&
            record.completedSeconds >= 10 * 60 &&
            calendar.isDate(record.endedAt, inSameDayAs: now)
        }
    }

    private static func focusCurrentStreak(
        records: [FocusSessionRecord],
        now: Date
    ) -> Int {
        let calendar = Calendar.current

        let completedDays = records
            .filter { $0.isCompleted && $0.completedSeconds >= 10 * 60 }
            .map { calendar.startOfDay(for: $0.endedAt) }

        let uniqueDays = Set(completedDays).sorted(by: >)

        var streak = 0
        var current = calendar.startOfDay(for: now)

        for day in uniqueDays {
            if day == current {
                streak += 1
                current = calendar.date(byAdding: .day, value: -1, to: current) ?? current
            } else {
                break
            }
        }

        return streak
    }

    // MARK: - Time Helpers

    private static func triggerDateToday(
        hour: Int,
        minute: Int,
        now: Date
    ) -> Date? {
        let calendar = Calendar.current

        let todayTarget = calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: now
        ) ?? now

        if todayTarget > now.addingTimeInterval(5 * 60),
           !isQuietHour(todayTarget) {
            return todayTarget
        }

        let fallbackToday = now.addingTimeInterval(12 * 60)

        if !isQuietHour(fallbackToday),
           calendar.isDate(fallbackToday, inSameDayAs: now) {
            return fallbackToday
        }

        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else {
            return nil
        }

        let tomorrowTarget = calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: tomorrow
        ) ?? tomorrow

        if !isQuietHour(tomorrowTarget) {
            return tomorrowTarget
        }

        return calendar.date(
            bySettingHour: 9,
            minute: 20,
            second: 0,
            of: tomorrow
        )
    }

    private static func isQuietHour(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)

        let total = hour * 60 + minute
        let quietStart = 22 * 60 + 30
        let quietEnd = 8 * 60

        return total >= quietStart || total < quietEnd
    }

    private static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
