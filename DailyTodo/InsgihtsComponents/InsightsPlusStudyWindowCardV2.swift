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

    private var secondaryAccent: Color {
        Color(red: 0.03, green: 0.18, blue: 0.36)
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Best Study Window")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(data.tint.opacity(0.98))
                            .tracking(0.7)

                        Text(data.timeText)
                            .font(.system(size: 29, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)

                        Text(data.confidenceText)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.66))
                    }

                    Spacer()

                    radialWindow
                }

                Text(data.summary)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
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
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.52))
                }
            }
            .padding(16)
            .background(premiumBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var radialWindow: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                .frame(width: 88, height: 88)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            data.tint.opacity(0.24),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 46
                    )
                )
                .frame(width: 88, height: 88)

            Circle()
                .trim(from: 0.18, to: 0.82)
                .stroke(
                    LinearGradient(
                        colors: [
                            data.tint.opacity(0.98),
                            Color.white.opacity(0.88)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(130))
                .frame(width: 68, height: 68)
                .shadow(color: data.tint.opacity(0.18), radius: 10)

            Image(systemName: data.symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white.opacity(0.90))
                .shadow(color: data.tint.opacity(0.22), radius: 6)
        }
    }

    private var premiumBackground: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        data.tint.opacity(0.34),
                        data.tint.opacity(0.16),
                        secondaryAccent.opacity(0.62),
                        Color(red: 0.035, green: 0.035, blue: 0.070)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                data.tint.opacity(0.24),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: 150
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.075),
                                Color.clear,
                                Color.black.opacity(0.18)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
    }
}
