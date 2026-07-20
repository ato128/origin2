//
//  FocusLiveStyleViews.swift
//  DailyTodo
//
//  The single source of truth for every Focus Live Activity lock-screen style.
//  Compiled into BOTH targets: the widget extension renders the real activity
//  with these views, and the in-app style picker renders the exact same views
//  as live previews (the timer even ticks). Deliberately self-contained — no
//  widget-only theme files — so it can live in two targets.
//
//  RULE (verified on device): a live `Text(timerInterval:)` FREEZES under
//  gradient foregroundStyle / kerning / minimumScaleFactor / contentTransition.
//  Every style therefore renders its running timer in a SOLID color.
//

import SwiftUI

// MARK: - Tokens (local copies — this file must not depend on widget-only files)

enum LiveStyleTokens {
    static let surfaceTop = Color(red: 0.058, green: 0.069, blue: 0.114)
    static let surfaceBottom = Color(red: 0.027, green: 0.033, blue: 0.060)
    static let hairline = Color.white.opacity(0.09)

    static let silver = Color(white: 0.92)
    static let cyan = Color(red: 0.18, green: 0.83, blue: 1.00)     // #2DD4FF
    static let purple = Color(red: 0.49, green: 0.23, blue: 0.93)   // #7C3AED
    static let green = Color(red: 0.20, green: 0.83, blue: 0.29)
    static let gold = Color(red: 0.984, green: 0.749, blue: 0.141)  // #FBBF24

    static let textSecondary = Color.white.opacity(0.60)
    static let textTertiary = Color.white.opacity(0.38)
}

/// All selectable styles, in picker order. Raw value is what lands in the
/// App Group ("focus_live_style_v1").
enum FocusLiveStyle: String, CaseIterable {
    case classic, poster, minimal, gold, neon, terminal, aura, arena, zen

    var displayName: String {
        switch self {
        case .classic: return liveStyleLocalized("Klasik", "Classic")
        case .poster: return "Poster"
        case .minimal: return "Minimal"
        case .gold: return "Gold"
        case .neon: return "Neon"
        case .terminal: return "Terminal"
        case .aura: return "Aura"
        case .arena: return "Arena"
        case .zen: return "Zen"
        }
    }

    var isProOnly: Bool { self != .classic }
}

// MARK: - Shared helpers

/// App-group language pick (same behavior as the widget's widgetLocalized —
/// duplicated here because that helper is widget-target-only).
func liveStyleLocalized(_ trText: String, _ enText: String) -> String {
    let lang = UserDefaults(suiteName: "group.com.atakan.updo")?.string(forKey: "appLanguage") ?? "system"
    switch lang {
    case "turkish": return trText
    case "english": return enText
    default:
        return (Locale.preferredLanguages.first ?? "en").hasPrefix("tr") ? trText : enText
    }
}

func liveStyleFinished(_ state: FocusAttributes.ContentState) -> Bool {
    if state.isCompleted { return true }
    if state.isPaused { return false }
    return Date() >= state.endDate
}

func liveStyleProgress(_ state: FocusAttributes.ContentState) -> CGFloat {
    if liveStyleFinished(state) { return 1 }
    if state.isPaused { return CGFloat(max(0, min(1, state.pausedProgress ?? 0))) }
    let now = Date()
    if now >= state.endDate { return 1 }
    let total = state.endDate.timeIntervalSince(state.startDate)
    guard total > 0 else { return 0 }
    return CGFloat(min(1, max(0, now.timeIntervalSince(state.startDate) / total)))
}

func liveStyleRunningRange(_ state: FocusAttributes.ContentState) -> ClosedRange<Date>? {
    if liveStyleFinished(state) || state.isPaused { return nil }
    guard state.endDate > state.startDate, Date() < state.endDate else { return nil }
    return state.startDate...state.endDate
}

