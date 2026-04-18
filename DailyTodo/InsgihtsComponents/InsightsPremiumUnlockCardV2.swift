//
//  InsightsPremiumUnlockCardV2.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//
import SwiftUI

struct InsightsPremiumUnlockCardV2: View {
    let data: InsightsPremiumPreviewData

    var body: some View {
        InsightsGlassCard(
            cornerRadius: 30,
            tint: .purple,
            glowOpacity: 0.16,
            fillOpacity: 0.13,
            strokeOpacity: 0.10
        ) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Premium")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.56))

                    Text("Unlock deeper patterns")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 7) {
                        bullet("Best study window")
                        bullet("Smarter AI coaching")
                        bullet("Identity evolution")
                    }

                    Button(action: {}) {
                        Text(data.buttonTitle)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .background(Color.white.opacity(0.95), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)

                premiumOrb
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.78))

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.80))
        }
    }

    private var premiumOrb: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .frame(width: 100, height: 124)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.purple.opacity(0.46),
                            Color.pink.opacity(0.16),
                            .clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 28
                    )
                )
                .frame(width: 62, height: 62)

            VStack(spacing: 9) {
                Circle()
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    .frame(width: 46, height: 46)
                    .overlay {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white.opacity(0.80))
                    }

                Capsule()
                    .fill(Color.white.opacity(0.13))
                    .frame(width: 48, height: 6)

                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 34, height: 6)
            }
        }
    }
}
