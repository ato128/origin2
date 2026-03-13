//
//  MostBusyCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI

struct MostBusyDayCard: View {

    let data: MostBusyDayData
    @State private var isVisible = false

    var body: some View {

        VStack(alignment: .leading, spacing: 8) {

            Text(data.title)
                .font(.system(size: 16, weight: .semibold))

            Text(data.dayText)
                .font(.system(size: 32, weight: .bold, design: .rounded))

            Text(data.durationText)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            Text(data.subtitle)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(cardBackground)
        .animateWhenVisible($isVisible)
        .subtleParallax()
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.07))
            )
    }
}
