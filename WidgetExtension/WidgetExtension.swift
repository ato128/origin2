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
                    WidgetEvent(id: "1", title: "Physics - II", weekday: 0, startMinute: 9 * 60, durationMinute: 60, location: "Lab", colorHex: "#2DD4FF"),
                    WidgetEvent(id: "2", title: "Calculus - II", weekday: 0, startMinute: 11 * 60, durationMinute: 90, location: "B-202", colorHex: "#7C3AED"),
                    WidgetEvent(id: "3", title: "Software", weekday: 0, startMinute: 14 * 60, durationMinute: 60, location: "A-101", colorHex: "#1593FF")
                ]
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
        completion(ScheduleEntry(date: Date(), payload: WidgetShared.readPayload()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
        let now = Date()
        let entry = ScheduleEntry(date: now, payload: WidgetShared.readPayload())

        let cal = Calendar.current
        let nextMinute = cal.date(bySetting: .second, value: 0, of: now)?
            .addingTimeInterval(60) ?? now.addingTimeInterval(60)

        completion(Timeline(entries: [entry], policy: .after(nextMinute)))
    }
}

// MARK: - Main Widget View

struct ScheduleWidgetView: View {
    let entry: ScheduleProvider.Entry
    @Environment(\.widgetFamily) private var family

    private let dayTitles = ["PZT", "SAL", "ÇAR", "PER", "CUM", "CMT", "PAZ"]

    private var isSmall: Bool { family == .systemSmall }

    private var todayWeekday: Int { widgetWeekdayToday() }

    private var todayEvents: [WidgetEvent] {
        (entry.payload?.events ?? [])
            .filter { $0.weekday == todayWeekday }
            .sorted { $0.startMinute < $1.startMinute }
    }

    private var nowMinute: Int { currentMinuteOfDay() }

    private var liveEvent: WidgetEvent? {
        todayEvents.first { ev in
            nowMinute >= ev.startMinute && nowMinute < ev.startMinute + ev.durationMinute
        }
    }

    private var nextEvent: WidgetEvent? {
        todayEvents.first { $0.startMinute > nowMinute }
    }

