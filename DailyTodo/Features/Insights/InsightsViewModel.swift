//
//  InsightsViewModel.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import Foundation
import SwiftUI

struct InsightsViewModel {
    let tasks: [DTTaskItem]
    let focusSessions: [FocusSessionRecord]
    let events: [EventItem]
    let exams: [ExamItem]
    let userID: String?
    let localeIdentifier: String

    private let calendar = Calendar.current

    // MARK: - Localization

    private func tr(_ key: String, _ args: CVarArg...) -> String {
        let format = String(localized: LocalizedStringResource(stringLiteral: key))
        return String(format: format, locale: Locale(identifier: localeIdentifier), arguments: args)
    }

    private var isTurkish: Bool {
        !appLanguageIsEnglish()
    }

    private var dayLabels: [String] {
        if isTurkish {
            return (0..<7).map { localizedWeekdayShort($0) }
        } else {
            return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        }
    }

    private var lastSuggestionKey: String {
        "lastSmartSuggestionIndex_\(userID ?? "guest")"
    }

    // MARK: - Core Filters

    private var completedTasks: [DTTaskItem] {
        tasks.filter(\.isDone)
    }

    private var activeTasks: [DTTaskItem] {
        tasks.filter { !$0.isDone }
    }

    private var completedTodayTasks: [DTTaskItem] {
        completedTasks.filter {
            if let completedAt = $0.completedAt {
                return calendar.isDateInToday(completedAt)
            }
            if let dueDate = $0.dueDate {
                return calendar.isDateInToday(dueDate)
            }
            return false
        }
    }

    private var todayPendingTasks: [DTTaskItem] {
        tasks.filter { task in
            guard !task.isDone else { return false }
            if let due = task.dueDate, calendar.isDateInToday(due) { return true }
            if let scheduled = task.scheduledWeekDate, calendar.isDateInToday(scheduled) { return true }
            return false
        }
    }

    private var overdueTasks: [DTTaskItem] {
        tasks.filter { task in
            guard !task.isDone else { return false }
            guard let due = task.dueDate else { return false }
            return due < Date()
        }
    }

    private var upcomingExams: [ExamItem] {
        exams
            .filter { !$0.isCompleted && $0.examDate >= calendar.startOfDay(for: Date()) }
            .sorted { $0.examDate < $1.examDate }
    }

    private var todayFocusSessions: [FocusSessionRecord] {
        focusSessions.filter { calendar.isDateInToday($0.startedAt) }
    }

    private var todayFocusMinutes: Int {
        todayFocusSessions.reduce(0) { $0 + ($1.completedSeconds / 60) }
    }

    private var totalFocusMinutes: Int {
        focusSessions.reduce(0) { $0 + ($1.completedSeconds / 60) }
    }

    private var totalFocusSessionsCount: Int {
        focusSessions.count
    }

    private var completedTasksCount: Int {
        completedTasks.count
    }

    private var activeTasksCount: Int {
        activeTasks.count
    }

    private var averageFocusMinutes: Int {
        guard !focusSessions.isEmpty else { return 0 }
        return totalFocusMinutes / max(focusSessions.count, 1)
    }

    private var streakCount: Int {
        var streak = 0
        let today = calendar.startOfDay(for: Date())

        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { break }

            let hasCompletion = completedTasks.contains {
                guard let completedAt = $0.completedAt else { return false }
                return calendar.isDate(completedAt, inSameDayAs: day)
            }

            if hasCompletion {
                streak += 1
            } else {
                if offset == 0 { continue }
                break
            }
        }

