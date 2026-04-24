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

    private var accent: Color {
        state == .free
        ? Color(red: 0.56, green: 0.36, blue: 1.00)
        : Color(red: 0.16, green: 0.56, blue: 1.00)
    }

    private var secondaryAccent: Color {
        state == .free
        ? Color(red: 0.16, green: 0.07, blue: 0.32)
        : Color(red: 0.03, green: 0.18, blue: 0.36)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    topRow

                    Text(titleOverride ?? title)
                        .font(.system(size: 25, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Text(subtitleOverride ?? subtitle)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.74))
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)

                    VStack(alignment: .leading, spacing: 8) {
                        featureRow(feature1Icon, feature1Text)
                        featureRow(feature2Icon, feature2Text)
                        featureRow(feature3Icon, feature3Text)
                    }

                    HStack(spacing: 8) {
                        Text(buttonTitleOverride ?? buttonTitle)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.98), in: Capsule())
                            .shadow(color: accent.opacity(0.22), radius: 14, y: 5)

                        if state == .premium {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    }
                }

                Spacer(minLength: 0)

                rightVisual
            }
            .padding(18)
            .background(
                premiumBackground(cornerRadius: 30)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var topRow: some View {
        HStack(spacing: 8) {
            Text(eyebrowOverride ?? eyebrow)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(accent.opacity(0.98))
                .tracking(0.8)

            if state == .premium {
                Text("ACTIVE")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.96), in: Capsule())
            }
        }
    }

    private func featureRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.82))

            Text(text)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.80))
        }
    }

    private var rightVisual: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .frame(width: 108, height: 136)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accent.opacity(0.52),
                            Color.blue.opacity(state == .free ? 0.16 : 0.22),
                            .clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 42
                    )
                )
                .frame(width: 78, height: 78)
                .blur(radius: 2)

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
                        .foregroundStyle(.white.opacity(0.84))
                }
                .shadow(color: accent.opacity(0.18), radius: 10)

            Capsule()
                .fill(Color.white.opacity(0.15))
                .frame(width: 48, height: 6)

            Capsule()
                .fill(Color.white.opacity(0.09))
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
                        .foregroundStyle(.white.opacity(0.88))
                }
                .shadow(color: accent.opacity(0.18), radius: 10)

            HStack(spacing: 5) {
                Capsule().fill(Color.white.opacity(0.22)).frame(width: 10, height: 6)
                Capsule().fill(Color.white.opacity(0.18)).frame(width: 10, height: 6)
                Capsule().fill(Color.white.opacity(0.14)).frame(width: 10, height: 6)
            }

            Text("LIVE")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.74))
        }
    }

    private func premiumBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.52),
                        accent.opacity(0.22),
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
                        RadialGradient(
                            colors: [
                                accent.opacity(0.28),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: 170
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.clear,
                                Color.black.opacity(0.18)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
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

    private var feature1Icon: String { state == .free ? "clock" : "brain.head.profile" }
    private var feature2Icon: String { state == .free ? "brain.head.profile" : "clock.fill" }
    private var feature3Icon: String { state == .free ? "sparkles" : "waveform.path.ecg" }

    private var feature1Text: String { state == .free ? "Best study window" : "AI Coach" }
    private var feature2Text: String { state == .free ? "Smarter AI coaching" : "Study window" }
    private var feature3Text: String { state == .free ? "Identity evolution" : "Weekly signal" }
}
