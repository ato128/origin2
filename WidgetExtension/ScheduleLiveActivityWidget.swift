//
//  ScheduleLiveActivityWidget.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 4.03.2026.
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
            let accent = scheduleAccent(for: context)

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
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Link(destination: URL(string: "dailytodo://live/stop")!) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.10)))
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(alignment: .firstTextBaseline) {
                            scheduleTimer(now: now, start: start, end: end)
                                .focusHeroNumber(size: 26, accent: accent, live: true)
                            Spacer()
                            Text("\(hmDate(start))–\(hmDate(end))")
                                .focusHeroNumber(size: 12, accent: accent)
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
                scheduleCompactTimer(now: now, start: start, end: end)
                    .focusHeroNumber(size: 14, accent: accent, live: true)
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
        let accent = scheduleAccent(for: context)
        let now = Date()
        let start = context.state.startDate
        let end = context.state.endDate

        VStack(alignment: .leading, spacing: 12) {
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

                Link(destination: URL(string: "dailytodo://live/stop")!) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(UpdoWidgetPalette.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(UpdoWidgetPalette.fillSoft))
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                scheduleTimer(now: now, start: start, end: end)
                    .focusHeroNumber(size: 40, accent: accent, live: true)

                Text(now < start ? widgetLocalized("kala", "to go") : (now < end ? widgetLocalized("kaldı", "left") : ""))
                    .font(WidgetFont.caption())
                    .foregroundStyle(UpdoWidgetPalette.textTertiary)

                Spacer(minLength: 6)

                Text("\(hmDate(start))–\(hmDate(end))")
                    .focusHeroNumber(size: 12, accent: accent)
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

private func scheduleAccent(for context: ActivityViewContext<ScheduleAttributes>) -> Color {
    hexColor(context.state.colorHex)
}

private func scheduleIcon(now: Date, start: Date, end: Date) -> String {
    if now < start { return "clock.fill" }
    if now < end { return "books.vertical.fill" }
    return "checkmark.circle.fill"
}

private func scheduleStatus(now: Date, start: Date, end: Date) -> String {
    if now < start { return "Başlamak üzere" }
    if now < end { return "Şu an aktif" }
    return "Tamamlandı"
}

@ViewBuilder
private func scheduleTimer(now: Date, start: Date, end: Date) -> some View {
    if now < start {
        Text(timerInterval: now...start, countsDown: true)
    } else if now < end {
        Text(timerInterval: now...end, countsDown: true)
    } else {
        Text("Bitti")
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

/// Interval for the auto-advancing bar, or nil once the class is over.
private func scheduleRunningRange(now: Date, start: Date, end: Date) -> ClosedRange<Date>? {
    guard end > start, now < end else { return nil }
    return start...end
}

private func scheduleProgress(now: Date, start: Date, end: Date) -> CGFloat {
    if now < start {
        let total = start.timeIntervalSince(now)
        let window: TimeInterval = 600
        return CGFloat(max(0.05, 1 - (total / window)))
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

