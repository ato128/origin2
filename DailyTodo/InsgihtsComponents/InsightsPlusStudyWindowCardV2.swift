//
//  InsightsPlusStudyWindowCardV2.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//

import SwiftUI

struct InsightsPlusStudyWindowCardV2: View {
    let data: InsightsPlusStudyWindowCardData
    let action: (SmartSuggestionAction) -> Void
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            InsightsGlassCard(
                cornerRadius: 30,
                tint: data.tint,
                glowOpacity: 0.14,
                fillOpacity: 0.12,
                strokeOpacity: 0.08
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Best Study Window")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.56))

                            Text(data.timeText)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Text(data.confidenceText)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white.opacity(0.66))
                        }

                        Spacer()

                        radialWindow
                    }

                    Text(data.summary)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.74))
                        .lineLimit(2)

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

    private var radialWindow: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                .frame(width: 86, height: 86)

            Circle()
                .trim(from: 0.18, to: 0.82)
                .stroke(
                    LinearGradient(
                        colors: [data.tint.opacity(0.95), .white.opacity(0.88)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(130))
                .frame(width: 68, height: 68)

            Image(systemName: data.symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white.opacity(0.88))
        }
    }
}
