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

    private let calendar = Calendar.current

    private var isTurkish: Bool {
        Locale.current.language.languageCode?.identifier == "tr"
    }

    private var dayLabels: [String] {
        if isTurkish {
            return ["Pzt","Sal","Çar","Per","Cum","Cmt","Paz"]
        } else {
            return ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
        }
    }

    private var lastSuggestionKey: String {
        "lastSmartSuggestionIndex_\(userID ?? "guest")"
    }

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
            events.filter { $0.weekday == weekday }
                .reduce(0) { $0 + $1.durationMinute }
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

            if hasCompletion {
                streak += 1
            } else {
                if offset == 0 {
                    continue
                }
                break
            }
        }

        return streak
    }

    private var overviewProgress: Double {
        let total = max(tasks.count, 1)
        return min(1, Double(completedTasks.count) / Double(total))
    }

    private func minutesText(_ minutes: Int) -> String {
        isTurkish ? "\(minutes) dk" : "\(minutes) min"
    }

    private func hoursMinutesText(_ total: Int) -> String {
        let h = total / 60
        let m = total % 60

        if isTurkish {
            return h > 0 ? "\(h) sa \(m) dk" : "\(m) dk"
        } else {
            return h > 0 ? "\(h)h \(m)m" : "\(m) min"
        }
    }

    var dailyBoost: DailyBoostData {
        if !activeTasks.isEmpty {
            return .init(
                title: isTurkish ? "⚡ Günlük Destek" : "⚡ Daily Boost",
                message: isTurkish
                    ? "Sadece bir görev daha bitirerek bugünü güçlü kapatabilirsin."
                    : "You can finish today strong by completing just one more task.",
                buttonTitle: isTurkish ? "Görevleri Aç" : "Open Tasks"
            )
        }

        if todayFocusMinutes < 20 {
            return .init(
                title: isTurkish ? "🔥 Harika İş" : "🔥 Great Job",
                message: isTurkish
                    ? "Ana hedeflerin bitti. İstersen kısa bir ekstra focus açıp ritmi koru."
                    : "Your main goals are done. You could keep the rhythm with one short extra focus session.",
                buttonTitle: isTurkish ? "Yeni Focus" : "New Focus"
            )
        }

        return .init(
            title: isTurkish ? "✨ Güzel Akış" : "✨ Nice Flow",
            message: isTurkish
                ? "Bugün iyi gidiyorsun. Aynı tempoyla devam et."
                : "You are doing well today. Keep going at the same pace.",
            buttonTitle: nil
        )
    }

    var overview: OverviewData {
        let progress = overviewProgress
        let status: String

        switch progress {
        case 0..<0.2:
            status = isTurkish ? "Ritmi başlat" : "Start your momentum"
        case 0.2..<0.5:
            status = isTurkish ? "Ritim oluşuyor" : "Getting momentum"
        case 0.5..<0.85:
            status = isTurkish ? "Güçlü ilerleme" : "Solid progress"
        default:
            status = isTurkish ? "Harika ilerleme" : "Great progress"
        }

        return .init(
            progress: progress,
            progressText: "%\(Int(progress * 100))",
            statusText: status,
            streakText: isTurkish ? "\(streakCount) gün seri" : "\(streakCount)-day streak",
            completedText: isTurkish ? "\(completedTasks.count) tamamlandı" : "\(completedTasks.count) completed",
            subtitle: isTurkish
                ? "Görev tamamlama oranı ve genel ilerleme"
                : "Task completion rate and overall progress"
        )
    }

    var weeklyProgress: WeeklyProgressData {
        let values = weeklyCompletedCounts
        let highlight = values.enumerated().max(by: { $0.element < $1.element })?.offset
        let summary = highlight.map {
            isTurkish
                ? "En üretken günün: \(dayLabels[$0])"
                : "Your most productive day: \(dayLabels[$0])"
        } ?? (isTurkish ? "Henüz veri yok" : "No data yet")

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
            InsightsHeatmapCell(
                level: level,
                date: nil,
                isSelected: index == 26
            )
        }

        return .init(
            cells: cells,
            title: isTurkish ? "Son 4 Hafta" : "Last 4 Weeks",
            subtitle: isTurkish ? "28 gün" : "28 days",
            selectedDayText: isTurkish
                ? "13 Mar, Cum • tamamlanan görev yok"
                : "13 Mar, Fri • no completed tasks"
        )
    }

    var focusInsights: FocusInsightsData {
        return .init(
            streakTitle: isTurkish
                ? "\(max(streakCount, 3)) Günlük Focus Serisi"
                : "\(max(streakCount, 3))-Day Focus Streak",
            streakSubtitle: streakCount > 0
                ? (isTurkish ? "İvme kazanıyorsun" : "You're building momentum")
                : (isTurkish ? "Ritmi başlatabilirsin" : "You can start the rhythm"),
            todayFocusMinutesText: minutesText(todayFocusMinutes),
            todaySessionsText: isTurkish
                ? "\(todayFocusSessions.count) session"
                : "\(todayFocusSessions.count) sessions",
            longestSessionText: isTurkish
                ? "En uzun session: \(minutesText(longestFocusMinutes))"
                : "Longest session: \(minutesText(longestFocusMinutes))"
        )
    }

    var productivityScore: ScoreCardData {
        let raw = min(100, Int((Double(completedTasks.count) * 18) + (Double(todayFocusMinutes) * 0.35)))
        let subtitle: String

        switch raw {
        case 0..<30:
            subtitle = isTurkish ? "Yeni başlıyorsun" : "You're just getting started"
        case 30..<60:
            subtitle = isTurkish ? "Daha iyi olabilir" : "Could be better"
        case 60..<80:
            subtitle = isTurkish ? "İyi gidiyorsun" : "You're doing well"
        default:
            subtitle = isTurkish ? "Harika performans" : "Great performance"
        }

        return .init(
            title: isTurkish ? "Üretkenlik Skoru" : "Productivity Score",
            valueText: "\(raw)/100",
            subtitle: subtitle,
            progress: Double(raw) / 100
        )
    }

    var consistencyScore: ScoreCardData {
        let activeDays = weeklyCompletedCounts.filter { $0 > 0 }.count
        let raw = min(100, activeDays * 14)
        let subtitle = raw < 30
            ? (isTurkish ? "Biraz daha düzen lazım" : "You need a bit more consistency")
            : (isTurkish ? "Daha dengeli gidiyorsun" : "You're getting more consistent")

        return .init(
            title: isTurkish ? "Tutarlılık Skoru" : "Consistency Score",
            valueText: "%\(raw)",
            subtitle: subtitle,
            progress: Double(raw) / 100
        )
    }

    var mostBusyDay: MostBusyDayData {
        guard let maxIndex = weeklyStudyMinutes.enumerated().max(by: { $0.element < $1.element })?.offset else {
            return .init(
                title: isTurkish ? "En Yoğun Gün" : "Most Busy Day",
                dayText: "-",
                durationText: minutesText(0),
                subtitle: isTurkish ? "Bu haftanın en yoğun günü" : "The busiest day of this week"
            )
        }

        let total = weeklyStudyMinutes[maxIndex]
        let duration = hoursMinutesText(total)

        return .init(
            title: isTurkish ? "En Yoğun Gün" : "Most Busy Day",
            dayText: dayLabels[maxIndex],
            durationText: duration,
            subtitle: isTurkish ? "Bu haftanın en yoğun günü" : "The busiest day of this week"
        )
    }

    private var activeTasksCount: Int {
        tasks.filter { !$0.isDone }.count
    }

    private var completedTasksCount: Int {
        tasks.filter { $0.isDone }.count
    }

    private var totalFocusSessionsCount: Int {
        focusSessions.count
    }

    private var totalFocusMinutes: Int {
        focusSessions.reduce(into: 0) { result, session in
            result += session.completedSeconds / 60
        }
    }

    private var hasStrongTaskMomentum: Bool {
        completedTasksCount >= 3
    }

    private var hasLowTaskMomentum: Bool {
        activeTasksCount >= 5 && completedTasksCount == 0
    }

    private var hasNoFocusToday: Bool {
        totalFocusSessionsCount == 0
    }

    private var bestDayLabel: String {
        if let index = weeklyProgress.highlightIndex,
           weeklyProgress.labels.indices.contains(index) {
            return weeklyProgress.labels[index]
        }
        return isTurkish ? "bu hafta" : "this week"
    }

    private var isEveningProductive: Bool {
        let eveningSessions = focusSessions.filter {
            let hour = Calendar.current.component(.hour, from: $0.startedAt)
            return hour >= 18
        }
        return eveningSessions.count >= max(1, focusSessions.count / 2)
    }

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
            suggestions.append(
                SmartSuggestionData(
                    title: isTurkish ? "Görev İçgörüsü" : "Task Insight",
                    message: isTurkish
                        ? "Aktif görevlerin birikmiş görünüyor. Önce en küçük görevi kapatmak ritim kazanmanı sağlayabilir."
                        : "Your active tasks seem to be piling up. Finishing the smallest task first may help you build momentum.",
                    buttonTitle: isTurkish ? "Görevleri Aç" : "Open Tasks",
                    action: .openTasks
                )
            )
        }

        if hasNoFocusHabit && activeTasksCount > 0 {
            suggestions.append(
                SmartSuggestionData(
                    title: isTurkish ? "Focus Önerisi" : "Focus Suggestion",
                    message: isTurkish
                        ? "Bugün henüz bir focus oturumu başlatmadın. 25 dakikalık kısa bir session iyi gelebilir."
                        : "You haven’t started a focus session today yet. A short 25-minute session could help.",
                    buttonTitle: isTurkish ? "Focus Başlat" : "Start Focus",
                    action: .openFocus
                )
            )
        }

        if hasStrongMomentum {
            suggestions.append(
                SmartSuggestionData(
                    title: isTurkish ? "Momentum İçgörüsü" : "Momentum Insight",
                    message: isTurkish
                        ? "Bugün ritim yakalamış görünüyorsun. Şimdi bir zor görevi bitirmek için iyi bir an olabilir."
                        : "You seem to have built momentum today. This might be a good time to finish a difficult task.",
                    buttonTitle: isTurkish ? "Görevleri Aç" : "Open Tasks",
                    action: .openTasks
                )
            )
        }

        suggestions.append(
            SmartSuggestionData(
                title: isTurkish ? "Desen İçgörüsü" : "Pattern Insight",
                message: isTurkish
                    ? "Bu hafta en verimli günün \(bestDayLabel). Önemli işlerini o güne yerleştirmek iyi sonuç verebilir."
                    : "Your most productive day this week is \(bestDayLabel). Scheduling important work on that day may help.",
                buttonTitle: isTurkish ? "Haftayı Gör" : "View Week",
                action: .openWeek
            )
        )

        if isEveningProductive {
            suggestions.append(
                SmartSuggestionData(
                    title: isTurkish ? "Focus Deseni" : "Focus Pattern",
                    message: isTurkish
                        ? "Akşam saatlerinde daha iyi odaklanıyor gibisin. Derin işlerini 18:00 sonrası planlamayı deneyebilirsin."
                        : "You seem to focus better in the evening. You could try planning deep work after 18:00.",
                    buttonTitle: isTurkish ? "Focus Başlat" : "Start Focus",
                    action: .openFocus
                )
            )
        }

        if totalFocusMinutes >= 90 {
            suggestions.append(
                SmartSuggestionData(
                    title: isTurkish ? "Derin Çalışma İçgörüsü" : "Deep Work Insight",
                    message: isTurkish
                        ? "Uzun focus oturumları sende işe yarıyor. Zor görevleri focus sonrası bloklara koymak verimini artırabilir."
                        : "Long focus sessions seem to work well for you. Putting hard tasks after focus blocks may boost productivity.",
                    buttonTitle: isTurkish ? "Haftayı Gör" : "View Week",
                    action: .openWeek
                )
            )
        }

        suggestions.append(
            SmartSuggestionData(
                title: isTurkish ? "Günlük Öneri" : "Daily Suggestion",
                message: isTurkish
                    ? "Küçük ama net bir görev tamamlamak günün geri kalanını daha verimli hale getirebilir."
                    : "Completing one small but clear task can make the rest of your day more productive.",
                buttonTitle: isTurkish ? "Görevleri Aç" : "Open Tasks",
                action: .openTasks
            )
        )

        return suggestions
    }

    var smartSuggestion: SmartSuggestionData {
        let suggestions = rotatedSuggestions()
        guard !suggestions.isEmpty else {
            return SmartSuggestionData(
                title: isTurkish ? "Öneri" : "Suggestion",
                message: isTurkish
                    ? "Bugün küçük bir görev tamamlamak iyi bir başlangıç olabilir."
                    : "Completing a small task today could be a good start.",
                buttonTitle: isTurkish ? "Görevleri Aç" : "Open Tasks",
                action: .openTasks
            )
        }

        let todayIndex = Calendar.current.component(.day, from: Date()) % suggestions.count
        let lastIndex = UserDefaults.standard.integer(forKey: lastSuggestionKey)

        var index = todayIndex

        if suggestions.count > 1 && index == lastIndex {
            index = (index + 1) % suggestions.count
        }

        UserDefaults.standard.set(index, forKey: lastSuggestionKey)

        return suggestions[index]
    }

    var aiCoach: AICoachData {
        if totalFocusMinutes >= 60 && completedTasksCount >= 2 {
            return AICoachData(
                title: isTurkish ? "Yapay Zekâ Üretkenlik Koçu" : "AI Productivity Coach",
                message: isTurkish
                    ? "Focus sonrası görev kapatma hızın artıyor gibi görünüyor. Önce kısa bir focus sonra zor görev iyi çalışabilir."
                    : "You seem to complete tasks faster after focus sessions. A short focus first, then a hard task, may work well.",
                buttonTitle: isTurkish ? "Focus Başlat" : "Start Focus",
                action: .openFocus
            )
        }

        if let index = weeklyProgress.highlightIndex,
           weeklyProgress.labels.indices.contains(index) {

            let bestDay = weeklyProgress.labels[index]

            return AICoachData(
                title: isTurkish ? "Yapay Zekâ Üretkenlik Koçu" : "AI Productivity Coach",
                message: isTurkish
                    ? "\(bestDay) günü daha verimli görünüyorsun. Önemli işlerini o güne koymayı deneyebilirsin."
                    : "You seem more productive on \(bestDay). You could try scheduling important work on that day.",
                buttonTitle: isTurkish ? "Haftayı Gör" : "View Week",
                action: .openWeek
            )
        }

        return AICoachData(
            title: isTurkish ? "Yapay Zekâ Üretkenlik Koçu" : "AI Productivity Coach",
            message: isTurkish
                ? "Küçük görevleri hızlı kapatıp zor görevleri focus sonrası yapmak verimini artırabilir."
                : "Quickly finishing small tasks and doing hard tasks after focus sessions may improve your productivity.",
            buttonTitle: isTurkish ? "Görevleri Aç" : "Open Tasks",
            action: .openTasks
        )
    }
}
