//
//  InsightsStudentModels.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 4.04.2026.
//

import Foundation
import SwiftUI

struct StudentInsightHeroData {
    let title: String
    let subtitle: String
    let primaryMetric: String
    let primaryLabel: String
    let chip1: String
    let chip2: String
    let chip3: String
    let accent: Color
    let actionTitle: String
    let action: SmartSuggestionAction
}

struct ExamReadinessRowData: Identifiable {
    let id = UUID()
    let examTitle: String
    let countdownText: String
    let readinessText: String
    let readinessProgress: Double
    let studyMinutesText: String
    let accent: Color
    let action: SmartSuggestionAction
}

struct ExamReadinessData {
    let title: String
    let subtitle: String
    let rows: [ExamReadinessRowData]
    let emptyTitle: String
    let emptySubtitle: String
}

struct CourseBalanceRowData: Identifiable {
    let id = UUID()
    let courseName: String
    let minutesText: String
    let taskText: String
    let progress: Double
    let statusText: String
    let accent: Color
}

struct CourseBalanceData {
    let title: String
    let subtitle: String
    let rows: [CourseBalanceRowData]
    let emptyTitle: String
}

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

struct StudyPatternData {
    let title: String
    let subtitle: String
    let bestDayText: String
    let bestTimeText: String
    let avgFocusText: String
    let patternInsightText: String
}
