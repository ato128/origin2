//
//  InsightsPlusCoachCardV2.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//

import SwiftUI

struct InsightsPlusCoachCardV2: View {
    let data: InsightsPlusCoachCardData
    let action: (SmartSuggestionAction) -> Void
    let onTap: () -> Void

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
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(data.tint.opacity(0.16))
                            .frame(width: 66, height: 66)

                        Image(systemName: data.symbol)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white.opacity(0.90))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Insights+ Coach")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.56))

                        Text(data.title)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        Text(data.subtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.70))
                            .lineLimit(2)

                        HStack(spacing: 5) {
                            ForEach(0..<5, id: \.self) { index in
                                Circle()
                                    .fill(index < 4 ? .white.opacity(0.82) : .white.opacity(0.18))
                                    .frame(width: 5, height: 5)
                            }

                            Text(data.hint)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.54))
                                .padding(.leading, 4)
                        }
                    }

                    Spacer()

                    HStack(spacing: 10) {
                        Button {
                            action(data.action)
                        } label: {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.42))
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
