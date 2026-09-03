//
//  ScheduleLiveActivityWidget.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 4.03.2026.
//
//  The class/schedule Live Activity — brought to parity with the Focus Live
//  Activity (FocusLiveActivityWidget): same card chrome, icon bubble, phase
//  chip, serif hero timer and a live auto-advancing progress bar. Two live
//  phases — a countdown that starts 10 min BEFORE class ("kala") and a
//  countdown DURING class ("kaldı") — each drives the timer AND the bar so
//  nothing freezes across the boundary. Phase-aware accent: the event colour
//  before/during, green once done.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ScheduleLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScheduleAttributes.self) { context in
            ScheduleLockScreenView(context: context)
                .activityBackgroundTint(UpdoWidgetPalette.bgMid.opacity(0.96))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let now = Date()
            let start = context.state.startDate
            let end = context.state.endDate
            let accent = scheduleAccent(now: now, start: start, end: end, hex: context.state.colorHex)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 10) {
                        ScheduleIconBubble(accent: accent, now: now, start: start, end: end, size: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.title)
                                .font(.system(size: 15, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(scheduleStatus(now: now, start: start, end: end))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    SchedulePhaseChip(now: now, start: start, end: end, accent: accent)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(alignment: .firstTextBaseline) {
                            scheduleTimer(now: now, start: start, end: end)
                                .focusHeroNumber(size: 26, accent: accent, live: true)

                            Text(scheduleCountLabel(now: now, start: start, end: end))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)

                            Spacer(minLength: 8)

                            Text("\(hmDate(start))–\(hmDate(end))")
                                .font(.system(size: 12, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        UpdoLiveProgressBar(
                            running: scheduleRunningRange(now: now, start: start, end: end),
                            staticProgress: scheduleProgress(now: now, start: start, end: end),
                            accent: accent,
                            height: 7
                        )
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                ScheduleIconBubble(accent: accent, now: now, start: start, end: end, size: 22)
            } compactTrailing: {
                // Fixed width + scale so the mm:ss timer never widens the island
                // (matches the Focus Live Activity's compact trailing).
                scheduleCompactTimer(now: now, start: start, end: end)
                    .focusHeroNumber(size: 14, accent: accent, live: true)
                    .minimumScaleFactor(0.6)
                    .frame(width: 48, alignment: .trailing)
            } minimal: {
                ScheduleIconBubble(accent: accent, now: now, start: start, end: end, size: 22)
            }
            .keylineTint(accent)
        }
    }
}

// MARK: - Lock Screen

private struct ScheduleLockScreenView: View {
    let context: ActivityViewContext<ScheduleAttributes>

    var body: some View {
        let now = Date()
        let start = context.state.startDate
        let end = context.state.endDate
        let accent = scheduleAccent(now: now, start: start, end: end, hex: context.state.colorHex)

        VStack(alignment: .leading, spacing: 12) {
            // Top row — icon + title + status + phase chip (Focus-parity).
            HStack(spacing: 11) {
                ScheduleIconBubble(accent: accent, now: now, start: start, end: end, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.title)
                        .font(WidgetFont.title(16))
                        .foregroundStyle(UpdoWidgetPalette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(scheduleStatus(now: now, start: start, end: end))
                        .font(WidgetFont.caption())
                        .foregroundStyle(UpdoWidgetPalette.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                SchedulePhaseChip(now: now, start: start, end: end, accent: accent)
            }

            // Hero timer — serif, live-ticking; "kala" before, "kaldı" during.
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                scheduleTimer(now: now, start: start, end: end)
                    .focusHeroNumber(size: 40, accent: accent, live: true)

                Text(scheduleCountLabel(now: now, start: start, end: end))
                    .font(WidgetFont.caption())
                    .foregroundStyle(UpdoWidgetPalette.textTertiary)

                Spacer(minLength: 6)

                Text("\(hmDate(start))–\(hmDate(end))")
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(UpdoWidgetPalette.textSecondary)
            }

            UpdoLiveProgressBar(
                running: scheduleRunningRange(now: now, start: start, end: end),
                staticProgress: scheduleProgress(now: now, start: start, end: end),
                accent: accent,
                height: 6
            )
        }
        .padding(16)
        .background(
            ZStack {
                LinearGradient(
                    colors: [UpdoWidgetPalette.surfaceTop, UpdoWidgetPalette.surfaceBottom],
                    startPoint: .top, endPoint: .bottom
                )
                RadialGradient(colors: [accent.opacity(0.10), .clear], center: .bottomTrailing, startRadius: 8, endRadius: 240)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(UpdoWidgetPalette.hairline, lineWidth: 1)
        )
    }
}

// MARK: - Shared subviews

private struct ScheduleIconBubble: View {
    let accent: Color
    let now: Date, start: Date, end: Date
    let size: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(accent.opacity(0.16))
            Image(systemName: scheduleIcon(now: now, start: start, end: end))
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(accent)
        }
        .frame(width: size, height: size)
    }
}

/// The phase pill (YAKINDA / CANLI / BİTTİ) — the schedule twin of the Focus
/// mode chip, so both Live Activities read the same.
private struct SchedulePhaseChip: View {
    let now: Date, start: Date, end: Date
    let accent: Color
    var body: some View {
        Text(schedulePhaseLabel(now: now, start: start, end: end))
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(accent)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(accent.opacity(0.16)))
    }
}

