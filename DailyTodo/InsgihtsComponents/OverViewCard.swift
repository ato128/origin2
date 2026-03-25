//
//  OverViewCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI

struct OverviewCard: View {
    let data: OverviewData

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    @State private var isVisible = false
    @State private var animatedProgress: Double = 0
    @State private var flamePulse = false
    @State private var emberDrift = false

    private var hasStarted: Bool {
        data.progress > 0 || !data.completedText.contains("0")
    }

    private var hasStrongStreak: Bool {
        let lower = data.streakText.lowercased()
        return !lower.contains("0")
    }

    private var headerTitle: String {
        hasStrongStreak
        ? String(localized: "insights_overview_streak")
        : String(localized: "insights_overview_getting_started")
    }

    private var headerStatusText: String {
        hasStrongStreak
        ? String(localized: "insights_overview_keep_fire_alive")
        : String(localized: "insights_overview_start_streak")
    }

    private var flameColor: Color {
        hasStrongStreak ? .orange : .gray.opacity(0.85)
    }

    private var glowOpacity: Double {
        hasStrongStreak ? 0.30 : 0.12
    }

    private var fallbackMessage: String {
        String(localized: "insights_overview_fallback_message")
    }

    private var completionText: String {
        String(localized: "insights_overview_completion")
    }

    private var startStreakHint: String {
        String(localized: "insights_overview_start_streak_hint")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(flameColor.opacity(hasStrongStreak ? 0.16 : 0.10))
                        .frame(width: 42, height: 42)
                        .shadow(
                            color: flameColor.opacity(glowOpacity),
                            radius: hasStrongStreak && flamePulse ? 14 : 6
                        )

                    if hasStrongStreak {
                        Circle()
                            .fill(Color.orange.opacity(0.20))
                            .frame(width: 10, height: 10)
                            .blur(radius: 2)
                            .offset(x: emberDrift ? 8 : 3, y: emberDrift ? -16 : -8)
                            .opacity(emberDrift ? 0.0 : 0.9)

                        Circle()
                            .fill(Color.yellow.opacity(0.18))
                            .frame(width: 7, height: 7)
                            .blur(radius: 2)
                            .offset(x: emberDrift ? -6 : -2, y: emberDrift ? -18 : -10)
                            .opacity(emberDrift ? 0.0 : 0.8)
                    }

                    Image(systemName: "flame.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(
                            hasStrongStreak
                            ? LinearGradient(
                                colors: [.yellow, .orange, .red],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            : LinearGradient(
                                colors: [flameColor, flameColor],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(hasStrongStreak && flamePulse ? 1.08 : 1.0)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(headerTitle)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Text(headerStatusText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer()

                Text(data.statusText)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(
                                hasStrongStreak
                                ? Color.orange.opacity(0.16)
                                : palette.secondaryCardFill
                            )
                    )
                    .foregroundStyle(hasStrongStreak ? Color.orange : palette.secondaryText)
            }

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                CountUpText(
                    value: data.progress * 100,
                    duration: 0.9,
                    trigger: isVisible,
                    formatter: { "%\(Int($0))" }
                )
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

                Text(completionText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(palette.secondaryCardFill)
                        .frame(height: 9)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: hasStrongStreak
                                ? [Color.orange.opacity(0.95), Color.accentColor]
                                : [Color.accentColor.opacity(0.85), Color.accentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(animatedProgress > 0.001 ? 20 : 0, geo.size.width * animatedProgress),
                            height: 9
                        )
                        .shadow(
                            color: (hasStrongStreak ? Color.orange : Color.accentColor).opacity(0.22),
                            radius: 8
                        )
                        .overlay(alignment: .trailing) {
                            Circle()
                                .fill(
                                    palette.isLight
                                    ? Color.black.opacity(0.10)
                                    : Color.white.opacity(0.22)
                                )
                                .frame(width: 10, height: 10)
                                .blur(radius: 2)
                                .opacity(animatedProgress > 0.02 ? 1 : 0)
                        }
                }
            }
            .frame(height: 9)

            HStack(spacing: 10) {
                pill(
                    text: data.streakText,
                    icon: "flame.fill",
                    tint: hasStrongStreak ? .orange : palette.secondaryText
                )

                pill(
                    text: data.completedText,
                    icon: "checkmark.circle.fill",
                    tint: .green
                )
            }

            if hasStarted {
                Text(data.subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(palette.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text(fallbackMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.secondaryText)

                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.accentColor)

                        Text(startStreakHint)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.14))
                    )
                }
                .padding(.top, 2)
            }
        }
        .padding(18)
        .background(cardBackground)
        .animateWhenVisible($isVisible)
        .onChange(of: isVisible) { _, newValue in
            guard newValue else { return }

            withAnimation(.spring(response: 0.9, dampingFraction: 0.85)) {
                animatedProgress = data.progress
            }

            if hasStrongStreak {
                flamePulse = true
                emberDrift = false

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                        emberDrift = true
                    }
                }
            }
        }
        .onAppear {
            if hasStrongStreak {
                flamePulse = true
                emberDrift = true
            }
        }
        .animation(
            hasStrongStreak
            ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
            : .default,
            value: flamePulse
        )
        .animation(
            hasStrongStreak
            ? .easeOut(duration: 1.4).repeatForever(autoreverses: false)
            : .default,
            value: emberDrift
        )
    }

    func pill(text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(palette.secondaryCardFill)
        )
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.12), lineWidth: 1)
        )
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(palette.cardStroke)
            )
    }
}
