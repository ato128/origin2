//
//  IdentityLevelUpCelebrationView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 27.04.2026.
//

import SwiftUI
import UIKit

struct IdentityLevelUpCelebrationView: View {
    let oldLevel: Int
    let newLevel: Int
    let title: String
    let accent: Color
    let onFinish: () -> Void

    @State private var appeared = false
    @State private var pulse = false
    @State private var rotateGlow = false
    @State private var particles = false

    private var resolvedAccent: Color {
        accent
    }

    private var secondaryAccent: Color {
        Color(arenaHex: AppArenaPalette.coral)
    }

    private var goldAccent: Color {
        Color(arenaHex: AppArenaPalette.gold)
    }

    private var stableGoldBloomOpacity: Double {
        PerformanceSettings.enableSlowAmbientAnimations
        ? (pulse ? 0.24 : 0.14)
        : 0.18
    }

    private var stableSecondaryBloomOpacity: Double {
        PerformanceSettings.enableSlowAmbientAnimations
        ? (pulse ? 0.12 : 0.08)
        : 0.09
    }

    private var stableOrbGlowOpacity: Double {
        PerformanceSettings.enableSlowAmbientAnimations
        ? (pulse ? 0.24 : 0.15)
        : 0.18
    }

    private var stableOrbBlur: CGFloat {
        if PerformanceSettings.enableHeavyBlurEffects {
            return PerformanceSettings.enableSlowAmbientAnimations ? (pulse ? 34 : 28) : 30
        }

        return 18
    }

    var body: some View {
        ZStack {
            background

            if PerformanceSettings.enableSlowAmbientAnimations {
                particleField
            }

            VStack(spacing: 26) {
                Spacer(minLength: 74)

                topLabel

                levelOrb

                titleBlock

                Spacer()

                continueButton
                    .padding(.bottom, 44)
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            withAnimation(.spring(response: 0.58, dampingFraction: 0.86)) {
                appeared = true
            }

            guard PerformanceSettings.enableSlowAmbientAnimations else {
                pulse = false
                rotateGlow = false
                particles = false
                return
            }

            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                pulse = true
            }

            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                rotateGlow = true
            }

            withAnimation(.easeOut(duration: 0.8).delay(0.10)) {
                particles = true
            }
        }
        .onDisappear {
            pulse = false
            rotateGlow = false
            particles = false
        }
    }

    private var topLabel: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(goldAccent)
                    .frame(width: 22, height: 1)

                Text("LEVEL UP")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(3.2)
                    .foregroundStyle(goldAccent)

                Rectangle()
                    .fill(goldAccent)
                    .frame(width: 22, height: 1)
            }

            Text("IDENTITY EVOLVED")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(2.4)
                .foregroundStyle(.white.opacity(0.42))
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
    }

    private var titleBlock: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("LV \(oldLevel)")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(.white.opacity(0.46))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.070))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    )

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(goldAccent)

                Text("LV \(newLevel)")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        goldAccent,
                                        secondaryAccent
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }

            Text(title)
                .font(.system(size: 42, weight: .black))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            Text(tr("ilu_new_status"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.50))
                .multilineTextAlignment(.center)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
    }

    private var continueButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onFinish()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 17, weight: .black))

                Text("DEVAM ET")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .tracking(1.0)

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .black))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                goldAccent,
                                secondaryAccent
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(
                        color: goldAccent.opacity(0.18),
                        radius: PerformanceSettings.glowShadowRadius,
                        y: 8
                    )
            )
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
    }

    private var background: some View {
        ZStack {
            ArenaBackground(
                primaryGlow: resolvedAccent,
                secondaryGlow: Color(arenaHex: AppArenaPalette.purple),
                warmGlow: goldAccent,
                intensity: 0.92
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(0.10),
                    Color.black.opacity(0.42)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    goldAccent.opacity(stableGoldBloomOpacity * PerformanceSettings.radialOpacityMultiplier),
                    secondaryAccent.opacity(stableSecondaryBloomOpacity * PerformanceSettings.radialOpacityMultiplier),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 380
            )
            .ignoresSafeArea()

            VStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.055),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 190)

                Spacer()
            }
            .ignoresSafeArea()
        }
    }

    private var levelOrb: some View {
        ZStack {
            Circle()
                .fill(goldAccent.opacity(stableOrbGlowOpacity * PerformanceSettings.radialOpacityMultiplier))
                .frame(width: 224, height: 224)
                .blur(radius: stableOrbBlur)

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            goldAccent.opacity(0.95),
                            secondaryAccent.opacity(0.82),
                            Color(arenaHex: AppArenaPalette.purple).opacity(0.65),
                            goldAccent.opacity(0.95)
                        ],
                        center: .center
                    ),
                    lineWidth: 2
                )
                .frame(width: 184, height: 184)
                .rotationEffect(
                    .degrees(
                        PerformanceSettings.enableSlowAmbientAnimations
                        ? (rotateGlow ? 360 : 0)
                        : 0
                    )
                )
                .opacity(0.74)

            Circle()
                .stroke(Color.white.opacity(0.070), lineWidth: 14)
                .frame(width: 164, height: 164)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.16),
                            goldAccent.opacity(0.20 * PerformanceSettings.radialOpacityMultiplier),
                            resolvedAccent.opacity(0.12 * PerformanceSettings.radialOpacityMultiplier),
                            Color.white.opacity(0.030)
                        ],
                        center: .topLeading,
                        startRadius: 8,
                        endRadius: 120
                    )
                )
                .frame(width: 154, height: 154)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.13), lineWidth: 1)
                )
                .shadow(
                    color: goldAccent.opacity(0.20),
                    radius: PerformanceSettings.glowShadowRadius,
                    y: 10
                )

            VStack(spacing: 0) {
                Text("LV")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.52))

                Text("\(newLevel)")
                    .font(.system(size: 72, weight: .black))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .monospacedDigit()
            }
        }
        .scaleEffect(appeared ? 1 : 0.78)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.58, dampingFraction: 0.86), value: appeared)
    }

    private var particleField: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                let angle = Double(index) * 30.0
                let radius = CGFloat(82 + (index % 4) * 24)
                let x = cos(angle * .pi / 180) * radius
                let y = sin(angle * .pi / 180) * radius

                Circle()
                    .fill(index.isMultiple(of: 3) ? goldAccent : resolvedAccent)
                    .frame(width: CGFloat(4 + (index % 3)), height: CGFloat(4 + (index % 3)))
                    .opacity(particles ? 0.42 : 0)
                    .offset(
                        x: particles ? x : 0,
                        y: particles ? y : 0
                    )
                    .blur(radius: index.isMultiple(of: 4) ? 0.8 : 0)
                    .animation(
                        .easeOut(duration: 0.9)
                        .delay(Double(index) * 0.014),
                        value: particles
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
