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

    var body: some View {
        ZStack {
            background

            VStack(spacing: 26) {
                Spacer(minLength: 80)

                Text("LEVEL UP")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(accent)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                levelOrb

                VStack(spacing: 10) {
                    Text("Lv.\(oldLevel) → Lv.\(newLevel)")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))

                    Text(title)
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onFinish()
                } label: {
                    Text("Devam Et")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .white.opacity(0.16), radius: 22, x: 0, y: 10)
                }
                .buttonStyle(.plain)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 18)
                .padding(.bottom, 44)
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            withAnimation(.spring(response: 0.72, dampingFraction: 0.84)) {
                appeared = true
            }
        }
    }

    private var background: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    accent.opacity(0.22),
                    Color.black.opacity(0.96),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    accent.opacity(0.36),
                    accent.opacity(0.14),
                    .clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 360
            )
            .ignoresSafeArea()

            VStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.035),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 180)

                Spacer()
            }
            .ignoresSafeArea()
        }
    }

    private var levelOrb: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.18))
                .frame(width: 184, height: 184)
                .blur(radius: 28)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.18),
                            accent.opacity(0.28),
                            Color.white.opacity(0.04)
                        ],
                        center: .topLeading,
                        startRadius: 8,
                        endRadius: 120
                    )
                )
                .frame(width: 158, height: 158)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: accent.opacity(0.34), radius: 34, x: 0, y: 18)

            VStack(spacing: 0) {
                Text("Lv")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))

                Text("\(newLevel)")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
        }
        .scaleEffect(appeared ? 1 : 0.78)
        .opacity(appeared ? 1 : 0)
    }
}
