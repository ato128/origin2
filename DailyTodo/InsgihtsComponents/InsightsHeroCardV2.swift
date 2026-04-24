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
        case .exams: return Color(red: 1.00, green: 0.55, blue: 0.18)
        case .courses: return Color(red: 0.20, green: 0.58, blue: 1.00)
        case .rhythm: return Color(red: 0.22, green: 0.78, blue: 0.46)
        case .empty: return Color(red: 0.56, green: 0.36, blue: 1.00)
        }
    }

    private var secondaryTint: Color {
        switch data.mode {
        case .exams: return Color(red: 0.36, green: 0.10, blue: 0.04)
        case .courses: return Color(red: 0.03, green: 0.18, blue: 0.36)
        case .rhythm: return Color(red: 0.04, green: 0.26, blue: 0.18)
        case .empty: return Color(red: 0.16, green: 0.07, blue: 0.32)
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
        case .exams: return "Short consistent blocks win."
        case .courses: return "Keep weaker courses in view."
        case .rhythm: return "Your pattern is starting to form."
        case .empty: return "A few sessions will light this up."
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
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(heroTint.opacity(0.98))
                            .tracking(1.1)

                        Text(compactTitle)
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(compactSubtitle)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.74))
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
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.98))
                    )
                    .shadow(color: heroTint.opacity(0.22), radius: 14, y: 5)
                }
                .buttonStyle(.plain)

                orbitDecoration
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, minHeight: 228, alignment: .topLeading)
            .background(
                premiumInsightsBackground(
                    accent: heroTint,
                    secondaryAccent: secondaryTint,
                    strength: 0.78,
                    cornerRadius: 34
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var metricOrb: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.09), lineWidth: 1.2)
                .frame(width: 128, height: 128)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            heroTint.opacity(0.26),
                            heroTint.opacity(0.08),
                            .clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 66
                    )
                )
                .frame(width: 132, height: 132)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            heroTint.opacity(0.88),
                            secondaryTint.opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 76, height: 76)
                .shadow(color: heroTint.opacity(0.22), radius: 18)

            VStack(spacing: 1) {
                Text(data.primaryValue)
                    .font(.system(size: 31, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text(data.primaryLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(1)
            }
        }
        .frame(width: 132, height: 132)
    }

    private func heroChip(_ text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.white.opacity(0.52))
                .frame(width: 5, height: 5)

            Text(text)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.075))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.055), lineWidth: 1)
                )
        )
    }

    private func premiumInsightsBackground(
        accent: Color,
        secondaryAccent: Color,
        strength: Double,
        cornerRadius: CGFloat
    ) -> some View {
        let topGlow = 0.12 + (strength * 0.08)
        let leadingGlow = 0.16 + (strength * 0.10)
        let bottomGlow = 0.14 + (strength * 0.16)

        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.82),
                        accent.opacity(0.46),
                        secondaryAccent.opacity(0.78),
                        Color(red: 0.035, green: 0.035, blue: 0.070)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(topGlow),
                                Color.clear,
                                Color.black.opacity(0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.screen)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(leadingGlow),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: 180
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                secondaryAccent.opacity(bottomGlow),
                                Color.clear
                            ],
                            center: .bottomLeading,
                            startRadius: 10,
                            endRadius: 180
                        )
                    )
                    .blur(radius: 10)
                    .mask(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.00),
                                Color.black.opacity(0.08),
                                Color.black.opacity(0.20)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
    }

    private var orbitDecoration: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 120, style: .continuous)
                .strokeBorder(
                    Color.white.opacity(0.035),
                    style: StrokeStyle(lineWidth: 0.8, dash: [3, 5])
                )

            GeometryReader { geo in
                let y = geo.size.height / 2

                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
                .stroke(
                    Color.white.opacity(0.025),
                    style: StrokeStyle(lineWidth: 0.8, dash: [3, 5])
                )

                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .stroke(
                            Color.white.opacity(0.032),
                            style: StrokeStyle(lineWidth: 0.8, dash: [3, 5])
                        )
                        .frame(width: 28, height: 28)
                        .position(
                            x: geo.size.width * (0.12 + CGFloat(index) * 0.24),
                            y: y
                        )
                }
            }
        }
        .frame(height: 30)
        .opacity(0.82)
    }
}
