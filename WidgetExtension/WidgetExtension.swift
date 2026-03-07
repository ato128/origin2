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

// MARK: - View

struct ScheduleWidgetView: View {
    let entry: ScheduleProvider.Entry

    @Environment(\.widgetFamily) private var family

    private let dayTitles = ["Pzt","Sal","Çar","Per","Cum","Cmt","Paz"]
    
    private var isSmall: Bool { family == .systemSmall }
    private var isMedium: Bool { family == .systemMedium }

    private var widgetCornerRadius: CGFloat {
        isSmall ? 20 : 24
    }

    private var headerFont: Font {
        isSmall ? .headline.bold() : .headline
    }

    private var titleFont: Font {
        isSmall ? .subheadline.weight(.semibold) : .subheadline.weight(.semibold)
    }

    private var timeFont: Font {
        isSmall ? .caption.weight(.semibold) : .caption.weight(.semibold)
    }

    private var rowSpacing: CGFloat {
        isSmall ? 6 : 8
    }

    private var verticalRowPadding: CGFloat {
        isSmall ? 2 : 3
    }

    var body: some View {
        let payload = entry.payload
        let now = currentMinuteOfDay()
        let todayWeekday = widgetWeekdayToday()

        let todayEvents = (payload?.events ?? [])
            .filter { $0.weekday == todayWeekday }
            .sorted { $0.startMinute < $1.startMinute }

        let live = todayEvents.first(where: { ev in
            let s = ev.startMinute
            let e = ev.startMinute + ev.durationMinute
            return now >= s && now < e
        })

        let next = todayEvents.first(where: { $0.startMinute > now })

        let accentEvent = live ?? next
        let accentColor = accentEvent.map { Color(hex: $0.colorHex) } ?? .secondary
        let backgroundTintOpacity: Double = {
            if accentEvent == nil { return 0 }
            return isSmall ? 0.05 : 0.08
        }()

        Group {
            if isSmall {
                smallWidgetLayout(
                    payload: payload,
                    todayWeekday: todayWeekday,
                    todayEvents: todayEvents,
                    live: live,
                    next: next,
                    now: now
                )
            } else {
                mediumWidgetLayout(
                    payload: payload,
                    todayWeekday: todayWeekday,
                    todayEvents: todayEvents,
                    live: live,
                    next: next,
                    now: now
                )
            }
        }
        .padding(isSmall ? 12 : 16)
        .applyWidgetBackground(
            accentColor: accentColor,
            tintOpacity: backgroundTintOpacity
        )
    }
    // MARK: - Pieces
    private func smallWidgetLayout(
        payload: WidgetPayload?,
        todayWeekday: Int,
        todayEvents: [WidgetEvent],
        live: WidgetEvent?,
        next: WidgetEvent?,
        now: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Bugün")
                    .font(.headline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer()

                Text(dayTitles[safeIndex(todayWeekday)])
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let ev = live {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(ev.title)
                            .font(.subheadline.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text("LIVE")
                            .font(.caption2.bold())
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(.green.opacity(0.18))
                                    .overlay(
                                        Capsule()
                                            .stroke(.green.opacity(0.35), lineWidth: 0.5)
                                    )
                            )
                            .foregroundStyle(.green)
                            .shadow(color: .green.opacity(0.4), radius: 4)

                        Spacer(minLength: 0)
                    }

                    liveProgressBar(ev: ev, now: now)

                    eventRow(
                        ev: ev,
                        showLocation: false,
                        showTimeRange: false
                    )
                }
            } else if let ev = next {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: ev.colorHex))
                            .frame(width: 8, height: 8)

                        Text(ev.title)
                            .font(.subheadline.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Spacer(minLength: 0)
                    }

                    nextStrip(ev: ev, now: now)

                    eventRow(
                        ev: ev,
                        showLocation: false,
                        showTimeRange: false
                    )
                }
            } else {
                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Bugün ders yok")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
        }
    }

    private func mediumWidgetLayout(
        payload: WidgetPayload?,
        todayWeekday: Int,
        todayEvents: [WidgetEvent],
        live: WidgetEvent?,
        next: WidgetEvent?,
        now: Int
    ) -> some View {
        let list = Array(todayEvents.prefix(3))

        return VStack(alignment: .leading, spacing: 10) {
            header(payload: payload)

            if let ev = live {
                liveStrip(ev: ev, now: now)
            } else if let ev = next {
                nextStrip(ev: ev, now: now)
            }

            if !todayEvents.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(list, id: \.id) { ev in
                        eventRow(
                            ev: ev,
                            showLocation: true,
                            showTimeRange: true
                        )
                    }
                }
            } else {
                Spacer(minLength: 6)

                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Bugün ders yok")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 6)
            }

            Spacer(minLength: 0)
        }
    }

    private func liveProgressBar(ev: WidgetEvent, now: Int) -> some View {
        let prog = progressForLive(ev, now: now)
        let left = minutesLeft(ev, now: now)

        let progressColor: Color = {
            if left <= 1 { return .red }
            if left <= 5 { return .orange }
            return Color(hex: ev.colorHex)
        }()

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.18))
                    .frame(height: 6)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                progressColor,
                                progressColor.opacity(0.35)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * prog, height: 6)
                    .animation(.easeInOut(duration: 0.6), value: prog)
            }
        }
        .frame(height: 6)
    }
    
    
    
    
    private func header(payload: WidgetPayload?) -> some View {
        let todayWeekday = widgetWeekdayToday()
        let todayCount = (payload?.events ?? []).filter { $0.weekday == todayWeekday }.count

        return HStack(spacing: 8) {
            Text("Bugün")
                .font(headerFont)

            if todayCount > 0  && !isSmall {
                Text("\(todayCount)")
                    .font(.caption2.bold())
                    .padding(.horizontal, isSmall ? 5 : 7)
                    .padding(.vertical, isSmall ? 1 : 3)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(isSmall ? 0.14 : 0.16))
                    )
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(dayTitles[safeIndex(todayWeekday)])
                .font(isSmall ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    private func liveStrip(ev: WidgetEvent, now: Int) -> some View {
        let prog = progressForLive(ev, now: now)
        let left = minutesLeft(ev, now: now)

        return VStack(alignment: .leading, spacing: isSmall ? 6 : 8) {
            HStack(spacing: 6) {
                Text(isSmall ? ev.title : "Şu an: \(ev.title)")
                    .font(isSmall ? .caption.weight(.semibold) : .caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("LIVE")
                    .font(.caption2.bold())
                    .padding(.horizontal, isSmall ? 4 : 5)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(.green.opacity(0.15))
                    )
                    .overlay(
                        Capsule()
                            .stroke(.green.opacity(0.35), lineWidth: 0.5)
                    )
                    .foregroundStyle(.green)
                    .shadow(color: .green.opacity(0.35), radius: 4)
                Spacer()

                if !isSmall {
                    Text("\(left) dk")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(left <= 1 ? .red : (left <= 5 ? .orange : .secondary))
                        .lineLimit(1)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.18))
                        .frame(height: isSmall ? 5 : 6)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: ev.colorHex),
                                    Color(hex: ev.colorHex).opacity(0.55)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * prog, height: isSmall ? 5 : 6)
                }
            }
            .frame(height: isSmall ? 5 : 6)
        }
    }
    private func nextStrip(ev: WidgetEvent, now: Int) -> some View {
        let mins = max(0, ev.startMinute - now)
        let urgent = mins <= 10

        return HStack(spacing: 8) {
            Circle()
                .fill(urgent ? .orange : Color(hex: ev.colorHex))
                .frame(width: 8, height: 8)

            Text(
                isSmall
                ? ev.title
                : (urgent ? "Başlıyor: \(ev.title)" : "Sıradaki: \(ev.title)")
            )
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            Spacer()

            Text(urgent ? "\(mins) dk" : (isSmall ? "\(mins) dk" : "\(mins) dk sonra"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(urgent ? .orange : .secondary)
                .lineLimit(1)
        }
    }
    private func eventRow(ev: WidgetEvent, showLocation: Bool, showTimeRange: Bool) -> some View {
        let isLive = {
            let now = currentMinuteOfDay()
            let start = ev.startMinute
            let end = ev.startMinute + ev.durationMinute
            return now >= start && now < end
        }()

        let startText = hm(ev.startMinute)
        let endText = hm(ev.startMinute + ev.durationMinute)
        let timeText = showTimeRange ?
            "\(startText)-\(endText)" :
            "→ \(endText)"
        return HStack(spacing: rowSpacing) {
            Circle()
                .fill(Color(hex: ev.colorHex))
                .frame(width: isSmall ? 7 : 8, height: isSmall ? 7 : 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(ev.title)
                    .font(.subheadline.weight(isLive ? .bold : .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if !isSmall,
                   showLocation,
                   let loc = ev.location,
                   !loc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(loc)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            Text(timeText)
                .font(timeFont)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.vertical, verticalRowPadding)
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
    
    private func widgetWeekdayToday() -> Int {
        let w = Calendar.current.component(.weekday, from: Date())
        return (w + 5) % 7
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
    func applyWidgetBackground(accentColor: Color, tintOpacity: Double) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self
                .containerBackground(for: .widget) {
                    ZStack {
                        Color(.secondarySystemBackground)
                        accentColor.opacity(tintOpacity)
                    }
                }
        } else {
            self.background(
                ZStack {
                    Color(.secondarySystemBackground)
                    accentColor.opacity(tintOpacity)
                }
            )
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
                .widgetURL(URL(string: "dailytodo://week"))
        }
        .configurationDisplayName("Bugünün Dersleri")
        .description("Bugün için sıradaki dersleri gösterir.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
