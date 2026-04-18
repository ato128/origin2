//
//  InsightsStudyWindowDetailedModels.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//

import SwiftUI

struct StudyWindowCourseBreakdownRow: Identifiable {
    let id = UUID()
    let courseName: String
    let minutes: Int
    let progress: Double
    let accent: Color
    let focusQualityText: String
}

struct InsightsStudyWindowDetailData {
    let timeRangeText: String
    let confidenceText: String
    let summaryText: String

    let strongestCourse: String
    let neglectedCourse: String
    let recommendedCourse: String
    let recommendationReason: String

    let rows: [StudyWindowCourseBreakdownRow]
}
