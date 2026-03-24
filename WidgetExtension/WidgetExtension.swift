//
//  WidgetExtension.swift
//  WidgetExtension
//
//  Created by Atakan Ortaç on 3.03.2026.
//

import WidgetKit
import SwiftUI

// MARK: - Entry

struct ScheduleEntry: TimelineEntry {
    let date: Date
    let payload: WidgetPayload?
}

// MARK: - Provider

struct ScheduleProvider: TimelineProvider {

    func placeholder(in context: Context) -> ScheduleEntry {
        ScheduleEntry(
            date: Date(),
            payload: WidgetPayload(
                weekday: 0,
                events: [
                    WidgetEvent(
                        id: "1",
                        title: "Math",
                        weekday: 0,
                        startMinute: 9 * 60,
                        durationMinute: 60,
                        location: "A-101",
                        colorHex: "#3B82F6"
                    ),
                    WidgetEvent(
                        id: "2",
                        title: "Physics",
                        weekday: 0,
                        startMinute: 11 * 60,
                        durationMinute: 90,
                        location: "Lab",
                        colorHex: "#EF4444"
                    ),
                    WidgetEvent(
                        id: "3",
                        title: "Chem",
                        weekday: 0,
                        startMinute: 14 * 60,
                        durationMinute: 60,
                        location: "B-202",
                        colorHex: "#22C55E"
                    )
                ]
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
        let payload = WidgetShared.readPayload()
        completion(ScheduleEntry(date: Date(), payload: payload))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
        let payload = WidgetShared.readPayload()
        let now = Date()

        let entry = ScheduleEntry(date: now, payload: payload)

        let cal = Calendar.current
        let nextMinute = cal.date(bySetting: .second, value: 0, of: now)?
            .addingTimeInterval(60) ?? now.addingTimeInterval(60)

        completion(
            Timeline(
                entries: [entry],
                policy: .after(nextMinute)
            )
        )
    }
}

// MARK: - Main Widget View

struct ScheduleWidgetView: View {
    let entry: ScheduleProvider.Entry
    @Environment(\.widgetFamily) private var family

    private let dayTitles = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]

    private var isSmall: Bool { family == .systemSmall }

    private var todayWeekday: Int {
        widgetWeekdayToday()
    }

    private var todayEvents: [WidgetEvent] {
        (entry.payload?.events ?? [])
            .filter { $0.weekday == todayWeekday }
            .sorted { $0.startMinute < $1.startMinute }
    }

    private var nowMinute: Int {
        currentMinuteOfDay()
    }

    private var liveEvent: WidgetEvent? {
        todayEvents.first(where: { ev in
            let start = ev.startMinute
            let end = ev.startMinute + ev.durationMinute
            return nowMinute >= start && nowMinute < end
        })
    }

    private var nextEvent: WidgetEvent? {
        todayEvents.first(where: { $0.startMinute > nowMinute })
    }

    private var accentColor: Color {
        if let liveEvent {
            return softTint(from: hexColor(liveEvent.colorHex))
        }
        if let nextEvent {
            return softTint(from: hexColor(nextEvent.colorHex))
        }
        return Color.blue.opacity(0.95)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isSmall ? 10 : 12) {
            headerRow

            if let liveEvent {
                liveSection(for: liveEvent)
            } else if let nextEvent {
                nextSection(for: nextEvent)
            } else {
                emptySection
            }

            lessonRows
        }
        .padding(isSmall ? 14 : 16)
        .widgetPremiumBackground(accentColor: accentColor)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 8) {
            Text("Bugün")
                .font(.system(size: isSmall ? 17 : 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            if !todayEvents.isEmpty {
                Text("\(todayEvents.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                    )
            }

            Spacer()

            Text(dayTitles[safeIndex(todayWeekday)])
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
        }
    }

    // MARK: - Live / Next / Empty

    private func liveSection(for event: WidgetEvent) -> some View {
        let left = minutesLeft(event, now: nowMinute)
        let progress = progressForLive(event, now: nowMinute)
        let tint = softTint(from: hexColor(event.colorHex))

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Şu an: \(event.title)")
                    .font(.system(size: isSmall ? 15 : 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text("LIVE")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.14))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.green.opacity(0.24), lineWidth: 0.8)
                    )

                Spacer(minLength: 6)

                Text("\(left) dk")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 7)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint,
                                    tint.opacity(0.88)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(14, geo.size.width * progress), height: 7)
                }
            }
            .frame(height: 7)

            HStack(spacing: 8) {
                Circle()
                    .fill(.white.opacity(0.68))
                    .frame(width: 7, height: 7)

                Text("\(hm(event.startMinute))-\(hm(event.startMinute + event.durationMinute))")
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .monospacedDigit()
            }
        }
    }

    private func nextSection(for event: WidgetEvent) -> some View {
        let mins = max(0, event.startMinute - nowMinute)
        let tint = softTint(from: hexColor(event.colorHex))

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Sıradaki: \(event.title)")
                    .font(.system(size: isSmall ? 15 : 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Text("\(mins) dk")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(tint)
                    .frame(width: 7, height: 7)

                Text("\(hm(event.startMinute))-\(hm(event.startMinute + event.durationMinute))")
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .monospacedDigit()
            }
        }
    }

    private var emptySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Bugün sakin")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text("Planlanmış ders görünmüyor.")
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
        }
    }

    // MARK: - Rows

    private var lessonRows: some View {
        let rows: [WidgetEvent]

        if liveEvent != nil {
            rows = Array(todayEvents.prefix(2))
        } else if nextEvent != nil {
            rows = Array(todayEvents.dropFirst().prefix(2))
        } else {
            rows = Array(todayEvents.prefix(2))
        }

        return VStack(alignment: .leading, spacing: 10) {
            ForEach(rows, id: \.id) { event in
                lessonRow(for: event)
            }
        }
    }

    private func lessonRow(for event: WidgetEvent) -> some View {
        let tint = softTint(from: hexColor(event.colorHex))

        return HStack(spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)

            Text(event.title)
                .font(.system(size: isSmall ? 12.5 : 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.74)

            Spacer(minLength: 8)

            Text("\(hm(event.startMinute))-\(hm(event.startMinute + event.durationMinute))")
                .font(.system(size: isSmall ? 11.5 : 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }

    // MARK: - Helpers

    private func safeIndex(_ i: Int) -> Int {
        max(0, min(6, i))
    }

    private func hm(_ minute: Int) -> String {
        let m = max(0, min(1439, minute))
        let h = m / 60
        let mm = m % 60
        return String(format: "%02d:%02d", h, mm)
    }

    private func currentMinuteOfDay() -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private func widgetWeekdayToday() -> Int {
        let w = Calendar.current.component(.weekday, from: Date())
        return (w + 5) % 7
    }

    private func progressForLive(_ event: WidgetEvent, now: Int) -> Double {
        let start = event.startMinute
        let end = event.startMinute + event.durationMinute
        guard end > start else { return 0 }
        let p = Double(now - start) / Double(end - start)
        return min(1, max(0, p))
    }

    private func minutesLeft(_ event: WidgetEvent, now: Int) -> Int {
        let end = event.startMinute + event.durationMinute
        return max(0, end - now)
    }

    private func softTint(from color: Color) -> Color {
        color.opacity(0.94)
    }
}

// MARK: - Premium Background

private extension View {
    @ViewBuilder
    func widgetPremiumBackground(accentColor: Color) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.26, green: 0.27, blue: 0.33),
                            Color(red: 0.20, green: 0.21, blue: 0.28),
                            Color(red: 0.14, green: 0.15, blue: 0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    RadialGradient(
                        colors: [
                            Color.purple.opacity(0.16),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 10,
                        endRadius: 180
                    )
                    RadialGradient(
                        colors: [
                            accentColor.opacity(0.08),
                            Color.clear
                        ],
                        center: .bottomTrailing,
                        startRadius: 10,
                        endRadius: 220
                    )

                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        .padding(1)
                }
            }
        } else {
            self.background(
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.24, green: 0.25, blue: 0.31),
                            Color(red: 0.18, green: 0.19, blue: 0.26),
                            Color(red: 0.13, green: 0.14, blue: 0.19)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    RadialGradient(
                        colors: [
                            Color.purple.opacity(0.22),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 10,
                        endRadius: 180
                    )

                    RadialGradient(
                        colors: [
                            accentColor.opacity(0.08),
                            Color.clear
                        ],
                        center: .bottomTrailing,
                        startRadius: 10,
                        endRadius: 220
                    )
                }
            )
        }
    }
}

// MARK: - Widget

struct ScheduleWidget: Widget {
    let kind: String = "ScheduleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScheduleProvider()) { entry in
            ScheduleWidgetView(entry: entry)
                .widgetURL(URL(string: "dailytodo://week"))
        }
        .configurationDisplayName("Bugünün Programı")
        .description("Bugün için canlı ve sıradaki dersleri gösterir.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

func weekdayIndexToday() -> Int {
    let w = Calendar.current.component(.weekday, from: Date())
    return (w + 5) % 7
}
