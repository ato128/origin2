//
//  UpdoStyledWidget.swift
//  WidgetExtensionExtension
//
//  The "Focus Card" — one widget, nine skins. The user picks a style in
//  Settings (same identities as the Live Activity styles) and this widget
//  renders today's focus / streak / level in that design. Classic is free;
//  Pro styles fall back to classic when the subscription lapses.
//

import WidgetKit
import SwiftUI

struct UpdoStyledWidgetView: View {
    let state: WidgetUserState
    @Environment(\.widgetFamily) private var family

    private var isSmall: Bool { family == .systemSmall }

    private var style: FocusLiveStyle {
        let chosen = FocusLiveStyle(rawValue: WidgetShared.readWidgetStyle())
        guard state.isPro else { return .classic }
        return chosen ?? .classic
    }

    var body: some View {
        UpdoWidgetStyleContent(style: style, state: state, isSmall: isSmall)
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .adaptiveContainerBackground {
                WidgetStyleBackground(style: style)
            }
    }
}

private extension View {
    @ViewBuilder
    func adaptiveContainerBackground<BG: View>(@ViewBuilder _ bg: @escaping () -> BG) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) { bg() }
        } else {
            self.background(bg())
        }
    }
}

// MARK: - Focus + Schedule (the same card, with today's programme on the right)

struct FocusDayEntry: TimelineEntry {
    let date: Date
    let state: WidgetUserState
    let events: [WidgetEvent]
}

/// One entry per moment the programme changes — a lesson starting or ending,
/// and midnight — so the list moves through the day without the app.
struct FocusDayProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusDayEntry {
        var state = WidgetUserState(
            iconName: nil, isPro: true, streak: 12, level: 7,
            todayFocusMinutes: 45, statsShared: true, longestStreak: 21
        )
        state.levelProgress = 0.62
        return FocusDayEntry(date: Date(), state: state, events: [
            WidgetEvent(id: "1", title: "Physics II", weekday: 0, startMinute: 9 * 60, durationMinute: 60, location: "Lab", colorHex: "#2DD4FF"),
            WidgetEvent(id: "2", title: "Calculus II", weekday: 0, startMinute: 11 * 60, durationMinute: 90, location: "B-202", colorHex: "#7C3AED"),
            WidgetEvent(id: "3", title: "Software", weekday: 0, startMinute: 14 * 60, durationMinute: 60, location: "A-101", colorHex: "#1593FF")
        ])
    }

    private func entry(at date: Date, payload: WidgetPayload?, state: WidgetUserState) -> FocusDayEntry {
        var state = state
        // Yesterday's minutes are not today's.
        if state.statusDayKey != WidgetUserState.dayKey(date) { state.todayFocusMinutes = 0 }
        return FocusDayEntry(date: date, state: state, events: payload?.events(on: date) ?? [])
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusDayEntry) -> Void) {
        completion(entry(at: Date(), payload: WidgetShared.readPayload(), state: WidgetShared.readUserState()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusDayEntry>) -> Void) {
        let now = Date()
        let calendar = Calendar.current
        let payload = WidgetShared.readPayload()
        let state = WidgetShared.readUserState()
        let startOfDay = calendar.startOfDay(for: now)
        let midnight = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now.addingTimeInterval(86_400)

        var moments: Set<Date> = [now, midnight]
        for event in payload?.events(on: now) ?? [] {
            for minute in [event.startMinute, event.startMinute + event.durationMinute] {
                let moment = startOfDay.addingTimeInterval(TimeInterval(minute * 60))
                if moment > now && moment < midnight { moments.insert(moment) }
            }
        }

        let entries = moments.sorted().map { entry(at: $0, payload: payload, state: state) }
        completion(Timeline(entries: entries, policy: .after(midnight.addingTimeInterval(60))))
    }
}

struct UpdoFocusDayWidgetView: View {
    let entry: FocusDayEntry

    private var style: FocusLiveStyle {
        let chosen = FocusLiveStyle(rawValue: WidgetShared.readWidgetStyle())
        guard entry.state.isPro else { return .classic }
        return chosen ?? .classic
    }

    var body: some View {
        UpdoWidgetStyleContent(style: style, state: entry.state, isSmall: false, schedule: entry.events, now: entry.date)
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .adaptiveContainerBackground {
                WidgetStyleBackground(style: style)
            }
    }
}

struct UpdoFocusDayWidget: Widget {
    let kind: String = "UpdoFocusDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusDayProvider()) { entry in
            UpdoFocusDayWidgetView(entry: entry)
                .widgetURL(URL(string: "dailytodo://week"))
        }
        .configurationDisplayName(widgetLocalized("Focus + Program", "Focus + Schedule"))
        .description(widgetLocalized(
            "Bugünkü odağın ve günün programı yan yana — haftandaki her değişiklikle güncellenir.",
            "Today's focus beside today's schedule — updated with every change to your week."
        ))
        .supportedFamilies([.systemMedium])
    }
}

struct UpdoStyledWidget: Widget {
    let kind: String = "UpdoStyledWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProStateProvider()) { entry in
            UpdoStyledWidgetView(state: entry.state)
                .widgetURL(URL(string: "dailytodo://focus"))
        }
        .configurationDisplayName(widgetLocalized("Focus Kartı", "Focus Card"))
        .description(widgetLocalized(
            "Bugünkü odağın — ayarlardan seçtiğin stilde.",
            "Today's focus — in the style you pick in Settings."
        ))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
