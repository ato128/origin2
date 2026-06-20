//
//  InsightsIdentityLevelSheet.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 27.04.2026.
//

import SwiftUI

struct InsightsIdentityLevelSheet: View {
    @Environment(\.dismiss) private var dismiss

    let snapshot: IdentityLevelSnapshot
    let onLevelUp: () -> Void

    private var currentLevel: IdentityLevelInfo {
        snapshot.currentRequirement
    }

    private var nextLevel: IdentityLevelInfo {
        snapshot.nextRequirement
    }

    private var accent: Color {
        snapshot.isReadyForLevelUp ? Color(arenaHex: AppArenaPalette.gold) : currentLevel.accent
    }

    private var secondaryAccent: Color {
        snapshot.isReadyForLevelUp ? Color(arenaHex: AppArenaPalette.coral) : nextLevel.accent
    }

    var body: some View {
        ZStack {
            background

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    heroCard
                    requirementsCard
                    nextLevelCard

                    if snapshot.isReadyForLevelUp {
                        levelUpButton
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var background: some View {
        ArenaBackground(
            primaryGlow: accent,
            secondaryGlow: Color(arenaHex: AppArenaPalette.purple),
            warmGlow: secondaryAccent,
            intensity: 0.92
        )
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(accent)
                        .frame(width: 20, height: 1)

                    Text("IDENTITY LEVEL")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(2.3)
                        .foregroundStyle(accent)
                        .lineLimit(1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("Identity")
                        .font(.system(size: 38, weight: .black))
                        .foregroundStyle(.white)

                    Text("level")
                        .font(.system(size: 35, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    accent,
                                    secondaryAccent
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .lineLimit(1)
                .minimumScaleFactor(0.72)

                Text(tr("ils_requirements"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.095),
                                        Color.white.opacity(0.045)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.11), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.24), radius: 12, y: 6)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(accent)
                            .frame(width: 18, height: 1)

                        Text("CURRENT STATUS")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.7)
                            .foregroundStyle(accent)
                    }

                    Text(currentLevel.title)
                        .font(.system(size: 31, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.74)

                    Text(snapshot.isMaxLevel ? "Maksimum seviyedesin" : tr("ils_progressing_lv", nextLevel.level))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                }

                Spacer()

                levelBadge(level: currentLevel.level, tint: accent)
            }

            progressBeam(progress: snapshot.progress, tint: accent)

            HStack(spacing: 8) {
                Text("\(snapshot.percentText) \(tr("done_word"))")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(accent)

                Spacer()

                HStack(spacing: 6) {
                    Circle()
                        .fill(snapshot.isReadyForLevelUp ? Color(arenaHex: AppArenaPalette.green) : .white.opacity(0.34))
                        .frame(width: 7, height: 7)

                    Text(snapshot.isReadyForLevelUp ? "LEVEL READY" : snapshot.statusText.uppercased())
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(0.7)
                        .foregroundStyle(snapshot.isReadyForLevelUp ? Color(arenaHex: AppArenaPalette.green) : .white.opacity(0.42))
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                }
            }
        }
        .padding(18)
        .background(cardBackground(tint: accent, strength: 0.86))
    }

    private var requirementsCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(accent)
                            .frame(width: 18, height: 1)

