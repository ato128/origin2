//
//  FocusHeroCardV3.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 9.04.2026.
//

import SwiftUI

struct FocusFullPageStageV7: View {
    let mode: FocusMode
    let durationText: String
    let statusText: String
    let metaText: String
    let progress: Double
    let isLaunching: Bool

    @EnvironmentObject var focusSession: FocusSessionManager

    @State private var appeared = false
    @State private var pulse = false
    @State private var drift = false

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var theme: FocusStageTheme {
        FocusStageTheme.forMode(mode)
    }

    var body: some View {
        ZStack {
            backgroundAtmosphere

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(theme.accent)
                                .frame(width: 18, height: 1)

                            Text(modeEyebrow.uppercased())
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .tracking(1.9)
                                .foregroundStyle(theme.accent)
                                .lineLimit(1)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(modeTitleMain)
                                .font(.system(size: 26, weight: .black))
                                .foregroundStyle(.white)

                            Text(modeTitleAccent)
                                .font(.system(size: 25, weight: .regular, design: .serif))
                                .italic()
                                .foregroundStyle(theme.accent)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    }

                    Spacer(minLength: 8)

                    stageStatusPill
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .opacity(isLaunching ? 0.88 : 1)

                Spacer(minLength: 12)

                ringStage
                    .scaleEffect(isLaunching ? 1.08 : (appeared ? 1 : 0.95))
                    .opacity(isLaunching ? 0.98 : (appeared ? 1 : 0))
                    .blur(radius: isLaunching ? 0.7 : 0)

                Spacer(minLength: 14)

                HStack(spacing: 8) {
                    Circle()
                        .fill(theme.dotColor)
                        .frame(width: 7, height: 7)
                        .shadow(color: theme.dotColor.opacity(0.40), radius: 7)

                    Text(focusSession.isSessionActive && focusSession.selectedMode == mode ? "Aktif session" : statusText)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(theme.dotColor)

                    Text("•")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.25))

                    Text(metaText)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.54))
                        .lineLimit(1)
                        .minimumScaleFactor(0.80)
                }
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.055))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.080), lineWidth: 1)
                        )
                )
                .opacity(isLaunching ? 0.0 : (appeared ? 1 : 0))
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 318)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .compositingGroup()
        .scaleEffect(isLaunching ? 1.018 : (appeared ? 1 : 0.988))
        .opacity(isLaunching ? 0.98 : (appeared ? 1 : 0))
        .offset(y: isLaunching ? -5 : (appeared ? 0 : 10))
        .animation(.spring(response: 0.78, dampingFraction: 0.88), value: appeared)
        .animation(.spring(response: 0.46, dampingFraction: 0.84), value: isLaunching)
        .animation(.easeInOut(duration: 0.50), value: mode)
        .onAppear {
            appeared = true
            pulse = true
            drift = true
        }
    }
}

private extension FocusFullPageStageV7 {

    var modeEyebrow: String {
        switch mode {
        case .personal:
            return "Personal Rhythm"
        case .crew:
            return "Crew Focus"
        case .friend:
            return "Friend Session"
        }
    }

    var modeTitleMain: String {
        switch mode {
        case .personal:
            return "Kişisel"
        case .crew:
            return "Crew"
        case .friend:
            return "Friend"
        }
    }

    var modeTitleAccent: String {
        "Focus"
    }

    var stageStatusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(theme.dotColor)
                .frame(width: 7, height: 7)

