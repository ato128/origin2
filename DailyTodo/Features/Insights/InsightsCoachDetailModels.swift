//
//  File.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//

import SwiftUI

struct InsightsCoachActionRow: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let intensity: String
    let symbol: String
    let tint: Color
    let action: SmartSuggestionAction
}

struct InsightsCoachDetailData {
    let headline: String
    let summary: String
    let confidenceText: String
    let confidenceLevel: Int   // 0...5

    let todayDirectionTitle: String
    let todayDirectionSubtitle: String

    let strongestSignal: String
    let blockingSignal: String
    let recommendationReason: String

    let actionRows: [InsightsCoachActionRow]
}
