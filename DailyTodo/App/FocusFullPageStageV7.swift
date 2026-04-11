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
                Spacer(minLength: 8)

                VStack(spacing: 6) {
                    Text(modeEyebrow)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.58))
                        .tracking(1.7)

                    Text(modeDisplayTitle)
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.82)
                        .lineLimit(1)
                        .foregroundStyle(Color.white.opacity(0.99))
                        .multilineTextAlignment(.center)
                }
                .scaleEffect(isLaunching ? 0.985 : 1)
                .opacity(isLaunching ? 0.92 : 1)

                Spacer(minLength: 12)

                ringStage
                    .scaleEffect(isLaunching ? 1.10 : (appeared ? 1 : 0.95))
                    .opacity(isLaunching ? 0.97 : (appeared ? 1 : 0))
                    .blur(radius: isLaunching ? 1.0 : 0)

                Spacer(minLength: 10)

                HStack(spacing: 8) {
                    Circle()
                        .fill(theme.dotColor)
                        .frame(width: 8, height: 8)

                    Text(focusSession.isSessionActive && focusSession.selectedMode == mode ? "Aktif session" : statusText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.88))
                }
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.18))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                )
                .opacity(isLaunching ? 0.0 : (appeared ? 1 : 0))

                Spacer(minLength: 6)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 338)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .compositingGroup()
        .scaleEffect(isLaunching ? 1.02 : (appeared ? 1 : 0.988))
        .opacity(isLaunching ? 0.98 : (appeared ? 1 : 0))
        .offset(y: isLaunching ? -6 : (appeared ? 0 : 10))
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
        case .personal: return "Personal"
        case .crew: return "Crew"
        case .friend: return "Friend"
        }
    }

    var modeDisplayTitle: String {
        switch mode {
        case .personal: return "Kişisel Focus"
        case .crew: return "Crew Focus"
        case .friend: return "Friend Focus"
        }
    }

    var backgroundAtmosphere: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
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
                    theme.primaryBloom.opacity(pulse ? 0.68 : 0.52),
                    theme.primaryBloom.opacity(0.24),
                    Color.clear
                ],
                center: .top,
                startRadius: 16,
                endRadius: 250
            )
            .blur(radius: 18)
            .offset(x: drift ? 14 : -8, y: drift ? -8 : 8)
            .animation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true), value: drift)
            .animation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true), value: pulse)

            RadialGradient(
                colors: [
                    theme.secondaryBloom.opacity(pulse ? 0.38 : 0.28),
                    theme.secondaryBloom.opacity(0.12),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 8,
                endRadius: 220
            )
            .blur(radius: 24)
            .offset(x: drift ? -12 : 8, y: drift ? 6 : -6)
            .animation(.easeInOut(duration: 6.8).repeatForever(autoreverses: true), value: drift)
            .animation(.easeInOut(duration: 5.8).repeatForever(autoreverses: true), value: pulse)

            Ellipse()
                .fill(theme.coreBloom.opacity(isLaunching ? 0.26 : 0.16))
                .frame(width: isLaunching ? 300 : 250, height: isLaunching ? 170 : 140)
                .blur(radius: isLaunching ? 36 : 28)
                .offset(y: isLaunching ? 8 : 22)
                .animation(.easeInOut(duration: 0.32), value: isLaunching)

            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.040),
                            Color.clear,
                            Color.black.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .drawingGroup()
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
    }

    var ringStage: some View {
        ZStack {
            Circle()
                .fill(theme.innerGlow.opacity(isLaunching ? 0.24 : 0.16))
                .frame(width: isLaunching ? 220 : 196, height: isLaunching ? 220 : 196)
                .blur(radius: isLaunching ? 28 : 22)
                .animation(.easeInOut(duration: 0.32), value: isLaunching)

            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 14)

            Circle()
                .trim(from: 0, to: appeared ? clampedProgress : 0)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.98),
                            theme.ringTint.opacity(0.95),
                            Color.white.opacity(0.98)
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: theme.ringTint.opacity(0.18), radius: 10, x: 0, y: 0)
                .animation(.easeOut(duration: 0.9), value: appeared)
                .animation(.easeInOut(duration: 0.42), value: progress)

            Circle()
                .stroke(Color.white.opacity(0.03), lineWidth: 1)
                .padding(12)

            VStack(spacing: 4) {
                Text(durationText)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.995))
                    .contentTransition(.numericText())

                Text(statusText)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.74))

                Text(metaText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.54))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .opacity(isLaunching ? 0.72 : 1)
            }
        }
        .frame(width: 196, height: 196)
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
    let ringTint: Color
    let dotColor: Color

    static func forMode(_ mode: FocusMode) -> FocusStageTheme {
        switch mode {
        case .personal:
            return FocusStageTheme(
                baseTop: Color(red: 0.10, green: 0.14, blue: 0.37),
                baseMid: Color(red: 0.05, green: 0.08, blue: 0.23),
                baseBottom: Color(red: 0.01, green: 0.03, blue: 0.10),
                primaryBloom: Color(red: 0.42, green: 0.66, blue: 1.00),
                secondaryBloom: Color(red: 0.66, green: 0.54, blue: 1.00),
                coreBloom: Color(red: 0.32, green: 0.54, blue: 1.00),
                innerGlow: Color(red: 0.22, green: 0.39, blue: 0.98),
                ringTint: Color(red: 0.94, green: 0.97, blue: 1.00),
                dotColor: Color(red: 0.80, green: 0.91, blue: 1.00)
            )

        case .crew:
            return FocusStageTheme(
                baseTop: Color(red: 0.30, green: 0.08, blue: 0.12),
                baseMid: Color(red: 0.18, green: 0.04, blue: 0.07),
                baseBottom: Color(red: 0.08, green: 0.01, blue: 0.03),
                primaryBloom: Color(red: 1.00, green: 0.40, blue: 0.48),
                secondaryBloom: Color(red: 1.00, green: 0.70, blue: 0.56),
                coreBloom: Color(red: 0.92, green: 0.22, blue: 0.32),
                innerGlow: Color(red: 0.60, green: 0.10, blue: 0.16),
                ringTint: Color(red: 1.00, green: 0.92, blue: 0.94),
                dotColor: Color(red: 1.00, green: 0.84, blue: 0.86)
            )

        case .friend:
            return FocusStageTheme(
                baseTop: Color(red: 0.22, green: 0.08, blue: 0.31),
                baseMid: Color(red: 0.13, green: 0.05, blue: 0.20),
                baseBottom: Color(red: 0.05, green: 0.02, blue: 0.10),
                primaryBloom: Color(red: 0.90, green: 0.54, blue: 1.00),
                secondaryBloom: Color(red: 0.72, green: 0.60, blue: 1.00),
                coreBloom: Color(red: 0.68, green: 0.28, blue: 0.96),
                innerGlow: Color(red: 0.42, green: 0.16, blue: 0.72),
                ringTint: Color(red: 0.97, green: 0.91, blue: 1.00),
                dotColor: Color(red: 0.94, green: 0.86, blue: 1.00)
            )
        }
    }
}

