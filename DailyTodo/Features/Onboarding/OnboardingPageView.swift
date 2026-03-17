//
//  OnboardingPageView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 14.03.2026.
//

import SwiftUI

struct OnboardingPageView: View {
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    let isFinalPage: Bool
    let features: [(String, String)]

    @State private var animateIcon = false
    @State private var animateCard = false
    @State private var animateText = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(accent.opacity(isFinalPage ? 0.22 : 0.16))
                    .frame(width: isFinalPage ? 164 : 150, height: isFinalPage ? 164 : 150)
                    .blur(radius: isFinalPage ? 6 : 2)
                    .scaleEffect(animateIcon ? 1.06 : 0.94)
                    .animation(
                        .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                        value: animateIcon
                    )

                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 126, height: 126)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                Image(systemName: icon)
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(accent)
                    .shadow(color: isFinalPage ? accent.opacity(0.35) : .clear, radius: 12)
                    .offset(y: animateIcon ? -4 : 4)
                    .animation(
                        .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                        value: animateIcon
                    )
            }

            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .opacity(animateText ? 1 : 0)
                    .offset(y: animateText ? 0 : 14)

                Text(subtitle)
                    .font(.system(size: 16, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .opacity(animateText ? 1 : 0)
                    .offset(y: animateText ? 0 : 18)
            }
            .animation(.spring(response: 0.55, dampingFraction: 0.86), value: animateText)

            VStack(spacing: 12) {
                ForEach(Array(features.enumerated()), id: \.offset) { _, item in
                    featurePill(icon: item.0, text: item.1)
                }
            }
            .opacity(animateCard ? 1 : 0)
            .offset(y: animateCard ? 0 : 18)
            .animation(.spring(response: 0.5, dampingFraction: 0.86), value: animateCard)

            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear {
            animateIcon = true
            animateText = false
            animateCard = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                animateText = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                animateCard = true
            }
        }
    }

    @ViewBuilder
    private func featurePill(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accent)

            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(
                            isFinalPage ? accent.opacity(0.18) : Color.white.opacity(0.06),
                            lineWidth: 1
                        )
                )
        )
    }
}
