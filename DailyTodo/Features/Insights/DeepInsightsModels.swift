//
//  DeepInsightsModels.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//

import SwiftUI

struct DeepInsightsHeroData {
    let title: String
    let subtitle: String
    let primaryValue: String
    let primaryLabel: String
    let chip1: String
    let chip2: String
}

struct BestStudyWindowData {
    let timeRange: String
    let confidenceText: String
    let summary: String
    let accent: Color
}

struct WeeklyDeepReviewData {
    let strongestDay: String
    let weakestDay: String
    let deltaText: String
    let recommendation: String
}

struct IdentityEvolutionData {
    let currentIdentity: String
    let nextIdentity: String
    let progressText: String
    let progress: Double
}

struct ExamReadinessProRow: Identifiable {
    let id = UUID()
    let title: String
    let readinessText: String
    let progress: Double
    let riskText: String
    let accent: Color
}

struct PatternAlertData: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let icon: String
    let tint: Color
}
