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
        if event.isCompleted { return .green }
        if hasConflict { return .red }
        if isSoon { return .orange }
        if isDoneByTime { return palette.secondaryText }
        return rawAccent
    }
    
    private var cardPrimaryTint: Color {
        if event.isCompleted {
            return Color(red: 0.18, green: 0.74, blue: 0.34)
        }

        if hasConflict {
            return Color(red: 0.92, green: 0.33, blue: 0.34)
        }

        if isLive {
            return rawAccent
        }

        if isUpNext || isSoon {
            return rawAccent
        }

        return rawAccent
    }

    private var cardWarmTint: Color {
        if event.isCompleted {
            return Color(red: 0.18, green: 0.74, blue: 0.34)
        }

        if hasConflict {
            return Color(red: 0.86, green: 0.24, blue: 0.26)
        }

        if isLive {
            return rawAccent.opacity(0.95)
        }

        if isUpNext || isSoon {
            return rawAccent.opacity(0.88)
        }

        return rawAccent.opacity(0.82)
    }

    private var cardCoolTint: Color {
        if event.isCompleted {
            return Color(red: 0.22, green: 0.82, blue: 0.42)
        }

        if hasConflict {
            return Color(red: 0.42, green: 0.08, blue: 0.18)
        }

        if isLive {
            return rawAccent.opacity(0.72)
        }

        if isUpNext || isSoon {
            return rawAccent.opacity(0.64)
        }

        return rawAccent.opacity(0.56)
    }

    private var secondaryAccent: Color {
        if event.isCompleted { return Color(red: 0.10, green: 0.24, blue: 0.16) }
        if hasConflict { return Color(red: 0.30, green: 0.05, blue: 0.10) }
        if isLive { return Color(red: 0.30, green: 0.06, blue: 0.34) }
        if isUpNext || isSoon { return Color(red: 0.26, green: 0.08, blue: 0.28) }
        return Color(red: 0.20, green: 0.06, blue: 0.24)
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
            if exerciseCount > 0 { return "\(exerciseCount) hareket" }
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
        if event.isCompleted { return .green }
        if isLive { return accent }
        if isSoon { return .orange }
        if isUpNext { return accent }
        if isDoneByTime { return palette.secondaryText }
        return accent
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

            VStack(alignment: .leading, spacing: 6) {
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
        .padding(.vertical, 8)
        .background(cardBackground)
        .overlay(cardStroke)
        .shadow(
            color: isLive ? accent.opacity(0.07) : .clear,
            radius: isLive ? 9 : 0,
            y: isLive ? 3 : 0
        )
        .opacity(isDone ? 0.80 : 1.0)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        cardWarmTint.opacity(backgroundTopOpacity),
                        cardPrimaryTint.opacity(backgroundMidOpacity),
                        cardCoolTint.opacity(backgroundBottomOpacity),
                        Color(red: 0.10, green: 0.03, blue: 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.10),
                                Color.clear,
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .blendMode(.screen)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                cardWarmTint.opacity(isLive ? 0.18 : 0.12),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 8,
                            endRadius: 110
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                cardCoolTint.opacity(isLive ? 0.22 : 0.16),
                                Color.clear
                            ],
                            center: .bottomTrailing,
                            startRadius: 8,
                            endRadius: 130
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.00),
                                Color.black.opacity(0.06),
                                Color.black.opacity(0.16)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(borderColor, lineWidth: isLive ? 1.15 : 1)
    }

    private var backgroundTopOpacity: Double {
        if event.isCompleted { return 0.22 }
        if hasConflict { return 0.24 }
        if isLive { return 0.30 }
        if isUpNext { return 0.26 }
        if isDoneByTime { return 0.16 }
        return 0.24
    }

    private var backgroundMidOpacity: Double {
        if event.isCompleted { return 0.16 }
        if hasConflict { return 0.16 }
        if isLive { return 0.18 }
        if isUpNext { return 0.15 }
        if isDoneByTime { return 0.10 }
        return 0.14
    }

    private var backgroundBottomOpacity: Double {
        if event.isCompleted { return 0.26 }
        if hasConflict { return 0.20 }
        if isLive { return 0.30 }
        if isUpNext { return 0.24 }
        if isDoneByTime { return 0.14 }
        return 0.24
    }

    private var borderColor: Color {
        if event.isCompleted { return Color.green.opacity(0.18) }
        if hasConflict { return Color.red.opacity(0.22) }
        if isLive { return accent.opacity(0.24) }
        if isUpNext { return accent.opacity(0.18) }
        if isDoneByTime { return Color.white.opacity(0.08) }
        return Color.white.opacity(0.08)
    }

    private var timelineRail: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(accent.opacity(isLive ? 0.20 : 0.11))
                    .frame(width: isLive ? 16 : 13, height: isLive ? 16 : 13)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isDone ? 0.66 : 0.96),
                                accent
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isLive ? 9 : 7, height: isLive ? 9 : 7)
                    .shadow(
                        color: accent.opacity(isLive ? 0.22 : 0.10),
                        radius: isLive ? 6 : 2,
                        y: 1
                    )
            }

            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(accent.opacity(isDone ? 0.10 : 0.16))
                .frame(width: isLive ? 3 : 2.5)
                .frame(maxHeight: .infinity)
                .padding(.top, 6)
                .opacity(isDone ? 0.40 : 1)
        }
        .frame(width: 14)
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.98))
                        .lineLimit(1)

                    if let statusText {
                        statusPill(statusText, tint: statusTintColor)
                    }
                }

                Text(subtitleText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
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
                        .fill(Color.white.opacity(0.055))
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isLive || isUpNext
                            ? accent.opacity(0.20)
                            : Color.white.opacity(0.08),
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
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(statusTintColor)
                .monospacedDigit()

            Spacer()
        }
    }

    private var liveProgressBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            ProgressView(value: progress)
                .tint(accent)
                .scaleEffect(y: 0.82)

            HStack {
                Text("İlerleme %\(Int(progress * 100))")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))

                Spacer()

                Text("\(minutesLeft) dk")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
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
                tint: .white.opacity(0.62)
            )

            if hasConflict && !event.isCompleted {
                metaChip(
                    icon: "exclamationmark.triangle.fill",
                    text: "Çakışma",
                    tint: .red
                )
            } else if isWorkout {
                metaChip(
                    icon: "dumbbell.fill",
                    text: workoutDay ?? "Workout",
                    tint: .green
                )
            } else if exerciseCount > 0 {
                metaChip(
                    icon: "figure.strengthtraining.traditional",
                    text: "\(exerciseCount)",
                    tint: .blue
                )
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func statusPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tint.opacity(0.16))
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
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
        )
    }
}