            Text(focusSession.isSessionActive && focusSession.selectedMode == mode ? "LIVE" : statusText.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(theme.dotColor)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(
            Capsule(style: .continuous)
                .fill(theme.dotColor.opacity(0.12))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(theme.dotColor.opacity(0.18), lineWidth: 1)
                )
        )
    }

    var backgroundAtmosphere: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            theme.baseTop,
                            theme.baseMid,
                            theme.baseBottom
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RadialGradient(
                colors: [
                    theme.primaryBloom.opacity(pulse ? 0.34 : 0.24),
                    theme.primaryBloom.opacity(0.12),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 8,
                endRadius: 250
            )
            .blur(radius: 18)
            .offset(x: drift ? 12 : -8, y: drift ? -6 : 8)
            .animation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true), value: drift)
            .animation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true), value: pulse)

            RadialGradient(
                colors: [
                    theme.secondaryBloom.opacity(pulse ? 0.28 : 0.18),
                    theme.secondaryBloom.opacity(0.10),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 8,
                endRadius: 230
            )
            .blur(radius: 24)
            .offset(x: drift ? -12 : 8, y: drift ? 6 : -6)
            .animation(.easeInOut(duration: 6.8).repeatForever(autoreverses: true), value: drift)
            .animation(.easeInOut(duration: 5.8).repeatForever(autoreverses: true), value: pulse)

            Ellipse()
                .fill(theme.coreBloom.opacity(isLaunching ? 0.20 : 0.11))
                .frame(width: isLaunching ? 300 : 250, height: isLaunching ? 170 : 140)
                .blur(radius: isLaunching ? 36 : 30)
                .offset(y: isLaunching ? 6 : 24)
                .animation(.easeInOut(duration: 0.32), value: isLaunching)

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.045),
                            Color.clear,
                            Color.black.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(theme.accent.opacity(0.15), lineWidth: 1)
                .shadow(color: theme.accent.opacity(0.16), radius: 18, y: 8)
        }
        .drawingGroup()
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    var ringStage: some View {
        ZStack {
            Circle()
                .fill(theme.innerGlow.opacity(isLaunching ? 0.22 : 0.14))
                .frame(width: isLaunching ? 214 : 190, height: isLaunching ? 214 : 190)
                .blur(radius: isLaunching ? 28 : 22)
                .animation(.easeInOut(duration: 0.32), value: isLaunching)

            Circle()
                .stroke(Color.white.opacity(0.070), lineWidth: 13)

            Circle()
                .trim(from: 0, to: appeared ? clampedProgress : 0)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            theme.accent.opacity(0.96),
                            theme.secondaryAccent.opacity(0.95),
                            theme.accent.opacity(0.96)
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 13, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: theme.accent.opacity(0.24), radius: 12)
                .animation(.easeOut(duration: 0.9), value: appeared)
                .animation(.easeInOut(duration: 0.42), value: progress)

            Circle()
                .stroke(Color.white.opacity(0.035), lineWidth: 1)
                .padding(13)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            theme.accent.opacity(0.10),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 88
                    )
                )
                .padding(20)

            VStack(spacing: 4) {
                Text(durationText)
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(statusText)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(1)

                Text(metaText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.50))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .opacity(isLaunching ? 0.72 : 1)
            }
        }
        .frame(width: 190, height: 190)
    }
}

private struct FocusStageTheme {
    let baseTop: Color
    let baseMid: Color
    let baseBottom: Color

    let primaryBloom: Color
    let secondaryBloom: Color
    let coreBloom: Color
    let innerGlow: Color

    let accent: Color
    let secondaryAccent: Color
    let dotColor: Color

    static func forMode(_ mode: FocusMode) -> FocusStageTheme {
        switch mode {
        case .personal:
            return FocusStageTheme(
                baseTop: Color(arenaHex: "#0B1624"),
                baseMid: Color(arenaHex: "#090D1A"),
                baseBottom: Color(arenaHex: "#050711"),
                primaryBloom: Color(arenaHex: AppArenaPalette.cyan),
                secondaryBloom: Color(arenaHex: AppArenaPalette.purple),
                coreBloom: Color(arenaHex: AppArenaPalette.blue),
                innerGlow: Color(arenaHex: AppArenaPalette.cyan),
                accent: Color(arenaHex: AppArenaPalette.cyan),
                secondaryAccent: Color(arenaHex: AppArenaPalette.purple),
                dotColor: Color(arenaHex: AppArenaPalette.cyan)
            )

        case .crew:
            return FocusStageTheme(
                baseTop: Color(arenaHex: "#201013"),
                baseMid: Color(arenaHex: "#11080D"),
                baseBottom: Color(arenaHex: "#07040A"),
                primaryBloom: Color(arenaHex: AppArenaPalette.coral),
                secondaryBloom: Color(arenaHex: AppArenaPalette.gold),
                coreBloom: Color(arenaHex: AppArenaPalette.coral),
                innerGlow: Color(arenaHex: AppArenaPalette.coral),
                accent: Color(arenaHex: AppArenaPalette.coral),
                secondaryAccent: Color(arenaHex: AppArenaPalette.gold),
                dotColor: Color(arenaHex: AppArenaPalette.gold)
            )

        case .friend:
            return FocusStageTheme(
                baseTop: Color(arenaHex: "#171127"),
                baseMid: Color(arenaHex: "#0E0A1A"),
                baseBottom: Color(arenaHex: "#07040F"),
                primaryBloom: Color(arenaHex: AppArenaPalette.purple),
                secondaryBloom: Color(arenaHex: AppArenaPalette.blue),
                coreBloom: Color(arenaHex: AppArenaPalette.purple),
                innerGlow: Color(arenaHex: AppArenaPalette.purple),
                accent: Color(arenaHex: AppArenaPalette.purple),
                secondaryAccent: Color(arenaHex: AppArenaPalette.blue),
                dotColor: Color(arenaHex: AppArenaPalette.purple)
            )
        }
    }
}
