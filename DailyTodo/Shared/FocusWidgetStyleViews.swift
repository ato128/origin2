//
//  FocusWidgetStyleViews.swift
//  DailyTodo
//
//  Home-screen twin of FocusLiveStyleViews: the "Focus Card" widget rendered
//  in the same nine style identities (classic/poster/minimal/gold/neon/
//  terminal/aura/arena/zen). Compiled into BOTH targets so the in-app picker
//  previews the exact widget the extension draws.
//
//  Layout contract: `UpdoWidgetStyleContent` is the foreground only; the
//  background comes from `WidgetStyleBackground` — the widget applies it via
//  containerBackground (edge-to-edge), the app preview stacks them manually.
//

import SwiftUI

// MARK: - Background (per style, edge-to-edge)

struct WidgetStyleBackground: View {
    let style: FocusLiveStyle

    var body: some View {
        switch style {
        case .classic, .minimal:
            ZStack {
                LinearGradient(colors: [LiveStyleTokens.surfaceTop, LiveStyleTokens.surfaceBottom],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [LiveStyleTokens.cyan.opacity(0.10), .clear],
                               center: .bottomTrailing, startRadius: 10, endRadius: 220)
            }
        case .poster:
            ZStack {
                Color(red: 0.016, green: 0.02, blue: 0.04)
                LinearGradient(colors: [LiveStyleTokens.cyan.opacity(0.35), LiveStyleTokens.cyan.opacity(0.08), .clear],
                               startPoint: .bottom, endPoint: .top)
            }
        case .gold:
            ZStack {
                LinearGradient(colors: [LiveStyleTokens.surfaceTop, LiveStyleTokens.surfaceBottom],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [LiveStyleTokens.gold.opacity(0.13), .clear],
                               center: .topTrailing, startRadius: 8, endRadius: 200)
            }
        case .neon:
            Color(red: 0.015, green: 0.015, blue: 0.03)
        case .terminal:
            Color(red: 0.01, green: 0.035, blue: 0.015)
        case .aura:
            ZStack {
                Color(red: 0.03, green: 0.025, blue: 0.07)
                RadialGradient(colors: [LiveStyleTokens.purple.opacity(0.5), .clear],
                               center: .topLeading, startRadius: 10, endRadius: 190)
                RadialGradient(colors: [LiveStyleTokens.cyan.opacity(0.35), .clear],
                               center: .bottomTrailing, startRadius: 10, endRadius: 200)
            }
        case .arena:
            HStack(spacing: 0) {
                Rectangle().fill(Color(red: 0.88, green: 0.02, blue: 0.0)).frame(width: 5)
                Color(red: 0.04, green: 0.04, blue: 0.05)
            }
        case .zen:
            Color(red: 0.96, green: 0.95, blue: 0.92)
        }
    }
}

// MARK: - Foreground content
//
// One information design for all nine styles — what changes per style is the
// voice (type, colour, labels), not the facts:
//
//   small    label · streak            medium   the same block, then this
//            85 dk                              week: total, change vs last
//            today · goal                       week, and seven bars with
//            ▬▬▬▬▬▬▭▭ progress to goal           their weekday letters
//            Lv 6 · 70 %                        (today in full accent).
//
// `minimal` keeps its own centred, almost empty composition on purpose.

struct UpdoWidgetStyleContent: View {
    let style: FocusLiveStyle
    let state: WidgetUserState
    let isSmall: Bool
    /// The student's daily focus goal (minutes), if they have set one.
    var dailyGoalMinutes: Int? = WidgetShared.readDailyGoal()

    var body: some View {
        if style == .minimal {
            minimal
        } else if isSmall {
            summary
        } else {
            HStack(spacing: 14) {
                summary
                    .frame(width: 124, alignment: .leading)

                Rectangle()
                    .fill(voice.track)
                    .frame(width: 1)
                    .padding(.vertical, 2)

                weekPanel
            }
        }
    }

    // MARK: Facts

    private var goal: Int? {
        guard let dailyGoalMinutes, dailyGoalMinutes > 0 else { return nil }
        return dailyGoalMinutes
    }

    /// 0…1 toward the daily goal — or toward the next level when no goal is set.
    private var progress: Double {
        if let goal { return min(Double(state.todayFocusMinutes) / Double(goal), 1) }
        return min(max(state.levelProgress ?? 0, 0), 1)
    }

    private var goalReached: Bool {
        guard let goal else { return false }
        return state.todayFocusMinutes >= goal
    }