/// Mode/status accent: finished → green, paused/rest → orange, else the theme
/// accent (crew keeps its purple identity).
func liveStyleAccent(_ state: FocusAttributes.ContentState, themeAccent: Color) -> Color {
    if liveStyleFinished(state) { return LiveStyleTokens.green }
    if state.isPaused || state.isResting { return .orange }
    switch state.modeRaw {
    case "workout": return LiveStyleTokens.green
    case "crew": return LiveStyleTokens.purple
    default: return themeAccent
    }
}

func liveStyleModeLabel(_ state: FocusAttributes.ContentState) -> String {
    if liveStyleFinished(state) { return "DONE" }
    if state.isPaused { return "PAUSED" }
    if state.isResting { return "REST" }
    switch state.modeRaw {
    case "workout": return "WORKOUT"
    case "crew": return "CREW"
    default: return "FOCUS"
    }
}

@ViewBuilder
func liveStyleTimerText(_ state: FocusAttributes.ContentState) -> some View {
    if liveStyleFinished(state) {
        Text(liveStyleLocalized("Tamamlandı", "Completed"))
    } else if state.isPaused {
        let seconds = max(0, state.pausedRemainingSeconds ?? 0)
        Text(String(format: "%02d:%02d", seconds / 60, seconds % 60))
    } else {
        Text(timerInterval: Date()...state.endDate, countsDown: true)
    }
}

/// Live-safe progress bar (local twin of the widget's UpdoLiveProgressBar).
struct LiveStyleProgressBar: View {
    var running: ClosedRange<Date>? = nil
    var staticProgress: CGFloat = 0
    let accent: Color
    var height: CGFloat = 6

    var body: some View {
        if let running, running.upperBound > running.lowerBound {
            ProgressView(timerInterval: running, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(accent)
            .frame(height: height)
        } else {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(accent)
                        .frame(width: max(6, proxy.size.width * max(0, min(1, staticProgress))))
                }
            }
            .frame(height: height)
        }
    }
}

/// The Updo crosshair mark, redrawn locally (the widget logo file is
/// widget-target-only). Circle + four ticks + north arrow.
struct LiveStyleMark: View {
    var size: CGFloat
    var tint: Color

    var body: some View {
        let lw = size * 0.052
        let r = size * 0.285

        ZStack {
            Circle()
                .stroke(style: StrokeStyle(lineWidth: lw, lineCap: .round))
                .fill(tint)
                .frame(width: r * 2, height: r * 2)

            ForEach(0..<4, id: \.self) { i in
                Capsule().fill(tint).frame(width: lw, height: size * 0.20)
                    .offset(y: -r)
                    .rotationEffect(.degrees(Double(i) * 90))
            }

            LiveStyleArrow()
                .fill(tint)
                .frame(width: size * 0.215, height: size * 0.235)
        }
        .frame(width: size, height: size)
    }
}

private struct LiveStyleArrow: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 0.50 * w, y: rect.minY + 0.02 * h))
        p.addLine(to: CGPoint(x: rect.minX + 0.97 * w, y: rect.minY + 0.97 * h))
        p.addLine(to: CGPoint(x: rect.minX + 0.50 * w, y: rect.minY + 0.66 * h))
        p.addLine(to: CGPoint(x: rect.minX + 0.03 * w, y: rect.minY + 0.97 * h))
        p.closeSubpath()
        return p
    }
}

/// Serif-italic focus identity for LIVE timers — solid color only (see rule).
private struct LiveTimerStyle: ViewModifier {
    var size: CGFloat
    var color: Color = LiveStyleTokens.silver

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .bold, design: .serif))
            .italic()
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

private extension View {
    func liveTimer(size: CGFloat, color: Color = LiveStyleTokens.silver) -> some View {
        modifier(LiveTimerStyle(size: size, color: color))
    }
}

private struct LiveIconBubble: View {
    let state: FocusAttributes.ContentState
    let accent: Color
    let size: CGFloat

