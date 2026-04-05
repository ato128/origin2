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
    
    private var upcomingExams: [ExamItem] {
            exams
                .filter { !$0.isCompleted && $0.examDate >= calendar.startOfDay(for: Date()) }
                .sorted { $0.examDate < $1.examDate }
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

        private var averageFocusMinutes: Int {
            guard !focusSessions.isEmpty else { return 0 }
            let total = focusSessions.reduce(0) { $0 + ($1.completedSeconds / 60) }
            return total / focusSessions.count
        }

        private var bestStudyHourRangeText: String {
            let sessionsByHour = Dictionary(grouping: focusSessions) {
                calendar.component(.hour, from: $0.startedAt)
            }

            guard let bestHour = sessionsByHour.max(by: { $0.value.count < $1.value.count })?.key else {
                return localeIdentifier.hasPrefix("tr") ? "Henüz net değil" : "Not clear yet"
            }

            switch bestHour {
            case 5..<12:
                return localeIdentifier.hasPrefix("tr") ? "Sabah" : "Morning"
            case 12..<17:
                return localeIdentifier.hasPrefix("tr") ? "Öğleden sonra" : "Afternoon"
            case 17..<22:
                return localeIdentifier.hasPrefix("tr") ? "Akşam" : "Evening"
            default:
                return localeIdentifier.hasPrefix("tr") ? "Gece" : "Night"
            }
        }

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
            let focusComponent = min(1.0, Double(relatedTasks.compactMap(\.workoutDurationMinutes).reduce(0, +)) / 240.0)

            let daysLeft = max(0, calendar.dateComponents([.day], from: Date(), to: exam.examDate).day ?? 0)
            let urgencyPenalty = daysLeft <= 2 ? 0.18 : (daysLeft <= 5 ? 0.10 : 0.0)

            return min(1, max(0, (taskComponent * 0.65) + (focusComponent * 0.35) - urgencyPenalty))
        }

        private func readinessText(for progress: Double) -> String {
            switch progress {
            case 0..<0.2:
                return localeIdentifier.hasPrefix("tr") ? "Düşük" : "Low"
            case 0.2..<0.45:
                return localeIdentifier.hasPrefix("tr") ? "Başlıyor" : "Starting"
            case 0.45..<0.7:
                return localeIdentifier.hasPrefix("tr") ? "Dengeli" : "Balanced"
            case 0.7..<0.9:
                return localeIdentifier.hasPrefix("tr") ? "Güçlü" : "Strong"
            default:
                return localeIdentifier.hasPrefix("tr") ? "Hazır görünüyor" : "Looks ready"
            }
        }

        private func countdownText(for exam: ExamItem) -> String {
            let days = max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: exam.examDate)).day ?? 0)

            if localeIdentifier.hasPrefix("tr") {
                if days == 0 { return "Bugün" }
                if days == 1 { return "1 gün kaldı" }
                return "\(days) gün kaldı"
            } else {
                if days == 0 { return "Today" }
                if days == 1 { return "1 day left" }
                return "\(days) days left"
            }
        }

        private func courseProgressRows() -> [CourseBalanceRowData] {
            let rows: [CourseBalanceRowData] = courseNames.map { course in
                let relatedTasks = tasks.filter {
                    $0.courseName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    == course.lowercased()
                }

                let completedCount = relatedTasks.filter(\.isDone).count
                let totalCount = relatedTasks.count
                let minutes = relatedTasks.compactMap(\.workoutDurationMinutes).reduce(0, +)
                let progress = totalCount == 0 ? 0 : Double(completedCount) / Double(max(totalCount, 1))

                let statusText: String
                switch progress {
                case 0:
                    statusText = localeIdentifier.hasPrefix("tr") ? "Geri planda" : "Behind"
                case 0..<0.4:
                    statusText = localeIdentifier.hasPrefix("tr") ? "Başlangıç" : "Starting"
                case 0.4..<0.75:
                    statusText = localeIdentifier.hasPrefix("tr") ? "Dengeli" : "Balanced"
                default:
                    statusText = localeIdentifier.hasPrefix("tr") ? "İyi gidiyor" : "Doing well"
                }

                let accent: Color
                switch progress {
                case 0:
                    accent = .red
                case 0..<0.4:
                    accent = .orange
                case 0.4..<0.75:
                    accent = .blue
                default:
                    accent = .green
                }

                return CourseBalanceRowData(
                    courseName: course,
                    minutesText: minutesText(minutes),
                    taskText: localeIdentifier.hasPrefix("tr")
                        ? "\(completedCount)/\(max(totalCount, 1)) görev"
                        : "\(completedCount)/\(max(totalCount, 1)) tasks",
                    progress: progress,
                    statusText: statusText,
                    accent: accent
                )
            }

            return rows.sorted { $0.progress < $1.progress }
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
    
    var studyPattern: StudyPatternData {
            let bestDay = bestDayLabel
            let bestTime = bestStudyHourRangeText
            let avgFocus = minutesText(averageFocusMinutes)

            let insight: String
            if averageFocusMinutes >= 40 {
                insight = localeIdentifier.hasPrefix("tr")
                    ? "Daha uzun bloklarda iyi performans gösteriyorsun."
                    : "You perform well in longer blocks."
            } else if averageFocusMinutes >= 20 {
                insight = localeIdentifier.hasPrefix("tr")
                    ? "Orta uzunlukta odak seansları sende iyi çalışıyor."
                    : "Medium-length sessions seem to work well for you."
            } else {
                insight = localeIdentifier.hasPrefix("tr")
                    ? "Kısa başlangıçlar yapıp ritmi büyütmek sana daha uygun olabilir."
                    : "Short starts that build into momentum may suit you better."
            }

            return StudyPatternData(
                title: localeIdentifier.hasPrefix("tr") ? "Çalışma Deseni" : "Study Pattern",
                subtitle: localeIdentifier.hasPrefix("tr")
                    ? "Ritmine dair kısa içgörüler"
                    : "Short insights about your rhythm",
                bestDayText: bestDay,
                bestTimeText: bestTime,
                avgFocusText: avgFocus,
                patternInsightText: insight
            )
        }
    
    var courseBalance: CourseBalanceData {
            let rows = courseProgressRows()

            return CourseBalanceData(
                title: localeIdentifier.hasPrefix("tr") ? "Ders Dengesi" : "Course Balance",
                subtitle: localeIdentifier.hasPrefix("tr")
                    ? "Hangi derse ne kadar emek verdiğini gör"
                    : "See where your effort is going",
                rows: Array(rows.prefix(5)),
                emptyTitle: localeIdentifier.hasPrefix("tr")
                    ? "Henüz ders verisi yok"
                    : "No course data yet"
            )
        }
    
    var examReadiness: ExamReadinessData {
            let rows = upcomingExams.prefix(3).map { exam in
                let progress = examReadinessProgress(for: exam)
                let relatedTasks = examRelatedTasks(for: exam)
                let totalMinutes = relatedTasks.compactMap(\.workoutDurationMinutes).reduce(0, +)

                return ExamReadinessRowData(
                    examTitle: "\(exam.courseName.isEmpty ? exam.title : exam.courseName) \(exam.examType)",
                    countdownText: countdownText(for: exam),
                    readinessText: readinessText(for: progress),
                    readinessProgress: progress,
                    studyMinutesText: minutesText(totalMinutes),
                    accent: progress < 0.25 ? .red : (progress < 0.55 ? .orange : .green),
                    action: .openWeek
                )
            }

            return ExamReadinessData(
                title: localeIdentifier.hasPrefix("tr") ? "Sınav Hazırlığı" : "Exam Readiness",
                subtitle: localeIdentifier.hasPrefix("tr")
                    ? "Yaklaşan sınavlara ne kadar hazır olduğunu gör"
                    : "See how prepared you are for upcoming exams",
                rows: rows,
                emptyTitle: localeIdentifier.hasPrefix("tr") ? "Yaklaşan sınav yok" : "No upcoming exams",
                emptySubtitle: localeIdentifier.hasPrefix("tr")
                    ? "Sınav eklediğinde hazırlık durumu burada görünür."
                    : "When you add exams, readiness will show here."
            )
        }
    
    var studentHero: StudentInsightHeroData {
            let accent: Color
            let title: String
            let subtitle: String
            let actionTitle: String
            let action: SmartSuggestionAction

            if !overdueTasks.isEmpty {
                accent = .red
                title = localeIdentifier.hasPrefix("tr") ? "Biraz yük birikmiş" : "A bit overloaded"
                subtitle = localeIdentifier.hasPrefix("tr")
                    ? "Önce gecikmiş işleri temizlersen gün daha rahat akar."
                    : "Clearing overdue work will make today easier."
                actionTitle = localeIdentifier.hasPrefix("tr") ? "Görevleri Aç" : "Open Tasks"
                action = .openTasks
            } else if !upcomingExams.isEmpty {
                accent = .orange
                title = localeIdentifier.hasPrefix("tr") ? "Sınav temposu başlıyor" : "Exam pressure is building"
                subtitle = localeIdentifier.hasPrefix("tr")
                    ? "Yaklaşan sınavlar için küçük ama düzenli bloklar en iyi sonucu verir."
                    : "Small consistent blocks work best for upcoming exams."
                actionTitle = localeIdentifier.hasPrefix("tr") ? "Haftayı Aç" : "Open Week"
                action = .openWeek
            } else if todayFocusMinutes >= 45 || completedTodayTasks.count >= 2 {
                accent = .green
                title = localeIdentifier.hasPrefix("tr") ? "Bugün ritmin iyi" : "Your rhythm is good today"
                subtitle = localeIdentifier.hasPrefix("tr")
                    ? "İyi gidiyorsun. Kısa bir blok daha eklersen günü güçlü kapatırsın."
                    : "You're doing well. One more block could finish the day strong."
                actionTitle = localeIdentifier.hasPrefix("tr") ? "Odak Başlat" : "Start Focus"
                action = .openFocus
            } else {
                accent = .blue
                title = localeIdentifier.hasPrefix("tr") ? "Bugün toparlanabilir" : "Today can still turn around"
                subtitle = localeIdentifier.hasPrefix("tr")
                    ? "Küçük bir görev veya kısa bir odak seansı bile momentumu başlatır."
                    : "A small task or short focus session can start momentum."
                actionTitle = localeIdentifier.hasPrefix("tr") ? "Görevleri Aç" : "Open Tasks"
                action = .openTasks
            }

            return StudentInsightHeroData(
                title: title,
                subtitle: subtitle,
                primaryMetric: "\(todayFocusMinutes)",
                primaryLabel: localeIdentifier.hasPrefix("tr") ? "bugün odak dk" : "focus min today",
                chip1: localeIdentifier.hasPrefix("tr")
                    ? "\(completedTodayTasks.count) tamamlandı"
                    : "\(completedTodayTasks.count) done",
                chip2: localeIdentifier.hasPrefix("tr")
                    ? "\(todayPendingTasks.count) açık"
                    : "\(todayPendingTasks.count) open",
                chip3: localeIdentifier.hasPrefix("tr")
                    ? "\(upcomingExams.count) sınav"
                    : "\(upcomingExams.count) exams",
                accent: accent,
                actionTitle: actionTitle,
                action: action
            )
        }
    
    var weeklyMomentum: WeeklyMomentumData {
            let values = weeklyCompletedCounts
            let highlight = values.enumerated().max(by: { $0.element < $1.element })?.offset
            let totalWeeklyFocus = focusSessions
                .filter {
                    guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else { return false }
                    return $0.startedAt >= weekAgo
                }
                .reduce(0) { $0 + ($1.completedSeconds / 60) }

            let completionText = localeIdentifier.hasPrefix("tr")
                ? "\(completedTasks.count) tamamlanan görev"
                : "\(completedTasks.count) completed tasks"

            let focusText = localeIdentifier.hasPrefix("tr")
                ? "\(totalWeeklyFocus) dk odak"
                : "\(totalWeeklyFocus) min focus"

            let streakText = localeIdentifier.hasPrefix("tr")
                ? "\(streakCount) gün seri"
                : "\(streakCount) day streak"

            let summary: String
            if let highlight {
                summary = localeIdentifier.hasPrefix("tr")
                    ? "\(dayLabels[highlight]) günü daha güçlü görünüyorsun."
                    : "\(dayLabels[highlight]) looks like your strongest day."
            } else {
                summary = localeIdentifier.hasPrefix("tr")
                    ? "Bu hafta ritim verisi oluşmadı."
                    : "No rhythm data yet this week."
            }

            return WeeklyMomentumData(
                title: localeIdentifier.hasPrefix("tr") ? "Haftalık Momentum" : "Weekly Momentum",
                subtitle: localeIdentifier.hasPrefix("tr") ? "Ritmini ve ilerlemeni gör" : "See your rhythm and progress",
                labels: dayLabels,
                values: values,
                highlightIndex: highlight,
                summaryText: summary,
                completionText: completionText,
                focusText: focusText,
                streakText: streakText
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
            if !upcomingExams.isEmpty {
                return .init(
                    title: tr("insights_ai_coach_title"),
                    message: localeIdentifier.hasPrefix("tr")
                        ? "Yaklaşan sınavların var. Düzenli kısa çalışma blokları en güvenli yol olur."
                        : "You have upcoming exams. Consistent short study blocks are the safest path.",
                    buttonTitle: tr("insights_action_view_week"),
                    action: .openWeek
                )
            }

            if !overdueTasks.isEmpty {
                return .init(
                    title: tr("insights_ai_coach_title"),
                    message: localeIdentifier.hasPrefix("tr")
                        ? "Gecikmiş görevleri önce temizlemek genel ritmini hızlıca toparlar."
                        : "Clearing overdue tasks first will restore your overall rhythm quickly.",
                    buttonTitle: tr("insights_action_open_tasks"),
                    action: .openTasks
                )
            }

            if totalFocusMinutes >= 60 && completedTasksCount >= 2 {
                return .init(
                    title: tr("insights_ai_coach_title"),
                    message: localeIdentifier.hasPrefix("tr")
                        ? "Bugün iyi gidiyorsun. Bir odak seansı daha seni çok güçlü kapatır."
                        : "You're doing well today. One more focus session would finish strong.",
                    buttonTitle: tr("insights_action_start_focus"),
                    action: .openFocus
                )
            }

            return .init(
                title: tr("insights_ai_coach_title"),
                message: localeIdentifier.hasPrefix("tr")
                    ? "Küçük ama net bir görev seçmek bugün için en doğru başlangıç olabilir."
                    : "Choosing one small but clear task may be the best start for today.",
                buttonTitle: tr("insights_action_open_tasks"),
                action: .openTasks
            )
        }
    // MARK: - Premium Study Insights

        private var activeExamCount: Int {
            upcomingExams.count
        }

        private var studyCourseCount: Int {
            courseNames.count
        }

        private var strongestCourseRow: CourseBalanceRowData? {
            courseProgressRows().max(by: { $0.progress < $1.progress })
        }

        private var weakestCourseRow: CourseBalanceRowData? {
            courseProgressRows().min(by: { $0.progress < $1.progress })
        }

        private var averageExamReadiness: Double {
            guard !upcomingExams.isEmpty else { return 0 }
            let total = upcomingExams.reduce(0.0) { partial, exam in
                partial + examReadinessProgress(for: exam)
            }
            return total / Double(upcomingExams.count)
        }

        private var totalPlannedExamMinutes: Int {
            upcomingExams.reduce(0) { $0 + $1.targetStudyMinutes }
        }

        private var totalCurrentExamMinutes: Int {
            upcomingExams.reduce(0) { partial, exam in
                let related = examRelatedTasks(for: exam)
                let minutes = related.compactMap(\.workoutDurationMinutes).reduce(0, +)
                return partial + minutes
            }
        }

        private var totalCurrentExamTasks: Int {
            upcomingExams.reduce(0) { partial, exam in
                partial + examRelatedTasks(for: exam).filter(\.isDone).count
            }
        }

        private var totalTargetExamTasks: Int {
            max(upcomingExams.reduce(0) { $0 + $1.targetStudyTaskCount }, 1)
        }

        private var bestFocusDayValue: Int {
            weeklyCompletedCounts.max() ?? 0
        }

        private var rhythmScore: Double {
            let streakComponent = min(Double(streakCount) / 7.0, 1.0)
            let focusComponent = min(Double(todayFocusMinutes) / 60.0, 1.0)
            let consistencyComponent = min(Double(weeklyCompletedCounts.filter { $0 > 0 }.count) / 7.0, 1.0)
            return min(1, (streakComponent * 0.35) + (focusComponent * 0.25) + (consistencyComponent * 0.40))
        }

        private var hasMeaningfulStudyData: Bool {
            !upcomingExams.isEmpty || !courseProgressRows().isEmpty || !focusSessions.isEmpty
        }

    var studyHeroPremium: StudyHeroData {
        if !upcomingExams.isEmpty {
            let readiness = Int(averageExamReadiness * 100)
            let nearest = upcomingExams.first
            let nearestText = nearest.map { countdownText(for: $0) } ?? (localeIdentifier.hasPrefix("tr") ? "Yakında" : "Soon")

            return StudyHeroData(
                mode: .exams,
                title: localeIdentifier.hasPrefix("tr") ? "Sınav görünümün netleşiyor" : "Your exam view is taking shape",
                subtitle: localeIdentifier.hasPrefix("tr")
                    ? "En yakın sınav için bugün kısa bir blok yeterli."
                    : "A short block today is enough for your nearest exam.",
                primaryValue: "\(readiness)",
                primaryLabel: localeIdentifier.hasPrefix("tr") ? "hazırlık" : "readiness",
                chip1: localeIdentifier.hasPrefix("tr") ? "\(activeExamCount) sınav" : "\(activeExamCount) exams",
                chip2: nearestText,
                chip3: localeIdentifier.hasPrefix("tr") ? "\(totalCurrentExamMinutes) dk" : "\(totalCurrentExamMinutes) min",
                accent: .orange,
                actionTitle: localeIdentifier.hasPrefix("tr") ? "Sınav Planını Aç" : "Open Exam Plan",
                action: .openWeek
            )
        }

        if studyCourseCount > 0 {
            let weakest = weakestCourseRow

            return StudyHeroData(
                mode: .courses,
                title: localeIdentifier.hasPrefix("tr") ? "Ders dengen şekilleniyor" : "Your course balance is forming",
                subtitle: localeIdentifier.hasPrefix("tr")
                    ? "Geride kalan dersi biraz öne çekmen yeterli."
                    : "Bringing your weaker course forward is enough.",
                primaryValue: "\(studyCourseCount)",
                primaryLabel: localeIdentifier.hasPrefix("tr") ? "aktif ders" : "courses",
                chip1: weakest?.courseName ?? (localeIdentifier.hasPrefix("tr") ? "Ders yok" : "No course"),
                chip2: weakest?.statusText ?? (localeIdentifier.hasPrefix("tr") ? "Başlangıç" : "Starting"),
                chip3: localeIdentifier.hasPrefix("tr") ? "\(completedTasksCount) tamam" : "\(completedTasksCount) done",
                accent: .blue,
                actionTitle: localeIdentifier.hasPrefix("tr") ? "Ders Görevlerini Aç" : "Open Course Tasks",
                action: .openTasks
            )
        }

        if !focusSessions.isEmpty || completedTasksCount > 0 {
            return StudyHeroData(
                mode: .rhythm,
                title: localeIdentifier.hasPrefix("tr") ? "Ritmin sana özel hale geliyor" : "Your rhythm is becoming personal",
                subtitle: localeIdentifier.hasPrefix("tr")
                    ? "Bir odak daha, çalışma desenini netleştirir."
                    : "One more focus session sharpens your study pattern.",
                primaryValue: "\(Int(rhythmScore * 100))",
                primaryLabel: localeIdentifier.hasPrefix("tr") ? "ritim" : "rhythm",
                chip1: localeIdentifier.hasPrefix("tr") ? "\(streakCount) gün" : "\(streakCount) days",
                chip2: bestDayLabel,
                chip3: averageFocusMinutes > 0 ? minutesText(averageFocusMinutes) : (localeIdentifier.hasPrefix("tr") ? "Kısa başla" : "Start small"),
                accent: .green,
                actionTitle: localeIdentifier.hasPrefix("tr") ? "Focus Başlat" : "Start Focus",
                action: .openFocus
            )
        }

        return StudyHeroData(
            mode: .empty,
            title: localeIdentifier.hasPrefix("tr") ? "Study Insights seni bekliyor" : "Study Insights is waiting",
            subtitle: localeIdentifier.hasPrefix("tr")
                ? "Bir sınav, ders etiketi veya focus ile açılır."
                : "Unlocks with an exam, course tag, or focus session.",
            primaryValue: "0",
            primaryLabel: localeIdentifier.hasPrefix("tr") ? "aktif görünüm" : "live insights",
            chip1: localeIdentifier.hasPrefix("tr") ? "Sınav ekle" : "Add exam",
            chip2: localeIdentifier.hasPrefix("tr") ? "Ders etiketi" : "Tag course",
            chip3: localeIdentifier.hasPrefix("tr") ? "25 dk" : "25 min",
            accent: .accentColor,
            actionTitle: localeIdentifier.hasPrefix("tr") ? "Görevleri Aç" : "Open Tasks",
            action: .openTasks
        )
    }
    

            

        var studyDeck: StudyInsightsDeckData {
            let pages: [StudyInsightsDeckPageData] = [
                studyDeckExamsPage,
                studyDeckCoursesPage,
                studyDeckRhythmPage
            ]
            return StudyInsightsDeckData(pages: pages)
        }

    private var studyDeckExamsPage: StudyInsightsDeckPageData {
        guard let nextExam = upcomingExams.first else {
            return StudyInsightsDeckPageData(
                page: .exams,
                title: localeIdentifier.hasPrefix("tr") ? "Sınavlar" : "Exams",
                subtitle: localeIdentifier.hasPrefix("tr") ? "Hazırlık görünümü" : "Preparation view",
                primaryValue: "0",
                primaryLabel: localeIdentifier.hasPrefix("tr") ? "yaklaşan sınav" : "upcoming exams",
                secondaryValue: "0%",
                secondaryLabel: localeIdentifier.hasPrefix("tr") ? "hazırlık" : "readiness",
                statusText: localeIdentifier.hasPrefix("tr") ? "Boş" : "Empty",
                accent: .orange,
                progress: 0,
                chips: [
                    .init(text: localeIdentifier.hasPrefix("tr") ? "İlk sınav" : "First exam", tint: .orange),
                    .init(text: localeIdentifier.hasPrefix("tr") ? "Plan aç" : "Open plan", tint: .blue)
                ],
                ctaTitle: localeIdentifier.hasPrefix("tr") ? "Sınav Ekle" : "Add Exam",
                action: .openWeek,
                emptyTitle: localeIdentifier.hasPrefix("tr") ? "Henüz sınav eklenmedi" : "No exams yet",
                emptySubtitle: localeIdentifier.hasPrefix("tr")
                    ? "İlk sınavını eklediğinde kalan gün ve hazırlık seviyesi burada görünür."
                    : "Add your first exam to unlock countdown and readiness here.",
                emptyButtonTitle: localeIdentifier.hasPrefix("tr") ? "Haftayı Aç" : "Open Week",
                isEmpty: true
            )
        }

        let readiness = examReadinessProgress(for: nextExam)
        let studiedMinutes = examRelatedTasks(for: nextExam).compactMap(\.workoutDurationMinutes).reduce(0, +)
        let doneTasks = examRelatedTasks(for: nextExam).filter(\.isDone).count
        let targetTasks = max(nextExam.targetStudyTaskCount, 1)

        return StudyInsightsDeckPageData(
            page: .exams,
            title: localeIdentifier.hasPrefix("tr") ? "Sınavlar" : "Exams",
            subtitle: nextExam.courseName.isEmpty ? nextExam.title : "\(nextExam.courseName) \(nextExam.examType)",
            primaryValue: countdownText(for: nextExam),
            primaryLabel: localeIdentifier.hasPrefix("tr") ? "kalan süre" : "time left",
            secondaryValue: "%\(Int(readiness * 100))",
            secondaryLabel: localeIdentifier.hasPrefix("tr") ? "hazırlık" : "readiness",
            statusText: readinessText(for: readiness),
            accent: readiness < 0.25 ? .red : (readiness < 0.55 ? .orange : .green),
            progress: readiness,
            chips: [
                .init(text: localeIdentifier.hasPrefix("tr") ? "\(doneTasks)/\(targetTasks) görev" : "\(doneTasks)/\(targetTasks) tasks", tint: .orange),
                .init(text: minutesText(studiedMinutes), tint: .blue),
                .init(text: localeIdentifier.hasPrefix("tr") ? "\(activeExamCount) sınav" : "\(activeExamCount) exams", tint: .green)
            ],
            ctaTitle: localeIdentifier.hasPrefix("tr") ? "Çalışma Planını Aç" : "Open Study Plan",
            action: .openWeek,
            emptyTitle: nil,
            emptySubtitle: nil,
            emptyButtonTitle: nil,
            isEmpty: false
        )
    }

    private var studyDeckCoursesPage: StudyInsightsDeckPageData {
        let rows = courseProgressRows()

        guard let weakest = weakestCourseRow, let strongest = strongestCourseRow else {
            return StudyInsightsDeckPageData(
                page: .courses,
                title: localeIdentifier.hasPrefix("tr") ? "Dersler" : "Courses",
                subtitle: localeIdentifier.hasPrefix("tr") ? "Denge görünümü" : "Balance view",
                primaryValue: "0",
                primaryLabel: localeIdentifier.hasPrefix("tr") ? "aktif ders" : "active courses",
                secondaryValue: "—",
                secondaryLabel: localeIdentifier.hasPrefix("tr") ? "öne çıkan ders" : "top course",
                statusText: localeIdentifier.hasPrefix("tr") ? "Boş" : "Empty",
                accent: .blue,
                progress: 0,
                chips: [
                    .init(text: localeIdentifier.hasPrefix("tr") ? "Ders etiketi" : "Tag course", tint: .blue),
                    .init(text: localeIdentifier.hasPrefix("tr") ? "Görev oluştur" : "Create task", tint: .orange)
                ],
                ctaTitle: localeIdentifier.hasPrefix("tr") ? "Görevleri Aç" : "Open Tasks",
                action: .openTasks,
                emptyTitle: localeIdentifier.hasPrefix("tr") ? "Henüz ders dengesi oluşmadı" : "No course balance yet",
                emptySubtitle: localeIdentifier.hasPrefix("tr")
                    ? "Görevlerine ders adı ekledikçe hangi derse daha az dokunduğun görünür."
                    : "As you tag tasks with course names, your weaker course starts to appear.",
                emptyButtonTitle: localeIdentifier.hasPrefix("tr") ? "Görevleri Aç" : "Open Tasks",
                isEmpty: true
            )
        }

        let balanceScore = rows.isEmpty ? 0 : rows.map(\.progress).reduce(0, +) / Double(rows.count)
        let status = balanceScore < 0.30
            ? (localeIdentifier.hasPrefix("tr") ? "Dağınık" : "Uneven")
            : (balanceScore < 0.65 ? (localeIdentifier.hasPrefix("tr") ? "Toparlanıyor" : "Improving") : (localeIdentifier.hasPrefix("tr") ? "Dengeli" : "Balanced"))

        return StudyInsightsDeckPageData(
            page: .courses,
            title: localeIdentifier.hasPrefix("tr") ? "Dersler" : "Courses",
            subtitle: localeIdentifier.hasPrefix("tr") ? "Çalışma dengesi" : "Study balance",
            primaryValue: weakest.courseName,
            primaryLabel: localeIdentifier.hasPrefix("tr") ? "daha çok ilgi isteyen" : "needs more attention",
            secondaryValue: strongest.courseName,
            secondaryLabel: localeIdentifier.hasPrefix("tr") ? "en güçlü ders" : "strongest course",
            statusText: status,
            accent: .blue,
            progress: balanceScore,
            chips: [
                .init(text: localeIdentifier.hasPrefix("tr") ? "\(studyCourseCount) ders" : "\(studyCourseCount) courses", tint: .blue),
                .init(text: weakest.statusText, tint: .orange),
                .init(text: strongest.statusText, tint: .green)
            ],
            ctaTitle: localeIdentifier.hasPrefix("tr") ? "Ders Görevlerini Aç" : "Open Course Tasks",
            action: .openTasks,
            emptyTitle: nil,
            emptySubtitle: nil,
            emptyButtonTitle: nil,
            isEmpty: false
        )
    }

    private var studyDeckRhythmPage: StudyInsightsDeckPageData {
        let progress = rhythmScore
        let bestTime = bestStudyHourRangeText
        let avg = averageFocusMinutes

        if completedTasksCount == 0 && focusSessions.isEmpty {
            return StudyInsightsDeckPageData(
                page: .rhythm,
                title: localeIdentifier.hasPrefix("tr") ? "Ritim" : "Rhythm",
                subtitle: localeIdentifier.hasPrefix("tr") ? "Çalışma deseni" : "Study pattern",
                primaryValue: localeIdentifier.hasPrefix("tr") ? "Henüz yok" : "Not yet",
                primaryLabel: localeIdentifier.hasPrefix("tr") ? "en iyi zaman" : "best time",
                secondaryValue: "0",
                secondaryLabel: localeIdentifier.hasPrefix("tr") ? "aktif gün" : "active days",
                statusText: localeIdentifier.hasPrefix("tr") ? "Başlamadı" : "Not started",
                accent: .green,
                progress: 0,
                chips: [
                    .init(text: localeIdentifier.hasPrefix("tr") ? "İlk focus" : "First focus", tint: .green),
                    .init(text: localeIdentifier.hasPrefix("tr") ? "Görev bitir" : "Finish task", tint: .blue)
                ],
                ctaTitle: localeIdentifier.hasPrefix("tr") ? "Focus Başlat" : "Start Focus",
                action: .openFocus,
                emptyTitle: localeIdentifier.hasPrefix("tr") ? "Ritmin henüz oluşmadı" : "Your rhythm has not formed yet",
                emptySubtitle: localeIdentifier.hasPrefix("tr")
                    ? "İlk birkaç görev ve odak oturumu sonrası en iyi zamanların görünür."
                    : "After a few tasks and focus sessions, your best windows appear here.",
                emptyButtonTitle: localeIdentifier.hasPrefix("tr") ? "Focus Başlat" : "Start Focus",
                isEmpty: true
            )
        }

        return StudyInsightsDeckPageData(
            page: .rhythm,
            title: localeIdentifier.hasPrefix("tr") ? "Ritim" : "Rhythm",
            subtitle: localeIdentifier.hasPrefix("tr") ? "Gün içi akışın" : "Your daily flow",
            primaryValue: bestTime,
            primaryLabel: localeIdentifier.hasPrefix("tr") ? "en iyi zaman" : "best time",
            secondaryValue: bestDayLabel,
            secondaryLabel: localeIdentifier.hasPrefix("tr") ? "en iyi gün" : "best day",
            statusText: localeIdentifier.hasPrefix("tr") ? "Kişiselleşiyor" : "Personalizing",
            accent: .green,
            progress: progress,
            chips: [
                .init(text: localeIdentifier.hasPrefix("tr") ? "\(streakCount) gün seri" : "\(streakCount) day streak", tint: .orange),
                .init(text: minutesText(avg), tint: .blue),
                .init(text: localeIdentifier.hasPrefix("tr") ? "\(weeklyCompletedCounts.filter { $0 > 0 }.count) aktif gün" : "\(weeklyCompletedCounts.filter { $0 > 0 }.count) active days", tint: .green)
            ],
            ctaTitle: localeIdentifier.hasPrefix("tr") ? "Focus Başlat" : "Start Focus",
            action: .openFocus,
            emptyTitle: nil,
            emptySubtitle: nil,
            emptyButtonTitle: nil,
            isEmpty: false
        )
    }

    var studyQuickActions: [StudyQuickActionData] {
        [
            .init(
                title: localeIdentifier.hasPrefix("tr") ? "Hafta" : "Week",
                icon: "calendar",
                tint: .blue,
                action: .openWeek
            ),
            .init(
                title: localeIdentifier.hasPrefix("tr") ? "Focus" : "Focus",
                icon: "timer",
                tint: .green,
                action: .openFocus
            ),
            .init(
                title: localeIdentifier.hasPrefix("tr") ? "Görevler" : "Tasks",
                icon: "checklist",
                tint: .orange,
                action: .openTasks
            )
        ]
    }
}
