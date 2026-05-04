//
//  EventRow.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 11.03.2026.
//

import SwiftUI

struct EventRow: View {
    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue

    let event: EventItem
    let timeText: String
    let hasConflict: Bool
    let nowMinute: Int
    let isTodaySelected: Bool
    let isWorkout: Bool
    let workoutDay: String?
    let exerciseCount: Int

    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onComplete: (() -> Void)?

    private let palette = ThemePalette()

    private var start: Int { event.startMinute }
    private var end: Int { event.startMinute + event.durationMinute }
    private var duration: Int { max(1, event.durationMinute) }

    private var rawAccent: Color {
        hexColor(event.colorHex)
    }

    private var isLive: Bool {
        guard !event.isCompleted else { return false }
        guard isTodaySelected else { return false }
        return nowMinute >= start && nowMinute < end
    }

    private var isUpNext: Bool {
        guard !event.isCompleted else { return false }
        guard isTodaySelected else { return false }
        let diff = start - nowMinute
        return diff > 0 && diff <= 20
    }

    private var isSoon: Bool {
        guard !event.isCompleted else { return false }
        guard isTodaySelected else { return false }
        let diff = start - nowMinute
        return diff > 0 && diff <= 5
    }

    private var isDoneByTime: Bool {
        guard !event.isCompleted else { return false }
        guard isTodaySelected else { return false }
        return nowMinute >= end
    }

    private var isDone: Bool {
        event.isCompleted || isDoneByTime
    }

    private var progress: Double {
        guard isLive else { return 0 }
        return min(1, max(0, Double(nowMinute - start) / Double(duration)))
    }

    private var minutesLeft: Int { max(0, end - nowMinute) }
    private var minutesUntilStart: Int { max(0, start - nowMinute) }

    private var accent: Color {
        if event.isCompleted { return Color(arenaHex: AppArenaPalette.green) }
        if hasConflict { return Color(arenaHex: AppArenaPalette.coral) }
        if isSoon { return Color(arenaHex: AppArenaPalette.gold) }
        if isDoneByTime { return .white.opacity(0.34) }
        return rawAccent
    }

    private var secondaryAccent: Color {
        if event.isCompleted { return Color(arenaHex: AppArenaPalette.green) }
        if hasConflict { return Color(arenaHex: AppArenaPalette.coral) }
        if isLive { return Color(arenaHex: AppArenaPalette.cyan) }
        if isUpNext || isSoon { return Color(arenaHex: AppArenaPalette.gold) }
        return Color(arenaHex: AppArenaPalette.purple)
    }

    private var statusText: String? {
        if event.isCompleted { return "Tamamlandı" }
        if isLive { return "Şu an" }
        if isSoon { return "Başlıyor" }
        if isUpNext { return "Sıradaki" }
        if isDoneByTime { return "Bitti" }
        return nil
    }

    private var subtitleText: String {
        if isWorkout {
            if let day = workoutDay, !day.isEmpty {
                if exerciseCount > 0 { return "\(day) • \(exerciseCount) hareket" }
                return day
            }

            if exerciseCount > 0 {
                return "\(exerciseCount) hareket"
            }
        }

        if let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines),
           !location.isEmpty {
            return location
        }