    private var week: [Int] {
        let values = state.weekFocusMinutes ?? []
        return values.count == 7 ? values : Array(repeating: 0, count: 7)
    }

    /// Weekday letters for the seven bars (oldest → today).
    private var weekLetters: [String] {
        let letters = liveStyleLocalized("P S Ç P C C P", "M T W T F S S").split(separator: " ").map(String.init)
        let today = (Calendar.current.component(.weekday, from: Date()) + 5) % 7   // 0 = Monday
        return (0..<7).map { letters[((today - 6 + $0) % 7 + 7) % 7] }
    }

    /// Change against the seven days before, in percent.
    private var weekDelta: Int? {
        guard let previous = state.prevWeekFocusMinutes, previous > 0 else { return nil }
        let total = week.reduce(0, +)
        return Int((Double(total - previous) / Double(previous) * 100).rounded())
    }

    private func duration(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        let hour = liveStyleLocalized("sa", "h"), minute = liveStyleLocalized("dk", "m")
        if h == 0 { return "\(m) \(minute)" }
        if m == 0 { return "\(h) \(hour)" }
        return "\(h) \(hour) \(m) \(minute)"
    }

    private func percent(_ value: Int) -> String {
        liveStyleLocalized("%\(value)", "\(value)%")
    }

    private var todayLabel: String { liveStyleLocalized("Bugün", "Today") }
    private var minuteUnit: String { liveStyleLocalized("dk", "m") }

    // MARK: Voice (what makes each style itself)

    private struct Voice {
        var label: String
        var labelFont: Font
        var labelTracking: CGFloat = 0.9
        var labelColor: Color
        /// A small lit dot before the label (neon, zen).
        var dot: Color? = nil
        var showsProChip = false
        var showsMark = false

        var hero: (CGFloat) -> Font
        var heroItalic = false
        var heroColor: Color
        var heroGlow: Color? = nil

        var text: Color                 // figures in chips and footers
        var caption: Color              // secondary words
        var captionFont: (CGFloat) -> Font = { .system(size: $0, weight: .medium) }
        var uppercase = false

        var accent: Color               // progress, today's bar
        var track: Color                // rails, hairlines, empty bars
        var flame: Color = LiveStyleTokens.gold
        var barRadius: CGFloat = 2.5
    }

    private var voice: Voice {
        let serif: (CGFloat) -> Font = { .system(size: $0, weight: .bold, design: .serif) }
        let white = Color.white

        switch style {
        case .classic, .minimal:
            return Voice(
                label: "FOCUS", labelFont: .system(size: 10.5, weight: .semibold),
                labelColor: LiveStyleTokens.textSecondary,
                hero: serif, heroItalic: true, heroColor: LiveStyleTokens.silver,
                text: white, caption: LiveStyleTokens.textTertiary,
                accent: LiveStyleTokens.cyan, track: white.opacity(0.09)
            )
        case .poster:
            return Voice(
                label: todayLabel.uppercased(), labelFont: .system(size: 10.5, weight: .heavy),
                labelColor: LiveStyleTokens.cyan, showsMark: true,
                hero: { .system(size: $0, weight: .black) }, heroColor: LiveStyleTokens.cyan,
                heroGlow: LiveStyleTokens.cyan,
                text: white, caption: white.opacity(0.55),
                accent: LiveStyleTokens.cyan, track: white.opacity(0.10)
            )
        case .gold:
            return Voice(
                label: "FOCUS", labelFont: .system(size: 10.5, weight: .semibold),
                labelColor: LiveStyleTokens.textSecondary, showsProChip: true,
                hero: serif, heroItalic: true, heroColor: LiveStyleTokens.silver,
                text: white, caption: LiveStyleTokens.textTertiary,
                accent: LiveStyleTokens.gold, track: white.opacity(0.09)
            )
        case .neon:
            let cyan = Color(red: 0.13, green: 0.83, blue: 0.93)
            let pink = Color(red: 1.00, green: 0.18, blue: 0.53)
            return Voice(
                label: "FOCUS", labelFont: .system(size: 10, weight: .bold), labelTracking: 1.4,
                labelColor: white, dot: pink,
                hero: { .system(size: $0, weight: .heavy, design: .rounded) }, heroColor: cyan, heroGlow: cyan,
                text: white, caption: white.opacity(0.5),
                accent: pink, track: white.opacity(0.10), flame: pink
            )
        case .terminal:
            let green = Color(red: 0.24, green: 1.0, blue: 0.45)
            let mono: (CGFloat) -> Font = { .system(size: $0, weight: .medium, design: .monospaced) }
            return Voice(
                label: "updo@stats:~$", labelFont: .system(size: 9.5, weight: .medium, design: .monospaced),
                labelTracking: 0, labelColor: green.opacity(0.6),
                hero: { .system(size: $0, weight: .bold, design: .monospaced) }, heroColor: green, heroGlow: green,
                text: green, caption: green.opacity(0.55), captionFont: mono,
                accent: green, track: green.opacity(0.16), flame: green, barRadius: 0.5
            )
        case .aura:
            return Voice(
                label: "FOCUS", labelFont: .system(size: 10.5, weight: .semibold),
                labelColor: white.opacity(0.7),
                hero: serif, heroItalic: true, heroColor: white,
                text: white, caption: white.opacity(0.55),
                accent: Color(red: 0.75, green: 0.62, blue: 1.0), track: white.opacity(0.14)
            )
        case .arena:
            let red = Color(red: 0.88, green: 0.02, blue: 0.0)
            return Voice(
                label: "FOCUS", labelFont: .system(size: 11, weight: .black).italic(), labelTracking: 0.6,
                labelColor: white,
                hero: { .system(size: $0, weight: .black) }, heroItalic: true, heroColor: white,
                text: white, caption: white.opacity(0.55),
                captionFont: { .system(size: $0, weight: .heavy).italic() }, uppercase: true,
                accent: red, track: white.opacity(0.12), flame: red, barRadius: 1
            )
        case .zen:
            let ink = Color(red: 0.13, green: 0.14, blue: 0.13)
            let sage = Color(red: 0.42, green: 0.52, blue: 0.40)
            return Voice(
                label: todayLabel, labelFont: .system(size: 11, weight: .medium), labelTracking: 0.2,
                labelColor: ink.opacity(0.6), dot: sage,
                hero: serif, heroItalic: true, heroColor: ink,
                text: ink, caption: ink.opacity(0.5),
                accent: sage, track: ink.opacity(0.10), flame: sage
            )
        }
    }

