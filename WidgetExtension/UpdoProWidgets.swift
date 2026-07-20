//
//  UpdoProWidgets.swift
//  WidgetExtensionExtension
//
//  Pro-exclusive widgets. Two pieces, both fed by the mirrored App Group
//  snapshot (no invented data):
//    • UpdoProWeeklyWidget — the weekly report: serif hero total, delta vs
//      last week, a 7-day gradient chart and the streak/level strip.
//    • UpdoProStreakWidget — the streak month: serif streak count + a mini
//      calendar of full/half days, mirroring the in-app streak calendar.
//  Non-Pro users see an elegant locked card instead.
//

import WidgetKit
import SwiftUI

// MARK: - Shared timeline (both widgets read the same snapshot)

struct ProStateEntry: TimelineEntry {
    let date: Date
    let state: WidgetUserState
}

struct ProStateProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProStateEntry {
        var state = WidgetUserState(
            iconName: nil, isPro: true, streak: 12, level: 7,
            todayFocusMinutes: 45, statsShared: true, longestStreak: 21
        )
        state.weekFocusMinutes = [25, 40, 10, 95, 70, 55, 45]
        state.prevWeekFocusMinutes = 290
        state.monthFullDays = [3, 4, 5, 6, 7, 8, 10, 11, 12]
        state.monthHalfDays = [2, 9]
        state.levelProgress = 0.62
        return ProStateEntry(date: Date(), state: state)
    }

    func getSnapshot(in context: Context, completion: @escaping (ProStateEntry) -> Void) {
        completion(ProStateEntry(date: Date(), state: WidgetShared.readUserState()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProStateEntry>) -> Void) {
        let entry = ProStateEntry(date: Date(), state: WidgetShared.readUserState())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
            ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Pro visual tokens

private enum ProWidgetStyle {
    static let gold = hexColor("#FBBF24")
    static let goldSoft = hexColor("#FCD34D")

    /// The Pro signature: gold → cyan, used for streak fills and accents.
    static var streakGradient: LinearGradient {
        LinearGradient(
            colors: [gold, UpdoWidgetPalette.cyan],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    static var barGradient: LinearGradient {
        LinearGradient(
            colors: [UpdoWidgetPalette.cyan, UpdoWidgetPalette.purple],
            startPoint: .top, endPoint: .bottom
        )
    }
}

/// Gold "PRO" chip — the quiet badge both widgets wear.
private struct ProChip: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 8, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(ProWidgetStyle.gold)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(
                Capsule()
                    .fill(ProWidgetStyle.gold.opacity(0.14))
                    .overlay(
                        Capsule().strokeBorder(ProWidgetStyle.gold.opacity(0.32), lineWidth: 0.5)
                    )
            )
    }
}

/// What non-Pro users see: a calm locked card, not a broken widget.
private struct ProLockedCard: View {
    let title: String

    var body: some View {
        VStack(spacing: 9) {
            ZStack {
                Circle()
                    .strokeBorder(ProWidgetStyle.gold.opacity(0.4), lineWidth: 1.2)
                    .frame(width: 40, height: 40)
                Image(systemName: "lock.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ProWidgetStyle.gold)
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(UpdoWidgetPalette.textPrimary)

                Text(widgetLocalized("Updo Pro'ya özel", "Updo Pro exclusive"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(UpdoWidgetPalette.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Formatting helpers

private func proDurationText(_ minutes: Int) -> String {
    if minutes < 60 { return "\(minutes)\(widgetLocalized("dk", "m"))" }
    let h = minutes / 60, m = minutes % 60
    let hUnit = widgetLocalized("s", "h")
    return m == 0 ? "\(h)\(hUnit)" : "\(h)\(hUnit) \(m)\(widgetLocalized("dk", "m"))"
}

/// Weekday letters for the last 7 days, oldest → today.
private func last7WeekdayLetters() -> [String] {
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let f = DateFormatter()
    f.locale = Locale(identifier: widgetLocalized("tr", "en"))
    f.dateFormat = "EEEEE"
    return (0..<7).reversed().map { offset in
        let day = cal.date(byAdding: .day, value: -offset, to: today) ?? today
        return f.string(from: day).uppercased()
    }
}

private func weekDeltaText(week: Int, prev: Int) -> (text: String, isUp: Bool)? {
    guard prev > 0, week != prev else { return nil }
    let pct = Int((Double(week - prev) / Double(prev) * 100).rounded())
    guard pct != 0 else { return nil }
    return (String(format: "%+d%%", pct), pct > 0)
}

// MARK: - Weekly report widget

struct UpdoProWeeklyView: View {
    let state: WidgetUserState
    @Environment(\.widgetFamily) private var family

    private var isSmall: Bool { family == .systemSmall }
    private var theme: UpdoWidgetIconTheme.Theme { UpdoWidgetIconTheme.current() }

    private var week: [Int] { state.weekFocusMinutes ?? Array(repeating: 0, count: 7) }
    private var weekTotal: Int { week.reduce(0, +) }
    private var delta: (text: String, isUp: Bool)? {
        weekDeltaText(week: weekTotal, prev: state.prevWeekFocusMinutes ?? 0)
    }

    var body: some View {
        Group {
            if !state.isPro {
                ProLockedCard(title: widgetLocalized("Haftalık Rapor", "Weekly Report"))
            } else if isSmall {
                smallCard
            } else {
                mediumCard
            }
        }
        .padding(isSmall ? 15 : 17)
        .widgetUpdoBackground(accent: state.isPro ? ProWidgetStyle.gold : theme.accent)
    }

    // MARK: Small — hero total + mini chart

    private var smallCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(title: widgetLocalized("HAFTA", "WEEK"))

            Spacer(minLength: 6)

            heroTotal(size: 30)

            Spacer(minLength: 8)

            chart(barMaxHeight: 26, showLetters: true)
        }
    }

    // MARK: Medium — hero + delta + chart + streak strip

    private var mediumCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(title: widgetLocalized("HAFTALIK RAPOR", "WEEKLY REPORT"))

            Spacer(minLength: 8)

            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    heroTotal(size: 38)

                    HStack(spacing: 10) {
                        miniStat(icon: "flame.fill", tint: ProWidgetStyle.gold,
                                 text: "\(state.streak)")
                        miniStat(icon: "scope", tint: UpdoWidgetPalette.cyan,
                                 text: "\(state.todayFocusMinutes)\(widgetLocalized("dk", "m"))")
                        miniStat(icon: "chevron.up.circle.fill", tint: UpdoWidgetPalette.textSecondary,
                                 text: "Lv \(state.level)")
                    }
                }

                Spacer(minLength: 4)

                chart(barMaxHeight: 44, showLetters: true)
                    .frame(width: 128)
            }
        }
    }

    // MARK: Pieces

    private func header(title: String) -> some View {
        HStack(spacing: 7) {
            Text(title)
                .font(WidgetFont.eyebrow(10.5))
                .tracking(0.9)
                .foregroundStyle(UpdoWidgetPalette.textSecondary)
            ProChip()
            Spacer(minLength: 0)

            if let delta {
                HStack(spacing: 2) {
                    Image(systemName: delta.isUp ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 8, weight: .bold))
                    Text(delta.text)
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(delta.isUp ? UpdoWidgetPalette.green : UpdoWidgetPalette.textTertiary)
            }
        }
    }

    private func heroTotal(size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(proDurationText(weekTotal))
                .focusHeroNumber(size: size, accent: ProWidgetStyle.gold)
            Text(widgetLocalized("bu hafta odak", "focus this week"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(UpdoWidgetPalette.textTertiary)
        }
    }

    private func chart(barMaxHeight: CGFloat, showLetters: Bool) -> some View {
        let maxValue = max(week.max() ?? 0, 1)
        let letters = last7WeekdayLetters()

        return HStack(alignment: .bottom, spacing: 5) {
            ForEach(0..<7, id: \.self) { idx in
                let value = week[idx]
                let isToday = idx == 6

                VStack(spacing: 3) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(UpdoWidgetPalette.fillSoft)
                            .frame(height: barMaxHeight)

                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(
                                isToday
                                ? AnyShapeStyle(ProWidgetStyle.streakGradient)
                                : AnyShapeStyle(ProWidgetStyle.barGradient)
                            )
                            .frame(height: max(value == 0 ? 0 : 3,
                                               barMaxHeight * CGFloat(value) / CGFloat(maxValue)))
                    }

                    if showLetters {
                        Text(letters[idx])
                            .font(.system(size: 7.5, weight: .semibold))
                            .foregroundStyle(isToday
                                             ? UpdoWidgetPalette.textPrimary.opacity(0.85)
                                             : UpdoWidgetPalette.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func miniStat(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(UpdoWidgetPalette.textPrimary)
        }
    }
}

struct UpdoProWeeklyWidget: Widget {
    let kind: String = "UpdoProWeeklyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProStateProvider()) { entry in
            UpdoProWeeklyView(state: entry.state)
                .widgetURL(URL(string: "dailytodo://focus"))
        }
        .configurationDisplayName(widgetLocalized("Haftalık Rapor (Pro)", "Weekly Report (Pro)"))
        .description(widgetLocalized(
            "Haftalık odak toplamın, gidişatın ve günlük grafiğin — Pro'ya özel.",
            "Your weekly focus total, trend and daily chart — Pro exclusive."
        ))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Streak month widget

struct UpdoProStreakView: View {
    let state: WidgetUserState
    @Environment(\.widgetFamily) private var family

    private var isSmall: Bool { family == .systemSmall }

    private var cal: Calendar { Calendar.current }
    private var today: Date { cal.startOfDay(for: Date()) }
    private var monthStart: Date {
        cal.date(from: cal.dateComponents([.year, .month], from: today)) ?? today
    }
    private var daysInMonth: Int {
        cal.range(of: .day, in: .month, for: monthStart)?.count ?? 30
    }
    private var leadingBlanks: Int {
        (cal.component(.weekday, from: monthStart) + 5) % 7
    }
    private var todayNumber: Int { cal.component(.day, from: today) }

    private var monthLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: widgetLocalized("tr", "en"))
        f.dateFormat = "MMM"
        return f.string(from: today).uppercased()
    }

    var body: some View {
        Group {
            if !state.isPro {
                ProLockedCard(title: widgetLocalized("Seri Takvimi", "Streak Calendar"))
            } else if isSmall {
                smallCard
            } else {
                mediumCard
            }
        }
        .padding(isSmall ? 14 : 17)
        .widgetUpdoBackground(accent: ProWidgetStyle.gold)
    }

    private var smallCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Text(widgetLocalized("SERİ", "STREAK"))
                    .font(WidgetFont.eyebrow(10.5))
                    .tracking(0.9)
                    .foregroundStyle(UpdoWidgetPalette.textSecondary)
                ProChip()
                Spacer(minLength: 0)
                Text(monthLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(UpdoWidgetPalette.textTertiary)
            }

            Spacer(minLength: 7)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(state.streak)")
                    .focusHeroNumber(size: 32, accent: ProWidgetStyle.gold)
                Image(systemName: "flame.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ProWidgetStyle.gold)
                Text(widgetLocalized("gün", "days"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(UpdoWidgetPalette.textTertiary)
            }

            Spacer(minLength: 8)

            monthGrid(dotSize: 9, spacing: 3.5)
        }
    }

    private var mediumCard: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    Text(widgetLocalized("SERİ TAKVİMİ", "STREAK CALENDAR"))
                        .font(WidgetFont.eyebrow(10.5))
                        .tracking(0.9)
                        .foregroundStyle(UpdoWidgetPalette.textSecondary)
                    ProChip()
                }

                Spacer(minLength: 8)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(state.streak)")
                        .focusHeroNumber(size: 42, accent: ProWidgetStyle.gold)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ProWidgetStyle.gold)
                }

                Text(widgetLocalized("gün seri", "day streak"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(UpdoWidgetPalette.textTertiary)

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(UpdoWidgetPalette.textSecondary)
                    Text(widgetLocalized(
                        "En uzun: \(max(state.streak, state.longestStreak))g",
                        "Longest: \(max(state.streak, state.longestStreak))d"
                    ))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(UpdoWidgetPalette.textSecondary)
                }
            }

            VStack(alignment: .trailing, spacing: 5) {
                Text(monthLabel)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(UpdoWidgetPalette.textTertiary)

                monthGrid(dotSize: 12, spacing: 5)
            }
            .frame(width: 128)
        }
    }

    /// The mini month: gold→cyan filled dot = full day, gold ring = half,
    /// hairline = empty, near-invisible = future. Same rules as in-app.
    private func monthGrid(dotSize: CGFloat, spacing: CGFloat) -> some View {
        let full = Set(state.monthFullDays ?? [])
        let half = Set(state.monthHalfDays ?? [])
        let columns = Array(repeating: GridItem(.fixed(dotSize), spacing: spacing), count: 7)

        return LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
            ForEach(0..<leadingBlanks, id: \.self) { _ in
                Color.clear.frame(width: dotSize, height: dotSize)
            }

            ForEach(1...daysInMonth, id: \.self) { day in
                ZStack {
                    if full.contains(day) {
                        Circle().fill(ProWidgetStyle.streakGradient)
                    } else if half.contains(day) {
                        Circle().strokeBorder(ProWidgetStyle.gold.opacity(0.55), lineWidth: 1.2)
                    } else if day > todayNumber {
                        Circle().fill(Color.white.opacity(0.03))
                    } else {
                        Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    }
                }
                .frame(width: dotSize, height: dotSize)
                .overlay {
                    if day == todayNumber {
                        Circle().strokeBorder(Color.white.opacity(0.65), lineWidth: 1.2)
                    }
                }
            }
        }
    }
}

struct UpdoProStreakWidget: Widget {
    let kind: String = "UpdoProStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProStateProvider()) { entry in
            UpdoProStreakView(state: entry.state)
                .widgetURL(URL(string: "dailytodo://home"))
        }
        .configurationDisplayName(widgetLocalized("Seri Takvimi (Pro)", "Streak Calendar (Pro)"))
        .description(widgetLocalized(
            "Serin ve bu ayın dolu günleri — Pro'ya özel.",
            "Your streak and this month's completed days — Pro exclusive."
        ))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
