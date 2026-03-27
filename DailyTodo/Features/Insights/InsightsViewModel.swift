//
//  InsightsViewModel.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import Foundation

struct InsightsViewModel {
    let tasks: [DTTaskItem]
    let focusSessions: [FocusSessionRecord]
    let events: [EventItem]
    let userID: String?
    let localeIdentifier: String

    private let calendar = Calendar.current

    private var dayLabels: [String] {
        [
            tr("weekday_mon_short"),
            tr("weekday_tue_short"),
            tr("weekday_wed_short"),
            tr("weekday_thu_short"),
            tr("weekday_fri_short"),
            tr("weekday_sat_short"),
            tr("weekday_sun_short")
        ]
    }

    private var lastSuggestionKey: String {
        "lastSmartSuggestionIndex_\(userID ?? "guest")"
    }

    private var completedTasks: [DTTaskItem] { tasks.filter(\.isDone) }
    private var activeTasks: [DTTaskItem] { tasks.filter { !$0.isDone } }

    private var completedTodayTasks: [DTTaskItem] {
        completedTasks.filter {
            if let completedAt = $0.completedAt { return calendar.isDateInToday(completedAt) }
            if let dueDate = $0.dueDate { return calendar.isDateInToday(dueDate) }
            return false
        }
    }

    private var todayFocusSessions: [FocusSessionRecord] {
        focusSessions.filter { calendar.isDateInToday($0.startedAt) }
    }

    private var todayFocusMinutes: Int {
        todayFocusSessions.reduce(0) { $0 + ($1.completedSeconds / 60) }
    }

    private var longestFocusMinutes: Int {
        todayFocusSessions.map { $0.completedSeconds / 60 }.max() ?? 0
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

    private var weeklyStudyMinutes: [Int] {
        (0..<7).map { weekday in
            events.filter { $0.weekday == weekday }.reduce(0) { $0 + $1.durationMinute }
        }
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
            if hasCompletion { streak += 1 }
            else { if offset == 0 { continue }; break }
        }
        return streak
    }

    private var overviewProgress: Double {
        min(1, Double(completedTasks.count) / Double(max(tasks.count, 1)))
    }

    private func minutesText(_ minutes: Int) -> String {
        tr("insights_minutes_format", minutes)
    }

    private func hoursMinutesText(_ total: Int) -> String {
        let h = total / 60
        let m = total % 60
        if h > 0 {
            return tr("insights_hours_minutes_format", h, m)
        }
        return minutesText(m)
    }

    var dailyBoost: DailyBoostData {
        if !activeTasks.isEmpty {
            return .init(
                title: tr("insights_daily_boost_title"),
                message: tr("insights_daily_boost_tasks_message"),
                buttonTitle: tr("insights_action_open_tasks")
            )
        }
        if todayFocusMinutes < 20 {
            return .init(
                title: tr("insights_daily_boost_great_job"),
                message: tr("insights_daily_boost_focus_message"),
                buttonTitle: tr("insights_action_new_focus")
            )
        }
        return .init(
            title: tr("insights_daily_boost_nice_flow"),
            message: tr("insights_daily_boost_nice_flow_message"),
            buttonTitle: nil
        )
    }

    var overview: OverviewData {
        let progress = overviewProgress
        let status: String
        switch progress {
        case 0..<0.2: status = tr("insights_overview_status_start")
        case 0.2..<0.5: status = tr("insights_overview_status_momentum")
        case 0.5..<0.85: status = tr("insights_overview_status_solid")
        default: status = tr("insights_overview_status_great")
        }
        return .init(
            progress: progress,
            progressText: "%\(Int(progress * 100))",
            statusText: status,
            streakText: tr("insights_overview_streak_format", streakCount),
            completedText: tr("insights_overview_completed_format", completedTasks.count),
            subtitle: tr("insights_overview_subtitle")
        )
    }

