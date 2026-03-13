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

    private let calendar = Calendar.current
    private let dayLabels = ["Pzt","Sal","Çar","Per","Cum","Cmt","Paz"]

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

    var dailyBoost: DailyBoostData {
        if !activeTasks.isEmpty {
            return .init(
                title: "⚡ Daily Boost",
                message: "Sadece bir görev daha bitirerek bugünü güçlü kapatabilirsin.",
                buttonTitle: "Open Tasks"
            )
        }

        if todayFocusMinutes < 20 {
            return .init(
                title: "🔥 Great Job",
                message: "Ana hedeflerin bitti. İstersen kısa bir ekstra focus açıp ritmi koru.",
                buttonTitle: "New Focus"
            )
        }

        return .init(
            title: "✨ Nice Flow",
            message: "Bugün iyi gidiyorsun. Aynı tempoyla devam et.",
            buttonTitle: nil
        )
    }

    var overview: OverviewData {
        let progress = overviewProgress
        let status: String

        switch progress {
        case 0..<0.2: status = "Start your momentum"
        case 0.2..<0.5: status = "Getting momentum"
        case 0.5..<0.85: status = "Solid progress"
        default: status = "Great progress"
        }

        return .init(
            progress: progress,
            progressText: "%\(Int(progress * 100))",
            statusText: status,
            streakText: "\(streakCount) gün seri",
            completedText: "\(completedTasks.count) tamamlandı",
            subtitle: "Görev tamamlama oranı ve genel ilerleme"
        )
    }

    var weeklyProgress: WeeklyProgressData {
        let values = weeklyCompletedCounts
        let highlight = values.enumerated().max(by: { $0.element < $1.element })?.offset
        let summary = highlight.map { "En üretken günün: \(dayLabels[$0])" } ?? "Henüz veri yok"

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
            title: "Last 4 Weeks",
            subtitle: "28 gün",
            selectedDayText: "13 Mar, Cum • tamamlanan görev yok"
        )
    }

    var focusInsights: FocusInsightsData {
        return .init(
            streakTitle: "\(max(streakCount, 3)) Günlük Focus Serisi",
            streakSubtitle: streakCount > 0 ? "İvme kazanıyorsun" : "Ritmi başlatabilirsin",
            todayFocusMinutesText: "\(todayFocusMinutes) dk",
            todaySessionsText: "\(todayFocusSessions.count) session",
            longestSessionText: "En uzun session: \(longestFocusMinutes) dk"
        )
    }

    var productivityScore: ScoreCardData {
        let raw = min(100, Int((Double(completedTasks.count) * 18) + (Double(todayFocusMinutes) * 0.35)))
        let subtitle: String

        switch raw {
        case 0..<30: subtitle = "Yeni başlıyorsun"
        case 30..<60: subtitle = "Daha iyi olabilir"
        case 60..<80: subtitle = "İyi gidiyorsun"
        default: subtitle = "Harika performans"
        }

        return .init(
            title: "Productivity Score",
            valueText: "\(raw)/100",
            subtitle: subtitle,
            progress: Double(raw) / 100
        )
    }

    var consistencyScore: ScoreCardData {
        let activeDays = weeklyCompletedCounts.filter { $0 > 0 }.count
        let raw = min(100, activeDays * 14)
        let subtitle = raw < 30 ? "Biraz daha düzen lazım" : "Daha dengeli gidiyorsun"

        return .init(
            title: "Consistency Score",
            valueText: "%\(raw)",
            subtitle: subtitle,
            progress: Double(raw) / 100
        )
    }

    var mostBusyDay: MostBusyDayData {
        guard let maxIndex = weeklyStudyMinutes.enumerated().max(by: { $0.element < $1.element })?.offset else {
            return .init(
                title: "Most Busy Day",
                dayText: "-",
                durationText: "0 dk",
                subtitle: "Bu haftanın en yoğun günü"
            )
        }

        let total = weeklyStudyMinutes[maxIndex]
        let h = total / 60
        let m = total % 60
        let duration = h > 0 ? "\(h)s \(m)dk" : "\(m)dk"

        return .init(
            title: "Most Busy Day",
            dayText: dayLabels[maxIndex],
            durationText: duration,
            subtitle: "Bu haftanın en yoğun günü"
        )
    }

    var smartSuggestion: SmartSuggestionData {
        if !activeTasks.isEmpty {
            return .init(
                title: "Smart Suggestion",
                message: "Aktif görevlerinden birini bitirerek bugününü daha güçlü kapatabilirsin.",
                buttonTitle: "Open Tasks"
            )
        }

        if todayFocusMinutes < 15 {
            return .init(
                title: "Smart Suggestion",
                message: "15 dakikalık kısa bir focus, bugünkü ritmi korumana yardımcı olabilir.",
                buttonTitle: "Start Focus"
            )
        }

        return .init(
            title: "Smart Suggestion",
            message: "Bugün iyi gidiyorsun. Ritmi korumak için küçük bir adım daha atabilirsin.",
            buttonTitle: nil
        )
    }
}