    private var iconName: String {
        if liveStyleFinished(state) { return "checkmark.seal.fill" }
        if state.isPaused { return "pause.fill" }
        if state.isResting { return "figure.cooldown" }
        switch state.modeRaw {
        case "workout": return "dumbbell.fill"
        case "crew": return "person.2.fill"
        default: return "scope"
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(accent.opacity(0.16))
            Image(systemName: iconName)
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(accent)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - The style card (single entry point for widget + in-app preview)

struct FocusLiveStyleCard: View {
    let style: FocusLiveStyle
    let state: FocusAttributes.ContentState
    let userState: WidgetUserState
    let totalMinutes: Int
    /// Personal-mode accent (the widget passes the app-icon theme color).
    var themeAccent: Color = LiveStyleTokens.cyan

    var body: some View {
        switch style {
        case .classic: ClassicStyleView(state: state, totalMinutes: totalMinutes, themeAccent: themeAccent)
        case .poster: PosterStyleView(state: state, themeAccent: themeAccent)
        case .minimal: MinimalStyleView(state: state, themeAccent: themeAccent)
        case .gold: GoldStyleView(state: state, userState: userState, totalMinutes: totalMinutes, themeAccent: themeAccent)
        case .neon: NeonStyleView(state: state)
        case .terminal: TerminalStyleView(state: state, totalMinutes: totalMinutes)
        case .aura: AuraStyleView(state: state)
        case .arena: ArenaStyleView(state: state, totalMinutes: totalMinutes)
        case .zen: ZenStyleView(state: state)
        }
    }
}

// MARK: - Shared card chrome

private struct LiveCardChrome: ViewModifier {
    var border: Color = LiveStyleTokens.hairline

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
    }
}

private extension View {
    func liveCardChrome(border: Color = LiveStyleTokens.hairline) -> some View {
        modifier(LiveCardChrome(border: border))
    }
}

// MARK: - 1. Classic (free)

private struct ClassicStyleView: View {
    let state: FocusAttributes.ContentState
    let totalMinutes: Int
    let themeAccent: Color

    var body: some View {
        let accent = liveStyleAccent(state, themeAccent: themeAccent)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 11) {
                LiveIconBubble(state: state, accent: accent, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(state.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(LiveStyleTokens.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 6)

                Text(liveStyleModeLabel(state))
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(accent.opacity(0.14)))
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                liveStyleTimerText(state)
                    .liveTimer(size: state.isCompleted ? 26 : 40)

                if !liveStyleFinished(state) && !state.isPaused {
                    Text("/ \(totalMinutes) \(liveStyleLocalized("dk", "min"))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(LiveStyleTokens.textTertiary)
                }

                Spacer(minLength: 6)

                Text("\(Int(liveStyleProgress(state) * 100))%")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(accent)
            }

            LiveStyleProgressBar(
                running: liveStyleRunningRange(state),
                staticProgress: liveStyleProgress(state),
                accent: accent,
                height: 6
            )
        }
        .padding(16)
        .background(
            ZStack {
                LinearGradient(colors: [LiveStyleTokens.surfaceTop, LiveStyleTokens.surfaceBottom],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [accent.opacity(state.isCompleted ? 0.16 : 0.10), .clear],
                               center: .bottomTrailing, startRadius: 8, endRadius: 240)
            }
        )
        .liveCardChrome()
    }
}

// MARK: - 2. Poster (F1 energy)

private struct PosterStyleView: View {
    let state: FocusAttributes.ContentState
    let themeAccent: Color

    var body: some View {
        let accent = liveStyleAccent(state, themeAccent: themeAccent)

        HStack(spacing: 14) {
            ZStack {
                Text("FOCUS")
                    .font(.system(size: 34, weight: .black))
                    .kerning(1)
                    .foregroundStyle(Color.white.opacity(0.05))
                    .rotationEffect(.degrees(-90))
                    .fixedSize()

                LiveStyleMark(size: 74, tint: accent)
                    .rotationEffect(.degrees(-8))
                    .shadow(color: accent.opacity(0.5), radius: 16)
            }
            .frame(width: 96)
            .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 3) {
                Text(state.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(state.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LiveStyleTokens.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 6)

                Text(posterStatusLabel)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(accent)

                liveStyleTimerText(state)
                    .font(.system(size: state.isCompleted ? 24 : 42, weight: .black))
                    .monospacedDigit()
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .shadow(color: accent.opacity(0.45), radius: 12)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .background(
            ZStack {
                Color(red: 0.016, green: 0.02, blue: 0.04)
                LinearGradient(colors: [accent.opacity(0.42), accent.opacity(0.10), .clear],
                               startPoint: .bottom, endPoint: .top)
                    .frame(height: 90)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        )
        .liveCardChrome(border: accent.opacity(0.22))
    }

    private var posterStatusLabel: String {
        if liveStyleFinished(state) { return liveStyleLocalized("BİTTİ", "DONE") }
        if state.isPaused { return liveStyleLocalized("DURAKLATILDI", "PAUSED") }
        if state.isResting { return liveStyleLocalized("MOLA", "BREAK") }
        return liveStyleLocalized("KALAN", "REMAINING")
    }
}

// MARK: - 3. Minimal

private struct MinimalStyleView: View {
    let state: FocusAttributes.ContentState
    let themeAccent: Color

    var body: some View {
        let accent = liveStyleAccent(state, themeAccent: themeAccent)

        VStack(spacing: 10) {
            Text(minimalLabel)
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.2)
                .foregroundStyle(LiveStyleTokens.textTertiary)

            liveStyleTimerText(state)
                .liveTimer(size: state.isCompleted ? 24 : 46)
                .frame(maxWidth: .infinity)

            LiveStyleProgressBar(
                running: liveStyleRunningRange(state),
                staticProgress: liveStyleProgress(state),
                accent: accent,
                height: 3
            )
            .frame(maxWidth: 160)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [LiveStyleTokens.surfaceTop, LiveStyleTokens.surfaceBottom],
                           startPoint: .top, endPoint: .bottom)
        )
        .liveCardChrome()
    }

    private var minimalLabel: String {
        if liveStyleFinished(state) { return liveStyleLocalized("TAMAMLANDI", "COMPLETED") }
        if state.isPaused { return liveStyleLocalized("DURAKLATILDI", "PAUSED") }
        if state.isResting { return liveStyleLocalized("MOLA", "BREAK") }
        return state.modeRaw == "crew" ? "CREW" : "FOCUS"
    }
}

// MARK: - 4. Gold (the Pro classic)

private struct GoldStyleView: View {
    let state: FocusAttributes.ContentState
    let userState: WidgetUserState
    let totalMinutes: Int
    let themeAccent: Color

    private let gold = LiveStyleTokens.gold

    var body: some View {
        let accent = liveStyleAccent(state, themeAccent: themeAccent)

        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 11) {
                LiveIconBubble(state: state, accent: accent, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(state.subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(LiveStyleTokens.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("PRO")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(gold)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(
                            Capsule()
                                .fill(gold.opacity(0.14))
                                .overlay(Capsule().strokeBorder(gold.opacity(0.35), lineWidth: 0.5))
                        )

                    Text(liveStyleModeLabel(state))
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(accent.opacity(0.14)))
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                liveStyleTimerText(state)
                    .liveTimer(size: state.isCompleted ? 26 : 40)

                if !liveStyleFinished(state) && !state.isPaused {
                    Text("/ \(totalMinutes) \(liveStyleLocalized("dk", "min"))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(LiveStyleTokens.textTertiary)
                }

                Spacer(minLength: 6)

                Text("\(Int(liveStyleProgress(state) * 100))%")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(gold)
            }

            LiveStyleProgressBar(
                running: liveStyleRunningRange(state),
                staticProgress: liveStyleProgress(state),
                accent: gold,
                height: 6
            )

            HStack(spacing: 16) {
                if userState.streak > 0 {
                    stripItem(icon: "flame.fill", tint: gold,
                              text: liveStyleLocalized("\(userState.streak) gün", "\(userState.streak) days"))
                }

                stripItem(icon: "scope", tint: LiveStyleTokens.cyan,
                          text: liveStyleLocalized("Bugün \(userState.todayFocusMinutes)dk",
                                                   "Today \(userState.todayFocusMinutes)m"))

                HStack(spacing: 5) {
                    levelRing
                    Text("Lv \(userState.level)")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(LiveStyleTokens.textSecondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.top, 1)
        }
        .padding(16)
        .background(
            ZStack {
                LinearGradient(colors: [LiveStyleTokens.surfaceTop, LiveStyleTokens.surfaceBottom],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [gold.opacity(0.12), .clear],
                               center: .topTrailing, startRadius: 8, endRadius: 220)
                RadialGradient(colors: [accent.opacity(state.isCompleted ? 0.16 : 0.10), .clear],
                               center: .bottomLeading, startRadius: 8, endRadius: 240)
            }
        )
        .liveCardChrome(border: gold.opacity(0.26))
    }

    private func stripItem(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(LiveStyleTokens.textSecondary)
        }
    }

    private var levelRing: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.12), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: min(max(userState.levelProgress ?? 0, 0.04), 1))
                .stroke(gold, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 15, height: 15)
    }
}

// MARK: - 5. Neon

private struct NeonStyleView: View {
    let state: FocusAttributes.ContentState

    private let neonCyan = Color(red: 0.13, green: 0.83, blue: 0.93)   // #22D3EE
    private let neonPink = Color(red: 1.00, green: 0.18, blue: 0.53)   // #FF2E88

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(neonPink)
                    .frame(width: 6, height: 6)
                    .shadow(color: neonPink.opacity(0.9), radius: 5)

                Text(state.title.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 6)

                Text(liveStyleModeLabel(state))
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(neonPink)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .overlay(Capsule().strokeBorder(neonPink.opacity(0.6), lineWidth: 1))
                    .shadow(color: neonPink.opacity(0.5), radius: 6)
            }

            liveStyleTimerText(state)
                .font(.system(size: state.isCompleted ? 24 : 44, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(neonCyan)
                .lineLimit(1)
                .shadow(color: neonCyan.opacity(0.85), radius: 10)
                .shadow(color: neonCyan.opacity(0.35), radius: 26)
                .frame(maxWidth: .infinity)

            LiveStyleProgressBar(
                running: liveStyleRunningRange(state),
                staticProgress: liveStyleProgress(state),
                accent: neonPink,
                height: 4
            )
            .shadow(color: neonPink.opacity(0.6), radius: 6)
        }
        .padding(16)
        .background(Color(red: 0.015, green: 0.015, blue: 0.03))
        .liveCardChrome(border: neonCyan.opacity(0.35))
    }
}

// MARK: - 6. Terminal

private struct TerminalStyleView: View {
    let state: FocusAttributes.ContentState
    let totalMinutes: Int