        return "\(max(15, event.durationMinute)) dk"
    }

    private var supportingInfoText: String? {
        if isLive { return "\(minutesLeft) dk kaldı" }
        if isUpNext { return "\(minutesUntilStart) dk sonra" }
        if isDoneByTime { return "Bugünkü blok tamamlandı" }
        return nil
    }

    private var statusTintColor: Color {
        if event.isCompleted { return Color(arenaHex: AppArenaPalette.green) }
        if isLive { return accent }
        if isSoon { return Color(arenaHex: AppArenaPalette.gold) }
        if isUpNext { return accent }
        if isDoneByTime { return .white.opacity(0.38) }
        return accent
    }

    private var timeRangePillTint: Color {
        if event.isCompleted { return Color(arenaHex: AppArenaPalette.green) }
        if isLive { return accent }
        if isUpNext { return accent }
        return .white.opacity(0.48)
    }

    var body: some View {
        HStack(spacing: 12) {
            timelineRail

            VStack(alignment: .leading, spacing: 8) {
                headerRow

                if let supportingInfoText {
                    supportingInfoRow(text: supportingInfoText)
                }

                if isLive {
                    liveProgressBlock
                }

                footerMetaRow
            }
            .padding(.vertical, 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(cardBackground)
        .overlay(cardStroke)
        .shadow(color: Color.black.opacity(0.20), radius: 12, y: 6)
        .shadow(
            color: isLive ? accent.opacity(0.14) : .clear,
            radius: isLive ? 16 : 0,
            y: isLive ? 7 : 0
        )
        .opacity(isDone ? 0.72 : 1.0)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {
            Haptics.impact(.light)
            onTap()
        }
        .contextMenu {
            Button {
                Haptics.impact(.light)
                onTap()
            } label: {
                Label("Detay", systemImage: "info.circle")
            }

            Button {
                Haptics.impact(.light)
                onEdit()
            } label: {
                Label("Düzenle", systemImage: "pencil")
            }

            if !event.isCompleted {
                Button {
                    Haptics.impact(.medium)
                    onComplete?()
                } label: {
                    Label("Tamamlandı", systemImage: "checkmark.circle")
                }
            }

            Button(role: .destructive) {
                Haptics.impact(.heavy)
                onDelete()
            } label: {
                Label("Sil", systemImage: "trash")
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(isLive ? 0.105 : 0.075),
                        secondaryAccent.opacity(isLive ? 0.060 : 0.040),
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
                                accent.opacity(isLive ? 0.18 : 0.105),
                                Color.clear
                            ],
                            center: .topTrailing,
                            startRadius: 6,
                            endRadius: 170
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                secondaryAccent.opacity(isLive ? 0.12 : 0.075),
                                Color.clear
                            ],
                            center: .bottomLeading,
                            startRadius: 8,
                            endRadius: 170
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.040),
                                Color.clear,
                                Color.black.opacity(0.12)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(borderColor, lineWidth: isLive ? 1.2 : 1)
    }

    private var borderColor: Color {
        if event.isCompleted { return Color(arenaHex: AppArenaPalette.green).opacity(0.18) }
        if hasConflict { return Color(arenaHex: AppArenaPalette.coral).opacity(0.24) }
        if isLive { return accent.opacity(0.26) }
        if isUpNext { return accent.opacity(0.18) }
        if isDoneByTime { return Color.white.opacity(0.08) }
        return Color.white.opacity(0.075)
    }

    private var timelineRail: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(accent.opacity(isLive ? 0.22 : 0.12))
                    .frame(width: isLive ? 18 : 14, height: isLive ? 18 : 14)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isDone ? 0.58 : 0.96),
                                accent
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isLive ? 10 : 7, height: isLive ? 10 : 7)
                    .shadow(
                        color: accent.opacity(isLive ? 0.28 : 0.12),
                        radius: isLive ? 7 : 2,
                        y: 1
                    )
            }

            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(isDone ? 0.10 : 0.24),
                            Color.white.opacity(0.045)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: isLive ? 3 : 2.5)
                .frame(maxHeight: .infinity)
                .padding(.top, 6)
                .opacity(isDone ? 0.40 : 1)
        }
        .frame(width: 16)
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.white.opacity(0.98))
                        .lineLimit(1)

                    if let statusText {
                        statusPill(statusText, tint: statusTintColor)
                    }
                }

                Text(subtitleText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.56))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(timeText)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(timeRangePillTint)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(
                    Capsule()
                        .fill(timeRangePillTint.opacity(0.11))
                        .overlay(
                            Capsule()
                                .stroke(
                                    isLive || isUpNext
                                    ? accent.opacity(0.18)
                                    : Color.white.opacity(0.075),
                                    lineWidth: 1
                                )
                        )
                )
        }
    }

    @ViewBuilder
    private func supportingInfoRow(text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusTintColor)
                .frame(width: 6, height: 6)
                .shadow(color: statusTintColor.opacity(0.35), radius: 6)

            Text(text.uppercased())
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(statusTintColor)
                .monospacedDigit()

            Spacer()
        }
    }

    private var liveProgressBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.075))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    accent,
                                    Color(arenaHex: AppArenaPalette.cyan).opacity(0.82)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, proxy.size.width * progress))
                        .shadow(color: accent.opacity(0.18), radius: 7, y: 2)
                }
            }
            .frame(height: 7)

            HStack {
                Text("İLERLEME %\(Int(progress * 100))")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.46))

                Spacer()

                Text("\(minutesLeft) DK")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(accent)
                    .monospacedDigit()
            }
        }
    }

    private var footerMetaRow: some View {
        HStack(spacing: 6) {
            metaChip(
                icon: "clock",
                text: "\(max(15, event.durationMinute)) dk",
                tint: .white.opacity(0.58)
            )

            if hasConflict && !event.isCompleted {
                metaChip(
                    icon: "exclamationmark.triangle.fill",
                    text: "Çakışma",
                    tint: Color(arenaHex: AppArenaPalette.coral)
                )
            } else if isWorkout {
                metaChip(
                    icon: "dumbbell.fill",
                    text: workoutDay ?? "Workout",
                    tint: Color(arenaHex: AppArenaPalette.green)
                )
            } else if exerciseCount > 0 {
                metaChip(
                    icon: "figure.strengthtraining.traditional",
                    text: "\(exerciseCount)",
                    tint: Color(arenaHex: AppArenaPalette.blue)
                )
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func statusPill(_ text: String, tint: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(
                Capsule()
                    .fill(tint.opacity(0.13))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.16), lineWidth: 1)
                    )
            )
    }

    @ViewBuilder
    private func metaChip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .black))

            Text(text.uppercased())
                .lineLimit(1)
        }
        .font(.system(size: 9, weight: .black, design: .monospaced))
        .tracking(0.45)
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.055))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.070), lineWidth: 1)
                )
        )
    }
}
