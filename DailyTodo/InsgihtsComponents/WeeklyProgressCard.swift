//
//  WeeklyProgressCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI

struct WeeklyProgressCard: View {
    let data: WeeklyProgressData

    @State private var isVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Weekly Progress")
                    .font(.system(size: 17, weight: .bold))

                Spacer()

                Text("7 gün")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(data.values.enumerated()), id: \.offset) { index, value in
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(index == data.highlightIndex ? Color.accentColor : Color.white.opacity(0.08))
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
                            .foregroundStyle(.secondary)

                        CountUpText(
                            value: Double(value),
                            duration: 0.7,
                            trigger: isVisible,
                            formatter: { "\(Int($0))" }
                        )
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 118, alignment: .bottom)

            Text(data.summaryText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
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
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
    }
}
