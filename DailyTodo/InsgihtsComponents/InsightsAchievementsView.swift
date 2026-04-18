//
//  InsightsAchievementsView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//

import SwiftUI

struct InsightsAchievementsView: View {
    @Environment(\.dismiss) private var dismiss
    let badges: [InsightsBadgeData]

    private var unlocked: [InsightsBadgeData] {
        badges.filter { $0.isUnlocked }
    }

    private var inProgress: [InsightsBadgeData] {
        badges.filter { !$0.isUnlocked && ($0.progress ?? 0) > 0 }
    }

    private var locked: [InsightsBadgeData] {
        badges.filter { !$0.isUnlocked && ($0.progress ?? 0) == 0 }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    summaryCard

                    if !unlocked.isEmpty {
                        groupSection("Unlocked", items: unlocked)
                    }

                    if !inProgress.isEmpty {
                        groupSection("In Progress", items: inProgress)
                    }

                    if !locked.isEmpty {
                        groupSection("Locked", items: locked)
                    }

                    Spacer(minLength: 36)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Achievements")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Milestones and upcoming unlocks")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.60))
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var summaryCard: some View {
        InsightsGlassCard(cornerRadius: 28, tint: .purple, glowOpacity: 0.14) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Progress")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.56))

                    Text("\(unlocked.count) unlocked")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("\(inProgress.count) close to unlocking")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        .frame(width: 68, height: 68)

                    Text("\(badges.count)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func groupSection(_ title: String, items: [InsightsBadgeData]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(items) { badge in
                    badgeCard(badge)
                }
            }
        }
    }

    private func badgeCard(_ badge: InsightsBadgeData) -> some View {
        InsightsGlassCard(
            cornerRadius: 24,
            tint: badge.isUnlocked ? badge.accent : .white,
            glowOpacity: badge.isUnlocked ? 0.14 : 0.08,
            fillOpacity: badge.isUnlocked ? 0.12 : 0.07
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: badge.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(badge.isUnlocked ? badge.accent : .white.opacity(0.42))

                    Spacer()

                    Text(badge.isUnlocked ? "Unlocked" : "Locked")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.56))
                }

                Spacer(minLength: 0)

                Text(badge.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(badge.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.60))
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
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 144, alignment: .topLeading)
        }
    }
}
