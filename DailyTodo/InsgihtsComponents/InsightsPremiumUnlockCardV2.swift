//
//  InsightsPremiumUnlockCardV2.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//
import SwiftUI

struct InsightsPremiumUnlockCardV2: View {
    let data: InsightsPremiumPreviewData

    private let accent = Color(red: 0.56, green: 0.36, blue: 1.00)
    private let secondaryAccent = Color(red: 0.16, green: 0.07, blue: 0.32)

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text("Premium")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(accent.opacity(0.98))
                        .tracking(0.8)

                    Text("ACTIVE")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.white.opacity(0.96)))
                }

                Text("Unlock deeper patterns")
                    .font(.system(size: 25, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                VStack(alignment: .leading, spacing: 8) {
                    bullet("Best study window")
                    bullet("Smarter AI coaching")
                    bullet("Identity evolution")
                }

                Button(action: {}) {
                    HStack(spacing: 8) {
                        Text(data.buttonTitle)
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.white.opacity(0.98)))
                    .shadow(color: accent.opacity(0.22), radius: 14, y: 5)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            premiumOrb
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

    private func bullet(_ text: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.82))

            Text(text)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.80))
        }
    }

    private var premiumOrb: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .frame(width: 104, height: 128)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accent.opacity(0.52),
                            Color.blue.opacity(0.20),
                            .clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 42
                    )
                )
                .frame(width: 78, height: 78)
                .blur(radius: 2)

            VStack(spacing: 9) {
                Circle()
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white.opacity(0.86))
                    }
                    .shadow(color: accent.opacity(0.18), radius: 10)

                HStack(spacing: 5) {
                    Capsule().fill(Color.white.opacity(0.18)).frame(width: 20, height: 6)
                    Capsule().fill(Color.white.opacity(0.13)).frame(width: 20, height: 6)
                    Capsule().fill(Color.white.opacity(0.09)).frame(width: 20, height: 6)
                }

                Text("LIVE")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
            }
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
}
