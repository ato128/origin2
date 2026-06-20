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
            headerRow

            HStack(spacing: 12) {
                if let nextTarget {
                    achievementPreviewCard(
                        eyebrow: tr("ias_next"),
                        badge: nextTarget,
                        tint: nextTarget.accent,
                        mode: .target
                    )
                }

                if let recentUnlocked {
                    achievementPreviewCard(
                        eyebrow: tr("ia_earned_label"),
                        badge: recentUnlocked,
                        tint: recentUnlocked.accent,
                        mode: .unlocked
                    )
                } else if let fallback = activeTargets.dropFirst().first {
                    achievementPreviewCard(
                        eyebrow: tr("bcd_soon"),
                        badge: fallback,
                        tint: fallback.accent,
                        mode: .locked
                    )
                }
            }
        }
    }
}

private extension InsightsAchievementsSectionV2 {

    enum PreviewMode {
        case target
        case unlocked
        case locked
    }

    var sectionAccent: Color {
        if let nextTarget {
            return nextTarget.accent
        }

        if let recentUnlocked {
            return recentUnlocked.accent
        }

        return Color(arenaHex: AppArenaPalette.gold)
    }

    var headerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(sectionAccent)
                        .frame(width: 18, height: 1)

                    Text("ACHIEVEMENTS")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(sectionAccent)
                }

                Text(tr("ias_rewards"))
                    .font(.system(size: 25, weight: .black))
                    .foregroundStyle(.white)

                Text("\(tr("ia_unlocked_n", unlockedBadges.count)) • \(tr("ias_targets_active", activeTargets.count))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
            }

            Spacer()

            Button {
                onSeeAll()
            } label: {
                Text(tr("ch_all_caps"))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(sectionAccent)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(
                        Capsule()
                            .fill(sectionAccent.opacity(0.13))
                            .overlay(
                                Capsule()
                                    .stroke(sectionAccent.opacity(0.18), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }

    func achievementPreviewCard(
        eyebrow: String,
        badge: InsightsBadgeData,
        tint: Color,
        mode: PreviewMode
    ) -> some View {
        let progress = min(max(badge.progress ?? (badge.isUnlocked ? 1 : 0), 0), 1)
        let resolvedTint = mode == .unlocked ? Color(arenaHex: AppArenaPalette.green) : tint

        return Button {
            onSeeAll()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 7) {
                            Rectangle()
                                .fill(resolvedTint)
                                .frame(width: 14, height: 1)

                            Text(eyebrow.uppercased())
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .tracking(1.2)
                                .foregroundStyle(resolvedTint)
                                .lineLimit(1)
                        }

                        Text(mode == .unlocked ? "TAMAMLANDI" : "\(Int(progress * 100))%")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(.white.opacity(0.38))
                    }

                    Spacer()

                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(resolvedTint.opacity(mode == .unlocked ? 0.16 : 0.12))
                            .frame(width: 36, height: 36)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(resolvedTint.opacity(0.16), lineWidth: 1)
                            )

                        Image(systemName: badge.icon)
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(mode == .locked ? .white.opacity(0.42) : resolvedTint)
                    }
                }

                Spacer(minLength: 0)

                Text(badge.title)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                VStack(alignment: .leading, spacing: 7) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.075))

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            resolvedTint,
                                            tint.opacity(0.90),
                                            Color(arenaHex: AppArenaPalette.cyan).opacity(0.78)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(10, proxy.size.width * progress))
                                .shadow(color: resolvedTint.opacity(0.16), radius: 7, y: 2)
                        }
                    }
                    .frame(height: 7)

                    HStack {
                        Text(mode == .unlocked ? "KAZANILDI" : "HEDEF")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(0.7)
                            .foregroundStyle(resolvedTint)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.white.opacity(0.30))
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
                                resolvedTint.opacity(mode == .unlocked ? 0.095 : 0.080),
                                Color(arenaHex: AppArenaPalette.purple).opacity(0.040),
                                Color(arenaHex: AppArenaPalette.surface).opacity(0.94)
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
                                        resolvedTint.opacity(mode == .unlocked ? 0.17 : 0.13),
                                        Color.clear
                                    ],
                                    center: .topTrailing,
                                    startRadius: 4,
                                    endRadius: 135
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(resolvedTint.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.20), radius: 14, y: 7)
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
        activeTarget?.accent ?? Color(arenaHex: AppArenaPalette.gold)
    }

    private var resolvedAccent: Color {
        unlockedCount > 0 ? Color(arenaHex: AppArenaPalette.gold) : accent
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                topRow

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(unlockedCount)")
                        .font(.system(size: 48, weight: .black))
                        .foregroundStyle(resolvedAccent)
                        .monospacedDigit()
                        .lineLimit(1)

                    Text(tr("ias_reward_earned"))
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Rectangle()
                    .fill(Color.white.opacity(0.075))
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: 7) {
                    Text(activeTarget?.title ?? tr("ias_unlock_first"))
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.075))

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            resolvedAccent,
                                            accent,
                                            Color(arenaHex: AppArenaPalette.cyan).opacity(0.78)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(10, proxy.size.width * progress))
                                .shadow(color: resolvedAccent.opacity(0.16), radius: 7, y: 2)
                        }
                    }
                    .frame(height: 7)
                }
            }
            .padding(17)
            .frame(maxWidth: .infinity, minHeight: 214, alignment: .topLeading)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
    }
}

private extension InsightsAchievementMiniCard {

    var topRow: some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(resolvedAccent)
                    .frame(width: 16, height: 1)

                Text("ACHIEVE")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.7)
                    .foregroundStyle(resolvedAccent)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(resolvedAccent.opacity(0.13))
                    .frame(width: 34, height: 34)
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(resolvedAccent.opacity(0.16), lineWidth: 1)
                    )

                Image(systemName: activeTarget?.icon ?? "sparkles")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(resolvedAccent)
            }
        }
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        resolvedAccent.opacity(0.085),
                        Color(arenaHex: AppArenaPalette.coral).opacity(0.042),
                        Color(arenaHex: AppArenaPalette.surface).opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                resolvedAccent.opacity(0.15),
                                Color.clear
                            ],
                            center: .topTrailing,
                            startRadius: 6,
                            endRadius: 175
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(0.10),
                                Color.clear
                            ],
                            center: .bottomLeading,
                            startRadius: 8,
                            endRadius: 175
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(resolvedAccent.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 16, y: 9)
    }
}
