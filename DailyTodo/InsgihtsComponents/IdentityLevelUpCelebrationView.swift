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

    var body: some View {
        ZStack {
            background

            particleField

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

            withAnimation(.spring(response: 0.72, dampingFraction: 0.84)) {
                appeared = true
            }

            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                pulse = true
            }

            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                rotateGlow = true
            }

            withAnimation(.easeOut(duration: 1.0).delay(0.12)) {
                particles = true
            }
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

            Text("Yeni statü açıldı. İlerlemen kaydedildi.")
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
                    .shadow(color: goldAccent.opacity(0.24), radius: 22, y: 12)
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
                intensity: 0.98
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
                    goldAccent.opacity(pulse ? 0.24 : 0.14),
                    secondaryAccent.opacity(pulse ? 0.12 : 0.08),
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
                .fill(goldAccent.opacity(pulse ? 0.24 : 0.15))
                .frame(width: 224, height: 224)
                .blur(radius: pulse ? 34 : 28)

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
                .rotationEffect(.degrees(rotateGlow ? 360 : 0))
                .opacity(0.74)

            Circle()
                .stroke(Color.white.opacity(0.070), lineWidth: 14)
                .frame(width: 164, height: 164)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.16),
                            goldAccent.opacity(0.20),
                            resolvedAccent.opacity(0.12),
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
                .shadow(color: goldAccent.opacity(0.28), radius: 34, y: 18)

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
        .animation(.spring(response: 0.72, dampingFraction: 0.84), value: appeared)
    }

    private var particleField: some View {
        ZStack {
            ForEach(0..<18, id: \.self) { index in
                let angle = Double(index) * 20.0
                let radius = CGFloat(90 + (index % 5) * 28)
                let x = cos(angle * .pi / 180) * radius
                let y = sin(angle * .pi / 180) * radius

                Circle()
                    .fill(index.isMultiple(of: 3) ? goldAccent : resolvedAccent)
                    .frame(width: CGFloat(4 + (index % 3)), height: CGFloat(4 + (index % 3)))
                    .opacity(particles ? 0.55 : 0)
                    .offset(
                        x: particles ? x : 0,
                        y: particles ? y : 0
                    )
                    .blur(radius: index.isMultiple(of: 4) ? 1.2 : 0)
                    .animation(
                        .easeOut(duration: 1.15)
                        .delay(Double(index) * 0.018),
                        value: particles
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
