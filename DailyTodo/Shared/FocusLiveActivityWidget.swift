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

                        UpdoLiveProgressBar(
                            running: focusRunningRange(for: context.state),
                            staticProgress: focusProgress(for: context.state),
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

    private var state: FocusAttributes.ContentState { context.state }

    private var totalMinutes: Int {
        max(1, Int((state.endDate.timeIntervalSince(state.startDate) / 60).rounded()))
    }

    var body: some View {
        let accent = focusAccent(for: state)

        VStack(spacing: 0) {
            headerBand(accent: accent)
            bodyBlock(accent: accent)
        }
        .background(
            ZStack {
                LinearGradient(
                    colors: [UpdoWidgetPalette.bgMid, UpdoWidgetPalette.bgBottom],
                    startPoint: .top, endPoint: .bottom
                )
                RadialGradient(
                    colors: [accent.opacity(state.isCompleted ? 0.20 : 0.14), .clear],
                    center: .bottomTrailing, startRadius: 8, endRadius: 240
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(accent.opacity(state.isCompleted ? 0.30 : 0.18), lineWidth: 1)
        )
    }

    // MARK: Header band — hero timer + mode + brand logo

    private func headerBand(accent: Color) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(focusModeLabel(for: state))
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(1.6)
                        .foregroundStyle(.white.opacity(0.95))
                    ProStreakChip()
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    focusTimerText(for: state)
                        .font(.system(size: state.isCompleted ? 30 : 42, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    if !isFocusFinished(state) && !state.isPaused {
                        Text("/ \(totalMinutes) dk")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 6)

            UpdoWidgetLogo(size: 26)
                .shadow(color: .black.opacity(0.4), radius: 4, y: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 13)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [accent.opacity(0.42), accent.opacity(0.10), .clear],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
    }

    // MARK: Body — identity row, progress, status line

    private func bodyBlock(accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 11) {
                FocusIconBubble(state: state, accent: accent, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(state.subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 4)
            }

            UpdoLiveProgressBar(
                running: focusRunningRange(for: state),
                staticProgress: focusProgress(for: state),
                accent: accent,
                height: 8
            )

            HStack(spacing: 6) {
                Image(systemName: focusStatusIcon(for: state))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent)

                Text(focusStatusText(for: state))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 4)

                Text("\(Int(focusProgress(for: state) * 100))%")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(accent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }
}

// MARK: - Pro extras

/// Small flame + streak chip shown only to Pro users (reads the mirrored stats
/// from the App Group). A premium, useful touch on the lock screen.
struct ProStreakChip: View {
    var body: some View {
        let state = WidgetShared.readUserState()
        if state.isPro && state.streak > 0 {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 9, weight: .black))
                Text("\(state.streak)")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(hexColor("#FBBF24"))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(hexColor("#FBBF24").opacity(0.15)))
        }
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
        // Personal focus → mirror the selected app-icon color.
        return UpdoWidgetIconTheme.current().accent
    }
}

/// The interval for the auto-advancing progress bar, or nil for paused/done.
private func focusRunningRange(for state: FocusAttributes.ContentState) -> ClosedRange<Date>? {
    if isFocusFinished(state) || state.isPaused { return nil }
    guard state.endDate > state.startDate, Date() < state.endDate else { return nil }
    return state.startDate...state.endDate
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

private func focusStatusIcon(for state: FocusAttributes.ContentState) -> String {
    if isFocusFinished(state) { return "checkmark.seal.fill" }
    if state.isPaused { return "pause.circle.fill" }
    if state.isResting { return "cup.and.saucer.fill" }
    return "bolt.fill"
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

/// Widget-side localization. The widget extension can't use the app's `tr()`
/// (it lives only in the app target), so it reads the user's chosen language
/// from the shared App Group and picks the matching string.
func widgetLocalized(_ trText: String, _ enText: String) -> String {
    let lang = UserDefaults(suiteName: "group.com.atakan.updo")?.string(forKey: "appLanguage") ?? "system"
    switch lang {
    case "turkish": return trText
    case "english": return enText
    default:
        return (Locale.preferredLanguages.first ?? "en").hasPrefix("tr") ? trText : enText
    }
}

private func focusStatusText(for state: FocusAttributes.ContentState) -> String {
    if isFocusFinished(state) { return widgetLocalized("Tamamlandı", "Completed") }
    if state.isPaused { return widgetLocalized("Duraklatıldı", "Paused") }
    if state.isResting { return widgetLocalized("Dinlenme aktif", "Resting") }

    switch state.modeRaw {
    case "workout":
        return widgetLocalized("Workout sürüyor", "Workout in progress")
    case "crew":
        return widgetLocalized("Ortak focus sürüyor", "Shared focus in progress")
    default:
        return widgetLocalized("Focus sürüyor", "Focus in progress")
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
        Text(widgetLocalized("Focus tamamlandı", "Focus completed"))
    } else if state.isPaused {
        let seconds = max(0, state.pausedRemainingSeconds ?? 0)
        Text(String(format: "%02d:%02d", seconds / 60, seconds % 60))
    } else {
        Text(timerInterval: Date()...state.endDate, countsDown: true)
    }
}
