//
//  InsightsModels.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import Foundation

struct DailyBoostData {
    let title: String
    let message: String
    let buttonTitle: String?
}

struct OverviewData {
    let progress: Double
    let progressText: String
    let statusText: String
    let streakText: String
    let completedText: String
    let subtitle: String
}

struct WeeklyProgressData {
    let values: [Int]
    let labels: [String]
    let highlightIndex: Int?
    let summaryText: String
}

struct InsightsHeatmapCell: Identifiable {
    let id = UUID()
    let level: Int
    let date: Date?
    let isSelected: Bool
}

struct StudyHeatmapData {
    let cells: [InsightsHeatmapCell]
    let title: String
    let subtitle: String
    let selectedDayText: String
}

struct FocusInsightsData {
    let streakTitle: String
    let streakSubtitle: String
    let todayFocusMinutesText: String
    let todaySessionsText: String
    let longestSessionText: String
}

struct ScoreCardData {
    let title: String
    let valueText: String
    let subtitle: String
    let progress: Double
}

struct MostBusyDayData {
    let title: String
    let dayText: String
    let durationText: String
    let subtitle: String
}

struct SmartSuggestionData {
    let title: String
    let message: String
    let buttonTitle: String?
    let action: SmartSuggestionAction
}

enum SmartSuggestionAction {
    case openTasks
    case openFocus
    case openWeek
    case none
}
