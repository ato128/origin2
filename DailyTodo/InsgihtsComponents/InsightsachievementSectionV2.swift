//
//  InsightsachievementSectionV2.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//

import SwiftUI

struct InsightsAchievementsSectionV2: View {
    let badges: [InsightsBadgeData]
    let onSeeAll: () -> Void

    private var nextUnlock: InsightsBadgeData? {
        badges.first { !$0.isUnlocked }
    }

    private var recentUnlocked: InsightsBadgeData? {
        badges.first { $0.isUnlocked } ?? badges.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Achievements")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                Button("See All") {
                    onSeeAll()
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
            }

            HStack(spacing: 12) {
                if let nextUnlock {
                    previewCard(
                        title: "Next Unlock",
                        badge: nextUnlock,
                        tint: nextUnlock.accent,
                        isPrimary: true
                    )
                }

                if let recentUnlocked {
                    previewCard(
                        title: "Recent",
                        badge: recentUnlocked,
                        tint: recentUnlocked.isUnlocked ? recentUnlocked.accent : Color(red: 0.52, green: 0.58, blue: 0.72),
                        isPrimary: false
                    )
                }
            }
        }
    }

    private func previewCard(
        title: String,
        badge: InsightsBadgeData,
        tint: Color,
        isPrimary: Bool
    ) -> some View {
        Button {
            onSeeAll()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(tint.opacity(0.95))
                        .tracking(0.5)

                    Spacer()

                    premiumIcon(systemName: badge.icon, tint: tint, unlocked: badge.isUnlocked)
                }

                Spacer(minLength: 0)

                Text(badge.title)
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                if let progress = badge.progress, !badge.isUnlocked {
                    progressBeam(progress: progress, tint: tint)
                } else {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(badge.isUnlocked ? tint : Color.white.opacity(0.50))
                            .frame(width: 6, height: 6)

                        Text(badge.isUnlocked ? "Unlocked" : "Locked")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 154, alignment: .topLeading)
            .background(
                achievementBackground(
                    tint: tint,
                    isUnlocked: badge.isUnlocked,
                    isPrimary: isPrimary
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func premiumIcon(systemName: String, tint: Color, unlocked: Bool) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            tint.opacity(unlocked ? 0.28 : 0.12),
                            Color.white.opacity(0.035),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 22
                    )
                )
                .frame(width: 34, height: 34)

            Circle()
                .fill(Color.white.opacity(0.055))
                .frame(width: 28, height: 28)

            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(unlocked ? Color.white.opacity(0.92) : Color.white.opacity(0.42))
                .shadow(color: tint.opacity(0.22), radius: 4)
        }
    }

    private func progressBeam(progress: Double, tint: Color) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let value = min(max(progress, 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 7)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.98),
                                Color.white.opacity(0.86)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(12, width * value), height: 7)
                    .shadow(color: tint.opacity(0.14), radius: 8)
            }
        }
        .frame(height: 7)
    }

    private func achievementBackground(
        tint: Color,
        isUnlocked: Bool,
        isPrimary: Bool
    ) -> some View {
        let strength: Double = isUnlocked ? 0.72 : 0.42
        let secondary = isPrimary
            ? Color(red: 0.04, green: 0.16, blue: 0.30)
            : Color(red: 0.12, green: 0.10, blue: 0.18)

        return RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.18 + strength * 0.16),
                        tint.opacity(0.10),
                        secondary.opacity(0.62),
                        Color(red: 0.035, green: 0.035, blue: 0.070)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                tint.opacity(0.16 + strength * 0.12),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: 130
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.07),
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
struct InsightsAchievementMiniCard: View {
    let badges: [InsightsBadgeData]
    let onTap: () -> Void

    private var featuredBadge: InsightsBadgeData? {
        badges.first { $0.isUnlocked } ?? badges.first
    }

    private var accent: Color {
        Color(red: 1.00, green: 0.55, blue: 0.18)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("SERİ")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.42))
                        .tracking(3.0)

                    Spacer()

                    Image(systemName: featuredBadge?.icon ?? "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(accent)
                }

                Spacer(minLength: 2)

                Text("3")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(accent)

                Text("gündür üst üste")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))

                Rectangle()
                    .fill(.white.opacity(0.075))
                    .frame(height: 1)

                Text(featuredBadge?.title ?? "İlk Focus")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.50))
                    .lineLimit(1)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.22),
                                Color.red.opacity(0.10),
                                Color.black.opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RadialGradient(
                            colors: [
                                accent.opacity(0.20),
                                .clear
                            ],
                            center: .topTrailing,
                            startRadius: 4,
                            endRadius: 120
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.white.opacity(0.075), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
