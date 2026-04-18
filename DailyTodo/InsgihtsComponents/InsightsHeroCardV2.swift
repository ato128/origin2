//
//  InsightsHeroCardV2.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//

import SwiftUI

struct InsightsHeroCardV2: View {
    let data: StudyHeroData
    let isStudyMode: Bool
    let action: (SmartSuggestionAction) -> Void

    private var heroTint: Color {
        switch data.mode {
        case .exams: return .orange
        case .courses: return .blue
        case .rhythm: return .purple
        case .empty: return .indigo
        }
    }

    private var compactTitle: String {
        switch data.mode {
        case .exams: return "Exam Rhythm"
        case .courses: return "Course Balance"
        case .rhythm: return "Rhythm"
        case .empty: return "Insights"
        }
    }

    private var compactSubtitle: String {
        switch data.mode {
        case .exams:
            return "Short consistent blocks win."
        case .courses:
            return "Keep weaker courses in view."
        case .rhythm:
            return "Your pattern is starting to form."
        case .empty:
            return "A few sessions will light this up."
        }
    }

    var body: some View {
        InsightsGlassCard(
            cornerRadius: 34,
            tint: heroTint,
            glowOpacity: 0.18,
            fillOpacity: 0.16,
            strokeOpacity: 0.11
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today Pulse")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.58))

                        Text(compactTitle)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(compactSubtitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(2)
                    }

                    Spacer(minLength: 8)

                    metricOrb
                }

                HStack(spacing: 8) {
                    heroChip(data.chip1)
                    heroChip(data.chip2)
                }

                Button {
                    action(data.action)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(data.actionTitle)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.96), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var metricOrb: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .frame(width: 118, height: 118)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            heroTint.opacity(0.72),
                            heroTint.opacity(0.24),
                            .clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 34
                    )
                )
                .frame(width: 72, height: 72)

            VStack(spacing: 2) {
                Text(data.primaryValue)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(data.primaryLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }
        }
        .frame(width: 122, height: 122)
    }

    private func heroChip(_ text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.white.opacity(0.52))
                .frame(width: 5, height: 5)

            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.08), in: Capsule())
    }
}
