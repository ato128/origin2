//
//  InsightsWeeklySignalDetailModels.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//

import SwiftUI

struct WeeklySignalDayDetail: Identifiable {
    let id = UUID()
    let label: String
    let completedCount: Int
    let focusMinutes: Int
    let value: CGFloat
    let isHighlight: Bool
}

struct InsightsWeeklySignalDetailData {
    let title: String
    let subtitle: String

    let strongestDay: String
    let weakestDay: String
    let trendSummary: String

    let completionTotalText: String
    let focusTotalText: String
    let streakText: String

    let days: [WeeklySignalDayDetail]
}
