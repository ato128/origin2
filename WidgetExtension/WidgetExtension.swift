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

    private let dayTitles = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]

    private var isSmall: Bool { family == .systemSmall }

    var body: some View {
        let payload = entry.payload
        let now = currentMinuteOfDay()
        let todayWeekday = widgetWeekdayToday()

        let todayEvents = (payload?.events ?? [])
            .filter { $0.weekday == todayWeekday }
            .sorted { $0.startMinute < $1.startMinute }

        let live = todayEvents.first(where: { ev in
            let start = ev.startMinute
            let end = ev.startMinute + ev.durationMinute
            return now >= start && now < end
        })

        let next = todayEvents.first(where: { $0.startMinute > now })
        let accentColor = (live ?? next).map { hexColor($0.colorHex) } ?? Color.blue

        Group {
            if isSmall {
                smallLayout(
                    todayWeekday: todayWeekday,
                    todayEvents: todayEvents,
                    live: live,
                    next: next,
                    now: now,
                    accentColor: accentColor
                )
            } else {
                mediumLayout(
                    todayWeekday: todayWeekday,
                    todayEvents: todayEvents,
                    live: live,
                    next: next,
                    now: now,
                    accentColor: accentColor
                )
            }
        }
        .padding(isSmall ? 14 : 16)
        .widgetPremiumBackground(accentColor: accentColor)
    }

    // MARK: - Small

    private func smallLayout(
        todayWeekday: Int,
        todayEvents: [WidgetEvent],
        live: WidgetEvent?,
        next: WidgetEvent?,
        now: Int,
        accentColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            topHeader(todayWeekday: todayWeekday, count: todayEvents.count)

            if let live {
                compactHero(
                    titlePrefix: "Şu an",
                    event: live,
                    now: now,
                    accentColor: accentColor,
                    showRemaining: true
                )
            } else if let next {
                compactHero(
                    titlePrefix: "Sıradaki",
                    event: next,
                    now: now,
                    accentColor: accentColor,
                    showRemaining: false
                )
            } else {
                emptyMinimalState()
            }
        }
    }

    // MARK: - Medium

    private func mediumLayout(
        todayWeekday: Int,
        todayEvents: [WidgetEvent],
        live: WidgetEvent?,
        next: WidgetEvent?,
        now: Int,
        accentColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            topHeader(todayWeekday: todayWeekday, count: todayEvents.count)

            if let live {
                compactHero(
                    titlePrefix: "Şu an",
                    event: live,
                    now: now,
                    accentColor: accentColor,
                    showRemaining: true
                )

                if let nextAfterLive = todayEvents.first(where: { $0.startMinute > now }) {
                    bottomInfoRow(
                        title: "Sıradaki",
                        value: "\(nextAfterLive.title) • \(hm(nextAfterLive.startMinute))",
                        tint: hexColor(nextAfterLive.colorHex)
                    )
                } else {
                    bottomInfoRow(
                        title: "Bugün",
                        value: "\(todayEvents.count) ders planlandı",
                        tint: .white.opacity(0.78)
                    )
                }
            } else if let next {
                compactHero(
                    titlePrefix: "Sıradaki",
                    event: next,
                    now: now,
                    accentColor: accentColor,
                    showRemaining: false
                )

                bottomInfoRow(
                    title: "Başlangıç",
                    value: "\(hm(next.startMinute)) • \(next.durationMinute) dk",
                    tint: accentColor
                )
            } else {
                emptyMinimalState()
            }
        }
    }

    // MARK: - Header

    private func topHeader(todayWeekday: Int, count: Int) -> some View {
        HStack(spacing: 8) {
            Text("Bugün")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
            }

            Spacer()

            Text(dayTitles[safeIndex(todayWeekday)])
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
        }
    }

    // MARK: - Hero

    private func compactHero(
        titlePrefix: String,
        event: WidgetEvent,
        now: Int,
        accentColor: Color,
        showRemaining: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("\(titlePrefix): \(event.title)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)

                if titlePrefix == "Şu an" {
                    Text("LIVE")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.12))
                        .overlay(
                            Capsule()
                                .stroke(Color.green.opacity(0.25), lineWidth: 1)
                        )
                        .clipShape(Capsule())
                }

                Spacer()

                if showRemaining {
                    Text("\(minutesLeft(event, now: now)) dk")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                        .monospacedDigit()
                }
            }

            progressBar(
                value: titlePrefix == "Şu an"
                    ? progressForLive(event, now: now)
                    : 0.0,
                accentColor: accentColor
            )

            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.72))

                Text("\(hm(event.startMinute))-\(hm(event.startMinute + event.durationMinute))")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.76))
                    .monospacedDigit()

                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Bottom row

    private func bottomInfoRow(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Empty

    private func emptyMinimalState() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.white.opacity(0.7))

                Text("Bugün planlanmış ders yok")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text("Rahat bir gün gibi görünüyor.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: - Progress

    private func progressBar(value: Double, accentColor: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.14))
                    .frame(height: 10)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.95),
                                accentColor.opacity(0.72)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * value), height: 10)
            }
        }
        .frame(height: 10)
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

// MARK: - Premium Background

private extension View {
    @ViewBuilder
    func widgetPremiumBackground(accentColor: Color) -> some View {
        let bg = ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.96),
                            Color(red: 0.02, green: 0.03, blue: 0.08),
                            Color.black.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            LinearGradient(
                colors: [
                    Color.purple.opacity(0.18),
                    Color.clear,
                    Color.blue.opacity(0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    accentColor.opacity(0.20),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 180
            )

            RadialGradient(
                colors: [
                    Color.purple.opacity(0.12),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 12,
                endRadius: 170
            )

            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }

        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) {
                bg
            }
        } else {
            self.background(bg)
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
        .configurationDisplayName("Bugünün Dersleri")
        .description("Bugün için sıradaki dersleri gösterir.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

func weekdayIndexToday() -> Int {
    let w = Calendar.current.component(.weekday, from: Date())
    return (w + 5) % 7
}
