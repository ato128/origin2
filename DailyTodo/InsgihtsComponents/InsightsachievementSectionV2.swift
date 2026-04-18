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
                    .font(.system(size: 22, weight: .bold, design: .rounded))
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
                        tint: recentUnlocked.isUnlocked ? recentUnlocked.accent : .white,
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
            InsightsGlassCard(
                cornerRadius: 26,
                tint: tint,
                glowOpacity: badge.isUnlocked ? 0.16 : 0.10,
                fillOpacity: badge.isUnlocked ? 0.14 : 0.08,
                strokeOpacity: 0.08
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.54))

                        Spacer()

                        Image(systemName: badge.icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(badge.isUnlocked ? tint : .white.opacity(0.42))
                    }

                    Spacer(minLength: 0)

                    Text(badge.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    if let progress = badge.progress, !badge.isUnlocked {
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 6)

                            Capsule()
                                .fill(Color.white.opacity(0.84))
                                .frame(width: max(12, 120 * progress), height: 6)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.white.opacity(0.82))
                                .frame(width: 6, height: 6)

                            Text(badge.isUnlocked ? "Unlocked" : "Locked")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 138, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
    }
}
