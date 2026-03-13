//
//  FocusInsightsCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI

struct FocusInsightsCard: View {
    let data: FocusInsightsData

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

                    Text(data.streakSubtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(15)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text("Today Focus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    CountUpText(
                        value: focusMinutesValue,
                        duration: 1.0,
                        trigger: isVisible,
                        formatter: { "\(Int($0))" }
                    )
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                    Text("dk")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }

                HStack(spacing: 4) {
                    CountUpText(
                        value: sessionCountValue,
                        duration: 0.75,
                        trigger: isVisible,
                        formatter: { "\(Int($0))" }
                    )
                    .font(.system(size: 14, weight: .medium))

                    Text("session")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Text(data.longestSessionText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(15)
            .frame(maxWidth: 188, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
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
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
    }
}