                        Text("REQUIREMENTS")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.7)
                            .foregroundStyle(accent)
                    }

                    Text(tr("ils_level_reqs"))
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(.white)
                }

                Spacer()

                Text(snapshot.levelRangeText.uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(accent)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(
                        Capsule()
                            .fill(accent.opacity(0.12))
                            .overlay(
                                Capsule()
                                    .stroke(accent.opacity(0.18), lineWidth: 1)
                            )
                    )
            }

            requirementRow(
                icon: "scope",
                title: "Focus oturumu",
                currentValue: snapshot.focusSessions,
                targetValue: nextLevel.requiredFocusSessions,
                ratio: snapshot.focusRatio,
                tint: Color(arenaHex: AppArenaPalette.cyan)
            )

            requirementRow(
                icon: "checkmark.circle.fill",
                title: tr("ils_complete_task"),
                currentValue: snapshot.completedTasks,
                targetValue: nextLevel.requiredCompletedTasks,
                ratio: snapshot.taskRatio,
                tint: Color(arenaHex: AppArenaPalette.green)
            )

            requirementRow(
                icon: "flame.fill",
                title: tr("ils_streak_day"),
                currentValue: snapshot.streakDays,
                targetValue: nextLevel.requiredStreakDays,
                ratio: snapshot.streakRatio,
                tint: Color(arenaHex: AppArenaPalette.gold)
            )
        }
        .padding(18)
        .background(cardBackground(tint: accent, strength: 0.58))
    }

    private var nextLevelCard: some View {
        HStack(spacing: 14) {
            levelBadge(level: nextLevel.level, tint: secondaryAccent)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(secondaryAccent)
                        .frame(width: 16, height: 1)

                    Text(snapshot.isMaxLevel ? "FINAL STATUS" : "NEXT STATUS")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(secondaryAccent)
                }

                Text("Lv.\(nextLevel.level) • \(nextLevel.title)")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(nextLevelSummary)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(18)
        .background(cardBackground(tint: secondaryAccent, strength: 0.62))
    }

    private var levelUpButton: some View {
        Button {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                onLevelUp()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.up.forward.circle.fill")
                    .font(.system(size: 17, weight: .black))

                Text(tr("ils_level_up_caps"))
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .tracking(0.9)

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .black))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(arenaHex: AppArenaPalette.gold),
                                Color(arenaHex: AppArenaPalette.coral)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.13), lineWidth: 1)
                    )
                    .shadow(color: Color(arenaHex: AppArenaPalette.gold).opacity(0.22), radius: 16, y: 8)
            )
        }
        .buttonStyle(.plain)
    }

    private var nextLevelSummary: String {
        if snapshot.isMaxLevel {
            return "Bu seviyeden sonra yeni ligler eklenebilir."
        }

        return "\(nextLevel.requiredFocusSessions) focus • \(tr("rel_task_count", nextLevel.requiredCompletedTasks)) • \(tr("oc_day_streak", nextLevel.requiredStreakDays))"
    }

    private func requirementRow(
        icon: String,
        title: String,
        currentValue: Int,
        targetValue: Int,
        ratio: Double,
        tint: Color
    ) -> some View {
        let isCompleted = currentValue >= targetValue
        let resolvedTint: Color = isCompleted ? Color(arenaHex: AppArenaPalette.green) : tint

        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(resolvedTint)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(resolvedTint.opacity(0.12))
                    )

                Text(title)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)

                Spacer()

                Text("\(min(currentValue, targetValue))/\(targetValue)")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(resolvedTint)
                    .monospacedDigit()
            }

            progressBeam(progress: ratio, tint: resolvedTint, height: 6)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            resolvedTint.opacity(0.060),
                            Color.white.opacity(0.035)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(resolvedTint.opacity(0.11), lineWidth: 1)
                )
        )
    }

    private func levelBadge(level: Int, tint: Color) -> some View {
        VStack(spacing: 0) {
            Text("LV")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.52))

            Text("\(level)")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(width: 66, height: 66)
        .background(
            Circle()
                .fill(tint.opacity(0.14))
                .overlay(
                    Circle()
                        .stroke(tint.opacity(0.22), lineWidth: 1)
                )
                .shadow(color: tint.opacity(0.18), radius: 12, y: 6)
        )
    }

    private func progressBeam(
        progress: Double,
        tint: Color,
        height: CGFloat = 8
    ) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.075))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                tint,
                                Color(arenaHex: AppArenaPalette.cyan).opacity(0.82)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, proxy.size.width * min(max(progress, 0), 1)))
                    .shadow(color: tint.opacity(0.18), radius: 7, y: 2)
            }
        }
        .frame(height: height)
    }

    private func cardBackground(tint: Color, strength: Double) -> some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.075 + strength * 0.035),
                        Color(arenaHex: AppArenaPalette.purple).opacity(0.040),
                        Color(arenaHex: AppArenaPalette.surface).opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                tint.opacity(0.11 + strength * 0.08),
                                Color.clear
                            ],
                            center: .topTrailing,
                            startRadius: 8,
                            endRadius: 180
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(arenaHex: AppArenaPalette.blue).opacity(0.070),
                                Color.clear
                            ],
                            center: .bottomLeading,
                            startRadius: 8,
                            endRadius: 190
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(tint.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 16, y: 9)
    }
}
