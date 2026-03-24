//
//  FocusLiveActivityWidget.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 24.03.2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct FocusLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusAttributes.self) { context in
            FocusLiveLockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.92))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let accent = focusAccentColor(for: context.state)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(accent.opacity(0.18))
                                .frame(width: 24, height: 24)

                            Image(systemName: focusIconName(for: context.state))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(accent)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)

                            Text(context.state.subtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(focusModeLabel(for: context.state))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(accent.opacity(0.16))
                        .foregroundStyle(accent)
                        .clipShape(Capsule())
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(focusStatusText(for: context.state))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Spacer(minLength: 12)

                            focusTimerText(for: context.state)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.10))
                                .frame(height: 6)

                            GeometryReader { proxy in
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [accent, accent.opacity(0.65)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width: max(
                                            10,
                                            proxy.size.width * focusProgress(for: context.state)
                                        ),
                                        height: 6
                                    )
                            }
                            .frame(height: 6)
                        }
                        .frame(height: 6)
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: 20, height: 20)

                    Image(systemName: focusIconName(for: context.state))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(accent)
                }
            } compactTrailing: {
                CompactFocusTimeView(state: context.state)
                    .frame(width: 42, alignment: .trailing)
            } minimal: {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: 20, height: 20)

                    Image(systemName: focusIconName(for: context.state))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }
            .keylineTint(accent)
        }
    }
}

private struct FocusLiveLockScreenView: View {
    let context: ActivityViewContext<FocusAttributes>

    var body: some View {
        let accent = focusAccentColor(for: context.state)

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accent.opacity(0.18))
                        .frame(width: 42, height: 42)

                    Image(systemName: focusIconName(for: context.state))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.title)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)

                    Text(context.state.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(focusModeLabel(for: context.state))
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(accent.opacity(0.16))
                    .foregroundStyle(accent)
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 10) {
                focusTimerText(for: context.state)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 8)

                    GeometryReader { proxy in
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [accent, accent.opacity(0.60)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: max(
                                    10,
                                    proxy.size.width * focusProgress(for: context.state)
                                ),
                                height: 8
                            )
                    }
                    .frame(height: 8)
                }
                .frame(height: 8)
            }
        }
        .padding(16)
    }
}

private struct CompactFocusTimeView: View {
    let state: FocusAttributes.ContentState

    var body: some View {
        Group {
            if state.isPaused {
                let seconds = max(0, state.pausedRemainingSeconds ?? 0)
                let minutes = seconds / 60
                Text("\(minutes)d")
            } else {
                Text(timerInterval: Date()...state.endDate, countsDown: true)
            }
        }
        .font(.system(size: 13, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }
}

private func focusAccentColor(for state: FocusAttributes.ContentState) -> Color {
    if state.isPaused { return .orange }
    if state.isResting { return .orange }

    switch state.modeRaw {
    case "workout":
        return .green
    case "crew":
        return .blue
    default:
        return .cyan
    }
}

private func focusIconName(for state: FocusAttributes.ContentState) -> String {
    if state.isPaused { return "pause.fill" }
    if state.isResting { return "figure.cooldown" }

    switch state.modeRaw {
    case "workout":
        return "dumbbell.fill"
    case "crew":
        return "person.2.fill"
    default:
        return "scope"
    }
}

private func focusModeLabel(for state: FocusAttributes.ContentState) -> String {
    if state.isPaused { return "PAUSED" }
    if state.isResting { return "REST" }

    switch state.modeRaw {
    case "workout":
        return "WORKOUT"
    case "crew":
        return "CREW"
    default:
        return "FOCUS"
    }
}

private func focusStatusText(for state: FocusAttributes.ContentState) -> String {
    if state.isPaused { return "Duraklatıldı" }
    if state.isResting { return "Dinlenme aktif" }

    switch state.modeRaw {
    case "workout":
        return "Workout running"
    case "crew":
        return "Shared focus running"
    default:
        return "Focus running"
    }
}

private func focusProgress(for state: FocusAttributes.ContentState) -> CGFloat {
    if state.isPaused {
        return CGFloat(max(0, min(1, state.pausedProgress ?? 0)))
    }

    let now = Date()

    if now >= state.endDate { return 1 }

    let total = state.endDate.timeIntervalSince(state.startDate)
    guard total > 0 else { return 0 }

    let elapsed = now.timeIntervalSince(state.startDate)
    return CGFloat(min(1, max(0, elapsed / total)))
}

@ViewBuilder
private func focusTimerText(for state: FocusAttributes.ContentState) -> some View {
    if state.isPaused {
        let seconds = max(0, state.pausedRemainingSeconds ?? 0)
        let minutes = seconds / 60
        let sec = seconds % 60
        Text(String(format: "%02d:%02d", minutes, sec))
    } else {
        Text(timerInterval: Date()...state.endDate, countsDown: true)
    }
}