struct GlowProgressBar: View {
    let progress: CGFloat
    let accent: Color
    var height: CGFloat = 8
    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.12)).frame(height: height)
            GeometryReader { proxy in
                Capsule()
                    .fill(LinearGradient(colors: [accent, accent.opacity(0.65)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(10, proxy.size.width * progress), height: height)
                    .shadow(color: accent.opacity(0.6), radius: 4)
            }
            .frame(height: height)
        }
        .frame(height: height)
    }
}

// MARK: - Helpers

/// Phase-aware accent: the class colour before/during, green once done.
private func scheduleAccent(now: Date, start: Date, end: Date, hex: String) -> Color {
    if now >= end { return UpdoWidgetPalette.green }
    return hexColor(hex)
}

private func scheduleIcon(now: Date, start: Date, end: Date) -> String {
    if now < start { return "clock.fill" }
    if now < end { return "books.vertical.fill" }
    return "checkmark.circle.fill"
}

private func scheduleStatus(now: Date, start: Date, end: Date) -> String {
    if now < start { return widgetLocalized("Başlamak üzere", "Starting soon") }
    if now < end { return widgetLocalized("Şu an aktif", "In progress now") }
    return widgetLocalized("Tamamlandı", "Completed")
}

private func schedulePhaseLabel(now: Date, start: Date, end: Date) -> String {
    if now < start { return widgetLocalized("YAKINDA", "SOON") }
    if now < end { return widgetLocalized("CANLI", "LIVE") }
    return widgetLocalized("BİTTİ", "DONE")
}

/// The little suffix next to the hero timer: "kala" before class, "kaldı" during.
private func scheduleCountLabel(now: Date, start: Date, end: Date) -> String {
    if now < start { return widgetLocalized("kala", "to go") }
    if now < end { return widgetLocalized("kaldı", "left") }
    return ""
}

@ViewBuilder
private func scheduleTimer(now: Date, start: Date, end: Date) -> some View {
    if now < start {
        Text(timerInterval: now...start, countsDown: true)
    } else if now < end {
        Text(timerInterval: now...end, countsDown: true)
    } else {
        Text(widgetLocalized("Bitti", "Ended"))
    }
}

@ViewBuilder
private func scheduleCompactTimer(now: Date, start: Date, end: Date) -> some View {
    if now < start {
        Text(timerInterval: now...start, countsDown: true)
    } else if now < end {
        Text(timerInterval: now...end, countsDown: true)
    } else {
        Text("·")
    }
}

/// Interval for the auto-advancing bar. Before class it fills over the last
/// 10 minutes toward start; during class it fills toward end; nil once over.
private func scheduleRunningRange(now: Date, start: Date, end: Date) -> ClosedRange<Date>? {
    if now < start {
        // Fill over the last 10 minutes toward start (auto-advancing).
        let windowStart = start.addingTimeInterval(-600)
        return windowStart < start ? windowStart...start : nil
    }
    guard end > start, now < end else { return nil }
    return start...end
}

private func scheduleProgress(now: Date, start: Date, end: Date) -> CGFloat {
    if now < start {
        let window: TimeInterval = 600
        let remaining = start.timeIntervalSince(now)
        return CGFloat(max(0.05, min(1, 1 - (remaining / window))))
    }
    if now >= end { return 1 }
    let total = end.timeIntervalSince(start)
    guard total > 0 else { return 0 }
    return CGFloat(now.timeIntervalSince(start) / total)
}

private func hmDate(_ date: Date) -> String {
    let c = Calendar.current.dateComponents([.hour, .minute], from: date)
    return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
}
