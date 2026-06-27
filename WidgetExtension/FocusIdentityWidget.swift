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

    var body: some View {
        Group {
            if isSmall { smallCard } else { mediumCard }
        }
        .padding(isSmall ? 15 : 17)
        .widgetUpdoBackground(accent: theme.accent)
    }

    // MARK: Small

    private var smallCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(title: "ODAK")

            Spacer(minLength: 6)

            heroLevel(size: 44)

            Spacer(minLength: 6)

            HStack(spacing: 0) {
                miniStat(icon: "flame.fill", value: "\(state.streak)", label: "SERİ", tint: gold)
                Spacer(minLength: 8)
                miniStat(icon: "scope", value: "\(state.todayFocusMinutes)dk", label: "BUGÜN", tint: theme.accent)
            }
        }
        .background(alignment: .topTrailing) {
            UpdoWidgetLogo(size: 78, tint: AnyShapeStyle(theme.accent.opacity(0.07)))
                .offset(x: 18, y: -8)
        }
    }

    // MARK: Medium

    private var mediumCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                header(title: "ODAK KİMLİĞİ")

                Spacer(minLength: 8)

                HStack(alignment: .firstTextBaseline, spacing: 20) {
                    bigStat(value: "\(state.level)", label: "SEVİYE", color: .white)
                    bigStat(value: "\(state.streak)", label: "GÜN SERİ", color: gold)
                }

                Spacer(minLength: 10)

                HStack(spacing: 0) {
                    miniStat(icon: "scope", value: "\(state.todayFocusMinutes)dk", label: "BUGÜN", tint: theme.accent)
                    Spacer(minLength: 8)
                    miniStat(icon: "crown.fill", value: "\(max(state.streak, state.longestStreak))g", label: "EN UZUN", tint: .white.opacity(0.75))
                    Spacer(minLength: 0)
                }
            }

            // Crosshair artwork bleeding off the right (like the card's hero art).
            UpdoWidgetLogo(size: 116, tint: theme.mark)
                .opacity(0.92)
                .shadow(color: theme.glow.opacity(0.4), radius: 10)
                .frame(width: 96)
                .offset(x: 14)
        }
    }

    // MARK: Pieces

    private func header(title: String) -> some View {
        HStack(spacing: 7) {
            Rectangle()
                .fill(theme.accent)
                .frame(width: 13, height: 2.5)
                .clipShape(Capsule())

            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(theme.accent)

            if state.isPro {
                Text("PRO")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(gold))
            }

            Spacer(minLength: 4)

            if isSmall {
                UpdoWidgetLogo(size: 19)
            }
        }
    }

    private func heroLevel(size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: -2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("LV")
                    .font(.system(size: size * 0.36, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                Text("\(state.level)")
                    .font(.system(size: size, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text("SEVİYE")
                .font(.system(size: 9, weight: .black, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func bigStat(value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: -1) {
            Text(value)
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private func miniStat(icon: String, value: String, label: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: -1) {
                Text(value)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.38))
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
