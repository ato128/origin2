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
            FocusLockScreenView(context: context)
                .activityBackgroundTint(UpdoWidgetPalette.bgMid.opacity(0.96))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let accent = focusAccent(for: context.state)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 10) {
                        FocusIconBubble(state: context.state, accent: accent, size: 34)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.title)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            Text(context.state.subtitle)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(context.state.isCompleted ? accent.opacity(0.95) : .secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(focusModeLabel(for: context.state))
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(0.5)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(accent.opacity(0.18)))
                        .overlay(Capsule().stroke(accent.opacity(0.35), lineWidth: 0.8))
                        .foregroundStyle(accent)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(focusStatusText(for: context.state))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(context.state.isCompleted ? accent : .secondary)
                                .lineLimit(1)

                            Spacer(minLength: 12)

                            focusTimerText(for: context.state)
                                .font(.system(size: context.state.isCompleted ? 22 : 26, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }

                        GlowProgressBar(
                            progress: focusProgress(for: context.state),
                            accent: accent,
                            height: 7
                        )
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                FocusIconBubble(state: context.state, accent: accent, size: 22)
            } compactTrailing: {
                CompactFocusTimeView(state: context.state)
                    .frame(width: 48, alignment: .trailing)
            } minimal: {
                FocusIconBubble(state: context.state, accent: accent, size: 22)
            }
            .keylineTint(accent)
        }
    }
}

// MARK: - Lock Screen

private struct FocusLockScreenView: View {
    let context: ActivityViewContext<FocusAttributes>

    var body: some View {
        let accent = focusAccent(for: context.state)

        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 11) {
                FocusIconBubble(state: context.state, accent: accent, size: 42)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(accent)
                            .frame(width: 12, height: 2.5)
                            .clipShape(Capsule())

                        Text(focusModeLabel(for: context.state))
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(accent)
                    }

                    Text(context.state.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(context.state.subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(context.state.isCompleted ? accent.opacity(0.92) : .secondary)
                        .lineLimit(1)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    focusTimerText(for: context.state)
                        .font(.system(size: context.state.isCompleted ? 28 : 34, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer()

                    Text(focusStatusText(for: context.state))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(accent)
                }

                GlowProgressBar(
                    progress: focusProgress(for: context.state),
                    accent: accent,
                    height: 8
                )
            }
        }
        .padding(16)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        UpdoWidgetPalette.bgTop,
                        UpdoWidgetPalette.bgBottom
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [
                        accent.opacity(context.state.isCompleted ? 0.22 : 0.16),
                        .clear
                    ],
                    center: .topTrailing,
                    startRadius: 6,
                    endRadius: 200
                )

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(accent.opacity(context.state.isCompleted ? 0.24 : 0.16), lineWidth: 1)
            }
        )
    }
}

// MARK: - Shared subviews

private struct FocusIconBubble: View {
    let state: FocusAttributes.ContentState
    let accent: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(accent.opacity(state.isCompleted ? 0.24 : 0.20))
                .shadow(color: accent.opacity(state.isCompleted ? 0.38 : 0.30), radius: 5)

            Image(systemName: focusIconName(for: state))
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(accent)
        }
        .frame(width: size, height: size)
    }
}

private struct CompactFocusTimeView: View {
    let state: FocusAttributes.ContentState

    var body: some View {
        Group {
            if isFocusFinished(state) {
                Text("Done")
            } else if state.isPaused {
                let seconds = max(0, state.pausedRemainingSeconds ?? 0)
                Text("\(seconds / 60)d")
            } else {
                Text(timerInterval: Date()...state.endDate, countsDown: true)
            }
        }
        .font(.system(size: state.isCompleted ? 11 : 13, weight: .bold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }
}

// MARK: - Helpers

private func focusAccent(for state: FocusAttributes.ContentState) -> Color {
    if isFocusFinished(state) { return UpdoWidgetPalette.green }
    if state.isPaused { return .orange }
    if state.isResting { return .orange }

    switch state.modeRaw {
    case "workout":
        return UpdoWidgetPalette.green
    case "crew":
        return UpdoWidgetPalette.purple
    default:
        return UpdoWidgetPalette.cyan
    }
}

private func focusIconName(for state: FocusAttributes.ContentState) -> String {
    if isFocusFinished(state) { return "checkmark.seal.fill" }
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

private func isFocusFinished(_ state: FocusAttributes.ContentState) -> Bool {
    if state.isCompleted { return true }
    if state.isPaused { return false }
    return Date() >= state.endDate
}

private func focusModeLabel(for state: FocusAttributes.ContentState) -> String {
    if isFocusFinished(state) { return "DONE" }
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
    if isFocusFinished(state) { return "Tamamlandı" }
    if state.isPaused { return "Duraklatıldı" }
    if state.isResting { return "Dinlenme aktif" }

    switch state.modeRaw {
    case "workout":
        return "Workout sürüyor"
    case "crew":
        return "Ortak focus sürüyor"
    default:
        return "Focus sürüyor"
    }
}

private func focusProgress(for state: FocusAttributes.ContentState) -> CGFloat {
    if isFocusFinished(state) {
        return 1
    }

    if state.isPaused {
        return CGFloat(max(0, min(1, state.pausedProgress ?? 0)))
    }

    let now = Date()

    if now >= state.endDate {
        return 1
    }

    let total = state.endDate.timeIntervalSince(state.startDate)
    guard total > 0 else { return 0 }

    return CGFloat(min(1, max(0, now.timeIntervalSince(state.startDate) / total)))
}

@ViewBuilder
private func focusTimerText(for state: FocusAttributes.ContentState) -> some View {
    if isFocusFinished(state) {
        Text("Focus tamamlandı")
    } else if state.isPaused {
        let seconds = max(0, state.pausedRemainingSeconds ?? 0)
        Text(String(format: "%02d:%02d", seconds / 60, seconds % 60))
    } else {
        Text(timerInterval: Date()...state.endDate, countsDown: true)
    }
}
