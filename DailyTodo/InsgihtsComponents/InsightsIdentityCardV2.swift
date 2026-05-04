//
//  InsightsIdentityCardV2.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//

import SwiftUI

struct InsightsIdentityCardV2: View {
    let snapshot: IdentityLevelSnapshot
    let isExpanded: Bool
    let hasPendingLevelUp: Bool
    let onTap: () -> Void

    private var accent: Color {
        hasPendingLevelUp ? Color(arenaHex: AppArenaPalette.gold) : snapshot.accent
    }

    private var secondaryAccent: Color {
        hasPendingLevelUp ? Color(arenaHex: AppArenaPalette.coral) : Color(arenaHex: AppArenaPalette.purple)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                topBar

                titleBlock

                progressArea

                bottomArea

                if isExpanded {
                    expandedArea
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(17)
            .frame(maxWidth: .infinity, minHeight: 214, alignment: .topLeading)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(accent)
                    .frame(width: 16, height: 1)

                Text("IDENTITY")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.7)
                    .foregroundStyle(accent)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Text("LV \(snapshot.level)")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(accent)
                .padding(.horizontal, 9)
                .frame(height: 26)
                .background(
                    Capsule()
                        .fill(accent.opacity(0.13))
                        .overlay(
                            Capsule()
                                .stroke(accent.opacity(0.18), lineWidth: 1)
                        )
                )
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(snapshot.title)
                .font(.system(size: 25, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            Text(hasPendingLevelUp ? "Yeni seviyeye hazırsın" : snapshot.statusText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(hasPendingLevelUp ? accent.opacity(0.95) : .white.opacity(0.50))
                .lineLimit(2)
        }
    }

    private var progressArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.075))
                        .frame(height: 9)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    accent,
                                    secondaryAccent,
                                    Color(arenaHex: AppArenaPalette.cyan).opacity(0.90)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(10, geo.size.width * min(max(snapshot.progress, 0), 1)),
                            height: 9
                        )
                        .shadow(color: accent.opacity(0.18), radius: 8, y: 2)
                }
            }
            .frame(height: 9)

            HStack {
                Text(snapshot.levelRangeText.uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(accent)
                    .lineLimit(1)

                Spacer()

                Text(snapshot.percentText)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.48))
                    .monospacedDigit()
            }
        }
    }

    private var bottomArea: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(hasPendingLevelUp ? Color(arenaHex: AppArenaPalette.green) : accent)
                .frame(width: 7, height: 7)
                .shadow(color: accent.opacity(0.35), radius: 7)

            Text(hasPendingLevelUp ? "LEVEL READY" : "PROGRESS")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(hasPendingLevelUp ? Color(arenaHex: AppArenaPalette.green) : accent)

            Spacer()

            Image(systemName: hasPendingLevelUp ? "arrow.up.forward.circle.fill" : "chevron.right")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(hasPendingLevelUp ? Color(arenaHex: AppArenaPalette.green) : .white.opacity(0.34))
        }
        .padding(.top, 2)
    }

    private var expandedArea: some View {
        VStack(spacing: 10) {
            Rectangle()
                .fill(Color.white.opacity(0.075))
                .frame(height: 1)

            stat(
                title: "Focus",
                value: "\(snapshot.focusSessions)/\(snapshot.nextRequirement.requiredFocusSessions)",
                tint: Color(arenaHex: AppArenaPalette.cyan)
            )

            stat(
                title: "Tasks",
                value: "\(snapshot.completedTasks)/\(snapshot.nextRequirement.requiredCompletedTasks)",
                tint: Color(arenaHex: AppArenaPalette.green)
            )

            stat(
                title: "Streak",
                value: "\(snapshot.streakDays)/\(snapshot.nextRequirement.requiredStreakDays)",
                tint: Color(arenaHex: AppArenaPalette.gold)
            )
        }
        .padding(.top, 2)
    }

    private func stat(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)

            Text(title.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.42))

            Spacer()

            Text(value)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            Capsule()
                .fill(tint.opacity(0.075))
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.090),
                        secondaryAccent.opacity(0.052),
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
                                accent.opacity(hasPendingLevelUp ? 0.22 : 0.15),
                                Color.clear
                            ],
                            center: .topTrailing,
                            startRadius: 6,
                            endRadius: 180
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                secondaryAccent.opacity(0.10),
                                Color.clear
                            ],
                            center: .bottomLeading,
                            startRadius: 8,
                            endRadius: 180
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(accent.opacity(hasPendingLevelUp ? 0.22 : 0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 16, y: 9)
    }
}