    private var accent: Color {
        if let liveEvent { return hexColor(liveEvent.colorHex) }
        if let nextEvent { return hexColor(nextEvent.colorHex) }
        return UpdoWidgetPalette.cyan
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isSmall ? 9 : 11) {
            headerRow

            if let liveEvent {
                liveSection(for: liveEvent)
            } else if let nextEvent {
                nextSection(for: nextEvent)
            } else {
                emptySection
            }

            if !isSmall || liveEvent == nil {
                Spacer(minLength: 0)
            }

            lessonRows
        }
        .padding(isSmall ? 14 : 16)
        .widgetUpdoBackground(accent: accent)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 7) {
            // Cyan section-label imzası ("— BUGÜN")
            Rectangle()
                .fill(UpdoWidgetPalette.cyan)
                .frame(width: 14, height: 2.5)
                .clipShape(Capsule())

            Text("BUGÜN")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(UpdoWidgetPalette.cyan)

            if !todayEvents.isEmpty {
                Text("\(todayEvents.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 17, height: 17)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }

            Spacer()

            Text(dayTitles[safeIndex(todayWeekday)])
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    // MARK: - Live

    private func liveSection(for event: WidgetEvent) -> some View {
        let left = minutesLeft(event, now: nowMinute)
        let progress = progressForLive(event, now: nowMinute)
        let tint = hexColor(event.colorHex)

        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                // Nabız atan canlı nokta
                PulseDot(color: UpdoWidgetPalette.green)

                Text(event.title)
                    .font(.system(size: isSmall ? 15 : 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 4)

                Text("\(left) dk")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(tint.opacity(0.18))
                    )
                    .overlay(
                        Capsule().stroke(tint.opacity(0.35), lineWidth: 0.8)
                    )
            }

            // Glow'lu progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 7)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint, tint.opacity(0.7)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(14, geo.size.width * progress), height: 7)
                        .shadow(color: tint.opacity(0.6), radius: 4, y: 0)
                }
            }
            .frame(height: 7)

            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))

                Text("\(hm(event.startMinute))–\(hm(event.startMinute + event.durationMinute))")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .monospacedDigit()

                if let loc = event.location, !loc.isEmpty, !isSmall {
                    Text("·")
                        .foregroundStyle(.white.opacity(0.3))
                    Image(systemName: "mappin")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                    Text(loc)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Next

    private func nextSection(for event: WidgetEvent) -> some View {
        let mins = max(0, event.startMinute - nowMinute)
        let tint = hexColor(event.colorHex)

        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)

                Text(event.title)
                    .font(.system(size: isSmall ? 15 : 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 4)

                Text("\(mins) dk")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                    .monospacedDigit()
            }

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))

                Text("\(hm(event.startMinute))–\(hm(event.startMinute + event.durationMinute))")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .monospacedDigit()

                Text("· Sıradaki")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    // MARK: - Empty

    private var emptySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(UpdoWidgetPalette.signatureGradient.opacity(0.22))
                        .frame(width: 34, height: 34)
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(UpdoWidgetPalette.cyan)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Bugün sakin")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Planlanmış ders yok")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
    }

    // MARK: - Lesson rows

    private var lessonRows: some View {
        let rows: [WidgetEvent]
        if liveEvent != nil {
            rows = Array(todayEvents.filter { $0.startMinute > nowMinute }.prefix(isSmall ? 1 : 2))
        } else if nextEvent != nil {
            rows = Array(todayEvents.dropFirst().prefix(isSmall ? 1 : 2))
        } else {
            rows = []
        }

        return VStack(alignment: .leading, spacing: 7) {
            if !rows.isEmpty {
                Divider()
                    .overlay(Color.white.opacity(0.06))
                    .padding(.vertical, 1)
            }
            ForEach(rows, id: \.id) { lessonRow(for: $0) }
        }
    }

    private func lessonRow(for event: WidgetEvent) -> some View {
        let tint = hexColor(event.colorHex)
        return HStack(spacing: 9) {
            // Renkli sol şerit
            Capsule()
                .fill(tint)
                .frame(width: 3, height: 14)

            Text(event.title)
                .font(.system(size: isSmall ? 12 : 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 6)

            Text("\(hm(event.startMinute))–\(hm(event.startMinute + event.durationMinute))")
                .font(.system(size: isSmall ? 11 : 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    // MARK: - Helpers

    private func safeIndex(_ i: Int) -> Int { max(0, min(6, i)) }

    private func hm(_ minute: Int) -> String {
        let m = max(0, min(1439, minute))
        return String(format: "%02d:%02d", m / 60, m % 60)
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
        return min(1, max(0, Double(now - start) / Double(end - start)))
    }

    private func minutesLeft(_ event: WidgetEvent, now: Int) -> Int {
        max(0, event.startMinute + event.durationMinute - now)
    }
}

// MARK: - Pulse Dot (canlı nokta)

private struct PulseDot: View {
    let color: Color
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.30))
                .frame(width: 14, height: 14)
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.8), radius: 3)
        }
    }
}

// MARK: - Updo Background

private extension View {
    @ViewBuilder
    func widgetUpdoBackground(accent: Color) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) {
                ZStack {
                    LinearGradient(
                        colors: [
                            UpdoWidgetPalette.bgTop,
                            UpdoWidgetPalette.bgMid,
                            UpdoWidgetPalette.bgBottom
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    RadialGradient(
                        colors: [UpdoWidgetPalette.purple.opacity(0.18), .clear],
                        center: .topLeading, startRadius: 8, endRadius: 200
                    )
                    RadialGradient(
                        colors: [accent.opacity(0.14), .clear],
                        center: .bottomTrailing, startRadius: 8, endRadius: 230
                    )
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                        .padding(0.5)
                }
            }
        } else {
            self.background(
                ZStack {
                    LinearGradient(
                        colors: [
                            UpdoWidgetPalette.bgTop,
                            UpdoWidgetPalette.bgMid,
                            UpdoWidgetPalette.bgBottom
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    RadialGradient(
                        colors: [UpdoWidgetPalette.purple.opacity(0.20), .clear],
                        center: .topLeading, startRadius: 8, endRadius: 200
                    )
                    RadialGradient(
                        colors: [accent.opacity(0.14), .clear],
                        center: .bottomTrailing, startRadius: 8, endRadius: 230
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

