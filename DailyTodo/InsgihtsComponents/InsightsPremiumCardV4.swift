//
//  InsightsPremiumCardV4.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//

import SwiftUI

struct InsightsPremiumCardV4: View {
    let state: PremiumState
    let action: () -> Void

    var titleOverride: String? = nil
    var subtitleOverride: String? = nil
    var buttonTitleOverride: String? = nil
    var eyebrowOverride: String? = nil

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(backgroundGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(borderGradient, lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        Circle()
                            .fill(glowColor.opacity(glowOpacity))
                            .frame(width: 180, height: 180)
                            .blur(radius: 44)
                            .offset(x: -18, y: -24)
                    }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        topRow

                        Text(titleOverride ?? title)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)

                        Text(subtitleOverride ?? subtitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.76))
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)

                        VStack(alignment: .leading, spacing: 7) {
                            featureRow(feature1Icon, feature1Text)
                            featureRow(feature2Icon, feature2Text)
                            featureRow(feature3Icon, feature3Text)
                        }

                        HStack(spacing: 8) {
                            Text(buttonTitleOverride ?? buttonTitle)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 11)
                                .background(Color.white.opacity(0.96), in: Capsule())

                            if state == .premium {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.70))
                            }
                        }
                    }

                    Spacer(minLength: 0)

                    rightVisual
                }
                .padding(18)
            }
        }
        .buttonStyle(.plain)
    }

    private var topRow: some View {
        HStack(spacing: 8) {
            Text(eyebrowOverride ?? eyebrow)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.58))

            if state == .premium {
                Text("ACTIVE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.92), in: Capsule())
            }
        }
    }

    private func featureRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.78))

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.82))
        }
    }

    private var rightVisual: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .frame(width: 108, height: 136)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            glowColor.opacity(0.62),
                            glowColor.opacity(0.18),
                            .clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 30
                    )
                )
                .frame(width: 70, height: 70)

            if state == .free {
                freeVisual
            } else {
                premiumVisual
            }
        }
    }

    private var freeVisual: some View {
        VStack(spacing: 10) {
            Circle()
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.82))
                }

            Capsule()
                .fill(Color.white.opacity(0.14))
                .frame(width: 48, height: 6)

            Capsule()
                .fill(Color.white.opacity(0.08))
                .frame(width: 34, height: 6)
        }
    }

    private var premiumVisual: some View {
        VStack(spacing: 10) {
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.86))
                }

            HStack(spacing: 5) {
                Capsule().fill(Color.white.opacity(0.22)).frame(width: 10, height: 6)
                Capsule().fill(Color.white.opacity(0.22)).frame(width: 10, height: 6)
                Capsule().fill(Color.white.opacity(0.22)).frame(width: 10, height: 6)
            }

            Text("LIVE")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.74))
        }
    }

    private var eyebrow: String {
        state == .free ? "Premium" : "Insights+"
    }

    private var title: String {
        state == .free ? "Unlock deeper patterns" : "Insights+ active"
    }

    private var subtitle: String {
        state == .free
        ? "See your best study window, stronger coaching, and identity evolution."
        : "Premium cards are now active in your main Insights flow."
    }

    private var buttonTitle: String {
        state == .free ? "Explore Premium" : "Return to Free"
    }

    private var feature1Icon: String {
        state == .free ? "clock" : "brain.head.profile"
    }

    private var feature2Icon: String {
        state == .free ? "brain.head.profile" : "clock.fill"
    }

    private var feature3Icon: String {
        state == .free ? "sparkles" : "waveform.path.ecg"
    }

    private var feature1Text: String {
        state == .free ? "Best study window" : "AI Coach"
    }

    private var feature2Text: String {
        state == .free ? "Smarter AI coaching" : "Study window"
    }

    private var feature3Text: String {
        state == .free ? "Identity evolution" : "Weekly signal"
    }

    private var glowColor: Color {
        state == .free ? .purple : .blue
    }

    private var glowOpacity: Double {
        state == .free ? 0.16 : 0.14
    }

    private var backgroundGradient: LinearGradient {
        if state == .free {
            return LinearGradient(
                colors: [
                    Color.purple.opacity(0.22),
                    Color.blue.opacity(0.10),
                    Color.black.opacity(0.94)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.blue.opacity(0.18),
                    Color.indigo.opacity(0.10),
                    Color.black.opacity(0.94)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.10),
                glowColor.opacity(0.10),
                Color.white.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
