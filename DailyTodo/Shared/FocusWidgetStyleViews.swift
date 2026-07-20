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

struct UpdoWidgetStyleContent: View {
    let style: FocusLiveStyle
    let state: WidgetUserState
    let isSmall: Bool

    var body: some View {
        switch style {
        case .classic: classic
        case .poster: poster
        case .minimal: minimal
        case .gold: goldCard
        case .neon: neon
        case .terminal: terminal
        case .aura: aura
        case .arena: arena
        case .zen: zen
        }
    }

    // MARK: Shared bits

    private var todayText: String { "\(state.todayFocusMinutes)" }

    private func serifNumber(_ text: String, size: CGFloat, color: Color = LiveStyleTokens.silver) -> some View {
        Text(text)
            .font(.system(size: size, weight: .bold, design: .serif))
            .italic()
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private func week(_ maxBars: Int = 7) -> [Int] {
        state.weekFocusMinutes ?? Array(repeating: 0, count: 7)
    }

    private func weekChart(accent: Color, trackOpacity: Double = 0.05, height: CGFloat = 40) -> some View {
        let values = week()
        let maxValue = max(values.max() ?? 0, 1)

        return HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<7, id: \.self) { idx in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.white.opacity(trackOpacity))
                        .frame(height: height)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(accent.opacity(idx == 6 ? 1 : 0.55))
                        .frame(height: max(values[idx] == 0 ? 0 : 3,
                                           height * CGFloat(values[idx]) / CGFloat(maxValue)))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func statPair(icon: String, text: String, tint: Color,
                          textColor: Color = .white) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(textColor)
        }
    }

    private var dkLabel: String { liveStyleLocalized("dk", "m") }
    private var todayLabel: String { liveStyleLocalized("Bugün", "Today") }

    // MARK: 1. Classic

    private var classic: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text("FOCUS")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(0.9)
                    .foregroundStyle(LiveStyleTokens.textSecondary)

                Spacer(minLength: 4)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    serifNumber(todayText, size: isSmall ? 38 : 42)
                    Text(dkLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(LiveStyleTokens.textTertiary)
                }
                Text(todayLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(LiveStyleTokens.textTertiary)

                Spacer(minLength: 6)

                HStack(spacing: 10) {
                    statPair(icon: "flame.fill", text: "\(state.streak)", tint: LiveStyleTokens.gold)
                    statPair(icon: "chevron.up.circle.fill", text: "Lv \(state.level)",
                             tint: LiveStyleTokens.textSecondary)
                }
            }

            if !isSmall {
                weekChart(accent: LiveStyleTokens.cyan)
                    .frame(width: 128)
            }
        }
    }

    // MARK: 2. Poster

    private var poster: some View {
        HStack(spacing: isSmall ? 8 : 14) {
            ZStack {
                if !isSmall {
                    Text("FOCUS")
                        .font(.system(size: 26, weight: .black))
                        .kerning(1)
                        .foregroundStyle(Color.white.opacity(0.05))
                        .rotationEffect(.degrees(-90))
                        .fixedSize()
                }

                LiveStyleMark(size: isSmall ? 44 : 66, tint: LiveStyleTokens.cyan)
                    .rotationEffect(.degrees(-8))
                    .shadow(color: LiveStyleTokens.cyan.opacity(0.5), radius: 12)
            }
            .frame(width: isSmall ? 46 : 84)

            VStack(alignment: .leading, spacing: 2) {
                Text(todayLabel.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(LiveStyleTokens.cyan)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(todayText)
                        .font(.system(size: isSmall ? 32 : 40, weight: .black))
                        .monospacedDigit()
                        .foregroundStyle(LiveStyleTokens.cyan)
                        .shadow(color: LiveStyleTokens.cyan.opacity(0.45), radius: 10)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(dkLabel)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(LiveStyleTokens.cyan.opacity(0.7))
                }

                HStack(spacing: 8) {
                    statPair(icon: "flame.fill", text: "\(state.streak)", tint: LiveStyleTokens.gold)
                    if !isSmall {
                        statPair(icon: "chevron.up.circle.fill", text: "Lv \(state.level)",
                                 tint: LiveStyleTokens.textSecondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: 3. Minimal

    private var minimal: some View {
        VStack(spacing: 6) {
            Text(todayLabel.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(2.2)
                .foregroundStyle(LiveStyleTokens.textTertiary)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                serifNumber(todayText, size: isSmall ? 42 : 48)
                Text(dkLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(LiveStyleTokens.textTertiary)
            }

            Capsule()
                .fill(Color.white.opacity(0.10))
                .frame(width: 110, height: 3)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(LiveStyleTokens.cyan)
                        .frame(width: 110 * min(max(state.levelProgress ?? 0, 0.03), 1))
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: 4. Gold

    private var goldCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Text("FOCUS")
                        .font(.system(size: 10.5, weight: .semibold))
                        .tracking(0.9)
                        .foregroundStyle(LiveStyleTokens.textSecondary)

                    Text("PRO")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(LiveStyleTokens.gold)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(LiveStyleTokens.gold.opacity(0.16)))
                }

                Spacer(minLength: 4)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    serifNumber(todayText, size: isSmall ? 38 : 42)
                    Text(dkLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(LiveStyleTokens.textTertiary)
                }
                Text(todayLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(LiveStyleTokens.textTertiary)

                Spacer(minLength: 6)

                HStack(spacing: 10) {
                    statPair(icon: "flame.fill", text: "\(state.streak)", tint: LiveStyleTokens.gold)
                    statPair(icon: "crown.fill", text: "\(max(state.streak, state.longestStreak))",
                             tint: LiveStyleTokens.textSecondary)
                    if !isSmall {
                        statPair(icon: "chevron.up.circle.fill", text: "Lv \(state.level)",
                                 tint: LiveStyleTokens.textSecondary)
                    }
                }
            }

            if !isSmall {
                weekChart(accent: LiveStyleTokens.gold)
                    .frame(width: 128)
            }
        }
    }

    // MARK: 5. Neon

    private var neon: some View {
        let neonCyan = Color(red: 0.13, green: 0.83, blue: 0.93)
        let neonPink = Color(red: 1.00, green: 0.18, blue: 0.53)

        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Circle().fill(neonPink).frame(width: 5, height: 5)
                        .shadow(color: neonPink.opacity(0.9), radius: 4)
                    Text("FOCUS")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 4)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(todayText)
                        .font(.system(size: isSmall ? 36 : 42, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(neonCyan)
                        .shadow(color: neonCyan.opacity(0.85), radius: 9)
                        .shadow(color: neonCyan.opacity(0.3), radius: 22)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(dkLabel)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(neonCyan.opacity(0.7))
                }

                Spacer(minLength: 6)

                HStack(spacing: 10) {
                    statPair(icon: "flame.fill", text: "\(state.streak)", tint: neonPink)
                    statPair(icon: "chevron.up.circle.fill", text: "Lv \(state.level)",
                             tint: Color.white.opacity(0.5))
                }
            }

            if !isSmall {
                weekChart(accent: neonPink, trackOpacity: 0.07)
                    .frame(width: 128)
            }
        }
    }

    // MARK: 6. Terminal

    private var terminal: some View {
        let green = Color(red: 0.22, green: 1.0, blue: 0.44)

        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 0) {
                Text("updo@stats:~$ ")
                    .foregroundStyle(green.opacity(0.55))
                Text(todayLabel.lowercased())
                    .foregroundStyle(green)
            }
            .font(.system(size: isSmall ? 10 : 11, weight: .semibold, design: .monospaced))
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(todayText)
                    .font(.system(size: isSmall ? 34 : 40, weight: .bold, design: .monospaced))
                    .foregroundStyle(green)
                    .shadow(color: green.opacity(0.45), radius: 7)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(dkLabel)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(green.opacity(0.6))
            }

            if !isSmall {
                weekChart(accent: green, trackOpacity: 0.06, height: 26)
            }

            Text("[str \(state.streak) | lv \(state.level)]")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(green.opacity(0.5))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: 7. Aura

    private var aura: some View {
        VStack(spacing: 5) {
            Text(todayLabel)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                serifNumber(todayText, size: isSmall ? 40 : 46)
                Text(dkLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }

            HStack(spacing: 10) {
                statPair(icon: "flame.fill", text: "\(state.streak)", tint: LiveStyleTokens.gold,
                         textColor: .white.opacity(0.85))
                statPair(icon: "chevron.up.circle.fill", text: "Lv \(state.level)",
                         tint: .white.opacity(0.5), textColor: .white.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: 8. Arena

    private var arena: some View {
        let raceRed = Color(red: 0.88, green: 0.02, blue: 0.0)

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("FOCUS")
                    .font(.system(size: 11, weight: .black))
                    .italic()
                    .foregroundStyle(.white)

                Spacer(minLength: 4)

                Text(todayLabel.uppercased())
                    .font(.system(size: 8, weight: .black))
                    .italic()
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 3).fill(raceRed))
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(todayText)
                    .font(.system(size: isSmall ? 38 : 44, weight: .black))
                    .italic()
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(dkLabel.uppercased())
                    .font(.system(size: 13, weight: .black))
                    .italic()
                    .foregroundStyle(raceRed)
            }

            Spacer(minLength: 2)

            if isSmall {
                Text("STREAK \(state.streak) · LV \(state.level)")
                    .font(.system(size: 9, weight: .heavy))
                    .italic()
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                HStack(spacing: 10) {
                    Text("STREAK \(state.streak) · LV \(state.level)")
                        .font(.system(size: 10, weight: .heavy))
                        .italic()
                        .foregroundStyle(.white.opacity(0.5))

                    weekChart(accent: raceRed, trackOpacity: 0.07, height: 22)
                        .frame(width: 110)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.leading, 5)
    }

    // MARK: 9. Zen

    private var zen: some View {
        let ink = Color(red: 0.11, green: 0.10, blue: 0.09)
        let sage = Color(red: 0.54, green: 0.60, blue: 0.48)

        return VStack(spacing: 6) {
            HStack(spacing: 5) {
                Circle().fill(sage).frame(width: 5, height: 5)
                Text(todayLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ink.opacity(0.75))
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                serifNumber(todayText, size: isSmall ? 40 : 46, color: ink)
                Text(dkLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ink.opacity(0.45))
            }

            HStack(spacing: 10) {
                statPair(icon: "flame.fill", text: "\(state.streak)", tint: sage,
                         textColor: ink.opacity(0.8))
                statPair(icon: "chevron.up.circle.fill", text: "Lv \(state.level)",
                         tint: ink.opacity(0.4), textColor: ink.opacity(0.8))
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

    var body: some View {
        ZStack {
            WidgetStyleBackground(style: style)

            UpdoWidgetStyleContent(style: style, state: state, isSmall: isSmall)
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
