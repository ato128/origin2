//
//  WeeklyMomentumCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 4.04.2026.
//

import SwiftUI

struct WeeklyMomentumCard: View {
    let data: WeeklyMomentumData

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(data.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text(data.subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(data.values.enumerated()), id: \.offset) { index, value in
                    VStack(spacing: 8) {
                        Text("\(value)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()

                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(index == data.highlightIndex ? Color.accentColor : Color.accentColor.opacity(0.28))
                            .frame(height: max(14, CGFloat(value) * 16))

                        Text(data.labels[index])
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .bottom)
                }
            }
            .frame(height: 150)

            HStack(spacing: 8) {
                statPill(data.completionText, tint: .green)
                statPill(data.focusText, tint: .blue)
                statPill(data.streakText, tint: .orange)
            }

            Text(data.summaryText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(cardBackground)
    }

    private func statPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}
