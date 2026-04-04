//
//  EventRow.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 11.03.2026.
//

import SwiftUI

struct EventRow: View {
    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    @State private var pulse: Bool = false

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
        if event.isCompleted { return .green }
        if hasConflict { return .red }
        if isSoon { return .orange }
        if isLive { return hexColor(event.colorHex) }
        if isUpNext { return hexColor(event.colorHex) }
        if isDoneByTime { return .gray }
        return hexColor(event.colorHex)
    }

    private var cardFill: Color {
        if event.isCompleted {
            return Color.white.opacity(palette.isLight ? 0.055 : 0.045)
        }

        if isDoneByTime {
            return Color.white.opacity(palette.isLight ? 0.05 : 0.04)
        }

        if isLive {
            return accent.opacity(palette.isLight ? 0.12 : 0.11)
        }

        if isUpNext {
            return accent.opacity(palette.isLight ? 0.075 : 0.07)
        }

        return Color.white.opacity(palette.isLight ? 0.045 : 0.035)
    }

    private var borderColor: Color {
        if event.isCompleted {
            return Color.white.opacity(0.08)
        }

        if hasConflict {
            return Color.red.opacity(0.20)
        }

        if isLive {
            return accent.opacity(0.22)
        }

        if isUpNext {
            return accent.opacity(0.14)
        }

        if isDoneByTime {
            return Color.white.opacity(0.07)
        }

        return Color.white.opacity(0.07)
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
                if exerciseCount > 0 {
                    return "\(day) • \(exerciseCount) hareket"
                }
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
        if isLive {
            return "\(minutesLeft) dk kaldı"
        }

        if isUpNext {
            return "\(minutesUntilStart) dk sonra"
        }

        if isDoneByTime {
            return "Bugünkü blok tamamlandı"
        }

        return nil
    }

    private var timeRangePillTint: Color {
        if event.isCompleted { return .green }
        if isLive { return accent }
        if isUpNext { return accent }
        return palette.secondaryText
    }

    var body: some View {
        HStack(spacing: 10) {
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
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(palette.isLight ? 0.08 : 0.04),
                                    accent.opacity(isLive ? 0.05 : 0.025),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(borderColor, lineWidth: isLive ? 1.15 : 1)
        )
        .shadow(
            color: isLive ? accent.opacity(0.06) : .clear,
            radius: isLive ? 10 : 0,
            y: isLive ? 3 : 0
        )
        .opacity(event.isCompleted ? 0.74 : 1.0)
        .scaleEffect(isLive && pulse ? 1.003 : 1.0)
        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
        .onAppear {
            pulse = isLive
        }
        .onChange(of: isLive) { _, newValue in
            pulse = newValue
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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

    private var timelineRail: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(accent.opacity(isLive ? 0.18 : 0.10))
                    .frame(width: isLive ? 18 : 14, height: isLive ? 18 : 14)
                    .blur(radius: isLive ? 4 : 1.5)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isDone ? 0.60 : 0.94),
                                accent
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isLive ? 10 : 8, height: isLive ? 10 : 8)
                    .scaleEffect(isLive && pulse ? 1.12 : 1.0)
                    .shadow(
                        color: accent.opacity(isLive ? 0.26 : 0.10),
                        radius: isLive ? 8 : 3,
                        y: 1
                    )
            }

            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(accent.opacity(isDone ? 0.10 : 0.18))
                .frame(width: isLive ? 3 : 2.5)
                .frame(maxHeight: .infinity)
                .padding(.top, 6)
                .opacity(isDone ? 0.38 : 1)
        }
        .frame(width: 14)
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(1)
                        .opacity(isDone ? 0.72 : 1.0)

                    if let statusText {
                        statusPill(statusText, tint: statusTintColor)
                    }
                }

                Text(subtitleText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
                    .opacity(isDone ? 0.72 : 1.0)
            }

            Spacer(minLength: 8)

            Text(timeText)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(timeRangePillTint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(palette.secondaryCardFill.opacity(0.92))
                        .overlay(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(palette.isLight ? 0.16 : 0.06),
                                            accent.opacity(isLive ? 0.10 : 0.04),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isLive ? accent.opacity(0.22) : palette.cardStroke,
                            lineWidth: 1
                        )
                )
        }
    }

    @ViewBuilder
    private func supportingInfoRow(text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusTintColor)
                .frame(width: 5, height: 5)

            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(statusTintColor)
                .monospacedDigit()

            Spacer()
        }
    }

    private var liveProgressBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: progress)
                .tint(accent)

            HStack {
                Text("İlerleme %\(Int(progress * 100))")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)

                Spacer()

                Text("\(minutesLeft) dk")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accent)
                    .monospacedDigit()
            }
        }
        .padding(.top, 1)
    }

    private var footerMetaRow: some View {
        HStack(spacing: 7) {
            metaChip(
                icon: "clock",
                text: "\(max(15, event.durationMinute)) dk",
                tint: palette.secondaryText
            )

            if isWorkout {
                metaChip(
                    icon: "dumbbell.fill",
                    text: workoutDay ?? "Workout",
                    tint: .green
                )
            }

            if exerciseCount > 0 {
                metaChip(
                    icon: "figure.strengthtraining.traditional",
                    text: "\(exerciseCount)",
                    tint: .blue
                )
            }

            if hasConflict && !event.isCompleted {
                metaChip(
                    icon: "exclamationmark.triangle.fill",
                    text: "Çakışma",
                    tint: .red
                )
            }

            Spacer()
        }
        .opacity(isDone ? 0.76 : 1.0)
    }

    private var statusTintColor: Color {
        if event.isCompleted { return .green }
        if isLive { return accent }
        if isSoon { return .orange }
        if isUpNext { return accent }
        if isDoneByTime { return palette.secondaryText }
        return accent
    }

    @ViewBuilder
    private func statusPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tint.opacity(0.14))
            )
    }

    @ViewBuilder
    private func metaChip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))

            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(tint.opacity(0.10))
        )
    }
}
