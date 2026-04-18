//
//  InsightsPlusModels.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//

import SwiftUI

struct InsightsPlusCoachCardData {
    let title: String
    let subtitle: String
    let hint: String
    let symbol: String
    let tint: Color
    let actionTitle: String
    let action: SmartSuggestionAction
}

struct InsightsPlusStudyWindowCardData {
    let title: String
    let timeText: String
    let confidenceText: String
    let summary: String
    let symbol: String
    let tint: Color
    let actionTitle: String
    let action: SmartSuggestionAction
}

struct InsightsPlusWeeklySignalCardData {
    let title: String
    let strongestDay: String
    let weakestDay: String
    let trendText: String
    let values: [CGFloat]
    let highlightIndex: Int
    let tint: Color
    let actionTitle: String
    let action: SmartSuggestionAction
}
