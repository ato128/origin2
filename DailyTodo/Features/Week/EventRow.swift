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
        return nowMinute < start && (start - nowMinute) <= 20
    }

    private var isSoon: Bool {
        guard !event.isCompleted else { return false }
        guard isTodaySelected else { return false }
        let diff = start - nowMinute
        return diff > 0 && diff <= 5
    }

    private var isDone: Bool {
        if event.isCompleted { return true }
        guard isTodaySelected else { return false }
        return nowMinute >= end
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
        return hexColor(event.colorHex)
    }

    private var cardFill: Color {
        if event.isCompleted {
            return Color.green.opacity(palette.isLight ? 0.12 : 0.16)
        }

        if isLive {
            return accent.opacity(palette.isLight ? 0.20 : 0.18)
        }

        if isUpNext {
            return accent.opacity(palette.isLight ? 0.14 : 0.13)
        }

        if isDone {
            return palette.secondaryCardFill.opacity(0.94)
        }

        return accent.opacity(palette.isLight ? 0.08 : 0.09)
    }

    private var borderColor: Color {
        if event.isCompleted {
            return Color.green.opacity(0.24)
        }

        if hasConflict {
            return Color.red.opacity(0.32)
        }

        if isLive {
            return accent.opacity(0.34)
        }

        if isUpNext {
            return accent.opacity(0.20)
        }

        return palette.cardStroke
    }

    private var statusText: String? {
        if event.isCompleted { return "Tamamlandı" }
        if isLive { return "Şu an" }
        if isSoon { return "5 dk" }
        if isUpNext { return "Sıradaki" }
        if isDone { return "Bitti" }
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

    private var liveInfoText: String? {
        if isLive {
            return "\(minutesLeft) dk kaldı"
        }

        if isUpNext {
            return "\(minutesUntilStart) dk sonra"
        }

        return nil
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(isLive ? 0.22 : 0.14))
                        .frame(width: isLive ? 20 : 16, height: isLive ? 20 : 16)
                        .blur(radius: isLive ? 5 : 2)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.95),
                                    accent
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: isLive ? 12 : 10, height: isLive ? 12 : 10)
                        .scaleEffect(isLive && pulse ? 1.14 : 1.0)
                        .shadow(
                            color: accent.opacity(isLive ? 0.34 : 0.14),
                            radius: isLive ? 10 : 4,
                            y: 1
                        )
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(accent.opacity(isDone ? 0.10 : 0.18))
                        .frame(width: isLive ? 5 : 4)

                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isLive ? 0.55 : 0.20),
                                    accent.opacity(0.95),
                                    accent.opacity(isDone ? 0.30 : 0.72)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: isLive ? 3 : 2.5)
                        .shadow(
                            color: isLive ? accent.opacity(0.28) : .clear,
                            radius: isLive ? 7 : 0
                        )
                }
                .frame(maxHeight: .infinity)
                .padding(.top, 7)
                .opacity(isDone ? 0.45 : 1)
            }
            .frame(width: 18)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
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
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(1)
                            .opacity(isDone ? 0.72 : 1.0)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(timeText)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(palette.primaryText)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(palette.secondaryCardFill.opacity(0.92))
                                    .overlay(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(palette.isLight ? 0.22 : 0.10),
                                                        accent.opacity(isLive ? 0.14 : 0.08),
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
                                        isLive ? accent.opacity(0.26) : palette.cardStroke,
                                        lineWidth: 1
                                    )
                            )
                            .shadow(
                                color: isLive ? accent.opacity(0.10) : .clear,
                                radius: isLive ? 8 : 0,
                                y: isLive ? 2 : 0
                            )

                        if let liveInfoText {
                            Text(liveInfoText)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(statusTintColor)
                                .monospacedDigit()
                        }
                    }
                }

                if isLive {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: progress)
                            .tint(accent)

                        HStack(spacing: 8) {
                            Text("%\(Int(progress * 100))")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(palette.secondaryText)

                            Spacer()

                            Text("\(minutesLeft) dk kaldı")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(accent)
                        }
                    }
                }

                HStack(spacing: 8) {
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
                .opacity(isDone ? 0.78 : 1.0)
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(palette.isLight ? 0.18 : 0.10),
                                    accent.opacity(0.10),
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
                .stroke(borderColor.opacity(isLive ? 1.0 : 0.92), lineWidth: isLive ? 1.25 : 1)
        )
        .shadow(
            color: isLive ? accent.opacity(0.12) : .clear,
            radius: isLive ? 12 : 6,
            y: isLive ? 4 : 2
        )
        .opacity(event.isCompleted ? 0.78 : 1.0)
        .scaleEffect(isLive && pulse ? 1.004 : 1.0)
        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
        .onAppear {
            pulse = isLive
        }
        .onChange(of: isLive) { _, newValue in
            pulse = newValue
        }
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

    private var statusTintColor: Color {
        if event.isCompleted { return .green }
        if isLive { return accent }
        if isSoon { return .orange }
        if isUpNext { return accent }
        if isDone { return palette.secondaryText }
        return accent
    }

    @ViewBuilder
    private func statusPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tint.opacity(0.14))
            )
    }

    @ViewBuilder
    private func metaChip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(tint.opacity(0.10))
        )
    }
}
