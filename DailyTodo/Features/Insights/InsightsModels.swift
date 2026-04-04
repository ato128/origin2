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
import SwiftUI

// MARK: - Study Insights Premium Models

enum StudyHeroMode {
    case exams
    case courses
    case rhythm
    case empty
}

struct StudyHeroData {
    let mode: StudyHeroMode
    let title: String
    let subtitle: String
    let primaryValue: String
    let primaryLabel: String
    let chip1: String
    let chip2: String
    let chip3: String
    let accent: Color
    let actionTitle: String
    let action: SmartSuggestionAction
}

enum StudyDeckPage: String, CaseIterable, Identifiable {
    case exams
    case courses
    case rhythm

    var id: String { rawValue }
}

struct StudyInsightsDeckData {
    let pages: [StudyInsightsDeckPageData]
}

struct StudyInsightsDeckPageData: Identifiable {
    let id = UUID()
    let page: StudyDeckPage
    let title: String
    let subtitle: String
    let primaryValue: String
    let primaryLabel: String
    let secondaryValue: String
    let secondaryLabel: String
    let statusText: String
    let accent: Color
    let progress: Double
    let chips: [StudyDeckChip]
    let ctaTitle: String
    let action: SmartSuggestionAction
    let emptyTitle: String?
    let emptySubtitle: String?
    let emptyButtonTitle: String?
    let isEmpty: Bool
}

struct StudyDeckChip: Identifiable {
    let id = UUID()
    let text: String
    let tint: Color
}

struct StudyQuickActionData: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let tint: Color
    let action: SmartSuggestionAction
}

struct StudyUnlockPromptData {
    let title: String
    let subtitle: String
    let progressText: String
    let progress: Double
    let actionTitle: String
    let action: SmartSuggestionAction
}
