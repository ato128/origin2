//
//  FocusIdentityWidget.swift
//  WidgetExtensionExtension
//
//  A premium "focus identity card" — level, streak and today's focus at a glance,
//  themed to the selected app icon, with the crosshair mark as artwork. Reads the
//  mirrored stats from the App Group (no schedule data, so it never repeats the
//  schedule widget).
//

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct IdentityEntry: TimelineEntry {
    let date: Date
    let state: WidgetUserState
}

struct IdentityProvider: TimelineProvider {
    func placeholder(in context: Context) -> IdentityEntry {
        IdentityEntry(date: Date(), state: WidgetUserState(
            iconName: nil, isPro: true, streak: 7, level: 5,
            todayFocusMinutes: 84, statsShared: true, longestStreak: 21
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (IdentityEntry) -> Void) {
        completion(IdentityEntry(date: Date(), state: WidgetShared.readUserState()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<IdentityEntry>) -> Void) {
        let entry = IdentityEntry(date: Date(), state: WidgetShared.readUserState())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
            ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - View

struct FocusIdentityView: View {
    let state: WidgetUserState
    @Environment(\.widgetFamily) private var family

    private var isSmall: Bool { family == .systemSmall }
    private var theme: UpdoWidgetIconTheme.Theme { UpdoWidgetIconTheme.current() }
    private let gold = hexColor("#FBBF24")

    // Streak-risk: only meaningful with a fresh (written today) status and a
    // live streak; when both halves are done there is nothing to warn about.
    private var todayTask: Bool { state.todayTaskDone ?? false }
    private var todayFocus: Bool { state.todayFocusDone ?? false }
    private var streakAtRisk: Bool {
        state.statusIsFresh && state.streak > 0 && !(todayTask && todayFocus)
    }

    /// Short label naming the missing half ("Focus ✗", "Görev ✗", "Bugün ✗").
    private var riskLabel: String {
        if !todayTask && !todayFocus { return widgetLocalized("Bugün ✗", "Today ✗") }
        if !todayFocus { return widgetLocalized("Focus ✗", "Focus ✗") }
        return widgetLocalized("Görev ✗", "Task ✗")
    }

    var body: some View {
        Group {
            if isSmall { smallCard } else { mediumCard }
        }
        .padding(isSmall ? 16 : 18)
        .widgetUpdoBackground(accent: theme.accent)
    }

    // MARK: Small

    private var smallCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(title: widgetLocalized("ODAK", "FOCUS"))

            Spacer(minLength: 8)

            heroLevel

            Spacer(minLength: 10)

            HStack(spacing: 0) {
                miniStat(icon: "flame", value: "\(state.streak)",
                         label: streakAtRisk ? riskLabel : widgetLocalized("Seri", "Streak"),
                         tint: gold,
                         labelTint: streakAtRisk ? hexColor("#FF8A5C") : nil)
                Spacer(minLength: 8)
                miniStat(icon: "scope", value: "\(state.todayFocusMinutes)\(widgetLocalized("dk", "m"))",
                         label: widgetLocalized("Bugün", "Today"), tint: theme.accent)
            }
        }
    }

    // MARK: Medium

    private var mediumCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                header(title: widgetLocalized("ODAK KİMLİĞİ", "FOCUS IDENTITY"))

                Spacer(minLength: 10)

                HStack(alignment: .firstTextBaseline, spacing: 22) {
                    bigStat(value: "\(state.level)", label: widgetLocalized("Seviye", "Level"), color: .white)
                    bigStat(value: "\(state.streak)", label: widgetLocalized("Gün seri", "Day streak"), color: gold)

                    if streakAtRisk {
                        riskChip
                    }
                }

                Spacer(minLength: 12)

                HStack(spacing: 0) {
                    miniStat(icon: "scope", value: "\(state.todayFocusMinutes)\(widgetLocalized("dk", "m"))",
                             label: widgetLocalized("Bugün", "Today"), tint: theme.accent)
                    Spacer(minLength: 8)
                    miniStat(icon: "crown", value: "\(max(state.streak, state.longestStreak))\(widgetLocalized("g", "d"))",
                             label: widgetLocalized("En uzun", "Longest"), tint: UpdoWidgetPalette.textSecondary)
                    Spacer(minLength: 0)
                }
            }

            // A subtle, single brand mark — quiet identity, not a loud watermark.
            VStack(spacing: 12) {
                UpdoWidgetLogo(size: 62, tint: theme.mark)
                    .opacity(0.5)

                Link(destination: URL(string: "dailytodo://focus?autostart=1")!) {
                    startPill
                }
            }
            .frame(width: 84)
        }
    }

    /// One-tap session start — opens the app and launches focus with the
    /// user's last settings.
    private var startPill: some View {
        HStack(spacing: 5) {
            Image(systemName: "play.fill")
                .font(.system(size: 9, weight: .bold))

            Text(widgetLocalized("Başlat", "Start"))
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(Color.black.opacity(0.85))
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(Capsule().fill(theme.accent))
    }

    // MARK: Pieces

    /// "Focus ✗" — quiet amber chip telling which half of today's streak rule
    /// is still missing. Hidden once the day is safe.
    private var riskChip: some View {
        Text(riskLabel)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(hexColor("#FF8A5C"))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(hexColor("#FF8A5C").opacity(0.13))
                    .overlay(
                        Capsule().strokeBorder(hexColor("#FF8A5C").opacity(0.30), lineWidth: 0.5)
                    )
            )
    }

    private func header(title: String) -> some View {
        HStack(spacing: 7) {
            Text(title)
                .font(WidgetFont.eyebrow(11))
                .tracking(0.8)
                .foregroundStyle(UpdoWidgetPalette.textSecondary)

            if state.isPro {
                Text("PRO")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(gold)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(gold.opacity(0.16)))
            }

            Spacer(minLength: 4)
        }
    }

    private var heroLevel: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(state.level)")
                .focusHeroNumber(size: 46, accent: theme.accent)
            Text(widgetLocalized("Seviye", "Level"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(UpdoWidgetPalette.textTertiary)
        }
    }

    private func bigStat(value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .focusHeroNumber(size: 38, accent: color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(UpdoWidgetPalette.textTertiary)
        }
    }

    private func miniStat(
        icon: String, value: String, label: String, tint: Color,
        labelTint: Color? = nil
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(UpdoWidgetPalette.textPrimary)
                    .contentTransition(.numericText(countsDown: true))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.system(size: 9, weight: labelTint == nil ? .medium : .semibold))
                    .foregroundStyle(labelTint ?? UpdoWidgetPalette.textTertiary)
            }
        }
    }
}

// MARK: - Widget

struct FocusIdentityWidget: Widget {
    let kind: String = "FocusIdentityWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: IdentityProvider()) { entry in
            FocusIdentityView(state: entry.state)
                .widgetURL(URL(string: "dailytodo://focus"))
        }
        .configurationDisplayName("Odak Kimliği")
        .description("Seviyen, serin ve bugünkü odağın — tek bakışta.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