    private let green = Color(red: 0.22, green: 1.0, blue: 0.44)   // #38FF70

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                Text("updo@focus:~$ ")
                    .foregroundStyle(green.opacity(0.55))
                Text(state.title.lowercased().replacingOccurrences(of: " ", with: "-"))
                    .foregroundStyle(green)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer(minLength: 4)
            }
            .font(.system(size: 12, weight: .semibold, design: .monospaced))

            liveStyleTimerText(state)
                .font(.system(size: state.isCompleted ? 22 : 40, weight: .bold, design: .monospaced))
                .foregroundStyle(green)
                .lineLimit(1)
                .shadow(color: green.opacity(0.45), radius: 8)

            HStack(spacing: 8) {
                LiveStyleProgressBar(
                    running: liveStyleRunningRange(state),
                    staticProgress: liveStyleProgress(state),
                    accent: green,
                    height: 4
                )

                Text("[\(Int(liveStyleProgress(state) * 100))%]")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(green.opacity(0.75))
            }

            Text("» \(totalMinutes)\(liveStyleLocalized("dk oturum", "min session")) · \(terminalStatus)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(green.opacity(0.45))
                .lineLimit(1)
        }
        .padding(16)
        .background(Color(red: 0.01, green: 0.035, blue: 0.015))
        .liveCardChrome(border: green.opacity(0.25))
    }

    private var terminalStatus: String {
        if liveStyleFinished(state) { return "exit 0" }
        if state.isPaused { return "suspended" }
        if state.isResting { return "sleep" }
        return "running"
    }
}

