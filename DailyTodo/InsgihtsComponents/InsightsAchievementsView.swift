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

    @State private var selectedBadge: InsightsBadgeData?

    private var unlocked: [InsightsBadgeData] {
        badges
            .filter(\.isUnlocked)
            .sorted { $0.title < $1.title }
    }

    private var activeTargets: [InsightsBadgeData] {
        badges
            .filter { !$0.isUnlocked && (($0.progress ?? 0) > 0) }
            .sorted { ($0.progress ?? 0) > ($1.progress ?? 0) }
    }

    private var locked: [InsightsBadgeData] {
        badges
            .filter { !$0.isUnlocked && (($0.progress ?? 0) <= 0) }
            .sorted { $0.title < $1.title }
    }

    private var nextTarget: InsightsBadgeData? {
        activeTargets.first ?? locked.first
    }

    private let accent = Color(red: 0.56, green: 0.36, blue: 1.00)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    summaryCard

                    if let nextTarget {
                        nextTargetCard(nextTarget)
                    }

                    if !activeTargets.isEmpty {
                        groupSection(
                            title: "Aktif Hedefler",
                            subtitle: "Bir sonraki kazanımlar",
                            items: activeTargets,
                            layout: .large
                        )
                    }

                    if !locked.isEmpty {
                        groupSection(
                            title: "Zor Hedefler",
                            subtitle: "Uzun vadeli rozetler",
                            items: locked,
                            layout: .compact
                        )
                    }

                    if !unlocked.isEmpty {
                        groupSection(
                            title: "Kazanılanlar",
                            subtitle: "Açtığın rozetler",
                            items: unlocked,
                            layout: .compact
                        )
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedBadge) { badge in
            AchievementDetailSheet(badge: badge)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Achievements")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text("Hedefler, seriler ve kazanılan rozetler")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.08), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var summaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("PROGRESS")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(accent)
                    .tracking(1.4)

                Text("\(unlocked.count) kazanıldı")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text("\(activeTargets.count) aktif hedef • \(locked.count) zor hedef")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.66))
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(.white.opacity(0.10), lineWidth: 1)
                    .frame(width: 78, height: 78)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accent.opacity(0.34), .clear],
                            center: .center,
                            startRadius: 4,
                            endRadius: 42
                        )
                    )
                    .frame(width: 78, height: 78)

                VStack(spacing: 1) {
                    Text("\(badges.count)")
                        .font(.system(size: 27, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text("total")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
        .padding(18)
        .background(cardBackground(tint: accent, strength: 0.76, radius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        )
    }

    private func nextTargetCard(_ badge: InsightsBadgeData) -> some View {
        let progress = clampedProgress(badge)

        return Button {
            selectedBadge = badge
        } label: {
            HStack(spacing: 14) {
                badgeIcon(badge, size: 52)

                VStack(alignment: .leading, spacing: 6) {
                    Text("SIRADAKİ HEDEF")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(badge.accent)
                        .tracking(1.2)

                    Text(badge.title)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(badge.subtitle)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.56))
                        .lineLimit(1)

                    progressBar(progress: progress, tint: badge.accent, height: 7)
                }

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(badge.accent)
            }
            .padding(16)
            .background(cardBackground(tint: badge.accent, strength: 0.62, radius: 26))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(.white.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private enum SectionLayout {
        case large
        case compact
    }

    private func groupSection(
        title: String,
        subtitle: String,
        items: [InsightsBadgeData],
        layout: SectionLayout
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 23, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.46))
            }

            if layout == .large {
                VStack(spacing: 10) {
                    ForEach(items) { badge in
                        achievementRow(badge)
                    }
                }
            } else {
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
    }

    private func achievementRow(_ badge: InsightsBadgeData) -> some View {
        let progress = clampedProgress(badge)

        return Button {
            selectedBadge = badge
        } label: {
            HStack(spacing: 14) {
                badgeIcon(badge, size: 46)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(badge.title)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Spacer()

                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(badge.accent)
                    }

                    Text(badge.subtitle)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.56))
                        .lineLimit(1)

                    progressBar(progress: progress, tint: badge.accent, height: 6)
                }
            }
            .padding(14)
            .background(cardBackground(tint: badge.accent, strength: 0.48, radius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.065), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func badgeCard(_ badge: InsightsBadgeData) -> some View {
        let progress = clampedProgress(badge)
        let tint = badge.isUnlocked ? badge.accent : Color(red: 0.52, green: 0.58, blue: 0.72)

        return Button {
            selectedBadge = badge
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    badgeIcon(badge, tintOverride: tint, size: 36)

                    Spacer()

                    Text(badge.isUnlocked ? "Kazanıldı" : "Locked")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                }

                Spacer(minLength: 0)

                Text(badge.title)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(badge.subtitle)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(2)

                progressBar(
                    progress: badge.isUnlocked ? 1 : progress,
                    tint: badge.isUnlocked ? .green : tint,
                    height: 6
                )
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 162, alignment: .topLeading)
            .background(
                cardBackground(
                    tint: tint,
                    strength: badge.isUnlocked ? 0.62 : 0.34,
                    radius: 24
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.065), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func badgeIcon(
        _ badge: InsightsBadgeData,
        tintOverride: Color? = nil,
        size: CGFloat
    ) -> some View {
        let tint = tintOverride ?? badge.accent

        return ZStack {
            Circle()
                .fill(tint.opacity(badge.isUnlocked ? 0.22 : 0.12))
                .frame(width: size, height: size)

            Image(systemName: badge.icon)
                .font(.system(size: size * 0.34, weight: .black))
                .foregroundStyle(badge.isUnlocked ? .white : .white.opacity(0.45))
        }
    }

    private func progressBar(progress: Double, tint: Color, height: CGFloat) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.08))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint, .white.opacity(0.84)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(10, proxy.size.width * min(max(progress, 0), 1)))
            }
        }
        .frame(height: height)
    }

    private func cardBackground(
        tint: Color,
        strength: Double,
        radius: CGFloat
    ) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.18 + strength * 0.18),
                        tint.opacity(0.08),
                        Color(red: 0.11, green: 0.10, blue: 0.17).opacity(0.68),
                        Color(red: 0.035, green: 0.035, blue: 0.070)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RadialGradient(
                    colors: [
                        tint.opacity(0.16 + strength * 0.10),
                        .clear
                    ],
                    center: .topLeading,
                    startRadius: 4,
                    endRadius: 140
                )
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            )
    }

    private func clampedProgress(_ badge: InsightsBadgeData) -> Double {
        min(max(badge.progress ?? (badge.isUnlocked ? 1 : 0), 0), 1)
    }
}

private struct AchievementDetailSheet: View {
    let badge: InsightsBadgeData
    @Environment(\.dismiss) private var dismiss

    private var progress: Double {
        min(max(badge.progress ?? (badge.isUnlocked ? 1 : 0), 0), 1)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Achievement")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(badge.accent)
                        .tracking(1.4)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(badge.accent.opacity(0.18))
                            .frame(width: 58, height: 58)

                        Image(systemName: badge.icon)
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(badge.title)
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)

                        Text(badge.isUnlocked ? "Kazanıldı" : "Henüz tamamlanmadı")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(badge.isUnlocked ? .green : .white.opacity(0.58))
                    }
                }

                Text(badge.subtitle)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineSpacing(3)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("İlerleme")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.62))

                        Spacer()

                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(badge.isUnlocked ? .green : badge.accent)
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.08))

                            Capsule()
                                .fill(badge.isUnlocked ? .green : badge.accent)
                                .frame(width: max(10, proxy.size.width * progress))
                        }
                    }
                    .frame(height: 8)
                }

                Spacer()
            }
            .padding(22)
        }
        .preferredColorScheme(.dark)
    }
}
