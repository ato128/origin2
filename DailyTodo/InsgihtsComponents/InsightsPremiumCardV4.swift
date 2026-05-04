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
        ? Color(arenaHex: AppArenaPalette.purple)
        : Color(arenaHex: AppArenaPalette.cyan)
    }

    private var secondaryAccent: Color {
        state == .free
        ? Color(arenaHex: AppArenaPalette.blue)
        : Color(arenaHex: AppArenaPalette.green)
    }

    private var warmAccent: Color {
        state == .free
        ? Color(arenaHex: AppArenaPalette.gold)
        : Color(arenaHex: AppArenaPalette.blue)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                topRow

                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(titleOverride ?? title)
                            .font(.system(size: 25, weight: .black))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .minimumScaleFactor(0.76)

                        Text(subtitleOverride ?? subtitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.54))
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)

                        VStack(alignment: .leading, spacing: 8) {
                            featureRow(feature1Icon, feature1Text, tint: accent)
                            featureRow(feature2Icon, feature2Text, tint: secondaryAccent)
                            featureRow(feature3Icon, feature3Text, tint: warmAccent)
                        }
                        .padding(.top, 2)
                    }

                    Spacer(minLength: 0)

                    rightVisual
                }

                bottomCTA
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(premiumBackground(cornerRadius: 30))
        }
        .buttonStyle(.plain)
    }

    private var topRow: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(accent)
                .frame(width: 18, height: 1)

            Text((eyebrowOverride ?? eyebrow).uppercased())
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(accent)

            if state == .premium {
                Text("ACTIVE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(
                        Capsule()
                            .fill(Color(arenaHex: AppArenaPalette.green))
                    )
            }

            Spacer()
        }
    }

    private func featureRow(_ icon: String, _ text: String, tint: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(tint.opacity(0.12))
                )

            Text(text)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
    }

    private var bottomCTA: some View {
        HStack(spacing: 10) {
            Text((buttonTitleOverride ?? buttonTitle).uppercased())
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(0.9)
                .foregroundStyle(.black)
                .padding(.horizontal, 13)
                .frame(height: 34)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    accent,
                                    secondaryAccent
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: accent.opacity(0.18), radius: 10, y: 4)

            if state == .premium {
                Text("LIVE SIGNAL")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color(arenaHex: AppArenaPalette.green))
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(
                        Capsule()
                            .fill(Color(arenaHex: AppArenaPalette.green).opacity(0.12))
                            .overlay(
                                Capsule()
                                    .stroke(Color(arenaHex: AppArenaPalette.green).opacity(0.18), lineWidth: 1)
                            )
                    )
            }

            Spacer()

            Image(systemName: state == .free ? "lock.open.fill" : "arrow.right")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(accent)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(accent.opacity(0.12))
                )
        }
    }

    private var rightVisual: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.090),
                            secondaryAccent.opacity(0.050),
                            Color.white.opacity(0.030)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 98, height: 132)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(accent.opacity(0.13), lineWidth: 1)
                )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accent.opacity(0.30),
                            secondaryAccent.opacity(0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 46
                    )
                )
                .frame(width: 82, height: 82)
                .blur(radius: 4)

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
                .stroke(accent.opacity(0.30), lineWidth: 1.2)
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(accent)
                }
                .shadow(color: accent.opacity(0.18), radius: 10)

            Capsule()
                .fill(Color.white.opacity(0.16))
                .frame(width: 48, height: 6)

            Capsule()
                .fill(Color.white.opacity(0.09))
                .frame(width: 34, height: 6)
        }
    }

    private var premiumVisual: some View {
        VStack(spacing: 10) {
            Circle()
                .stroke(Color(arenaHex: AppArenaPalette.green).opacity(0.30), lineWidth: 1.2)
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(Color(arenaHex: AppArenaPalette.green))
                }
                .shadow(color: Color(arenaHex: AppArenaPalette.green).opacity(0.18), radius: 10)

            HStack(spacing: 5) {
                Capsule()
                    .fill(accent.opacity(0.44))
                    .frame(width: 10, height: 6)

                Capsule()
                    .fill(secondaryAccent.opacity(0.34))
                    .frame(width: 10, height: 6)

                Capsule()
                    .fill(Color(arenaHex: AppArenaPalette.green).opacity(0.34))
                    .frame(width: 10, height: 6)
            }

            Text("LIVE")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.9)
                .foregroundStyle(Color(arenaHex: AppArenaPalette.green))
        }
    }

    private func premiumBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.085),
                        secondaryAccent.opacity(0.050),
                        Color(arenaHex: AppArenaPalette.surface).opacity(0.94)
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
                                accent.opacity(0.16),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: 190
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                warmAccent.opacity(0.11),
                                Color.clear
                            ],
                            center: .bottomTrailing,
                            startRadius: 8,
                            endRadius: 190
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(accent.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 16, y: 9)
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
}
