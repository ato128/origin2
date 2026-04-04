//
//  StudentInsightsHeroCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 4.04.2026.
//

import SwiftUI

struct StudentInsightHeroCard: View {
    let data: StudentInsightHeroData
    let onTap: (SmartSuggestionAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(data.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(data.subtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(data.primaryMetric)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(data.accent)
                        .monospacedDigit()

                    Text(data.primaryLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }

            HStack(spacing: 8) {
                heroChip(data.chip1, tint: data.accent)
                heroChip(data.chip2, tint: .blue)
                heroChip(data.chip3, tint: .orange)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Bugünkü durum")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(data.primaryMetric)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(data.accent)
                        .monospacedDigit()
                }

                ProgressView(value: heroProgressValue)
                    .tint(data.accent)

                Text(helperText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(data.accent.opacity(0.10), lineWidth: 1)
                    )
            )

            Button {
                onTap(data.action)
            } label: {
                HStack {
                    Text(data.actionTitle)
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(data.accent)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(cardBackground)
    }

    private var heroProgressValue: Double {
        let numeric = Double(data.primaryMetric.filter(\.isNumber)) ?? 0
        if data.primaryMetric.contains("%") {
            return min(max(numeric / 100, 0), 1)
        }
        if numeric == 0 { return 0.08 }
        return min(max(numeric / 180, 0.08), 1)
    }

    private var helperText: String {
        if data.primaryMetric.contains("0") {
            return "Küçük bir başlangıç yaparsan ekran daha güçlü görünmeye başlar."
        }
        return "Bugünkü ritmin oluşuyor. Bir adım daha atarsan tablo netleşecek."
    }

    private func heroChip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
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
                    .fill(
                        RadialGradient(
                            colors: [
                                data.accent.opacity(0.14),
                                Color.clear
                            ],
                            center: .topTrailing,
                            startRadius: 10,
                            endRadius: 260
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(data.accent.opacity(0.16), lineWidth: 1)
            )
    }
}
