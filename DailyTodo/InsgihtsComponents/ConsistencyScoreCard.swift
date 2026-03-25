//
//  ConsistencyScoreCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI

struct ConsistencyScoreCard: View {
    let data: ScoreCardData

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    @State private var isVisible = false

    private var scoreValue: Double {
        Double(data.valueText.replacingOccurrences(of: "%", with: "")) ?? 0
    }

    private func percentText(_ value: Double) -> String {
        "%\(Int(value))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(data.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.primaryText)

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        CountUpText(
                            value: scoreValue,
                            duration: 0.9,
                            trigger: isVisible,
                            formatter: { percentText($0) }
                        )
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                    }

                    Text(data.subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer()

                ZStack {
                    ProgressRing(
                        progress: data.progress,
                        color: .green,
                        lineWidth: 10,
                        trigger: isVisible
                    )

                    CountUpText(
                        value: scoreValue,
                        duration: 0.9,
                        trigger: isVisible,
                        formatter: { "\(Int($0))" }
                    )
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(palette.primaryText)
                }
                .frame(width: 82, height: 82)
            }
        }
        .padding(18)
        .background(cardBackground)
        .animateWhenVisible($isVisible)
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
