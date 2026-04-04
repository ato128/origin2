//
//  InsightsHeroPremiumCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 4.04.2026.
//

import SwiftUI

struct InsightsHeroPremiumCard: View {
    let title: String
    let message: String
    let ctaTitle: String
    let todayFocusMinutes: Int
    let completedCount: Int
    let activeCount: Int
    let examCount: Int
    let progress: Double
    let progressLabel: String
    let accent: Color
    let action: () -> Void

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(3)

                    Text(message)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(todayFocusMinutes)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                        .monospacedDigit()

                    Text("bugün odak dk")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(palette.secondaryText)
                        .multilineTextAlignment(.trailing)
                }
                .frame(minWidth: 72, alignment: .trailing)
            }

            HStack(spacing: 10) {
                heroChip(
                    title: "\(completedCount) tamamlandı",
                    tint: .green
                )

                heroChip(
                    title: "\(activeCount) açık",
                    tint: .blue
                )

                heroChip(
                    title: "\(examCount) sınav",
                    tint: .orange
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Bugünkü durum")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(palette.primaryText)

                    Spacer()

                    Text(progressLabel)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                        .monospacedDigit()
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.10))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accent.opacity(0.95),
                                        accent.opacity(0.72)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(18, geo.size.width * progress))
                    }
                }
                .frame(height: 8)

                Text(progressMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(2)
            }
            .insightsInnerGlass(accent: accent)

            Button(action: action) {
                HStack(spacing: 10) {
                    Text(ctaTitle)
                        .font(.system(size: 18, weight: .bold, design: .rounded))

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    accent,
                                    accent.opacity(0.86)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: accent.opacity(0.22), radius: 14, y: 6)
            }
            .buttonStyle(.plain)
        }
        .insightsPremiumCardStyle(accent: accent, cornerRadius: 32, padding: 18)
    }

    private var progressMessage: String {
        if progress <= 0.05 {
            return "Küçük bir başlangıç yaparsan ekran daha güçlü görünmeye başlar."
        } else if progress < 0.35 {
            return "Ritim oluşuyor. Aynı akışı korursan bugünü rahat kapatırsın."
        } else if progress < 0.7 {
            return "İvme kazandın. Bir güçlü blok daha seni çok iyi noktaya taşır."
        } else {
            return "Bugün sağlam gidiyor. Şimdi zor bir işi kapatmak için iyi bir an."
        }
    }

    @ViewBuilder
    private func heroChip(title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(tint.opacity(0.14))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.14), lineWidth: 1)
            )
    }
}
