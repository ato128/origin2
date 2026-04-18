//
//  InsightsModels.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI

// MARK: - Actions

enum SmartSuggestionAction {
    case openTasks
    case openWeek
    case openFocus
    case none
}

// MARK: - Legacy bridge models used by ViewModel

struct SmartSuggestionData {
    let title: String
    let message: String
    let buttonTitle: String
    let action: SmartSuggestionAction
}

struct AICoachData {
    let title: String
    let message: String
    let buttonTitle: String
    let action: SmartSuggestionAction
}

// MARK: - Hero

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

// MARK: - Weekly Momentum

struct WeeklyMomentumData {
    let title: String
    let subtitle: String

    let labels: [String]
    let values: [Int]
    let highlightIndex: Int?

    let summaryText: String

    let completionText: String
    let focusText: String
    let streakText: String
}

// MARK: - V2 Models

struct InsightsCoachUnifiedData {
    let eyebrow: String
    let title: String
    let message: String
    let actionTitle: String
    let action: SmartSuggestionAction
    let secondaryHint: String?
}

struct InsightsIdentityData {
    let title: String
    let subtitle: String
    let level: Int
    let progress: Double
    let progressText: String
    let traits: [String]
    let accent: Color
}

struct InsightsBadgeData: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let isUnlocked: Bool
    let progress: Double?
    let accent: Color
}

struct InsightsMiniStatData: Identifiable {
    let id = UUID()
    let value: String
    let label: String
    let hint: String
    let accent: Color
}

struct InsightsPremiumPreviewData {
    let title: String
    let subtitle: String
    let bullets: [String]
    let buttonTitle: String
}