// MARK: - 7. Aura

private struct AuraStyleView: View {
    let state: FocusAttributes.ContentState

    var body: some View {
        VStack(spacing: 8) {
            Text(state.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            liveStyleTimerText(state)
                .liveTimer(size: state.isCompleted ? 24 : 44)

            LiveStyleProgressBar(
                running: liveStyleRunningRange(state),
                staticProgress: liveStyleProgress(state),
                accent: Color.white.opacity(0.85),
                height: 3
            )
            .frame(maxWidth: 140)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            ZStack {
                Color(red: 0.03, green: 0.025, blue: 0.07)
                RadialGradient(colors: [LiveStyleTokens.purple.opacity(0.55), .clear],
                               center: .topLeading, startRadius: 10, endRadius: 200)
                RadialGradient(colors: [LiveStyleTokens.cyan.opacity(0.40), .clear],
                               center: .bottomTrailing, startRadius: 10, endRadius: 210)
            }
        )
        .liveCardChrome(border: Color.white.opacity(0.14))
    }
}

// MARK: - 8. Arena (scoreboard)

private struct ArenaStyleView: View {
    let state: FocusAttributes.ContentState
    let totalMinutes: Int

    private let raceRed = Color(red: 0.88, green: 0.02, blue: 0.0)   // #E10600

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(raceRed)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(state.title.uppercased())
                        .font(.system(size: 13, weight: .black))
                        .italic()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer(minLength: 6)

