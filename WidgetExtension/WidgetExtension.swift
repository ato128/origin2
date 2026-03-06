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
                        colorHex: "#22C55E"
                    ),
                    WidgetEvent(
                        id: "3",
                        title: "Chem",
                        weekday: 0,
                        startMinute: 14 * 60,
                        durationMinute: 60,
                        location: "B-202",
                        colorHex: "#EC4899"
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
        let entry = ScheduleEntry(date: Date(), payload: payload)

        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - View

struct ScheduleWidgetView: View {
    let entry: ScheduleProvider.Entry

    @Environment(\.widgetFamily) private var family

    private let dayTitles = ["Pzt","Sal","Çar","Per","Cum","Cmt","Paz"]

    var body: some View {
        let payload = entry.payload
        let now = currentMinuteOfDay()

        let live = payload?.events.first(where: { ev in
            let s = ev.startMinute
            let e = ev.startMinute + ev.durationMinute
            return now >= s && now < e
        })

        let next = payload?.events
            .filter { $0.startMinute > now }
            .sorted { $0.startMinute < $1.startMinute }
            .first

        let maxItems: Int = (family == .systemSmall) ? 2 : 3
        let list = Array((payload?.events ?? []).prefix(maxItems))

        VStack(alignment: .leading, spacing: 10) {

            header(payload: payload)

            if let ev = live {
                liveStrip(ev: ev, now: now)
            } else if let ev = next {
                nextStrip(ev: ev, now: now)
            }

            if let p = payload, !p.events.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(list, id: \.id) { ev in
                        eventRow(
                            ev: ev,
                            // ✅ Small: konum yok, sadece title
                            showLocation: (family == .systemMedium),
                            // ✅ Medium: 09:00–10:00, Small: sadece 09:00
                            showTimeRange: (family == .systemMedium)
                        )
                    }
                }
            } else {
                Spacer(minLength: 6)
                Text("Bugün ders yok")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 6)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .applyWidgetBackground()
    }

    // MARK: - Pieces

    private func header(payload: WidgetPayload?) -> some View {
        HStack {
            Text("Bugün")
                .font(.headline)

            Spacer()

            if let p = payload {
                Text(dayTitles[safeIndex(p.weekday)])
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func liveStrip(ev: WidgetEvent, now: Int) -> some View {
        let prog = progressForLive(ev, now: now)
        let left = minutesLeft(ev, now: now)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Şu an: \(ev.title)")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Spacer()

                Text("\(left) dk kaldı")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.18))
                        .frame(height: 6)

                    Capsule()
                        .fill(Color(hex: ev.colorHex))
                        .frame(width: geo.size.width * prog, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private func nextStrip(ev: WidgetEvent, now: Int) -> some View {
        let mins = max(0, ev.startMinute - now)
        return Text("Sıradaki: \(ev.title) • \(mins) dk sonra")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private func eventRow(ev: WidgetEvent, showLocation: Bool, showTimeRange: Bool) -> some View {
        let startText = hm(ev.startMinute)
        let endText = hm(ev.startMinute + ev.durationMinute)
        let timeText = showTimeRange ? "\(startText)–\(endText)" : startText

        return HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: ev.colorHex))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(ev.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                if showLocation,
                   let loc = ev.location,
                   !loc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(loc)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(timeText)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func safeIndex(_ i: Int) -> Int { max(0, min(6, i)) }

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

    private func progressForLive(_ ev: WidgetEvent, now: Int) -> Double {
        let start = ev.startMinute
        let end = ev.startMinute + ev.durationMinute
        guard end > start else { return 0 }
        let p = Double(now - start) / Double(end - start)
        return min(1, max(0, p))
    }

    private func minutesLeft(_ ev: WidgetEvent, now: Int) -> Int {
        let end = ev.startMinute + ev.durationMinute
        return max(0, end - now)
    }
}

// MARK: - Widget background helper

private extension View {
    @ViewBuilder
    func applyWidgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(.fill.tertiary, for: .widget)
        } else {
            self.background(Color(.systemBackground))
        }
    }
}

// MARK: - Hex to Color

private extension Color {
    init(hex: String) {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard cleaned.count == 6 else {
            self = .accentColor
            return
        }

        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Widget

struct ScheduleWidget: Widget {
    let kind: String = "ScheduleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScheduleProvider()) { entry in
            ScheduleWidgetView(entry: entry)
        }
        .configurationDisplayName("Bugünün Dersleri")
        .description("Bugün için sıradaki dersleri gösterir.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
