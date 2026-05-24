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
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(scheduleStatus(now: now, start: start, end: end))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Link(destination: URL(string: "dailytodo://live/stop")!) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.10)))
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(alignment: .firstTextBaseline) {
                            scheduleTimer(now: now, start: start, end: end)
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(hmDate(start))–\(hmDate(end))")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        GlowProgressBar(progress: scheduleProgress(now: now, start: start, end: end), accent: accent, height: 7)
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                ScheduleIconBubble(accent: accent, now: now, start: start, end: end, size: 22)
            } compactTrailing: {
                scheduleCompactTimer(now: now, start: start, end: end)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
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

        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 11) {
                ScheduleIconBubble(accent: accent, now: now, start: start, end: end, size: 42)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(UpdoWidgetPalette.cyan)
                            .frame(width: 12, height: 2.5)
                            .clipShape(Capsule())
                        Text("BUGÜN")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(1.4)
                            .foregroundStyle(UpdoWidgetPalette.cyan)
                    }
                    Text(context.state.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer()

                Link(destination: URL(string: "dailytodo://live/stop")!) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    scheduleTimer(now: now, start: start, end: end)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Spacer()
                    Text(scheduleStatus(now: now, start: start, end: end))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(accent)
                }
                GlowProgressBar(progress: scheduleProgress(now: now, start: start, end: end), accent: accent, height: 8)
            }
        }
        .padding(16)
        .background(
            ZStack {
                LinearGradient(
                    colors: [UpdoWidgetPalette.bgTop, UpdoWidgetPalette.bgBottom],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                RadialGradient(colors: [accent.opacity(0.14), .clear], center: .topTrailing, startRadius: 6, endRadius: 200)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(accent.opacity(0.14), lineWidth: 1)
            }
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
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(accent.opacity(0.2))
                .shadow(color: accent.opacity(0.3), radius: 5)
            Image(systemName: scheduleIcon(now: now, start: start, end: end))
                .font(.system(size: size * 0.42, weight: .semibold))
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

