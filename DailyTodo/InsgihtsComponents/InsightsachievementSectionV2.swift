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

    private var unlockedBadges: [InsightsBadgeData] {
        badges.filter(\.isUnlocked)
    }

    private var activeTargets: [InsightsBadgeData] {
        badges
            .filter { !$0.isUnlocked }
            .sorted {
                ($0.progress ?? 0) > ($1.progress ?? 0)
            }
    }

    private var nextTarget: InsightsBadgeData? {
        activeTargets.first
    }

    private var recentUnlocked: InsightsBadgeData? {
        unlockedBadges.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Achievements")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text("\(unlockedBadges.count) kazanıldı • \(activeTargets.count) hedef aktif")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.48))
                }

                Spacer()

                Button("Tümü") {
                    onSeeAll()
                }
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.07), in: Capsule())
            }

            HStack(spacing: 12) {
                if let nextTarget {
                    achievementPreviewCard(
                        eyebrow: "Sıradaki",
                        badge: nextTarget,
                        tint: nextTarget.accent,
                        mode: .target
                    )
                }

                if let recentUnlocked {
                    achievementPreviewCard(
                        eyebrow: "Kazanıldı",
                        badge: recentUnlocked,
                        tint: recentUnlocked.accent,
                        mode: .unlocked
                    )
                } else if let fallback = activeTargets.dropFirst().first {
                    achievementPreviewCard(
                        eyebrow: "Yakında",
                        badge: fallback,
                        tint: fallback.accent,
                        mode: .locked
                    )
                }
            }
        }
    }

    private enum PreviewMode {
        case target
        case unlocked
        case locked
    }

    private func achievementPreviewCard(
        eyebrow: String,
        badge: InsightsBadgeData,
        tint: Color,
        mode: PreviewMode
    ) -> some View {
        let progress = min(max(badge.progress ?? (badge.isUnlocked ? 1 : 0), 0), 1)

        return Button {
            onSeeAll()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(tint)
                        .tracking(1.4)

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(tint.opacity(mode == .unlocked ? 0.22 : 0.13))
                            .frame(width: 34, height: 34)

                        Image(systemName: badge.icon)
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(mode == .locked ? .white.opacity(0.42) : .white)
                    }
                }

                Spacer(minLength: 0)

                Text(badge.title)
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                VStack(alignment: .leading, spacing: 7) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.08))

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            mode == .unlocked ? .green : tint,
                                            .white.opacity(0.82)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(10, proxy.size.width * progress))
                        }
                    }
                    .frame(height: 7)

                    HStack {
                        Text(mode == .unlocked ? "Tamamlandı" : "\(Int(progress * 100))%")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(mode == .unlocked ? .green : .white.opacity(0.68))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 156)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(mode == .unlocked ? 0.30 : 0.18),
                                Color.white.opacity(0.045),
                                Color.black.opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RadialGradient(
                            colors: [
                                tint.opacity(mode == .unlocked ? 0.28 : 0.16),
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
                            .stroke(.white.opacity(0.075), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct InsightsAchievementMiniCard: View {
    let badges: [InsightsBadgeData]
    let onTap: () -> Void

    private var unlockedCount: Int {
        badges.filter(\.isUnlocked).count
    }

    private var activeTarget: InsightsBadgeData? {
        badges
            .filter { !$0.isUnlocked }
            .sorted { ($0.progress ?? 0) > ($1.progress ?? 0) }
            .first
    }

    private var progress: Double {
        min(max(activeTarget?.progress ?? 0, 0), 1)
    }

    private var accent: Color {
        activeTarget?.accent ?? Color(red: 1.00, green: 0.55, blue: 0.18)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("ACHIEVE")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.42))
                        .tracking(2.6)

                    Spacer()

                    Image(systemName: activeTarget?.icon ?? "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(accent)
                }

                Spacer(minLength: 0)

                Text("\(unlockedCount)")
                    .font(.system(size: 54, weight: .heavy, design: .rounded))
                    .foregroundStyle(accent)

                Text("ödül kazanıldı")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))

                Rectangle()
                    .fill(.white.opacity(0.075))
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: 6) {
                    Text(activeTarget?.title ?? "İlk hedefini aç")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.08))

                            Capsule()
                                .fill(accent)
                                .frame(width: max(10, proxy.size.width * progress))
                        }
                    }
                    .frame(height: 6)
                }
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
                            .stroke(.white.opacity(0.075), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
