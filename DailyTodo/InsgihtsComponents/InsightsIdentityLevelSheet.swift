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
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [
                    currentLevel.accent.opacity(0.28),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 360
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    nextLevel.accent.opacity(0.16),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 30,
                endRadius: 420
            )
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Identity Level")
                    .font(.system(size: 31, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text("Bir sonraki statü için gerekenler")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.56))
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.08), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MEVCUT STATÜ")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(currentLevel.accent)
                        .tracking(1.5)

                    Text(currentLevel.title)
                        .font(.system(size: 33, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(snapshot.isMaxLevel ? "Maksimum seviyedesin" : "Lv.\(nextLevel.level) için ilerliyorsun")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                }

                Spacer()

                levelBadge(level: currentLevel.level, tint: currentLevel.accent)
            }

            progressBeam(progress: snapshot.progress, tint: currentLevel.accent)

            HStack {
                Text("\(snapshot.percentText) tamamlandı")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(currentLevel.accent)

                Spacer()

                Text(snapshot.statusText)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(snapshot.isReadyForLevelUp ? .green : .white.opacity(0.42))
            }
        }
        .padding(18)
        .background(cardBackground(tint: currentLevel.accent, strength: 0.86))
    }

    private var requirementsCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("Seviye atlama şartları")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                Text(snapshot.levelRangeText)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(currentLevel.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(currentLevel.accent.opacity(0.12), in: Capsule())
            }

            requirementRow(
                icon: "scope",
                title: "Focus oturumu",
                currentValue: snapshot.focusSessions,
                targetValue: nextLevel.requiredFocusSessions,
                ratio: snapshot.focusRatio
            )

            requirementRow(
                icon: "checkmark.circle.fill",
                title: "Görev tamamla",
                currentValue: snapshot.completedTasks,
                targetValue: nextLevel.requiredCompletedTasks,
                ratio: snapshot.taskRatio
            )

            requirementRow(
                icon: "flame.fill",
                title: "Seri günü",
                currentValue: snapshot.streakDays,
                targetValue: nextLevel.requiredStreakDays,
                ratio: snapshot.streakRatio
            )
        }
        .padding(18)
        .background(cardBackground(tint: currentLevel.accent, strength: 0.58))
    }

    private var nextLevelCard: some View {
        HStack(spacing: 14) {
            levelBadge(level: nextLevel.level, tint: nextLevel.accent)

            VStack(alignment: .leading, spacing: 5) {
                Text(snapshot.isMaxLevel ? "Final statü" : "Sonraki statü")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.48))

                Text("Lv.\(nextLevel.level) • \(nextLevel.title)")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(nextLevelSummary)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(18)
        .background(cardBackground(tint: nextLevel.accent, strength: 0.62))
    }

    private var levelUpButton: some View {
        Button {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                onLevelUp()
            }
        } label: {
            Text("Yeni seviyeye geç")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var nextLevelSummary: String {
        if snapshot.isMaxLevel {
            return "Bu seviyeden sonra yeni ligler eklenebilir."
        }

        return "\(nextLevel.requiredFocusSessions) focus • \(nextLevel.requiredCompletedTasks) görev • \(nextLevel.requiredStreakDays) gün seri"
    }

    private func requirementRow(
        icon: String,
        title: String,
        currentValue: Int,
        targetValue: Int,
        ratio: Double
    ) -> some View {
        let isCompleted = currentValue >= targetValue
        let tint: Color = isCompleted ? .green : currentLevel.accent

        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(tint)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                Text("\(min(currentValue, targetValue))/\(targetValue)")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(tint)
            }

            progressBeam(progress: ratio, tint: tint, height: 6)
        }
        .padding(13)
        .background(.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func levelBadge(level: Int, tint: Color) -> some View {
        VStack(spacing: 0) {
            Text("Lv")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(.white.opacity(0.55))

            Text("\(level)")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: 66, height: 66)
        .background(tint.opacity(0.16), in: Circle())
        .overlay(Circle().stroke(tint.opacity(0.22), lineWidth: 1))
    }

    private func progressBeam(
        progress: Double,
        tint: Color,
        height: CGFloat = 8
    ) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.08))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                tint,
                                .white.opacity(0.82)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: height)
    }

    private func cardBackground(tint: Color, strength: Double) -> some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.18 + strength * 0.18),
                        tint.opacity(0.08),
                        Color.white.opacity(0.045),
                        Color.black.opacity(0.88)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RadialGradient(
                    colors: [
                        tint.opacity(0.22),
                        .clear
                    ],
                    center: .topTrailing,
                    startRadius: 8,
                    endRadius: 170
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.075), lineWidth: 1)
            )
    }
}
