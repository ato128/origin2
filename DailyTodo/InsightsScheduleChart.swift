//
//  InsightsScheduleChart.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 5.03.2026.
//

import SwiftUI
import Charts

struct InsightsScheduleChart: View {
    let events: [EventItem]

    var body: some View {
        let data = InsightsEngine.weeklyMinutes(events: events)

        Chart(data) { item in
            BarMark(
                x: .value("Gün", InsightsEngine.dayName(item.dayIndex)),
                y: .value("Dakika", item.minutes)
            )
        }
        .frame(height: 220)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
