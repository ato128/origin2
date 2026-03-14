//
//  MostBusyCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//
import SwiftUI

struct MostBusyDayCard: View {

    let data: MostBusyDayData

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    @State private var isVisible = false

    var body: some View {

        VStack(alignment: .leading, spacing: 8) {

            Text(data.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.primaryText)

            Text(data.dayText)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            Text(data.durationText)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(palette.secondaryText)

            Text(data.subtitle)
                .font(.system(size: 14))
                .foregroundStyle(palette.secondaryText)
        }
        .padding(18)
        .background(cardBackground)
        .animateWhenVisible($isVisible)
        .subtleParallax()
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }
}
