//
//  WeeklyProgressCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI

struct WeeklyProgressCard: View {
    let data: WeeklyProgressData

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    @State private var isVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Weekly Progress")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(palette.primaryText)

                Spacer()

                Text("7 gün")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(data.values.enumerated()), id: \.offset) { index, value in
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(
                                index == data.highlightIndex
                                ? Color.accentColor
                                : palette.secondaryCardFill
                            )
                            .frame(height: isVisible ? max(14, CGFloat(value) * 30) : 10)
                            .scaleEffect(y: isVisible ? 1 : 0.88, anchor: .bottom)
                            .shadow(
                                color: index == data.highlightIndex
                                    ? Color.accentColor.opacity(isVisible ? 0.18 : 0)
                                    : .clear,
                                radius: 6
                            )
                            .animation(
                                .spring(response: 0.55, dampingFraction: 0.82)
                                    .delay(Double(index) * 0.04),
                                value: isVisible
                            )

                        Text(data.labels[index])
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(palette.secondaryText)

                        CountUpText(
                            value: Double(value),
                            duration: 0.7,
                            trigger: isVisible,
                            formatter: { "\(Int($0))" }
                        )
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 118, alignment: .bottom)

            Text(data.summaryText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.secondaryText)
        }
        .padding(18)
        .background(cardBackground)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.985)
        .offset(y: isVisible ? 0 : 12)
        .animation(.spring(response: 0.48, dampingFraction: 0.86), value: isVisible)
        .animateWhenVisible($isVisible)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }
}
