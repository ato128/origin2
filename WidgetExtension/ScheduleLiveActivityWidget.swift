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
            PremiumLiveActivityLockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.92))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let now = Date()
            let start = context.state.startDate
            let end = context.state.endDate
            let accent = liveAccentColor(for: context)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(accent.opacity(0.18))
                                .frame(width: 30, height: 30)

                            Image(systemName: "books.vertical.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(accent)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)

                            Text(statusLabel(now: now, start: start, end: end))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Link(destination: URL(string: "dailytodo://live/stop")!) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.10))
                                .frame(width: 28, height: 28)

                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(remainingText(from: now, start: start, end: end))
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .monospacedDigit()

                            Spacer()

                            Text(statusLabel(now: now, start: start, end: end))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.10))
                                .frame(height: 6)

                            GeometryReader { proxy in
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                accent,
                                                accent.opacity(0.72)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width: max(10, proxy.size.width * progressValue(now: now, start: start, end: end)),
                                        height: 6
                                    )
                            }
                            .frame(height: 6)
                        }
                        .frame(height: 6)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: 22, height: 22)

                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accent)
                }
            } compactTrailing: {
                Text(compactRemainingText(from: now, start: start, end: end))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            } minimal: {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: 22, height: 22)

                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }
        }
    }
}

private struct PremiumLiveActivityLockScreenView: View {
    let context: ActivityViewContext<ScheduleAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.26),
                                    Color.blue.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 42, height: 42)

                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.title)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)

                    StatusText(context: context)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Link(destination: URL(string: "dailytodo://live/stop")!) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 34, height: 34)

                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                PremiumTimeLabel(context: context)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()

                PremiumProgressBar(context: context)
            }
        }
        .padding(16)
    }
}

private struct PremiumTimeLabel: View {
    let context: ActivityViewContext<ScheduleAttributes>

    var body: some View {
        let now = Date()
        let start = context.state.startDate
        let end = context.state.endDate

        Group {
            if now < start {
                Text(timerInterval: now...start, countsDown: true)
            } else if now < end {
                Text(timerInterval: now...end, countsDown: true)
            } else {
                Text("Bitti")
            }
        }
        .foregroundStyle(.white)
    }
}

private struct StatusText: View {
    let context: ActivityViewContext<ScheduleAttributes>

    var body: some View {
        let now = Date()
        let start = context.state.startDate
        let end = context.state.endDate

        Group {
            if now < start {
                Text("Ders başlamasına")
            } else if now < end {
                Text("Ders bitimine")
            } else {
                Text("Ders tamamlandı")
            }
        }
    }
}

private struct PremiumProgressBar: View {
    let context: ActivityViewContext<ScheduleAttributes>

    var body: some View {
        let progress = progressValue(
            now: Date(),
            start: context.state.startDate,
            end: context.state.endDate
        )

        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.12))
                .frame(height: 8)

            GeometryReader { proxy in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue,
                                Color.blue.opacity(0.72)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: max(10, proxy.size.width * progress),
                        height: 8
                    )
            }
            .frame(height: 8)
        }
        .frame(height: 8)
    }
}

private func liveAccentColor(for context: ActivityViewContext<ScheduleAttributes>) -> Color {
    .blue
}

private func remainingText(from now: Date, start: Date, end: Date) -> String {
    let target = now < start ? start : end
    let remaining = max(0, Int(target.timeIntervalSince(now)))

    let hours = remaining / 3600
    let minutes = (remaining % 3600) / 60

    if hours < 1 {
        return "\(max(1, minutes)) dk"
    } else {
        return "\(hours) sa \(minutes) dk"
    }
}

private func compactRemainingText(from now: Date, start: Date, end: Date) -> String {
    let target = now < start ? start : end
    let remaining = max(0, Int(target.timeIntervalSince(now)))

    let hours = remaining / 3600
    let minutes = (remaining % 3600) / 60

    if hours < 1 {
        return "\(max(1, minutes))d"
    } else {
        return "\(hours)s \(minutes)d"
    }
}

private func statusLabel(now: Date, start: Date, end: Date) -> String {
    if now < start {
        return "Ders başlamasına"
    } else if now < end {
        return "Ders bitimine"
    } else {
        return "Ders tamamlandı"
    }
}

private func progressValue(now: Date, start: Date, end: Date) -> CGFloat {
    if now <= start { return 0.02 }
    if now >= end { return 1.0 }

    let total = end.timeIntervalSince(start)
    guard total > 0 else { return 0.02 }

    let elapsed = now.timeIntervalSince(start)
    return min(max(CGFloat(elapsed / total), 0.02), 1.0)
}