        return streak
    }

    private var weeklyCompletedCounts: [Int] {
        (0..<7).map { weekday in
            completedTasks.filter {
                guard let completedAt = $0.completedAt else { return false }
                let mapped = (calendar.component(.weekday, from: completedAt) + 5) % 7
                return mapped == weekday
            }.count
        }
    }

    private var weeklyFocusMinutesLast7Days: Int {
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else { return 0 }
        return focusSessions
            .filter { $0.startedAt >= weekAgo }
            .reduce(0) { $0 + ($1.completedSeconds / 60) }
    }

    private var bestDayLabel: String {
        guard let index = weeklyCompletedCounts.enumerated().max(by: { $0.element < $1.element })?.offset,
              dayLabels.indices.contains(index) else {
            return isTurkish ? "Bu hafta" : "This week"
        }
        return dayLabels[index]
    }

    private var isEveningProductive: Bool {
        let eveningSessions = focusSessions.filter {
            calendar.component(.hour, from: $0.startedAt) >= 18
        }
        return !focusSessions.isEmpty && eveningSessions.count >= max(1, focusSessions.count / 2)
    }

    private var bestStudyHourRangeText: String {
        let sessionsByHour = Dictionary(grouping: focusSessions) {
            calendar.component(.hour, from: $0.startedAt)
        }

        guard let bestHour = sessionsByHour.max(by: { $0.value.count < $1.value.count })?.key else {
            return isTurkish ? tr("iv_not_clear") : "Not clear yet"
        }

        switch bestHour {
        case 5..<12:
            return isTurkish ? "Sabah" : "Morning"
        case 12..<17:
            return isTurkish ? tr("iv_afternoon") : "Afternoon"
        case 17..<22:
            return isTurkish ? tr("hd_evening") : "Evening"
        default:
            return isTurkish ? "Gece" : "Night"
        }
    }

    // MARK: - Courses & Exams

    private var courseNames: [String] {
        let fromTasks = tasks.map { $0.courseName.trimmingCharacters(in: .whitespacesAndNewlines) }
        let fromExams = exams.map { $0.courseName.trimmingCharacters(in: .whitespacesAndNewlines) }
        return Array(Set((fromTasks + fromExams).filter { !$0.isEmpty })).sorted()
    }

    private func examRelatedTasks(for exam: ExamItem) -> [DTTaskItem] {
        let examCourse = exam.courseName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let examTitle = exam.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return tasks.filter { task in
            let taskCourse = task.courseName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let taskTitle = task.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let taskType = task.taskType.lowercased()

            if !examCourse.isEmpty && taskCourse == examCourse { return true }
            if !examTitle.isEmpty && taskTitle.contains(examTitle) { return true }
            if taskType == "exam" && !examCourse.isEmpty && taskTitle.contains(examCourse) { return true }

            return false
        }
    }

    private func examReadinessProgress(for exam: ExamItem) -> Double {
        let relatedTasks = examRelatedTasks(for: exam)
        let doneCount = relatedTasks.filter(\.isDone).count
        let totalCount = max(relatedTasks.count, 1)

        let taskComponent = min(1.0, Double(doneCount) / Double(totalCount))
        let focusComponent = min(
            1.0,
            Double(relatedTasks.compactMap(\.workoutDurationMinutes).reduce(0, +)) / 240.0
        )

        let daysLeft = max(0, calendar.dateComponents([.day], from: Date(), to: exam.examDate).day ?? 0)
        let urgencyPenalty = daysLeft <= 2 ? 0.18 : (daysLeft <= 5 ? 0.10 : 0.0)

        return min(1, max(0, (taskComponent * 0.65) + (focusComponent * 0.35) - urgencyPenalty))
    }

    private var averageExamReadiness: Double {
        guard !upcomingExams.isEmpty else { return 0 }
        let total = upcomingExams.reduce(0.0) { partial, exam in
            partial + examReadinessProgress(for: exam)
        }
        return total / Double(upcomingExams.count)
    }

    private func countdownText(for exam: ExamItem) -> String {
        let days = max(
            0,
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: Date()),
                to: calendar.startOfDay(for: exam.examDate)
            ).day ?? 0
        )

        if isTurkish {
            if days == 0 { return tr("common_today") }
            if days == 1 { return tr("iv_one_day_left") }
            return tr("rel_days_left", days)
        } else {
            if days == 0 { return "Today" }
            if days == 1 { return "1 day left" }
            return "\(days) days left"
        }
    }

    // MARK: - Text Helpers

    private func minutesText(_ minutes: Int) -> String {
        if isTurkish {
            return "\(minutes) dk"
        } else {
            return "\(minutes) min"
        }
    }

    // MARK: - Suggestion Logic

    private var hasTaskBacklog: Bool {
        activeTasksCount >= 5
    }

    private var hasNoFocusHabit: Bool {
        totalFocusSessionsCount == 0
    }

    private var hasStrongMomentum: Bool {
        completedTasksCount >= 3 || totalFocusMinutes >= 60
    }

    private func rotatedSuggestions() -> [SmartSuggestionData] {
        var suggestions: [SmartSuggestionData] = []

        if hasTaskBacklog {
            suggestions.append(.init(
                title: isTurkish ? tr("iv_load_built") : "A bit of backlog is building",
                message: isTurkish
                    ? tr("iv_clear_small")
                    : "Clearing smaller tasks first can quickly restore momentum.",
                buttonTitle: isTurkish ? tr("hd_open_tasks") : "Open Tasks",
                action: .openTasks
            ))
        }

        if hasNoFocusHabit && activeTasksCount > 0 {
            suggestions.append(.init(
                title: isTurkish ? tr("iv_start_first_block") : "Start your first focus block",
                message: isTurkish
                    ? tr("iv_short_personal")
                    : "Even a short focus session will make this screen more personal.",
                buttonTitle: isTurkish ? tr("iv_start_focus") : "Start Focus",
                action: .openFocus
            ))
        }

        if hasStrongMomentum {
            suggestions.append(.init(
                title: isTurkish ? tr("iv_momentum_good") : "Your momentum looks good",
                message: isTurkish
                    ? tr("iv_one_more")
                    : "Complete one more task to preserve today's rhythm.",
                buttonTitle: isTurkish ? tr("hd_open_tasks") : "Open Tasks",
                action: .openTasks
            ))
        }

        suggestions.append(.init(
            title: isTurkish ? tr("iv_use_strong_day") : "Use your strongest day",
            message: isTurkish
                ? tr("iv_strong_day", bestDayLabel)
                : "\(bestDayLabel) seems to be your strongest day.",
            buttonTitle: isTurkish ? tr("hd_open_week") : "Open Week",
            action: .openWeek
        ))

        if isEveningProductive {
            suggestions.append(.init(
                title: isTurkish ? tr("iv_evening_stronger") : "Your evening rhythm is stronger",
                message: isTurkish
                    ? tr("iv_evening_work")
                    : "Placing important work in the evening may work better for you.",
                buttonTitle: isTurkish ? tr("iv_start_focus") : "Start Focus",
                action: .openFocus
            ))
        }

        if totalFocusMinutes >= 90 {
            suggestions.append(.init(
                title: isTurkish ? tr("iv_deep_signal") : "There is a deep work signal",
                message: isTurkish
                    ? tr("iv_longer_blocks")
                    : "Longer focus blocks may be working well for you.",
                buttonTitle: isTurkish ? tr("hd_open_week") : "Open Week",
                action: .openWeek
            ))
        }

        suggestions.append(.init(
            title: isTurkish ? tr("iv_start_small") : "Start small",
            message: isTurkish
                ? tr("iv_one_clear")
                : "Picking one clear task is a strong start for today.",
            buttonTitle: isTurkish ? tr("hd_open_tasks") : "Open Tasks",
            action: .openTasks
        ))

        return suggestions
    }

    var smartSuggestion: SmartSuggestionData {
        let suggestions = rotatedSuggestions()

        guard !suggestions.isEmpty else {
            return .init(
                title: isTurkish ? tr("iv_good_day_start") : "A good day to begin",
                message: isTurkish
                    ? tr("iv_first_fills")
                    : "Your first task or first focus session will start filling this space.",
                buttonTitle: isTurkish ? tr("hd_open_tasks") : "Open Tasks",
                action: .openTasks
            )
        }

        let todayIndex = calendar.component(.day, from: Date()) % suggestions.count
        let lastIndex = UserDefaults.standard.integer(forKey: lastSuggestionKey)

        var index = todayIndex
        if suggestions.count > 1 && index == lastIndex {
            index = (index + 1) % suggestions.count
        }

        UserDefaults.standard.set(index, forKey: lastSuggestionKey)
        return suggestions[index]
    }

    var aiCoach: AICoachData {
        if !upcomingExams.isEmpty {
            return .init(
                title: isTurkish ? "Mini Coach" : "Mini Coach",
                message: isTurkish
                    ? tr("iv_exams_coming")
                    : "You have upcoming exams. Consistent short blocks are the safest path.",
                buttonTitle: isTurkish ? tr("hd_open_week") : "Open Week",
                action: .openWeek
            )
        }

        if !overdueTasks.isEmpty {
            return .init(
                title: isTurkish ? "Mini Coach" : "Mini Coach",
                message: isTurkish
                    ? tr("iv_overdue_first")
                    : "Clearing overdue tasks first will quickly restore your rhythm.",
                buttonTitle: isTurkish ? tr("hd_open_tasks") : "Open Tasks",
                action: .openTasks
            )
        }

        if totalFocusMinutes >= 60 && completedTasksCount >= 2 {
            return .init(
                title: isTurkish ? "Mini Coach" : "Mini Coach",
                message: isTurkish
                    ? tr("iv_going_well_block")
                    : "You are doing well today. One more focus block would finish the day strong.",
                buttonTitle: isTurkish ? tr("iv_start_focus") : "Start Focus",
                action: .openFocus
            )
        }

        return .init(
            title: isTurkish ? "Mini Coach" : "Mini Coach",
            message: isTurkish
                ? tr("iv_one_clear_2")
                : "Choosing one clear task may be the best start for today.",
            buttonTitle: isTurkish ? tr("hd_open_tasks") : "Open Tasks",
            action: .openTasks
        )
    }

    // MARK: - New V2 Outputs

    var coachUnified: InsightsCoachUnifiedData {
        let coach = aiCoach
        let suggestion = smartSuggestion

        return InsightsCoachUnifiedData(
            eyebrow: isTurkish ? tr("iv_my_suggestion") : "My suggestion for today",
            title: coach.title,
            message: coach.message,
            actionTitle: coach.buttonTitle,
            action: coach.action,
            secondaryHint: suggestion.message
        )
    }

    var studyHeroPremium: StudyHeroData {
        if !upcomingExams.isEmpty {
            let readiness = Int(averageExamReadiness * 100)
            let nearest = upcomingExams.first
            let nearestText = nearest.map { countdownText(for: $0) } ?? (isTurkish ? tr("bcd_soon") : "Soon")

            return StudyHeroData(
                mode: .exams,
                title: isTurkish ? tr("iv_exam_view") : "Your exam view is taking shape",
                subtitle: isTurkish
                    ? tr("iv_nearest_exam")
                    : "A short block today is enough for your nearest exam.",
                primaryValue: "\(readiness)",
                primaryLabel: isTurkish ? tr("iv_prep_lc") : "readiness",
                chip1: isTurkish ? tr("iv_exam_count", upcomingExams.count) : "\(upcomingExams.count) exams",
                chip2: nearestText,
                chip3: isTurkish ? "\(totalFocusMinutes) dk" : "\(totalFocusMinutes) min",
                accent: .orange,
                actionTitle: isTurkish ? tr("iv_open_exam_plan") : "Open Exam Plan",
                action: .openWeek
            )
        }

        if !courseNames.isEmpty {
            return StudyHeroData(
                mode: .courses,
                title: isTurkish ? tr("iv_balance_forming") : "Your course balance is forming",
                subtitle: isTurkish
                    ? tr("iv_pull_forward")
                    : "Bringing your weaker course forward would help.",
                primaryValue: "\(courseNames.count)",
                primaryLabel: isTurkish ? "aktif ders" : "courses",
                chip1: isTurkish ? "\(completedTasksCount) tamam" : "\(completedTasksCount) done",
                chip2: isTurkish ? tr("rel_open_count", activeTasksCount) : "\(activeTasksCount) open",
                chip3: bestDayLabel,
                accent: .blue,
                actionTitle: isTurkish ? tr("hd_open_tasks") : "Open Tasks",
                action: .openTasks
            )
        }

        if !focusSessions.isEmpty || completedTasksCount > 0 {
            let rhythmScore = min(
                1.0,
                (Double(streakCount) / 7.0 * 0.45) +
                (Double(totalFocusMinutes) / 300.0 * 0.35) +
                (Double(completedTasksCount) / 12.0 * 0.20)
            )

            return StudyHeroData(
                mode: .rhythm,
                title: isTurkish ? tr("iv_rhythm_personal") : "Your rhythm is becoming personal",
                subtitle: isTurkish
                    ? tr("iv_one_more_focus")
                    : "One more focus session will sharpen your study pattern.",
                primaryValue: "\(Int(rhythmScore * 100))",
                primaryLabel: isTurkish ? "ritim" : "rhythm",
                chip1: isTurkish ? tr("ch_streak_days_n", streakCount) : "\(streakCount) days",
                chip2: bestDayLabel,
                chip3: averageFocusMinutes > 0 ? minutesText(averageFocusMinutes) : (isTurkish ? tr("iv_start_short") : "Start small"),
                accent: .green,
                actionTitle: isTurkish ? tr("iv_start_focus") : "Start Focus",
                action: .openFocus
            )
        }

        return StudyHeroData(
            mode: .empty,
            title: isTurkish ? "Insights seni bekliyor" : "Insights is waiting",
            subtitle: isTurkish
                ? tr("iv_space_comes_alive")
                : "A task, a focus session, or an exam will bring this space to life.",
            primaryValue: "0",
            primaryLabel: isTurkish ? tr("iv_live_insight") : "live insights",
            chip1: isTurkish ? tr("hv_add_task") : "Add task",
            chip2: isTurkish ? tr("tv_start_focus") : "Start focus",
            chip3: isTurkish ? tr("iv_add_exam") : "Add exam",
            accent: .accentColor,
            actionTitle: isTurkish ? tr("hd_open_tasks") : "Open Tasks",
            action: .openTasks
        )
    }

    var weeklyMomentum: WeeklyMomentumData {
        let values = weeklyCompletedCounts
        let highlight = values.enumerated().max(by: { $0.element < $1.element })?.offset

        let completionText = isTurkish
            ? tr("iv_completed_tasks", completedTasksCount)
            : "\(completedTasksCount) completed tasks"

        let focusText = isTurkish
            ? "\(weeklyFocusMinutesLast7Days) dk odak"
            : "\(weeklyFocusMinutesLast7Days) min focus"

        let streakText = isTurkish
            ? tr("oc_day_streak", streakCount)
            : "\(streakCount) day streak"

        let summary: String
        if let highlight {
            summary = isTurkish
                ? tr("iv_stronger_day", dayLabels[highlight])
                : "\(dayLabels[highlight]) looks like your strongest day."
        } else {
            summary = isTurkish
                ? tr("iv_no_rhythm_data")
                : "No rhythm data yet this week."
        }

        return WeeklyMomentumData(
            title: isTurkish ? tr("iv_weekly_momentum") : "Weekly Momentum",
            subtitle: isTurkish ? tr("iv_see_rhythm_progress") : "See your rhythm and progress",
            labels: dayLabels,
            values: values,
            highlightIndex: highlight,
            summaryText: summary,
            completionText: completionText,
            focusText: focusText,
            streakText: streakText
        )
    }

    var identityProfile: InsightsIdentityData {
        let levelBase = max(1, (streakCount / 3) + (totalFocusMinutes / 180) + 1)
        let level = min(levelBase, 12)

        let title: String
        let subtitle: String
        let accent: Color
        let traits: [String]

        if totalFocusMinutes >= 180 {
            title = "Deep Worker"
            subtitle = isTurkish
                ? tr("iv_deep_growing")
                : "You are getting stronger with long focus blocks."
            accent = .blue
            traits = isTurkish
                ? [tr("iv_focused"), tr("iv_deep_work"), "Ritimli"]
                : ["Focused", "Deep work", "Rhythmic"]
        } else if streakCount >= 4 {
            title = "Consistency Builder"
            subtitle = isTurkish
                ? tr("iv_steady_identity")
                : "Your consistency identity is taking shape."
            accent = .green
            traits = isTurkish
                ? [tr("iv_steady"), tr("iv_reliable"), tr("iv_progressing")]
                : ["Consistent", "Reliable", "Growing"]
        } else if isEveningProductive {
            title = "Night Finisher"
            subtitle = isTurkish
                ? tr("iv_evening_better")
                : "You seem to perform better in the evening."
            accent = .purple
            traits = isTurkish
                ? [tr("iv_evening_flow"), "Sessiz tempo", "Toparlayan"]
                : ["Evening flow", "Quiet pace", "Finisher"]
        } else {
            title = "Momentum Starter"
            subtitle = isTurkish
                ? tr("iv_small_starts")
                : "You build momentum through small starts."
            accent = .orange
            traits = isTurkish
                ? [tr("oc_start"), "Esnek", "Potansiyel"]
                : ["Starting", "Flexible", "Potential"]
        }

        let progressSeed = min(
            1.0,
            (Double(streakCount) / 7.0 * 0.45) +
            (Double(totalFocusMinutes) / 300.0 * 0.35) +
            (Double(completedTasksCount) / 12.0 * 0.20)
        )

        return InsightsIdentityData(
            title: title,
            subtitle: subtitle,
            level: level,
            progress: progressSeed,
            progressText: isTurkish
                ? "Sonraki seviyeye %\(Int(progressSeed * 100))"
                : "\(Int(progressSeed * 100))% to next level",
            traits: Array(traits.prefix(3)),
            accent: accent
        )
    }

    var achievementBadges: [InsightsBadgeData] {
        allAchievementBadges
            .filter { $0.isUnlocked || (($0.progress ?? 0) > 0) }
            .sorted {
                let lhs = $0.progress ?? ($0.isUnlocked ? 1 : 0)
                let rhs = $1.progress ?? ($1.isUnlocked ? 1 : 0)
                return lhs > rhs
            }
            .prefix(6)
            .map { $0 }
    }

    var allAchievementBadges: [InsightsBadgeData] {
        [
            // MARK: - Focus Path

            InsightsBadgeData(
                title: isTurkish ? tr("iv_first_focus") : "First Focus",
                subtitle: isTurkish ? tr("iv_first_focus_sub") : "Your first focus session",
                icon: "timer",
                isUnlocked: totalFocusSessionsCount >= 1,
                progress: min(Double(totalFocusSessionsCount) / 1.0, 1),
                accent: .blue
            ),
            InsightsBadgeData(
                title: "Deep Builder",
                subtitle: isTurkish ? "120 dk focus" : "120 min focus",
                icon: "timer",
                isUnlocked: totalFocusMinutes >= 120,
                progress: min(Double(totalFocusMinutes) / 120.0, 1),
                accent: .blue
            ),
            InsightsBadgeData(
                title: "Focus 300",
                subtitle: isTurkish ? "300 dk toplam odak" : "300 total focus minutes",
                icon: "brain.head.profile",
                isUnlocked: totalFocusMinutes >= 300,
                progress: min(Double(totalFocusMinutes) / 300.0, 1),
                accent: .blue
            ),
            InsightsBadgeData(
                title: "Focus 600",
                subtitle: isTurkish ? "600 dk toplam odak" : "600 total focus minutes",
                icon: "bolt.circle.fill",
                isUnlocked: totalFocusMinutes >= 600,
                progress: min(Double(totalFocusMinutes) / 600.0, 1),
                accent: .blue
            ),
            InsightsBadgeData(
                title: "Focus Master",
                subtitle: isTurkish ? "10 focus oturumu" : "10 focus sessions",
                icon: "target",
                isUnlocked: totalFocusSessionsCount >= 10,
                progress: min(Double(totalFocusSessionsCount) / 10.0, 1),
                accent: .blue
            ),
            InsightsBadgeData(
                title: "Flow State",
                subtitle: isTurkish ? "25 focus oturumu" : "25 focus sessions",
                icon: "waveform.path.ecg",
                isUnlocked: totalFocusSessionsCount >= 25,
                progress: min(Double(totalFocusSessionsCount) / 25.0, 1),
                accent: .blue
            ),
            InsightsBadgeData(
                title: "Ultra Focus",
                subtitle: isTurkish ? "1500 dk toplam odak" : "1500 total focus minutes",
                icon: "sparkles",
                isUnlocked: totalFocusMinutes >= 1500,
                progress: min(Double(totalFocusMinutes) / 1500.0, 1),
                accent: .blue
            ),

            // MARK: - Streak Path

            InsightsBadgeData(
                title: isTurkish ? tr("iv_3day_streak") : "3 Day Streak",
                subtitle: isTurkish ? tr("iv_3day_sub") : "Consistency has started",
                icon: "flame.fill",
                isUnlocked: streakCount >= 3,
                progress: min(Double(streakCount) / 3.0, 1),
                accent: .orange
            ),
            InsightsBadgeData(
                title: isTurkish ? tr("iv_7day_streak") : "7 Day Streak",
                subtitle: isTurkish ? tr("iv_7day_sub") : "A full week of consistency",
                icon: "flame.circle.fill",
                isUnlocked: streakCount >= 7,
                progress: min(Double(streakCount) / 7.0, 1),
                accent: .orange
            ),
            InsightsBadgeData(
                title: isTurkish ? tr("iv_14day_streak") : "14 Day Streak",
                subtitle: isTurkish ? tr("iv_14day_sub") : "Two weeks of rhythm",
                icon: "flame.circle.fill",
                isUnlocked: streakCount >= 14,
                progress: min(Double(streakCount) / 14.0, 1),
                accent: .orange
            ),
            InsightsBadgeData(
                title: isTurkish ? tr("iv_30day_streak") : "30 Day Streak",
                subtitle: isTurkish ? tr("iv_30day_sub") : "A lasting habit",
                icon: "flame.circle.fill",
                isUnlocked: streakCount >= 30,
                progress: min(Double(streakCount) / 30.0, 1),
                accent: .orange
            ),

            // MARK: - Task Path

            InsightsBadgeData(
                title: isTurkish ? tr("iv_first_task") : "First Task",
                subtitle: isTurkish ? tr("iv_first_task_sub") : "Complete your first task",
                icon: "checkmark.circle.fill",
                isUnlocked: completedTasksCount >= 1,
                progress: min(Double(completedTasksCount) / 1.0, 1),
                accent: .green
            ),
            InsightsBadgeData(
                title: "Weekly Warrior",
                subtitle: isTurkish ? tr("iv_7task") : "Complete 7 tasks",
                icon: "bolt.fill",
                isUnlocked: completedTasksCount >= 7,
                progress: min(Double(completedTasksCount) / 7.0, 1),
                accent: .green
            ),
            InsightsBadgeData(
                title: "Task Finisher",
                subtitle: isTurkish ? tr("iv_10task") : "Complete 10 tasks",
                icon: "checkmark.seal.fill",
                isUnlocked: completedTasksCount >= 10,
                progress: min(Double(completedTasksCount) / 10.0, 1),
                accent: .green
            ),
            InsightsBadgeData(
                title: "Task Master",
                subtitle: isTurkish ? tr("iv_50task") : "Complete 50 tasks",
                icon: "checkmark.seal.fill",
                isUnlocked: completedTasksCount >= 50,
                progress: min(Double(completedTasksCount) / 50.0, 1),
                accent: .green
            ),
            InsightsBadgeData(
                title: "Task Legend",
                subtitle: isTurkish ? tr("iv_100task") : "Complete 100 tasks",
                icon: "crown.fill",
                isUnlocked: completedTasksCount >= 100,
                progress: min(Double(completedTasksCount) / 100.0, 1),
                accent: .green
            ),

            // MARK: - Exam Path

            InsightsBadgeData(
                title: "Exam Ready",
                subtitle: isTurkish ? tr("iv_prep_balanced") : "Your readiness looks balanced",
                icon: "graduationcap.fill",
                isUnlocked: !upcomingExams.isEmpty && averageExamReadiness >= 0.60,
                progress: !upcomingExams.isEmpty ? min(averageExamReadiness / 0.60, 1) : 0,
                accent: .pink
            ),
            InsightsBadgeData(
                title: "Exam Sprint",
                subtitle: isTurkish ? tr("iv_strengthen_prep") : "Strengthen exam readiness",
                icon: "graduationcap.circle.fill",
                isUnlocked: !upcomingExams.isEmpty && averageExamReadiness >= 0.75,
                progress: !upcomingExams.isEmpty ? min(averageExamReadiness / 0.75, 1) : 0,
                accent: .pink
            ),
            InsightsBadgeData(
                title: "Exam Crusher",
                subtitle: isTurkish ? tr("iv_prep_90") : "Reach 90% exam readiness",
                icon: "star.circle.fill",
                isUnlocked: !upcomingExams.isEmpty && averageExamReadiness >= 0.90,
                progress: !upcomingExams.isEmpty ? min(averageExamReadiness / 0.90, 1) : 0,
                accent: .pink
            ),

            // MARK: - Special Path

            InsightsBadgeData(
                title: "Night Mode",
                subtitle: isTurkish ? tr("iv_build_evening") : "Build an evening rhythm",
                icon: "moon.stars.fill",
                isUnlocked: isEveningProductive && totalFocusSessionsCount >= 3,
                progress: min(Double(totalFocusSessionsCount) / 3.0, 1),
                accent: .purple
            ),
            InsightsBadgeData(
                title: "Comeback",
                subtitle: isTurkish ? tr("iv_restart_streak") : "Restart your rhythm",
                icon: "arrow.clockwise.circle.fill",
                isUnlocked: streakCount >= 1 && completedTasksCount >= 3,
                progress: min((Double(streakCount) / 1.0 + Double(completedTasksCount) / 3.0) / 2.0, 1),
                accent: .purple
            )
        ]
    }
    
    

    var miniStatsV2: [InsightsMiniStatData] {
        [
            InsightsMiniStatData(
                value: "\(streakCount)",
                label: isTurkish ? "seri" : "streak",
                hint: "",
                accent: .orange
            ),
            InsightsMiniStatData(
                value: isTurkish ? "\(totalFocusMinutes) dk" : "\(totalFocusMinutes)m",
                label: isTurkish ? "focus" : "focus",
                hint: "",
                accent: .blue
            ),
            InsightsMiniStatData(
                value: "\(completedTasksCount)",
                label: isTurkish ? "tamamlanan" : "done",
                hint: "",
                accent: .green
            ),
            InsightsMiniStatData(
                value: bestDayLabel,
                label: isTurkish ? tr("iv_best_day") : "best day",
                hint: "",
                accent: .purple
            )
        ]
    }
    var identityCompactStats: [InsightsMiniStatData] {
        miniStatsV2
    }

    var streakValueForUI: Int {
        streakCount
    }

    var premiumPreview: InsightsPremiumPreviewData {
        InsightsPremiumPreviewData(
            title: isTurkish
                ? tr("iv_unlock_deeper")
                : "Unlock deeper study patterns",
            subtitle: isTurkish
                ? tr("iv_premium_why")
                : "With Premium, you do not just see your rhythm — you understand why it forms.",
            bullets: isTurkish
                ? [
                    tr("iv_best_hours_est"),
                    tr("iv_advanced_coach"),
                    tr("iv_longterm_identity")
                ]
                : [
                    "Best study window prediction",
                    "More advanced AI coaching",
                    "Long-term identity and growth view"
                ],
            buttonTitle: isTurkish ? tr("iv_see_premium") : "See Premium"
        )
    }
   var deepInsightsHero: DeepInsightsHeroData {
        DeepInsightsHeroData(
            title: "Deep Insights",
            subtitle: "Your rhythm, patterns, and next moves",
            primaryValue: bestStudyHourRangeText,
            primaryLabel: isTurkish ? "en iyi zaman" : "best window",
            chip1: isTurkish ? tr("oc_day_streak", streakCount) : "\(streakCount) day streak",
            chip2: isTurkish ? "\(completedTasksCount) tamamlanan" : "\(completedTasksCount) done"
        )
    }

    var deepBestStudyWindow: BestStudyWindowData {
        BestStudyWindowData(
            timeRange: bestStudyHourRangeText,
            confidenceText: isTurkish ? tr("iv_confidence_up") : "Confidence rising",
            summary: isTurkish
                ? tr("iv_window_better")
                : "You tend to focus longer and complete more tasks in this window.",
            accent: .purple
        )
    }
    
    var plusCoachCard: InsightsPlusCoachCardData {
        InsightsPlusCoachCardData(
            title: isTurkish ? tr("iv_pick_one_clear") : "Choose one clear task today",
            subtitle: isTurkish
                ? tr("iv_after_block")
                : "Your completion chance rises after a short focus block.",
            hint: isTurkish ? tr("iv_high_confidence") : "high confidence",
            symbol: "brain.head.profile",
            tint: .cyan,
            actionTitle: isTurkish ? tr("hd_open_tasks") : "Open Tasks",
            action: .openTasks
        )
    }

    var plusStudyWindowCard: InsightsPlusStudyWindowCardData {
        InsightsPlusStudyWindowCardData(
            title: "Best Study Window",
            timeText: bestStudyHourRangeText,
            confidenceText: isTurkish ? tr("iv_confidence_up") : "Confidence rising",
            summary: isTurkish
                ? tr("iv_window_better_2")
                : "You focus longer and complete more tasks in this window.",
            symbol: "clock.fill",
            tint: .purple,
            actionTitle: isTurkish ? tr("iv_start_focus") : "Start Focus",
            action: .openFocus
        )
    }

    var plusWeeklySignalCard: InsightsPlusWeeklySignalCardData {
        let raw = weeklyCompletedCounts.map { value -> CGFloat in
            let normalized = min(max(CGFloat(value) / 4.0, 0.18), 1.0)
            return normalized
        }

        let strongestIndex = weeklyCompletedCounts.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
        let weakestIndex = weeklyCompletedCounts.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0

        return InsightsPlusWeeklySignalCardData(
            title: "Weekly Signal",
            strongestDay: dayLabels[strongestIndex],
            weakestDay: dayLabels[weakestIndex],
            trendText: isTurkish ? tr("iv_rhythm_recovering") : "Your rhythm is stabilizing",
            values: raw,
            highlightIndex: strongestIndex,
            tint: .blue,
            actionTitle: isTurkish ? tr("hd_open_week") : "Open Week",
            action: .openWeek
        )
    }

    var deepWeeklyReview: WeeklyDeepReviewData {
        let weakest = weeklyCompletedCounts.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0

        return WeeklyDeepReviewData(
            strongestDay: bestDayLabel,
            weakestDay: dayLabels[weakest],
            deltaText: isTurkish
                ? tr("iv_vs_last_week")
                : "Rhythm is improving compared to last week.",
            recommendation: isTurkish
                ? tr("iv_weak_day")
                : "Adding a short focus block to your weakest day may balance the week."
        )
    }

    var deepIdentityEvolution: IdentityEvolutionData {
        IdentityEvolutionData(
            currentIdentity: identityProfile.title,
            nextIdentity: streakCount >= 4 ? "Deep Worker" : "Consistency Builder",
            progressText: isTurkish
                ? tr("iv_next_identity")
                : "A few more active days will move you toward your next identity.",
            progress: min(1.0, identityProfile.progress)
        )
    }

    var deepExamRows: [ExamReadinessProRow] {
        if upcomingExams.isEmpty {
            return [
                ExamReadinessProRow(
                    title: isTurkish ? tr("iv_no_upcoming_exam") : "No upcoming exams",
                    readinessText: "—",
                    progress: 0,
                    riskText: isTurkish ? tr("iv_exam_appears") : "It appears here when you add an exam.",
                    accent: .gray
                )
            ]
        }

        return upcomingExams.prefix(3).map { exam in
            let progress = examReadinessProgress(for: exam)
            return ExamReadinessProRow(
                title: exam.courseName.isEmpty ? exam.title : exam.courseName,
                readinessText: "\(Int(progress * 100))%",
                progress: progress,
                riskText: countdownText(for: exam),
                accent: progress < 0.4 ? .red : (progress < 0.7 ? .orange : .green)
            )
        }
    }

    var deepPatternAlerts: [PatternAlertData] {
        var items: [PatternAlertData] = []

        if isEveningProductive {
            items.append(
                PatternAlertData(
                    title: isTurkish ? tr("iv_evening_rising") : "Evening rhythm is rising",
                    message: isTurkish
                        ? tr("iv_evening_perf")
                        : "You seem to perform better during evening hours.",
                    icon: "moon.stars.fill",
                    tint: .purple
                )
            )
        }

        if streakCount == 0 {
            items.append(
                PatternAlertData(
                    title: isTurkish ? tr("iv_streak_not_started") : "Streak has not started yet",
                    message: isTurkish
                        ? tr("iv_short_starts_rhythm")
                        : "Even a small task can start momentum.",
                    icon: "flame.fill",
                    tint: .orange
                )
            )
        }

        if completedTasksCount >= 2 {
            items.append(
                PatternAlertData(
                    title: isTurkish ? "Tamamlama ritmi var" : "Completion rhythm detected",
                    message: isTurkish
                        ? tr("iv_completion_forming")
                        : "A task completion pattern is starting to form.",
                    icon: "checkmark.circle.fill",
                    tint: .green
                )
            )
        }

        if items.isEmpty {
            items.append(
                PatternAlertData(
                    title: isTurkish ? "Daha fazla veri bekleniyor" : "Waiting for more data",
                    message: isTurkish
                        ? tr("iv_more_days")
                        : "A few more days of usage will unlock clearer alerts.",
                    icon: "sparkles",
                    tint: .blue
                )
            )
        }

        return items
    }
    private var courseMinutesMap: [(course: String, minutes: Int)] {
        let grouped = Dictionary(grouping: tasks.filter { !$0.courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            $0.courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let rows = grouped.map { key, value in
            let minutes = value.compactMap(\.workoutDurationMinutes).reduce(0, +)
            return (course: key, minutes: minutes)
        }

        return rows
            .filter { $0.minutes > 0 }
            .sorted { $0.minutes > $1.minutes }
    }

    private var strongestCourseName: String {
        courseMinutesMap.first?.course ?? (isTurkish ? tr("iv_not_clear") : "Not clear yet")
    }

    private var neglectedCourseName: String {
        courseMinutesMap.last?.course ?? (isTurkish ? tr("iv_not_clear") : "Not clear yet")
    }

    private var recommendedNextCourseName: String {
        if let examCourse = upcomingExams.first?.courseName.trimmingCharacters(in: .whitespacesAndNewlines),
           !examCourse.isEmpty {
            return examCourse
        }
        return neglectedCourseName
    }
    private func courseBreakdownRows() -> [StudyWindowCourseBreakdownRow] {
        let rows = courseMinutesMap
        let maxMinutes = max(rows.map(\.minutes).max() ?? 1, 1)

        return rows.prefix(5).enumerated().map { index, item in
            let progress = Double(item.minutes) / Double(maxMinutes)

            let accent: Color
            switch index {
            case 0: accent = .purple
            case 1: accent = .blue
            case 2: accent = .green
            case 3: accent = .orange
            default: accent = .pink
            }

            let focusQualityText: String
            switch progress {
            case 0.75...:
                focusQualityText = isTurkish ? tr("iv_high_intensity") : "high intensity"
            case 0.40..<0.75:
                focusQualityText = isTurkish ? "dengeli tempo" : "balanced tempo"
            default:
                focusQualityText = isTurkish ? "geri planda" : "lighter attention"
            }

            return StudyWindowCourseBreakdownRow(
                courseName: item.course,
                minutes: item.minutes,
                progress: progress,
                accent: accent,
                focusQualityText: focusQualityText
            )
        }
    }
    var studyWindowDetailData: InsightsStudyWindowDetailData {
        let strongest = strongestCourseName
        let neglected = neglectedCourseName
        let recommended = recommendedNextCourseName

        let reason: String
        if strongest == recommended {
            reason = isTurkish
                ? tr("iv_best_course", recommended)
                : "\(recommended) currently matches your rhythm the best."
        } else {
            reason = isTurkish
                ? tr("iv_balance_course", recommended)
                : "\(recommended) is receiving less attention and looks like the best next balancing move."
        }

        return InsightsStudyWindowDetailData(
            timeRangeText: bestStudyHourRangeText,
            confidenceText: isTurkish ? tr("iv_confidence_up") : "Confidence rising",
            summaryText: isTurkish
                ? tr("iv_window_better_2")
                : "You focus longer and complete more tasks in this window.",
            strongestCourse: strongest,
            neglectedCourse: neglected,
            recommendedCourse: recommended,
            recommendationReason: reason,
            rows: courseBreakdownRows()
        )
    }
    private var bestCompletedCourseName: String {
        let grouped = Dictionary(grouping: completedTasks.filter {
            !$0.courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) {
            $0.courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let best = grouped
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
            .first?.0

        return best ?? (isTurkish ? tr("iv_not_clear") : "Not clear yet")
    }

    private var activeTaskBacklogCount: Int {
        tasks.filter { !$0.isDone }.count
    }
    var coachDetailData: InsightsCoachDetailData {
        let confidence: Int
        if completedTasksCount >= 3 || totalFocusMinutes >= 60 {
            confidence = 5
        } else if completedTasksCount >= 2 || totalFocusMinutes >= 30 {
            confidence = 4
        } else if completedTasksCount >= 1 || totalFocusMinutes >= 15 {
            confidence = 3
        } else if activeTaskBacklogCount > 0 {
            confidence = 2
        } else {
            confidence = 1
        }

        let directionTitle: String
        let directionSubtitle: String
        let strongestSignal: String
        let blockingSignal: String
        let reason: String

        if activeTaskBacklogCount >= 5 {
            directionTitle = isTurkish ? tr("iv_start_clear_one") : "Start small, clear one task"
            directionSubtitle = isTurkish
                ? tr("iv_one_vs_block")
                : "Choosing one clear task may be more effective than a long block today."
            strongestSignal = isTurkish ? tr("iv_task_density") : "Visible task backlog"
            blockingSignal = isTurkish ? tr("iv_load_suppresses") : "Backlog is compressing rhythm"
            reason = isTurkish
                ? tr("iv_clear_then_focus")
                : "Clearing one task before opening a focus block may be your best flow today."
        } else if totalFocusMinutes == 0 && activeTaskBacklogCount > 0 {
            directionTitle = isTurkish ? tr("iv_open_first_block") : "Open your first short focus block"
            directionSubtitle = isTurkish
                ? tr("iv_2025_enough")
                : "A 20–25 minute block is enough to start momentum today."
            strongestSignal = isTurkish ? tr("iv_completable_load") : "Workload is actionable"
            blockingSignal = isTurkish ? tr("iv_focus_not_started") : "Focus rhythm has not started"
            reason = isTurkish
                ? tr("iv_manageable_count")
                : "Your workload looks manageable; building a short focus rhythm first makes sense."
        } else if !upcomingExams.isEmpty {
            directionTitle = isTurkish ? tr("iv_return_exam_course") : "Return to the nearest exam course"
            directionSubtitle = isTurkish
                ? tr("iv_nearest_exam_course")
                : "The course tied to your nearest exam looks like the most logical direction today."
            strongestSignal = isTurkish ? tr("iv_exam_pressure") : "Exam pressure is rising"
            blockingSignal = isTurkish ? tr("iv_distribution") : "Balance may drift"
            reason = isTurkish
                ? tr("iv_exam_strongest")
                : "Your nearest exam is currently the strongest signal for deciding your study direction."
        } else {
            directionTitle = isTurkish ? tr("iv_pick_one_clear") : "Choose one clear task today"
            directionSubtitle = isTurkish
                ? tr("iv_after_block")
                : "Your completion chance rises after a short focus block."
            strongestSignal = bestCompletedCourseName
            blockingSignal = activeTaskBacklogCount > 0
                ? (isTurkish ? tr("iv_open_tasks_n", activeTaskBacklogCount) : "\(activeTaskBacklogCount) open tasks")
                : (isTurkish ? tr("iv_rhythm_forming") : "Rhythm is still forming")
            reason = isTurkish
                ? tr("iv_short_starts_model")
                : "Short starts currently seem to fit your rhythm best."
        }

        let actions: [InsightsCoachActionRow] = [
            InsightsCoachActionRow(
                title: isTurkish ? tr("iv_short_cleanup") : "Short task cleanup",
                subtitle: isTurkish ? tr("iv_finish_one_open") : "Finish one open task and reduce pressure",
                intensity: isTurkish ? tr("iv_short_word") : "Short",
                symbol: "checkmark.circle.fill",
                tint: .green,
                action: .openTasks
            ),
            InsightsCoachActionRow(
                title: isTurkish ? tr("iv_open_focus_block") : "Open a focus block",
                subtitle: isTurkish ? tr("iv_2025_to_start") : "20–25 minutes is enough to start rhythm",
                intensity: isTurkish ? "Orta" : "Medium",
                symbol: "timer",
                tint: .purple,
                action: .openFocus
            ),
            InsightsCoachActionRow(
                title: isTurkish ? tr("iv_align_week") : "Align the week",
                subtitle: isTurkish ? tr("iv_see_distribution") : "See distribution and upcoming work together",
                intensity: isTurkish ? "Derin" : "Deep",
                symbol: "calendar",
                tint: .blue,
                action: .openWeek
            )
        ]

        return InsightsCoachDetailData(
            headline: directionTitle,
            summary: directionSubtitle,
            confidenceText: isTurkish ? tr("iv_high_confidence") : "high confidence",
            confidenceLevel: confidence,
            todayDirectionTitle: directionTitle,
            todayDirectionSubtitle: directionSubtitle,
            strongestSignal: strongestSignal,
            blockingSignal: blockingSignal,
            recommendationReason: reason,
            actionRows: actions
        )
    }
    var weeklySignalDetailData: InsightsWeeklySignalDetailData {
        let labels = dayLabels
        let maxCompleted = max(weeklyCompletedCounts.max() ?? 1, 1)
        let focusByDay: [Int] = (0..<7).map { weekday in
            focusSessions
                .filter {
                    let mapped = (calendar.component(.weekday, from: $0.startedAt) + 5) % 7
                    return mapped == weekday
                }
                .reduce(0) { $0 + ($1.completedSeconds / 60) }
        }

        let strongestIndex = weeklyCompletedCounts.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
        let weakestIndex = weeklyCompletedCounts.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0

        let details: [WeeklySignalDayDetail] = (0..<7).map { index in
            let value = CGFloat(max(CGFloat(weeklyCompletedCounts[index]) / CGFloat(maxCompleted), 0.18))
            return WeeklySignalDayDetail(
                label: labels[index],
                completedCount: weeklyCompletedCounts[index],
                focusMinutes: focusByDay[index],
                value: value,
                isHighlight: index == strongestIndex
            )
        }

        let totalCompletions = weeklyCompletedCounts.reduce(0, +)
        let totalFocus = focusByDay.reduce(0, +)

        return InsightsWeeklySignalDetailData(
            title: isTurkish ? "Weekly Signal" : "Weekly Signal",
            subtitle: isTurkish ? tr("iv_weekly_analysis") : "Weekly rhythm analysis",
            strongestDay: labels[strongestIndex],
            weakestDay: labels[weakestIndex],
            trendSummary: isTurkish ? tr("iv_rhythm_recovering") : "Your rhythm is stabilizing",
            completionTotalText: isTurkish ? tr("rel_task_count", totalCompletions) : "\(totalCompletions) tasks",
            focusTotalText: isTurkish ? "\(totalFocus) dk focus" : "\(totalFocus) min focus",
            streakText: isTurkish ? tr("oc_day_streak", streakCount) : "\(streakCount) day streak",
            days: details
        )
    }
}
