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
        localeIdentifier.hasPrefix("tr")
    }

    private var dayLabels: [String] {
        if isTurkish {
            return ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
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
            return isTurkish ? "Henüz net değil" : "Not clear yet"
        }

        switch bestHour {
        case 5..<12:
            return isTurkish ? "Sabah" : "Morning"
        case 12..<17:
            return isTurkish ? "Öğleden sonra" : "Afternoon"
        case 17..<22:
            return isTurkish ? "Akşam" : "Evening"
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
            if days == 0 { return "Bugün" }
            if days == 1 { return "1 gün kaldı" }
            return "\(days) gün kaldı"
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
                title: isTurkish ? "Yük biraz birikmiş" : "A bit of backlog is building",
                message: isTurkish
                    ? "Önce küçük görevleri temizlemek ritmi hızla toparlar."
                    : "Clearing smaller tasks first can quickly restore momentum.",
                buttonTitle: isTurkish ? "Görevleri Aç" : "Open Tasks",
                action: .openTasks
            ))
        }

        if hasNoFocusHabit && activeTasksCount > 0 {
            suggestions.append(.init(
                title: isTurkish ? "İlk odak bloğunu başlat" : "Start your first focus block",
                message: isTurkish
                    ? "Kısa bir focus oturumu bile bu ekranı daha kişisel hale getirir."
                    : "Even a short focus session will make this screen more personal.",
                buttonTitle: isTurkish ? "Focus Başlat" : "Start Focus",
                action: .openFocus
            ))
        }

        if hasStrongMomentum {
            suggestions.append(.init(
                title: isTurkish ? "Momentumun iyi görünüyor" : "Your momentum looks good",
                message: isTurkish
                    ? "Bugünkü akışı korumak için bir görev daha bitir."
                    : "Complete one more task to preserve today's rhythm.",
                buttonTitle: isTurkish ? "Görevleri Aç" : "Open Tasks",
                action: .openTasks
            ))
        }

        suggestions.append(.init(
            title: isTurkish ? "Güçlü gününü kullan" : "Use your strongest day",
            message: isTurkish
                ? "\(bestDayLabel) senin için daha güçlü görünüyor."
                : "\(bestDayLabel) seems to be your strongest day.",
            buttonTitle: isTurkish ? "Haftayı Aç" : "Open Week",
            action: .openWeek
        ))

        if isEveningProductive {
            suggestions.append(.init(
                title: isTurkish ? "Akşam ritmin daha güçlü" : "Your evening rhythm is stronger",
                message: isTurkish
                    ? "Önemli işi akşam saatlerine koymak daha iyi çalışabilir."
                    : "Placing important work in the evening may work better for you.",
                buttonTitle: isTurkish ? "Focus Başlat" : "Start Focus",
                action: .openFocus
            ))
        }

        if totalFocusMinutes >= 90 {
            suggestions.append(.init(
                title: isTurkish ? "Derin çalışma sinyali var" : "There is a deep work signal",
                message: isTurkish
                    ? "Daha uzun bloklar sende iyi sonuç veriyor olabilir."
                    : "Longer focus blocks may be working well for you.",
                buttonTitle: isTurkish ? "Haftayı Aç" : "Open Week",
                action: .openWeek
            ))
        }

        suggestions.append(.init(
            title: isTurkish ? "Küçük başla" : "Start small",
            message: isTurkish
                ? "Bugün tek net görev seçmek iyi bir başlangıç olur."
                : "Picking one clear task is a strong start for today.",
            buttonTitle: isTurkish ? "Görevleri Aç" : "Open Tasks",
            action: .openTasks
        ))

        return suggestions
    }

    var smartSuggestion: SmartSuggestionData {
        let suggestions = rotatedSuggestions()

        guard !suggestions.isEmpty else {
            return .init(
                title: isTurkish ? "Başlamak için iyi bir gün" : "A good day to begin",
                message: isTurkish
                    ? "İlk görevin veya ilk focus oturumun bu alanı doldurmaya başlar."
                    : "Your first task or first focus session will start filling this space.",
                buttonTitle: isTurkish ? "Görevleri Aç" : "Open Tasks",
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
                    ? "Yaklaşan sınavların var. Kısa ama düzenli bloklar en güvenli yol olur."
                    : "You have upcoming exams. Consistent short blocks are the safest path.",
                buttonTitle: isTurkish ? "Haftayı Aç" : "Open Week",
                action: .openWeek
            )
        }

        if !overdueTasks.isEmpty {
            return .init(
                title: isTurkish ? "Mini Coach" : "Mini Coach",
                message: isTurkish
                    ? "Gecikmiş görevleri önce temizlemek ritmini hızlıca toparlar."
                    : "Clearing overdue tasks first will quickly restore your rhythm.",
                buttonTitle: isTurkish ? "Görevleri Aç" : "Open Tasks",
                action: .openTasks
            )
        }

        if totalFocusMinutes >= 60 && completedTasksCount >= 2 {
            return .init(
                title: isTurkish ? "Mini Coach" : "Mini Coach",
                message: isTurkish
                    ? "Bugün iyi gidiyorsun. Bir focus bloğu daha günü güçlü kapatır."
                    : "You are doing well today. One more focus block would finish the day strong.",
                buttonTitle: isTurkish ? "Focus Başlat" : "Start Focus",
                action: .openFocus
            )
        }

        return .init(
            title: isTurkish ? "Mini Coach" : "Mini Coach",
            message: isTurkish
                ? "Bugün tek bir net görev seçmek en doğru başlangıç olabilir."
                : "Choosing one clear task may be the best start for today.",
            buttonTitle: isTurkish ? "Görevleri Aç" : "Open Tasks",
            action: .openTasks
        )
    }

    // MARK: - New V2 Outputs

    var coachUnified: InsightsCoachUnifiedData {
        let coach = aiCoach
        let suggestion = smartSuggestion

        return InsightsCoachUnifiedData(
            eyebrow: isTurkish ? "Bugün için önerim" : "My suggestion for today",
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
            let nearestText = nearest.map { countdownText(for: $0) } ?? (isTurkish ? "Yakında" : "Soon")

            return StudyHeroData(
                mode: .exams,
                title: isTurkish ? "Sınav görünümün netleşiyor" : "Your exam view is taking shape",
                subtitle: isTurkish
                    ? "En yakın sınav için bugün kısa bir blok yeterli."
                    : "A short block today is enough for your nearest exam.",
                primaryValue: "\(readiness)",
                primaryLabel: isTurkish ? "hazırlık" : "readiness",
                chip1: isTurkish ? "\(upcomingExams.count) sınav" : "\(upcomingExams.count) exams",
                chip2: nearestText,
                chip3: isTurkish ? "\(totalFocusMinutes) dk" : "\(totalFocusMinutes) min",
                accent: .orange,
                actionTitle: isTurkish ? "Sınav Planını Aç" : "Open Exam Plan",
                action: .openWeek
            )
        }

        if !courseNames.isEmpty {
            return StudyHeroData(
                mode: .courses,
                title: isTurkish ? "Ders dengen şekilleniyor" : "Your course balance is forming",
                subtitle: isTurkish
                    ? "Daha az dokunduğun dersi biraz öne çekmek iyi olur."
                    : "Bringing your weaker course forward would help.",
                primaryValue: "\(courseNames.count)",
                primaryLabel: isTurkish ? "aktif ders" : "courses",
                chip1: isTurkish ? "\(completedTasksCount) tamam" : "\(completedTasksCount) done",
                chip2: isTurkish ? "\(activeTasksCount) açık" : "\(activeTasksCount) open",
                chip3: bestDayLabel,
                accent: .blue,
                actionTitle: isTurkish ? "Görevleri Aç" : "Open Tasks",
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
                title: isTurkish ? "Ritmin sana özel hale geliyor" : "Your rhythm is becoming personal",
                subtitle: isTurkish
                    ? "Bir odak daha, çalışma desenini daha net hale getirir."
                    : "One more focus session will sharpen your study pattern.",
                primaryValue: "\(Int(rhythmScore * 100))",
                primaryLabel: isTurkish ? "ritim" : "rhythm",
                chip1: isTurkish ? "\(streakCount) gün" : "\(streakCount) days",
                chip2: bestDayLabel,
                chip3: averageFocusMinutes > 0 ? minutesText(averageFocusMinutes) : (isTurkish ? "Kısa başla" : "Start small"),
                accent: .green,
                actionTitle: isTurkish ? "Focus Başlat" : "Start Focus",
                action: .openFocus
            )
        }

        return StudyHeroData(
            mode: .empty,
            title: isTurkish ? "Insights seni bekliyor" : "Insights is waiting",
            subtitle: isTurkish
                ? "Bir görev, bir focus oturumu veya bir sınav ile bu alan canlanır."
                : "A task, a focus session, or an exam will bring this space to life.",
            primaryValue: "0",
            primaryLabel: isTurkish ? "canlı içgörü" : "live insights",
            chip1: isTurkish ? "Görev ekle" : "Add task",
            chip2: isTurkish ? "Focus başlat" : "Start focus",
            chip3: isTurkish ? "Sınav ekle" : "Add exam",
            accent: .accentColor,
            actionTitle: isTurkish ? "Görevleri Aç" : "Open Tasks",
            action: .openTasks
        )
    }

    var weeklyMomentum: WeeklyMomentumData {
        let values = weeklyCompletedCounts
        let highlight = values.enumerated().max(by: { $0.element < $1.element })?.offset

        let completionText = isTurkish
            ? "\(completedTasksCount) tamamlanan görev"
            : "\(completedTasksCount) completed tasks"

        let focusText = isTurkish
            ? "\(weeklyFocusMinutesLast7Days) dk odak"
            : "\(weeklyFocusMinutesLast7Days) min focus"

        let streakText = isTurkish
            ? "\(streakCount) gün seri"
            : "\(streakCount) day streak"

        let summary: String
        if let highlight {
            summary = isTurkish
                ? "\(dayLabels[highlight]) günü daha güçlü görünüyorsun."
                : "\(dayLabels[highlight]) looks like your strongest day."
        } else {
            summary = isTurkish
                ? "Bu hafta ritim verisi oluşmadı."
                : "No rhythm data yet this week."
        }

        return WeeklyMomentumData(
            title: isTurkish ? "Haftalık Momentum" : "Weekly Momentum",
            subtitle: isTurkish ? "Ritmini ve ilerlemeni gör" : "See your rhythm and progress",
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
                ? "Uzun odak bloklarıyla güçleniyorsun."
                : "You are getting stronger with long focus blocks."
            accent = .blue
            traits = isTurkish
                ? ["Odaklı", "Derin çalışma", "Ritimli"]
                : ["Focused", "Deep work", "Rhythmic"]
        } else if streakCount >= 4 {
            title = "Consistency Builder"
            subtitle = isTurkish
                ? "Düzenli ilerleme kimliğin oluşuyor."
                : "Your consistency identity is taking shape."
            accent = .green
            traits = isTurkish
                ? ["Düzenli", "Güvenilir", "İlerliyor"]
                : ["Consistent", "Reliable", "Growing"]
        } else if isEveningProductive {
            title = "Night Finisher"
            subtitle = isTurkish
                ? "Akşam saatlerinde daha iyi çalışıyorsun."
                : "You seem to perform better in the evening."
            accent = .purple
            traits = isTurkish
                ? ["Akşam akışı", "Sessiz tempo", "Toparlayan"]
                : ["Evening flow", "Quiet pace", "Finisher"]
        } else {
            title = "Momentum Starter"
            subtitle = isTurkish
                ? "Küçük başlangıçlarla ritim kuruyorsun."
                : "You build momentum through small starts."
            accent = .orange
            traits = isTurkish
                ? ["Başlangıç", "Esnek", "Potansiyel"]
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
        let hasFirstFocus = totalFocusSessionsCount >= 1
        let hasThreeDayStreak = streakCount >= 3
        let hasWeeklyWarrior = completedTasksCount >= 7
        let hasFocusBuilder = totalFocusMinutes >= 120
        let hasExamReady = !upcomingExams.isEmpty && averageExamReadiness >= 0.6

        return [
            InsightsBadgeData(
                title: isTurkish ? "İlk Focus" : "First Focus",
                subtitle: isTurkish ? "İlk odak oturumun" : "Your first focus session",
                icon: "sparkles",
                isUnlocked: hasFirstFocus,
                progress: hasFirstFocus ? 1 : min(Double(totalFocusSessionsCount), 1),
                accent: .blue
            ),
            InsightsBadgeData(
                title: isTurkish ? "3 Gün Seri" : "3 Day Streak",
                subtitle: isTurkish ? "Düzenli akış başladı" : "Consistency has started",
                icon: "flame.fill",
                isUnlocked: hasThreeDayStreak,
                progress: hasThreeDayStreak ? 1 : min(Double(streakCount) / 3.0, 1),
                accent: .orange
            ),
            InsightsBadgeData(
                title: isTurkish ? "Weekly Warrior" : "Weekly Warrior",
                subtitle: isTurkish ? "Haftalık güçlü tempo" : "A strong weekly pace",
                icon: "bolt.fill",
                isUnlocked: hasWeeklyWarrior,
                progress: hasWeeklyWarrior ? 1 : min(Double(completedTasksCount) / 7.0, 1),
                accent: .green
            ),
            InsightsBadgeData(
                title: isTurkish ? "Deep Builder" : "Deep Builder",
                subtitle: isTurkish ? "120 dk focus" : "120 min focus",
                icon: "timer",
                isUnlocked: hasFocusBuilder,
                progress: hasFocusBuilder ? 1 : min(Double(totalFocusMinutes) / 120.0, 1),
                accent: .purple
            ),
            InsightsBadgeData(
                title: isTurkish ? "Exam Ready" : "Exam Ready",
                subtitle: isTurkish ? "Hazırlık dengeli görünüyor" : "Your readiness looks balanced",
                icon: "graduationcap.fill",
                isUnlocked: hasExamReady,
                progress: hasExamReady ? 1 : min(averageExamReadiness, 1),
                accent: .pink
            )
        ]
    }
    
    var allAchievementBadges: [InsightsBadgeData] {
        let more: [InsightsBadgeData] = [
            InsightsBadgeData(
                title: isTurkish ? "7 Gün Seri" : "7 Day Streak",
                subtitle: isTurkish ? "Bir haftalık düzen" : "A full week of consistency",
                icon: "flame.circle.fill",
                isUnlocked: streakCount >= 7,
                progress: streakCount >= 7 ? 1 : min(Double(streakCount) / 7.0, 1),
                accent: .orange
            ),
            InsightsBadgeData(
                title: isTurkish ? "Focus 300" : "Focus 300",
                subtitle: isTurkish ? "300 dk toplam odak" : "300 total focus minutes",
                icon: "brain.head.profile",
                isUnlocked: totalFocusMinutes >= 300,
                progress: totalFocusMinutes >= 300 ? 1 : min(Double(totalFocusMinutes) / 300.0, 1),
                accent: .blue
            ),
            InsightsBadgeData(
                title: isTurkish ? "Night Mode" : "Night Mode",
                subtitle: isTurkish ? "Akşam ritmini kur" : "Build an evening rhythm",
                icon: "moon.stars.fill",
                isUnlocked: isEveningProductive && totalFocusSessionsCount >= 3,
                progress: (isEveningProductive && totalFocusSessionsCount >= 3) ? 1 : min(Double(totalFocusSessionsCount) / 3.0, 1),
                accent: .purple
            ),
            InsightsBadgeData(
                title: isTurkish ? "Task Finisher" : "Task Finisher",
                subtitle: isTurkish ? "10 görev tamamla" : "Complete 10 tasks",
                icon: "checkmark.seal.fill",
                isUnlocked: completedTasksCount >= 10,
                progress: completedTasksCount >= 10 ? 1 : min(Double(completedTasksCount) / 10.0, 1),
                accent: .green
            ),
            InsightsBadgeData(
                title: isTurkish ? "Exam Sprint" : "Exam Sprint",
                subtitle: isTurkish ? "Sınav hazırlığını güçlendir" : "Strengthen exam readiness",
                icon: "graduationcap.circle.fill",
                isUnlocked: !upcomingExams.isEmpty && averageExamReadiness >= 0.75,
                progress: !upcomingExams.isEmpty ? min(averageExamReadiness / 0.75, 1) : 0,
                accent: .pink
            )
        ]

        return achievementBadges + more
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
                label: isTurkish ? "en iyi gün" : "best day",
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
                ? "Daha derin çalışma desenlerini aç"
                : "Unlock deeper study patterns",
            subtitle: isTurkish
                ? "Premium ile ritmini sadece görmez, neden oluştuğunu da anlarsın."
                : "With Premium, you do not just see your rhythm — you understand why it forms.",
            bullets: isTurkish
                ? [
                    "En iyi çalışma saat tahmini",
                    "Daha gelişmiş AI koç önerileri",
                    "Uzun dönem kimlik ve gelişim görünümü"
                ]
                : [
                    "Best study window prediction",
                    "More advanced AI coaching",
                    "Long-term identity and growth view"
                ],
            buttonTitle: isTurkish ? "Premium'u Gör" : "See Premium"
        )
    }
   var deepInsightsHero: DeepInsightsHeroData {
        DeepInsightsHeroData(
            title: "Deep Insights",
            subtitle: "Your rhythm, patterns, and next moves",
            primaryValue: bestStudyHourRangeText,
            primaryLabel: isTurkish ? "en iyi zaman" : "best window",
            chip1: isTurkish ? "\(streakCount) gün seri" : "\(streakCount) day streak",
            chip2: isTurkish ? "\(completedTasksCount) tamamlanan" : "\(completedTasksCount) done"
        )
    }

    var deepBestStudyWindow: BestStudyWindowData {
        BestStudyWindowData(
            timeRange: bestStudyHourRangeText,
            confidenceText: isTurkish ? "Güven artıyor" : "Confidence rising",
            summary: isTurkish
                ? "Bu zaman aralığında daha uzun odaklanıyor ve daha fazla görev tamamlıyorsun."
                : "You tend to focus longer and complete more tasks in this window.",
            accent: .purple
        )
    }
    
    var plusCoachCard: InsightsPlusCoachCardData {
        InsightsPlusCoachCardData(
            title: isTurkish ? "Bugün tek net görev seç" : "Choose one clear task today",
            subtitle: isTurkish
                ? "Kısa bir odak bloğu sonrası tamamlama ihtimalin yükseliyor."
                : "Your completion chance rises after a short focus block.",
            hint: isTurkish ? "yüksek güven" : "high confidence",
            symbol: "brain.head.profile",
            tint: .cyan,
            actionTitle: isTurkish ? "Görevleri Aç" : "Open Tasks",
            action: .openTasks
        )
    }

    var plusStudyWindowCard: InsightsPlusStudyWindowCardData {
        InsightsPlusStudyWindowCardData(
            title: "Best Study Window",
            timeText: bestStudyHourRangeText,
            confidenceText: isTurkish ? "Güven artıyor" : "Confidence rising",
            summary: isTurkish
                ? "Bu pencerede daha uzun odaklanıyor ve daha fazla görev tamamlıyorsun."
                : "You focus longer and complete more tasks in this window.",
            symbol: "clock.fill",
            tint: .purple,
            actionTitle: isTurkish ? "Focus Başlat" : "Start Focus",
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
            trendText: isTurkish ? "Ritmin toparlanıyor" : "Your rhythm is stabilizing",
            values: raw,
            highlightIndex: strongestIndex,
            tint: .blue,
            actionTitle: isTurkish ? "Haftayı Aç" : "Open Week",
            action: .openWeek
        )
    }

    var deepWeeklyReview: WeeklyDeepReviewData {
        let weakest = weeklyCompletedCounts.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0

        return WeeklyDeepReviewData(
            strongestDay: bestDayLabel,
            weakestDay: dayLabels[weakest],
            deltaText: isTurkish
                ? "Geçen haftaya göre ritim toparlanıyor."
                : "Rhythm is improving compared to last week.",
            recommendation: isTurkish
                ? "Zayıf gününe kısa bir odak bloğu eklemek haftayı dengeler."
                : "Adding a short focus block to your weakest day may balance the week."
        )
    }

    var deepIdentityEvolution: IdentityEvolutionData {
        IdentityEvolutionData(
            currentIdentity: identityProfile.title,
            nextIdentity: streakCount >= 4 ? "Deep Worker" : "Consistency Builder",
            progressText: isTurkish
                ? "Bir sonraki kimliğe yaklaşmak için birkaç aktif gün daha gerekli."
                : "A few more active days will move you toward your next identity.",
            progress: min(1.0, identityProfile.progress)
        )
    }

    var deepExamRows: [ExamReadinessProRow] {
        if upcomingExams.isEmpty {
            return [
                ExamReadinessProRow(
                    title: isTurkish ? "Yaklaşan sınav yok" : "No upcoming exams",
                    readinessText: "—",
                    progress: 0,
                    riskText: isTurkish ? "Sınav eklediğinde burada görünür." : "It appears here when you add an exam.",
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
                    title: isTurkish ? "Akşam ritmi yükseliyor" : "Evening rhythm is rising",
                    message: isTurkish
                        ? "Akşam saatlerinde daha güçlü performans gösteriyorsun."
                        : "You seem to perform better during evening hours.",
                    icon: "moon.stars.fill",
                    tint: .purple
                )
            )
        }

        if streakCount == 0 {
            items.append(
                PatternAlertData(
                    title: isTurkish ? "Seri henüz başlamadı" : "Streak has not started yet",
                    message: isTurkish
                        ? "Kısa bir görev bile ritmi başlatabilir."
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
                        ? "Görev bitirme düzenin oluşmaya başlıyor."
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
                        ? "Birkaç gün daha kullanım sonrası daha net uyarılar oluşur."
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
        courseMinutesMap.first?.course ?? (isTurkish ? "Henüz net değil" : "Not clear yet")
    }

    private var neglectedCourseName: String {
        courseMinutesMap.last?.course ?? (isTurkish ? "Henüz net değil" : "Not clear yet")
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
                focusQualityText = isTurkish ? "yüksek yoğunluk" : "high intensity"
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
                ? "\(recommended) şu anda ritmine en iyi oturan ders gibi görünüyor."
                : "\(recommended) currently matches your rhythm the best."
        } else {
            reason = isTurkish
                ? "\(recommended) daha az ilgi görüyor ama dengeyi toparlamak için bir sonraki iyi aday."
                : "\(recommended) is receiving less attention and looks like the best next balancing move."
        }

        return InsightsStudyWindowDetailData(
            timeRangeText: bestStudyHourRangeText,
            confidenceText: isTurkish ? "Güven artıyor" : "Confidence rising",
            summaryText: isTurkish
                ? "Bu pencerede daha uzun odaklanıyor ve daha fazla görev tamamlıyorsun."
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

        return best ?? (isTurkish ? "Henüz net değil" : "Not clear yet")
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
            directionTitle = isTurkish ? "Kısa başla, bir görevi temizle" : "Start small, clear one task"
            directionSubtitle = isTurkish
                ? "Büyük blok yerine tek net görev seçmek bugün daha verimli olur."
                : "Choosing one clear task may be more effective than a long block today."
            strongestSignal = isTurkish ? "Görev yoğunluğu görünür" : "Visible task backlog"
            blockingSignal = isTurkish ? "Yük birikimi ritmi bastırıyor" : "Backlog is compressing rhythm"
            reason = isTurkish
                ? "Kısa bir görev temizliği sonrası focus açmak bugün en mantıklı akış olabilir."
                : "Clearing one task before opening a focus block may be your best flow today."
        } else if totalFocusMinutes == 0 && activeTaskBacklogCount > 0 {
            directionTitle = isTurkish ? "İlk kısa focus bloğunu aç" : "Open your first short focus block"
            directionSubtitle = isTurkish
                ? "Bugün ritmi başlatmak için 20–25 dakikalık bir odak yeterli."
                : "A 20–25 minute block is enough to start momentum today."
            strongestSignal = isTurkish ? "Tamamlanabilir yük var" : "Workload is actionable"
            blockingSignal = isTurkish ? "Odak ritmi başlamadı" : "Focus rhythm has not started"
            reason = isTurkish
                ? "Görev sayısı yönetilebilir görünüyor; önce kısa focus ritmi kurmak daha doğru."
                : "Your workload looks manageable; building a short focus rhythm first makes sense."
        } else if !upcomingExams.isEmpty {
            directionTitle = isTurkish ? "Sınava yakın derse dön" : "Return to the nearest exam course"
            directionSubtitle = isTurkish
                ? "En yakın sınavın olduğu ders bugün en mantıklı yön gibi görünüyor."
                : "The course tied to your nearest exam looks like the most logical direction today."
            strongestSignal = isTurkish ? "Sınav baskısı artıyor" : "Exam pressure is rising"
            blockingSignal = isTurkish ? "Dağılım dengesizleşebilir" : "Balance may drift"
            reason = isTurkish
                ? "Yaklaşan sınav, çalışma yönünü belirlemek için şu anda en güçlü sinyal."
                : "Your nearest exam is currently the strongest signal for deciding your study direction."
        } else {
            directionTitle = isTurkish ? "Bugün tek net görev seç" : "Choose one clear task today"
            directionSubtitle = isTurkish
                ? "Kısa bir odak bloğu sonrası tamamlama ihtimalin yükseliyor."
                : "Your completion chance rises after a short focus block."
            strongestSignal = bestCompletedCourseName
            blockingSignal = activeTaskBacklogCount > 0
                ? (isTurkish ? "\(activeTaskBacklogCount) açık görev" : "\(activeTaskBacklogCount) open tasks")
                : (isTurkish ? "Ritim daha yeni oluşuyor" : "Rhythm is still forming")
            reason = isTurkish
                ? "Kısa başlangıçlar şu an ritmine en iyi oturan karar modeli gibi görünüyor."
                : "Short starts currently seem to fit your rhythm best."
        }

        let actions: [InsightsCoachActionRow] = [
            InsightsCoachActionRow(
                title: isTurkish ? "Kısa görev temizliği" : "Short task cleanup",
                subtitle: isTurkish ? "Bir açık görevi bitir ve yükü hafiflet" : "Finish one open task and reduce pressure",
                intensity: isTurkish ? "Kısa" : "Short",
                symbol: "checkmark.circle.fill",
                tint: .green,
                action: .openTasks
            ),
            InsightsCoachActionRow(
                title: isTurkish ? "Focus bloğu aç" : "Open a focus block",
                subtitle: isTurkish ? "20–25 dakika ritmi başlatmak için yeterli" : "20–25 minutes is enough to start rhythm",
                intensity: isTurkish ? "Orta" : "Medium",
                symbol: "timer",
                tint: .purple,
                action: .openFocus
            ),
            InsightsCoachActionRow(
                title: isTurkish ? "Haftayı hizala" : "Align the week",
                subtitle: isTurkish ? "Dağılımı ve yaklaşan işleri birlikte gör" : "See distribution and upcoming work together",
                intensity: isTurkish ? "Derin" : "Deep",
                symbol: "calendar",
                tint: .blue,
                action: .openWeek
            )
        ]

        return InsightsCoachDetailData(
            headline: directionTitle,
            summary: directionSubtitle,
            confidenceText: isTurkish ? "yüksek güven" : "high confidence",
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
            subtitle: isTurkish ? "Haftalık ritim analizi" : "Weekly rhythm analysis",
            strongestDay: labels[strongestIndex],
            weakestDay: labels[weakestIndex],
            trendSummary: isTurkish ? "Ritmin toparlanıyor" : "Your rhythm is stabilizing",
            completionTotalText: isTurkish ? "\(totalCompletions) görev" : "\(totalCompletions) tasks",
            focusTotalText: isTurkish ? "\(totalFocus) dk focus" : "\(totalFocus) min focus",
            streakText: isTurkish ? "\(streakCount) gün seri" : "\(streakCount) day streak",
            days: details
        )
    }
}
