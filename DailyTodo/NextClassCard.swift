//
//  NextClassCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 5.03.2026.
//

import SwiftUI

struct NextClassCard: View {
    let next: DTNextClassResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next Class")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(next.event.title)
                .font(.headline)
                .lineLimit(1)

            if next.isOngoing {
                Text(timerInterval: Date()...next.endDate, countsDown: true)
                    .monospacedDigit()
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                Text("Ders bitimine")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(timerInterval: Date()...next.startDate, countsDown: true)
                    .monospacedDigit()
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                Text("Başlamasına")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
