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
    case aiSuggestion
    case weeklyRecap
}

struct SmartNotificationPreferences {
    let enabled: Bool
    let examEnabled: Bool
    let streakEnabled: Bool
    let dailyFocusEnabled: Bool
    let taskEnabled: Bool
    let aiSuggestionEnabled: Bool

    static var current: SmartNotificationPreferences {
        let defaults = UserDefaults.standard

        return SmartNotificationPreferences(
            enabled: defaults.object(forKey: "smartNotificationsEnabled") as? Bool ?? true,
            examEnabled: defaults.object(forKey: "smartExamNotificationsEnabled") as? Bool ?? true,
            streakEnabled: defaults.object(forKey: "smartStreakNotificationsEnabled") as? Bool ?? true,
            dailyFocusEnabled: defaults.object(forKey: "smartDailyFocusNotificationsEnabled") as? Bool ?? true,
            taskEnabled: defaults.object(forKey: "smartTaskNotificationsEnabled") as? Bool ?? true,
            aiSuggestionEnabled: defaults.object(forKey: "smartAiSuggestionNotificationsEnabled") as? Bool ?? true
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
        events: [EventItem] = [],
        focusRecords: [FocusSessionRecord],
        now: Date = Date()
    ) -> [SmartNotificationCandidate] {
        let preferences = SmartNotificationPreferences.current

        guard preferences.enabled else {
            return []
        }

        var candidates: [SmartNotificationCandidate] = []

        if preferences.aiSuggestionEnabled {
            candidates.append(
                contentsOf: aiSuggestionCandidates(
                    tasks: tasks,
                    exams: exams,
                    events: events,
                    focusRecords: focusRecords,
                    now: now
                )
            )
        }

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

        candidates.append(
            contentsOf: weeklyRecapCandidates(
                tasks: tasks,
                focusRecords: focusRecords,
                now: now
            )
        )

        return candidates
            .filter { $0.triggerDate > now.addingTimeInterval(60) }
            .sorted {
                if $0.priority != $1.priority {
                    return $0.priority > $1.priority
                }

                return $0.triggerDate < $1.triggerDate
            }
    }

    // MARK: - Updo AI Suggestion (empty-plan nudge)

    /// Fires only when the user has nothing on deck — no pending tasks, no exam in
    /// the next week. The copy adapts to who they are (brand-new vs. returning
    /// focuser) and the time of day, so Updo AI nudges them to take a first action.
    private static func aiSuggestionCandidates(
        tasks: [DTTaskItem],
        exams: [ExamItem],
        events: [EventItem],
        focusRecords: [FocusSessionRecord],
        now: Date
    ) -> [SmartNotificationCandidate] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        let hasPendingTask = tasks.contains { !$0.isDone }

        let hasUpcomingExam = exams.contains { exam in
            guard !exam.isCompleted else { return false }
            guard let days = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: exam.examDate)).day
            else { return false }
            return days >= 0 && days <= 7
        }

        // The plan is "empty" only when there's genuinely nothing to act on.
        guard !hasPendingTask, !hasUpcomingExam else { return [] }

        let hour = calendar.component(.hour, from: now)
        let hasEverFocused = focusRecords.contains { $0.countsTowardStats }
        let hasSchedule = !events.isEmpty

        // Pick the trigger window + adaptive body for who/when this is.
        let body: String
        let triggerHour: Int

        if !hasEverFocused, !hasSchedule {
            // Brand-new: invite the very first action, mid-morning.
            body = tr("snb_ai_new")
            triggerHour = 11
        } else if hour < 12 {
            body = tr("snb_ai_morning")
            triggerHour = 11
        } else if hour < 18 {
            body = tr("snb_ai_focus")
            triggerHour = 17
        } else {
            // "Plan tomorrow" is an end-of-day message — don't fire it while
            // the evening is still in progress.
            body = tr("snb_ai_evening")
            triggerHour = 21
        }

        guard let trigger = triggerDateToday(hour: triggerHour, minute: 15, now: now) else {
            return []
        }

        return [
            SmartNotificationCandidate(
                id: "smart.ai.suggestion.\(dayKey(now))",
                category: .aiSuggestion,
                title: tr("snb_ai_title"),
                body: body,
                triggerDate: trigger,
                deepLink: "dailytodo://week",
                priority: 48
            )
        ]
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
        // Unified app-wide streak rule (task AND focus per day) — the same number
        // the Home hero, widget and Insights identity card show.
        let streak = StreakProgressEngine.currentStreak(asOf: now, tasks: tasks, focusRecords: focusRecords)
        let todayQualified = StreakProgressEngine.dayQualifies(
            Calendar.current.startOfDay(for: now), tasks: tasks, focusRecords: focusRecords
        )

        guard !todayQualified else { return [] }
        guard streak >= 2 else { return [] }

        // Land ~30 min before the user's usual session so there is still time
        // to act; never earlier than 19:00 or later than 22:30.
        let minuteOfDay = personalizedMinute(
            defaultMinute: 20 * 60 + 45,
            records: focusRecords,
            offset: -30,
            clampedTo: (19 * 60)...(22 * 60 + 30),
            now: now
        )

        guard let trigger = triggerDateToday(hour: minuteOfDay / 60, minute: minuteOfDay % 60, now: now) else {
            return []
        }

        // Name the missing half of the daily rule (task AND focus) so the user
        // knows exactly what saves the streak tonight.
        let calendar = Calendar.current
        let hasTaskToday = tasks.contains { task in
            guard task.isDone, let done = task.completedAt else { return false }
            return calendar.isDate(done, inSameDayAs: now)
        }
        let hasFocusToday = didCompleteFocusToday(records: focusRecords, now: now)

        let body: String
        let deepLink: String
        switch (hasTaskToday, hasFocusToday) {
        case (true, false):
            body = tr("snb_streak_risk_focus", streak)
            deepLink = "dailytodo://focus"
        case (false, true):
            body = tr("snb_streak_risk_task", streak)
            deepLink = "dailytodo://week"
        default:
            body = tr("snb_streak_risk_both", streak)
            deepLink = "dailytodo://focus"
        }

        return [
            SmartNotificationCandidate(
                id: "smart.streak.protect.\(dayKey(now))",
                category: .streakProtection,
                title: tr("snb_streak_end"),
                body: body,
                triggerDate: trigger,
                deepLink: deepLink,
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

        // Nudge ~an hour before the user's usual focus time (12:00–20:30 window).
        let minuteOfDay = personalizedMinute(
            defaultMinute: 17 * 60 + 30,
            records: focusRecords,
            offset: -60,
            clampedTo: (12 * 60)...(20 * 60 + 30),
            now: now
        )

        guard let trigger = triggerDateToday(hour: minuteOfDay / 60, minute: minuteOfDay % 60, now: now) else {
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

    // MARK: - Weekly recap (Sunday evening)

    /// One notification per Sunday evening, only when the week actually has
    /// something to recap. Mirrors the Home weekly-summary card and deep-links
    /// into Insights.
    private static func weeklyRecapCandidates(
        tasks: [DTTaskItem],
        focusRecords: [FocusSessionRecord],
        now: Date
    ) -> [SmartNotificationCandidate] {
        let calendar = Calendar.current
        guard calendar.component(.weekday, from: now) == 1 else { return [] }
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }

        let weekMinutes = focusRecords
            .filter { $0.countsTowardStats && $0.endedAt >= weekStart }
            .reduce(0) { $0 + $1.completedSeconds } / 60

        let weekTasks = tasks.filter { task in
            guard task.isDone, let done = task.completedAt else { return false }
            return done >= weekStart
        }.count

        guard weekMinutes > 0 || weekTasks > 0 else { return [] }

        guard let trigger = triggerDateToday(hour: 19, minute: 30, now: now) else {
            return []
        }

        let hours = weekMinutes / 60
        let focusText = hours > 0
            ? tr("snb_recap_focus_h", hours, weekMinutes % 60)
            : tr("snb_recap_focus_m", weekMinutes)

        return [
            SmartNotificationCandidate(
                id: "smart.weekly.recap.\(dayKey(now))",
                category: .weeklyRecap,
                title: tr("snb_recap_title"),
                body: tr("snb_recap_body", focusText, weekTasks),
                triggerDate: trigger,
                deepLink: "dailytodo://insights",
                priority: 40
            )
        ]
    }

    // MARK: - Personalized timing
    //
    // A 17:30 "focus now" nudge is noise for someone who always studies at 22:00.
    // The median start time of the user's recent real sessions anchors the
    // triggers instead; with too little data we keep the fixed defaults.

    /// Median start minute-of-day of countsTowardStats sessions in the last 30
    /// days. Needs ≥ 3 sessions, otherwise nil (defaults apply).
    static func typicalFocusMinute(
        records: [FocusSessionRecord],
        now: Date = Date()
    ) -> Int? {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: -30, to: now) else { return nil }

        let minutes = records
            .filter { $0.countsTowardStats && $0.startedAt >= cutoff }
            .map { calendar.component(.hour, from: $0.startedAt) * 60
                 + calendar.component(.minute, from: $0.startedAt) }
            .sorted()

        guard minutes.count >= 3 else { return nil }
        return minutes[minutes.count / 2]
    }

    /// Shifts a default trigger toward the user's typical focus time.
    /// `offset` is applied to the typical minute (e.g. -60 = one hour before);
    /// the result is clamped so notifications stay in a sane window.
    private static func personalizedMinute(
        defaultMinute: Int,
        records: [FocusSessionRecord],
        offset: Int,
        clampedTo range: ClosedRange<Int>,
        now: Date
    ) -> Int {
        guard let typical = typicalFocusMinute(records: records, now: now) else {
            return defaultMinute
        }
        return min(max(typical + offset, range.lowerBound), range.upperBound)
    }

    // MARK: - Focus Helpers

    /// "Did the user really focus today" — same countsTowardStats rule as the
    /// rest of the app, so nudges never contradict the visible stats.
    private static func didCompleteFocusToday(
        records: [FocusSessionRecord],
        now: Date
    ) -> Bool {
        let calendar = Calendar.current

        return records.contains { record in
            record.countsTowardStats &&
            calendar.isDate(record.endedAt, inSameDayAs: now)
        }
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