    var weeklyProgress: WeeklyProgressData {
        let values = weeklyCompletedCounts
        let highlight = values.enumerated().max(by: { $0.element < $1.element })?.offset
        let summary = highlight.map {
            tr("insights_weekly_best_day_format", dayLabels[$0])
        } ?? tr("insights_no_data_yet")
        return .init(
            values: values,
            labels: dayLabels,
            highlightIndex: highlight,
            summaryText: summary
        )
    }

    var heatmap: StudyHeatmapData {
        let levels: [Int] = (0..<28).map { i in
            let value = weeklyCompletedCounts[i % 7]
            switch value {
            case 0: return 0
            case 1: return 1
            case 2...3: return 2
            default: return 3
            }
        }
        let cells = levels.enumerated().map { index, level in
            InsightsHeatmapCell(level: level, date: nil, isSelected: index == 26)
        }
        return .init(
            cells: cells,
            title: tr("insights_heatmap_title"),
            subtitle: tr("insights_heatmap_subtitle"),
            selectedDayText: tr("insights_heatmap_selected_day")
        )
    }

    var focusInsights: FocusInsightsData {
        return .init(
            streakTitle: tr("insights_focus_streak_format", max(streakCount, 3)),
            streakSubtitle: streakCount > 0
                ? tr("insights_focus_streak_subtitle_active")
                : tr("insights_focus_streak_subtitle_inactive"),
            todayFocusMinutesText: minutesText(todayFocusMinutes),
            todaySessionsText: tr("insights_focus_sessions_format", todayFocusSessions.count),
            longestSessionText: tr("insights_focus_longest_format", minutesText(longestFocusMinutes))
        )
    }

    var productivityScore: ScoreCardData {
        let raw = min(100, Int((Double(completedTasks.count) * 18) + (Double(todayFocusMinutes) * 0.35)))
        let subtitle: String
        switch raw {
        case 0..<30: subtitle = tr("insights_productivity_subtitle_low")
        case 30..<60: subtitle = tr("insights_productivity_subtitle_mid")
        case 60..<80: subtitle = tr("insights_productivity_subtitle_good")
        default: subtitle = tr("insights_productivity_subtitle_great")
        }
        return .init(
            title: tr("insights_productivity_title"),
            valueText: "\(raw)/100",
            subtitle: subtitle,
            progress: Double(raw) / 100
        )
    }

    var consistencyScore: ScoreCardData {
        let activeDays = weeklyCompletedCounts.filter { $0 > 0 }.count
        let raw = min(100, activeDays * 14)
        let subtitle = raw < 30
            ? tr("insights_consistency_subtitle_low")
            : tr("insights_consistency_subtitle_good")
        return .init(
            title: tr("insights_consistency_title"),
            valueText: "%\(raw)",
            subtitle: subtitle,
            progress: Double(raw) / 100
        )
    }

    var mostBusyDay: MostBusyDayData {
        guard let maxIndex = weeklyStudyMinutes.enumerated().max(by: { $0.element < $1.element })?.offset else {
            return .init(
                title: tr("insights_busy_day_title"),
                dayText: "-",
                durationText: minutesText(0),
                subtitle: tr("insights_busy_day_subtitle")
            )
        }
        return .init(
            title: tr("insights_busy_day_title"),
            dayText: dayLabels[maxIndex],
            durationText: hoursMinutesText(weeklyStudyMinutes[maxIndex]),
            subtitle: tr("insights_busy_day_subtitle")
        )
    }

    private var activeTasksCount: Int { tasks.filter { !$0.isDone }.count }
    private var completedTasksCount: Int { tasks.filter { $0.isDone }.count }
    private var totalFocusSessionsCount: Int { focusSessions.count }
    private var totalFocusMinutes: Int {
        focusSessions.reduce(into: 0) { $0 + $1.completedSeconds / 60 }
    }

    private var bestDayLabel: String {
        if let index = weeklyProgress.highlightIndex,
           weeklyProgress.labels.indices.contains(index) {
            return weeklyProgress.labels[index]
        }
        return tr("insights_this_week")
    }

    private var isEveningProductive: Bool {
        let eveningSessions = focusSessions.filter {
            Calendar.current.component(.hour, from: $0.startedAt) >= 18
        }
        return eveningSessions.count >= max(1, focusSessions.count / 2)
    }