                    Text(liveStyleModeLabel(state))
                        .font(.system(size: 9, weight: .black))
                        .italic()
                        .foregroundStyle(.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 4).fill(raceRed))
                }

                liveStyleTimerText(state)
                    .font(.system(size: state.isCompleted ? 24 : 46, weight: .black))
                    .italic()
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Text("\(liveStyleLocalized("SEANS", "SESSION")) \(totalMinutes)\(liveStyleLocalized("DK", "MIN"))")
                        .font(.system(size: 10, weight: .heavy))
                        .italic()
                        .foregroundStyle(.white.opacity(0.5))

                    Spacer(minLength: 6)

                    Text("\(Int(liveStyleProgress(state) * 100))%")
                        .font(.system(size: 12, weight: .black))
                        .italic()
                        .monospacedDigit()
                        .foregroundStyle(raceRed)
                }

                LiveStyleProgressBar(
                    running: liveStyleRunningRange(state),
                    staticProgress: liveStyleProgress(state),
                    accent: raceRed,
                    height: 4
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.05))
        .liveCardChrome(border: Color.white.opacity(0.10))
    }
}

// MARK: - 9. Zen (the light one)

private struct ZenStyleView: View {
    let state: FocusAttributes.ContentState

    private let paper = Color(red: 0.96, green: 0.95, blue: 0.92)
    private let ink = Color(red: 0.11, green: 0.10, blue: 0.09)
    private let sage = Color(red: 0.54, green: 0.60, blue: 0.48)

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 6) {
                Circle().fill(sage).frame(width: 6, height: 6)
                Text(state.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ink.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            liveStyleTimerText(state)
                .liveTimer(size: state.isCompleted ? 24 : 42, color: ink)

            LiveStyleProgressBar(
                running: liveStyleRunningRange(state),
                staticProgress: liveStyleProgress(state),
                accent: sage,
                height: 3
            )
            .frame(maxWidth: 150)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 17)
        .background(paper)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ink.opacity(0.08), lineWidth: 1)
        )
    }
}
