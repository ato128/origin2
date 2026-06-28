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
                                .font(.system(size: 15, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            Text(context.state.subtitle)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(context.state.isCompleted ? accent.opacity(0.95) : .secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(focusModeLabel(for: context.state))
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.4)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(accent.opacity(0.16)))
                        .foregroundStyle(accent)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(focusStatusText(for: context.state))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(context.state.isCompleted ? accent : .secondary)
                                .lineLimit(1)

                            Spacer(minLength: 12)

                            focusTimerText(for: context.state)
                                .focusHeroNumber(size: context.state.isCompleted ? 22 : 26, accent: accent, live: true)
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

        VStack(alignment: .leading, spacing: 12) {
            // Identity row
            HStack(spacing: 11) {
                FocusIconBubble(state: state, accent: accent, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title)
                        .font(WidgetFont.title(16))
                        .foregroundStyle(UpdoWidgetPalette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(state.subtitle)
                        .font(WidgetFont.caption())
                        .foregroundStyle(UpdoWidgetPalette.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 4) {
                    modeChip(accent: accent)
                    ProStreakChip()
                }
            }

            // Hero timer + percent
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                focusTimerText(for: state)
                    .focusHeroNumber(size: state.isCompleted ? 26 : 40, accent: accent, live: true)

                if !isFocusFinished(state) && !state.isPaused {
                    Text("/ \(totalMinutes) \(widgetLocalized("dk", "min"))")
                        .font(WidgetFont.caption())
                        .foregroundStyle(UpdoWidgetPalette.textTertiary)
                }

                Spacer(minLength: 6)

                Text("\(Int(focusProgress(for: state) * 100))%")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(accent)
            }

            UpdoLiveProgressBar(
                running: focusRunningRange(for: state),
                staticProgress: focusProgress(for: state),
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
                RadialGradient(
                    colors: [accent.opacity(state.isCompleted ? 0.16 : 0.10), .clear],
                    center: .bottomTrailing, startRadius: 8, endRadius: 240
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(UpdoWidgetPalette.hairline, lineWidth: 1)
        )
    }

    private func modeChip(accent: Color) -> some View {
        Text(focusModeLabel(for: state))
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(accent.opacity(0.14)))
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
                    .font(.system(size: 9, weight: .semibold))
                Text("\(state.streak)")
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(hexColor("#FBBF24"))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(hexColor("#FBBF24").opacity(0.14)))
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
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(accent.opacity(0.16))

            Image(systemName: focusIconName(for: state))
                .font(.system(size: size * 0.42, weight: .medium))
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
                Text("✓")
            } else if state.isPaused {
                let seconds = max(0, state.pausedRemainingSeconds ?? 0)
                Text("\(seconds / 60)")
            } else {
                Text(timerInterval: Date()...state.endDate, countsDown: true)
            }
        }
        // Focus serif identity; `live` keeps the timer ticking (no contentTransition).
        .focusHeroNumber(size: state.isCompleted ? 12 : 14, accent: focusAccent(for: state), live: true)
        .minimumScaleFactor(0.6)
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
