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
        case .rhythm: return .green
        case .empty: return .purple
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
        Button {
            action(data.action)
        } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today Pulse")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.54))
                            .tracking(0.35)

                        Text(compactTitle)
                            .font(.system(size: 31, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(compactSubtitle)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    metricOrb
                        .padding(.top, 4)
                }

                HStack(spacing: 8) {
                    heroChip(data.chip1)
                    heroChip(data.chip2)

                    if !data.chip3.isEmpty {
                        heroChip(data.chip3)
                    }
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.98))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
            .background(heroCardBackground(accent: heroTint))
        }
        .buttonStyle(.plain)
    }

    private var metricOrb: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 1.2)
                .frame(width: 128, height: 128)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            heroTint.opacity(0.22),
                            heroTint.opacity(0.10),
                            .clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 64
                    )
                )
                .frame(width: 132, height: 132)
                .blur(radius: 8)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            heroTint.opacity(0.55),
                            heroTint.opacity(0.20),
                            .clear
                        ],
                        center: .center,
                        startRadius: 6,
                        endRadius: 42
                    )
                )
                .frame(width: 92, height: 92)
                .blur(radius: 3)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            heroTint.opacity(0.95),
                            heroTint.opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 74, height: 74)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            .clear
                        ],
                        center: UnitPoint(x: 0.42, y: 0.30),
                        startRadius: 2,
                        endRadius: 18
                    )
                )
                .frame(width: 74, height: 74)

            VStack(spacing: 1) {
                Text(data.primaryValue)
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(data.primaryLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.64))
                    .lineLimit(1)
            }
        }
        .frame(width: 132, height: 132)
    }

    private func heroChip(_ text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.white.opacity(0.50))
                .frame(width: 5, height: 5)

            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }

    private func heroCardBackground(accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 34, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent,
                        accent.opacity(0.85),
                        accent.opacity(0.65),
                        Color.black.opacity(0.35)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(0.9),
                                accent.opacity(0.5),
                                accent.opacity(0.15),
                                .clear
                            ],
                            center: .topLeading,
                            startRadius: 10,
                            endRadius: 280
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.08),
                                .clear
                            ],
                            center: UnitPoint(x: 0.78, y: 0.22),
                            startRadius: 6,
                            endRadius: 120
                        )
                    )
            )
            .overlay(
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.35))
                        .frame(width: 300, height: 300)
                        .blur(radius: 70)
                        .offset(x: -120, y: 160)

                    Circle()
                        .fill(accent.opacity(0.22))
                        .frame(width: 220, height: 220)
                        .blur(radius: 60)
                        .offset(x: 100, y: 180)
                }
            )
            .overlay(
                HeroDustOverlay()
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.06),
                                Color.clear,
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(accent.opacity(0.25), lineWidth: 1)
            )
    }
}

private struct HeroDustOverlay: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.25))
                .frame(width: 10, height: 10)
                .offset(x: -90, y: 110)

            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 8, height: 8)
                .offset(x: -30, y: 120)

            Circle()
                .fill(Color.white.opacity(0.14))
                .frame(width: 8, height: 8)
                .offset(x: 30, y: 112)

            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 7, height: 7)
                .offset(x: 95, y: 125)
        }
        .allowsHitTesting(false)
    }
}
