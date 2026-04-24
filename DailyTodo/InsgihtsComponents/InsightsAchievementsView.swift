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

    private var unlocked: [InsightsBadgeData] { badges.filter { $0.isUnlocked } }
    private var inProgress: [InsightsBadgeData] { badges.filter { !$0.isUnlocked && ($0.progress ?? 0) > 0 } }
    private var locked: [InsightsBadgeData] { badges.filter { !$0.isUnlocked && ($0.progress ?? 0) == 0 } }

    private let accent = Color(red: 0.56, green: 0.36, blue: 1.00)
    private let secondaryAccent = Color(red: 0.16, green: 0.07, blue: 0.32)

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            AppBackground()

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
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text("Milestones and upcoming unlocks")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.08), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.07), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var summaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Progress")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(accent.opacity(0.98))
                    .tracking(0.8)

                Text("\(unlocked.count) unlocked")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text("\(inProgress.count) close to unlocking")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    .frame(width: 74, height: 74)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(0.34),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 4,
                            endRadius: 42
                        )
                    )
                    .frame(width: 74, height: 74)

                VStack(spacing: 1) {
                    Text("\(badges.count)")
                        .font(.system(size: 25, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text("total")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                }
            }
        }
        .padding(18)
        .background(
            premiumBackground(
                tint: accent,
                secondary: secondaryAccent,
                cornerRadius: 28,
                strength: 0.72
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    private func groupSection(_ title: String, items: [InsightsBadgeData]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
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
        let tint = badge.isUnlocked ? badge.accent : Color(red: 0.52, green: 0.58, blue: 0.72)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                premiumIcon(systemName: badge.icon, tint: tint, unlocked: badge.isUnlocked)

                Spacer()

                Text(badge.isUnlocked ? "Unlocked" : "Locked")
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
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(2)

            if let progress = badge.progress, !badge.isUnlocked {
                progressBeam(progress: progress, tint: tint)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 154, alignment: .topLeading)
        .background(
            premiumBackground(
                tint: tint,
                secondary: Color(red: 0.12, green: 0.10, blue: 0.18),
                cornerRadius: 24,
                strength: badge.isUnlocked ? 0.70 : 0.42
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.065), lineWidth: 1)
        )
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

    private func premiumBackground(
        tint: Color,
        secondary: Color,
        cornerRadius: CGFloat,
        strength: Double
    ) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.18 + strength * 0.18),
                        tint.opacity(0.10),
                        secondary.opacity(0.66),
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
                                tint.opacity(0.16 + strength * 0.12),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: 150
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.075),
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
