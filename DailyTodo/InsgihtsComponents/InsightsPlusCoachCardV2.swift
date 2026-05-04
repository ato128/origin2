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

    private var accent: Color {
        data.tint
    }

    private var secondaryAccent: Color {
        Color(arenaHex: AppArenaPalette.purple)
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 14) {
                premiumIcon

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(accent)
                            .frame(width: 16, height: 1)

                        Text("INSIGHTS+ COACH")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.5)
                            .foregroundStyle(accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }

                    Text(data.title)
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text(data.subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.52))
                        .lineLimit(2)

                    progressHint
                }

                Spacer(minLength: 8)

                Button {
                    action(data.action)
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.black)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(accent)
                                .shadow(color: accent.opacity(0.22), radius: 10, y: 5)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(premiumBackground)
        }
        .buttonStyle(.plain)
    }

    private var premiumIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.14),
                            secondaryAccent.opacity(0.08),
                            Color.white.opacity(0.035)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 66, height: 66)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(accent.opacity(0.16), lineWidth: 1)
                )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accent.opacity(0.30),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 42
                    )
                )
                .frame(width: 58, height: 58)

            Image(systemName: data.symbol)
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.22), radius: 8)
        }
    }

    private var progressHint: some View {
        HStack(spacing: 5) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index < 4 ? accent.opacity(0.95) : Color.white.opacity(0.16))
                    .frame(width: 5, height: 5)
            }

            Text(data.hint.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(.white.opacity(0.46))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.leading, 4)
        }
    }

    private var premiumBackground: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.085),
                        secondaryAccent.opacity(0.045),
                        Color(arenaHex: AppArenaPalette.surface).opacity(0.94)
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
                                accent.opacity(0.15),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: 160
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(arenaHex: AppArenaPalette.blue).opacity(0.08),
                                Color.clear
                            ],
                            center: .bottomTrailing,
                            startRadius: 8,
                            endRadius: 180
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(accent.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 16, y: 9)
    }
}