    private var hasTaskBacklog: Bool { activeTasksCount >= 5 }
    private var hasNoFocusHabit: Bool { totalFocusSessionsCount == 0 }
    private var hasStrongMomentum: Bool { completedTasksCount >= 3 || totalFocusMinutes >= 60 }

    private func rotatedSuggestions() -> [SmartSuggestionData] {
        var suggestions: [SmartSuggestionData] = []

        if hasTaskBacklog {
            suggestions.append(.init(
                title: tr("insights_suggestion_task_title"),
                message: tr("insights_suggestion_task_message"),
                buttonTitle: tr("insights_action_open_tasks"),
                action: .openTasks
            ))
        }

        if hasNoFocusHabit && activeTasksCount > 0 {
            suggestions.append(.init(
                title: tr("insights_suggestion_focus_title"),
                message: tr("insights_suggestion_focus_message"),
                buttonTitle: tr("insights_action_start_focus"),
                action: .openFocus
            ))
        }

        if hasStrongMomentum {
            suggestions.append(.init(
                title: tr("insights_suggestion_momentum_title"),
                message: tr("insights_suggestion_momentum_message"),
                buttonTitle: tr("insights_action_open_tasks"),
                action: .openTasks
            ))
        }

        suggestions.append(.init(
            title: tr("insights_suggestion_pattern_title"),
            message: tr("insights_suggestion_pattern_message", bestDayLabel),
            buttonTitle: tr("insights_action_view_week"),
            action: .openWeek
        ))

        if isEveningProductive {
            suggestions.append(.init(
                title: tr("insights_suggestion_focus_pattern_title"),
                message: tr("insights_suggestion_focus_pattern_message"),
                buttonTitle: tr("insights_action_start_focus"),
                action: .openFocus
            ))
        }

        if totalFocusMinutes >= 90 {
            suggestions.append(.init(
                title: tr("insights_suggestion_deep_work_title"),
                message: tr("insights_suggestion_deep_work_message"),
                buttonTitle: tr("insights_action_view_week"),
                action: .openWeek
            ))
        }

        suggestions.append(.init(
            title: tr("insights_suggestion_daily_title"),
            message: tr("insights_suggestion_daily_message"),
            buttonTitle: tr("insights_action_open_tasks"),
            action: .openTasks
        ))

        return suggestions
    }

    var smartSuggestion: SmartSuggestionData {
        let suggestions = rotatedSuggestions()
        guard !suggestions.isEmpty else {
            return .init(
                title: tr("insights_suggestion_fallback_title"),
                message: tr("insights_suggestion_fallback_message"),
                buttonTitle: tr("insights_action_open_tasks"),
                action: .openTasks
            )
        }
        let todayIndex = Calendar.current.component(.day, from: Date()) % suggestions.count
        let lastIndex = UserDefaults.standard.integer(forKey: lastSuggestionKey)
        var index = todayIndex
        if suggestions.count > 1 && index == lastIndex { index = (index + 1) % suggestions.count }
        UserDefaults.standard.set(index, forKey: lastSuggestionKey)
        return suggestions[index]
    }

    var aiCoach: AICoachData {
        if totalFocusMinutes >= 60 && completedTasksCount >= 2 {
            return .init(
                title: tr("insights_ai_coach_title"),
                message: tr("insights_ai_coach_focus_message"),
                buttonTitle: tr("insights_action_start_focus"),
                action: .openFocus
            )
        }
        if let index = weeklyProgress.highlightIndex,
           weeklyProgress.labels.indices.contains(index) {
            return .init(
                title: tr("insights_ai_coach_title"),
                message: tr("insights_ai_coach_best_day_message", weeklyProgress.labels[index]),
                buttonTitle: tr("insights_action_view_week"),
                action: .openWeek
            )
        }
        return .init(
            title: tr("insights_ai_coach_title"),
            message: tr("insights_ai_coach_default_message"),
            buttonTitle: tr("insights_action_open_tasks"),
            action: .openTasks
        )
    }
}
