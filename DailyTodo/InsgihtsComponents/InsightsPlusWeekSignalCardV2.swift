//
//  InsightsPlusWeekSignalCardV2.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//

import SwiftUI

struct InsightsPlusWeeklySignalCardV2: View {
    let data: InsightsPlusWeeklySignalCardData
    let action: (SmartSuggestionAction) -> Void
    let onTap: () -> Void

    private let labels = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]

    var body: some View {
        Button {
            onTap()
        } label: {
            InsightsGlassCard(
                cornerRadius: 30,
                tint: data.tint,
                glowOpacity: 0.12,
                fillOpacity: 0.10,
                strokeOpacity: 0.08
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Weekly Signal")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.56))

                            Text(data.trendText)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                        }

                        Spacer()

                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white.opacity(0.78))
                    }

                    HStack(alignment: .bottom, spacing: 10) {
                        ForEach(0..<min(data.values.count, labels.count), id: \.self) { index in
                            VStack(spacing: 8) {
                                Capsule()
                                    .fill(index == data.highlightIndex ? .white.opacity(0.94) : .white.opacity(0.18))
                                    .frame(
                                        width: index == data.highlightIndex ? 38 : 28,
                                        height: max(10, data.values[index] * 52)
                                    )

                                Text(labels[index])
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.56))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 96)

                    HStack(spacing: 8) {
                        statPill("Strongest \(data.strongestDay)")
                        statPill("Weakest \(data.weakestDay)")
                    }

                    HStack {
                        Button {
                            action(data.action)
                        } label: {
                            Text(data.actionTitle)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(Color.white.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.52))
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func statPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.82))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.08), in: Capsule())
    }
}
