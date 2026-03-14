//
//  FocusInsightsCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI

struct FocusInsightsCard: View {
    let data: FocusInsightsData

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    @State private var isVisible = false
    @State private var flamePulse = false

    private var focusMinutesValue: Double {
        Double(data.todayFocusMinutesText.replacingOccurrences(of: " dk", with: "")) ?? 0
    }

    private var sessionCountValue: Double {
        Double(data.todaySessionsText.replacingOccurrences(of: " session", with: "")) ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Focus Insights")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(palette.primaryText)

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 38, height: 38)
                        .scaleEffect(flamePulse ? 1.08 : 0.96)
                        .shadow(color: Color.orange.opacity(flamePulse ? 0.22 : 0.08), radius: flamePulse ? 12 : 4)

                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 18, weight: .bold))
                        .scaleEffect(flamePulse ? 1.07 : 1.0)
                        .shadow(color: Color.orange.opacity(flamePulse ? 0.26 : 0.10), radius: flamePulse ? 8 : 3)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(data.streakTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(palette.primaryText)

                    Text(data.streakSubtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer()
            }
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(palette.secondaryCardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(palette.cardStroke.opacity(0.7), lineWidth: 1)
                    )
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("Today Focus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    CountUpText(
                        value: focusMinutesValue,
                        duration: 1.0,
                        trigger: isVisible,
                        formatter: { "\(Int($0))" }
                    )
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                    Text("dk")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                }

                HStack(spacing: 4) {
                    CountUpText(
                        value: sessionCountValue,
                        duration: 0.75,
                        trigger: isVisible,
                        formatter: { "\(Int($0))" }
                    )
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.primaryText)

                    Text("session")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                }

                Text(data.longestSessionText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
            }
            .padding(15)
            .frame(maxWidth: 188, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        appTheme == AppTheme.light.rawValue
                        ? Color.accentColor.opacity(0.10)
                        : Color.accentColor.opacity(0.12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                appTheme == AppTheme.light.rawValue
                                ? Color.accentColor.opacity(0.14)
                                : Color.clear,
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.accentColor.opacity(0.10), radius: 14)
            )
        }
        .padding(18)
        .background(cardBackground)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.985)
        .offset(y: isVisible ? 0 : 12)
        .animation(.spring(response: 0.48, dampingFraction: 0.86), value: isVisible)
        .animateWhenVisible($isVisible)
        .onChange(of: isVisible) { _, newValue in
            guard newValue else { return }
            flamePulse = false
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                flamePulse = true
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }
}
