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
            // LOCK SCREEN UI
            LiveActivityLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.title)
                        .font(.headline)
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    // “X kapat” -> app’a deep link
                    Link(destination: URL(string: "dailytodo://live/stop")!) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    LiveActivityTimerLine(context: context)
                }
            } compactLeading: {
                Text("📚")
            } compactTrailing: {
                LiveActivityCompactTimer(context: context)
            } minimal: {
                LiveActivityCompactTimer(context: context)
            }
        }
    }
}

private struct LiveActivityLockScreenView: View {
    let context: ActivityViewContext<ScheduleAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(context.state.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Link(destination: URL(string: "dailytodo://live/stop")!) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                }
            }

            LiveActivityTimerLine(context: context)
        }
        .padding()
    }
}

private struct LiveActivityTimerLine: View {
    let context: ActivityViewContext<ScheduleAttributes>

    var body: some View {
        let now = Date()
        let start = context.state.startDate
        let end = context.state.endDate

        if now < start {
            // 10 dk kala -> derse kalan
            Text(timerInterval: now...start, countsDown: true)
                .monospacedDigit()
                .font(.system(.title3, design: .rounded).weight(.semibold))
            Text("Derse kalan")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if now < end {
            // ders başladı -> derse kalan
            Text(timerInterval: now...end, countsDown: true)
                .monospacedDigit()
                .font(.system(.title3, design: .rounded).weight(.semibold))
            Text("Ders bitimine")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("Bitti")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct LiveActivityCompactTimer: View {
    let context: ActivityViewContext<ScheduleAttributes>

    var body: some View {
        let now = Date()
        let start = context.state.startDate
        let end = context.state.endDate

        if now < start {
            Text(timerInterval: now...start, countsDown: true)
                .monospacedDigit()
        } else if now < end {
            Text(timerInterval: now...end, countsDown: true)
                .monospacedDigit()
        } else {
            Text("—")
        }
    }
}
