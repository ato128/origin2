//
//  InsightsAchievementCardV3.swift
//  DailyTodo
//
//  Tek kart achievement özeti.
//  - Üst: eyebrow + "X / Y" + "tümü ↗" hint
//  - Sol: SON KAZANILAN (gold halo, ikon büyük)
//  - Sağ: SIRADAKİ (mor border, mini progress bar)
//  - Alt strip: "+N KİLİTLİ" + soluk ikonlar
//
//  Tap → InsightsAchievementsView sheet açılır.
//

import SwiftUI

struct InsightsAchievementCardV3: View {
    let badges: [InsightsBadgeData]
    let onTap: () -> Void

    private var unlocked: [InsightsBadgeData] {
        badges.filter(\.isUnlocked)
    }

    private var lastUnlocked: InsightsBadgeData? {
        unlocked.first
    }

    private var nextTarget: InsightsBadgeData? {
        badges
            .filter { !$0.isUnlocked }
            .sorted { ($0.progress ?? 0) > ($1.progress ?? 0) }
            .first
    }

    private var locked: [InsightsBadgeData] {
        badges.filter { !$0.isUnlocked && ($0.progress ?? 0) == 0 }
    }

    private var sectionAccent: Color {
        if lastUnlocked != nil {
            return Color(arenaHex: AppArenaPalette.gold)
        }
        return nextTarget?.accent ?? Color(arenaHex: AppArenaPalette.gold)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            eyebrowRow

            Button(action: onTap) {
                cardContent
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Eyebrow row (üstte)

    private var eyebrowRow: some View {
        HStack(spacing: 7) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(arenaHex: AppArenaPalette.gold),
                            Color(arenaHex: AppArenaPalette.coral)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 16, height: 1)

            Text("ACHIEVEMENTS")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(arenaHex: AppArenaPalette.gold),
                            Color(arenaHex: AppArenaPalette.coral)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Text("· \(unlocked.count)/\(badges.count)")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))

            Spacer()

            HStack(spacing: 4) {
                Text("tümü")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.50))

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.white.opacity(0.50))
            }
        }
    }

    // MARK: Card content — tek kart, 2 yan + alt strip

    private var cardContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                lastUnlockedTile
                nextTargetTile
            }

            // Alt strip — locked preview
            if !locked.isEmpty {
                lockedStrip
            }
        }
        .padding(13)
        .background(cardBackground)
    }

    // MARK: SOL — son kazanılan

    @ViewBuilder
    private var lastUnlockedTile: some View {
        if let badge = lastUnlocked {
            VStack(alignment: .center, spacing: 5) {
                Text("SON KAZANILAN")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(0.9)
                    .foregroundStyle(Color(arenaHex: AppArenaPalette.gold))

                ZStack {
                    Circle()
                        .fill(Color(arenaHex: AppArenaPalette.gold).opacity(0.18))
                        .frame(width: 56, height: 56)
                        .shadow(
                            color: Color(arenaHex: AppArenaPalette.gold).opacity(0.40),
                            radius: 10,
                            y: 4
                        )

                    Image(systemName: badge.icon)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(Color(arenaHex: AppArenaPalette.gold))
                }

                Text(badge.title)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.center)

                Text("kazanıldı")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(arenaHex: AppArenaPalette.gold).opacity(0.16),
                                Color(arenaHex: AppArenaPalette.coral).opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(arenaHex: AppArenaPalette.gold).opacity(0.30), lineWidth: 1)
                    )
            )
        } else {
            // Henüz hiç kazanılmamış — ilk hedefi göster
            emptyTile(
                title: "İLK HEDEFİN",
                subtitle: "Henüz açılmadı",
                icon: "lock.fill",
                tint: .white.opacity(0.35)
            )
        }
    }

    // MARK: SAĞ — sıradaki

    @ViewBuilder
    private var nextTargetTile: some View {
        if let target = nextTarget {
            let progress = min(max(target.progress ?? 0, 0), 1)
            let tint = target.accent

            VStack(alignment: .center, spacing: 5) {
                Text("SIRADAKİ")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(0.9)
                    .foregroundStyle(tint)

                ZStack {
                    Circle()
                        .fill(tint.opacity(0.16))
                        .frame(width: 56, height: 56)
                        .shadow(
                            color: tint.opacity(0.30),
                            radius: 8,
                            y: 4
                        )

                    Image(systemName: target.icon)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(tint)
                        .opacity(0.85)
                }

                Text(target.title)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.center)

                // Mini progress
                HStack(spacing: 5) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.08))

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [tint, Color(arenaHex: AppArenaPalette.cyan).opacity(0.80)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(4, geo.size.width * progress))
                        }
                    }
                    .frame(width: 50, height: 3)

                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(tint)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.12),
                                Color(arenaHex: AppArenaPalette.cyan).opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(tint.opacity(0.24), lineWidth: 1)
                    )
            )
        } else {
            emptyTile(
                title: "TAMAMI BİTTİ",
                subtitle: "Tebrikler",
                icon: "checkmark.seal.fill",
                tint: Color(arenaHex: AppArenaPalette.green)
            )
        }
    }

    private func emptyTile(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .center, spacing: 5) {
            Text(title)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .tracking(0.9)
                .foregroundStyle(tint)

            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(tint)
            }

            Text(subtitle)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.025))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: Alt — locked strip

    private var lockedStrip: some View {
        HStack(spacing: 8) {
            Text("+\(locked.count) KİLİTLİ")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(.white.opacity(0.45))

            Spacer(minLength: 6)

            // İlk 4 locked badge ikonu (mat)
            HStack(spacing: 5) {
                ForEach(Array(locked.prefix(4)), id: \.id) { badge in
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.04))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
                            )

                        Image(systemName: badge.icon)
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.white.opacity(0.30))
                    }
                }

                if locked.count > 4 {
                    Text("+\(locked.count - 4)")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.horizontal, 6)
                        .frame(height: 22)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.045))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                                )
                        )
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.020))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        )
    }

    // MARK: Card background

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        sectionAccent.opacity(0.080),
                        Color(arenaHex: AppArenaPalette.purple).opacity(0.042),
                        Color(arenaHex: AppArenaPalette.surface).opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                sectionAccent.opacity(0.15),
                                Color.clear
                            ],
                            center: .topTrailing,
                            startRadius: 6,
                            endRadius: 180
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(sectionAccent.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 14, y: 8)
    }
}
