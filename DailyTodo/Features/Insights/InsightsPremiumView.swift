//
//  InsightsPremiumView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//

import SwiftUI

struct InsightsPremiumView: View {
    @Environment(\.dismiss) private var dismiss
    let onStartPremium: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    hero
                    features
                    comparison
                    cta
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Premium")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Unlock the deeper version of Insights")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.60))
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var hero: some View {
        premiumCard(tint: .purple) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Unlock deeper patterns")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("DailyTodo does not just track your rhythm — it interprets it and guides your next move.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.76))

                HStack(spacing: 8) {
                    chip("Best study window")
                    chip("Smarter coaching")
                    chip("Identity evolution")
                }
            }
        }
    }

    private var features: some View {
        VStack(spacing: 12) {
            featureCard("Best Study Window", "Find your strongest study hours with confidence.", "clock", .purple)
            featureCard("Advanced AI Coach", "Get more specific and contextual daily guidance.", "brain.head.profile", .blue)
            featureCard("Identity Evolution", "See how your rhythm changes over time.", "sparkles", .orange)
            featureCard("Weekly Deep Review", "Understand what improved and what needs recovery.", "chart.line.uptrend.xyaxis", .green)
            featureCard("Exam Readiness Pro", "Track how prepared you are for upcoming exams.", "graduationcap.fill", .pink)
        }
    }

    private var comparison: some View {
        premiumCard(tint: .white) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Free vs Premium")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                row(left: "Basic pulse", right: "Deep pattern analysis")
                row(left: "Mini coach", right: "Advanced AI coach")
                row(left: "Basic identity", right: "Identity evolution")
                row(left: "Preview achievements", right: "Expanded premium insights")
            }
        }
    }

    private var cta: some View {
        VStack(spacing: 12) {
            Button {
                onStartPremium()
                dismiss()
            } label: {
                Text("Start Premium")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)

            Text("This can later become a real paywall or trial flow.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private func featureCard(_ title: String, _ subtitle: String, _ icon: String, _ tint: Color) -> some View {
        premiumCard(tint: tint) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(tint.opacity(0.16))
                        .frame(width: 54, height: 54)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white.opacity(0.90))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.68))
                }

                Spacer()
            }
        }
    }

    private func row(left: String, right: String) -> some View {
        HStack {
            Text(left)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.42))

            Spacer()

            Text(right)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.86))
        }
    }

    private func premiumCard<Content: View>(tint: Color, @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.14),
                            Color.white.opacity(0.03),
                            Color.black.opacity(0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )

            content()
                .padding(18)
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.84))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.08), in: Capsule())
    }
}