    private func words(_ text: String) -> String { voice.uppercase ? text.uppercased() : text }

    // MARK: Summary (the small widget; the left block of the medium one)

    private var summary: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Spacer(minLength: 4)

            heroNumber(size: isSmall ? 40 : 38)

            Text(words(summaryCaption))
                .font(voice.captionFont(10.5))
                .foregroundStyle(voice.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 6)

            progressRail

            footer
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// "Today · goal 2 h" — without repeating "Today" when the style's own
    /// label already says it (poster, zen).
    private var summaryCaption: String {
        let labelIsToday = voice.label.caseInsensitiveCompare(todayLabel) == .orderedSame
        let goalText = goal.map { "\(liveStyleLocalized("hedef", "goal")) \(duration($0))" }
        switch (labelIsToday, goalText) {
        case (false, let goalText?): return "\(todayLabel) · \(goalText)"
        case (false, nil): return todayLabel
        case (true, let goalText?): return goalText
        case (true, nil): return liveStyleLocalized("odak", "focus")
        }
    }

    private var header: some View {
        HStack(spacing: 5) {
            if voice.showsMark {
                LiveStyleMark(size: 15, tint: voice.accent)
                    .rotationEffect(.degrees(-8))
            }
            if let dot = voice.dot {
                Circle().fill(dot).frame(width: 5, height: 5)
                    .shadow(color: dot.opacity(style == .neon ? 0.9 : 0), radius: 4)
            }
            Text(voice.label)
                .font(voice.labelFont)
                .tracking(voice.labelTracking)
                .foregroundStyle(voice.labelColor)
                .lineLimit(1)

            if voice.showsProChip {
                Text("PRO")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(LiveStyleTokens.gold)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(LiveStyleTokens.gold.opacity(0.16)))
            }

            Spacer(minLength: 4)

            // The streak: the one number worth a glance every day.
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(state.streak > 0 ? voice.flame : voice.caption)
                Text("\(state.streak)")
                    .font(voice.captionFont(12).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(voice.text)
                    .contentTransition(.numericText())
            }
        }
    }

    private func heroNumber(size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text("\(state.todayFocusMinutes)")
                .font(voice.hero(size))
                .italic(voice.heroItalic)
                .monospacedDigit()
                .foregroundStyle(voice.heroColor)
                .shadow(color: (voice.heroGlow ?? .clear).opacity(0.45), radius: voice.heroGlow == nil ? 0 : 9)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(words(minuteUnit))
                .font(voice.captionFont(13))
                .foregroundStyle(voice.caption)
        }
    }

    private var progressRail: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(voice.track)
                Capsule()
                    .fill(voice.accent)
                    .frame(width: max(progress > 0 ? 4 : 0, geo.size.width * progress))
                    .shadow(color: voice.heroGlow == nil ? .clear : voice.accent.opacity(0.6), radius: 4)
            }
        }
        .frame(height: 4)
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Text(words("Lv \(state.level)"))
                .font(voice.captionFont(10.5).weight(.semibold))
                .foregroundStyle(voice.caption)

            Spacer(minLength: 4)

            if goalReached {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 10, weight: .semibold))
                    Text(words(liveStyleLocalized("Hedef tamam", "Goal done")))
                        .font(voice.captionFont(10.5).weight(.semibold))
                }
                .foregroundStyle(voice.accent)
            } else if goal != nil {
                Text(percent(Int((progress * 100).rounded())))
                    .font(voice.captionFont(10.5).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(voice.text.opacity(0.85))
            } else if state.longestStreak > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "crown.fill").font(.system(size: 9, weight: .semibold))
                    Text("\(max(state.streak, state.longestStreak))")
                        .font(voice.captionFont(10.5).weight(.semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(voice.caption)
            }
        }
        .lineLimit(1)
    }

    // MARK: Week (the right block of the medium widget)

    private var weekPanel: some View {
        let values = week
        let total = values.reduce(0, +)
        let peak = max(values.max() ?? 0, 1)
        let letters = weekLetters

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(words(liveStyleLocalized("Bu hafta", "This week")))
                    .font(voice.captionFont(10.5).weight(.semibold))
                    .foregroundStyle(voice.caption)

                Spacer(minLength: 4)

                if let delta = weekDelta, delta != 0 {
                    HStack(spacing: 2) {
                        Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 8, weight: .bold))
                        Text(percent(abs(delta)))
                            .font(voice.captionFont(10.5).weight(.semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(delta > 0 ? voice.accent : voice.caption)
                }
            }

            Text(duration(total))
                .font(voice.captionFont(15).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(voice.text)
                .padding(.top, 2)

            Spacer(minLength: 6)

            HStack(alignment: .bottom, spacing: 5) {
                ForEach(0..<7, id: \.self) { index in
                    let isToday = index == 6
                    VStack(spacing: 4) {
                        GeometryReader { geo in
                            let filled = values[index] == 0 ? 0 : max(3, geo.size.height * CGFloat(values[index]) / CGFloat(peak))
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: voice.barRadius, style: .continuous)
                                    .fill(voice.track.opacity(0.4))
                                RoundedRectangle(cornerRadius: voice.barRadius, style: .continuous)
                                    .fill(voice.accent.opacity(isToday ? 1 : 0.45))
                                    .frame(height: filled)
                            }
                        }

                        Text(letters[index])
                            .font(voice.captionFont(8.5).weight(isToday ? .bold : .medium))
                            .foregroundStyle(isToday ? voice.text : voice.caption)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: Minimal (one number, one line — nothing else)

    private var minimal: some View {
        VStack(spacing: 7) {
            Text(todayLabel.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(2.2)
                .foregroundStyle(LiveStyleTokens.textTertiary)

            heroNumber(size: isSmall ? 44 : 50)

            progressRail
                .frame(width: isSmall ? 104 : 150)

            if let goal {
                Text(goalReached
                     ? liveStyleLocalized("Hedef tamam", "Goal done")
                     : "\(liveStyleLocalized("hedef", "goal")) \(duration(goal))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(goalReached ? LiveStyleTokens.cyan : LiveStyleTokens.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - In-app preview wrapper (background + content + widget-like frame)

struct UpdoWidgetStylePreview: View {
    let style: FocusLiveStyle
    let state: WidgetUserState
    let isSmall: Bool
    /// Defaults to the student's own goal; samples pass one explicitly.
    var dailyGoalMinutes: Int? = WidgetShared.readDailyGoal()

    var body: some View {
        ZStack {
            WidgetStyleBackground(style: style)

            UpdoWidgetStyleContent(style: style, state: state, isSmall: isSmall, dailyGoalMinutes: dailyGoalMinutes)
                .padding(16)
        }
        .frame(width: isSmall ? 158 : 338, height: 158)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    style == .zen ? Color.black.opacity(0.08) : Color.white.opacity(0.09),
                    lineWidth: 1
                )
        )
    }
}
