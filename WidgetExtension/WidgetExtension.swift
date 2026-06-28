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

    private var dayTitles: [String] {
        widgetLocalized("tr", "en") == "tr"
            ? ["PZT", "SAL", "ÇAR", "PER", "CUM", "CMT", "PAZ"]
            : ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    }

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

    /// Brand accent follows the selected app icon (header, glow, watermark).
    private var brandAccent: Color { UpdoWidgetIconTheme.current().accent }

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

            Spacer(minLength: 0)

            lessonRows
        }
        .padding(isSmall ? 15 : 17)
        .widgetUpdoBackground(accent: brandAccent)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 6) {
            Text(widgetLocalized("BUGÜN", "TODAY"))
                .font(WidgetFont.eyebrow(11))
                .tracking(0.8)
                .foregroundStyle(UpdoWidgetPalette.textSecondary)

            if !todayEvents.isEmpty {
                Text("\(todayEvents.count)")
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(UpdoWidgetPalette.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .background(Capsule().fill(UpdoWidgetPalette.fillSoft))
            }

            Spacer()

            Text(dayTitles[safeIndex(todayWeekday)])
                .font(.system(size: 11, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(UpdoWidgetPalette.textTertiary)
        }
    }

    // MARK: - Live

    private func liveSection(for event: WidgetEvent) -> some View {
        let left = minutesLeft(event, now: nowMinute)
        let progress = progressForLive(event, now: nowMinute)
        let tint = hexColor(event.colorHex)

        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                PulseDot(color: tint)

                Text(event.title)
                    .font(WidgetFont.title(isSmall ? 16 : 18))
                    .foregroundStyle(UpdoWidgetPalette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 4)

                Text("\(left) \(widgetLocalized("dk", "min"))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
            }

            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.10)).frame(height: 5)
                GeometryReader { geo in
                    Capsule().fill(tint)
                        .frame(width: max(8, geo.size.width * progress), height: 5)
                }
                .frame(height: 5)
            }
            .frame(height: 5)

            metaRow(event: event, showLocation: !isSmall, tint: UpdoWidgetPalette.textTertiary)
        }
    }

    // MARK: - Next

    private func nextSection(for event: WidgetEvent) -> some View {
        let mins = max(0, event.startMinute - nowMinute)
        let tint = hexColor(event.colorHex)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Capsule().fill(tint).frame(width: 3, height: isSmall ? 17 : 19)

                Text(event.title)
                    .font(WidgetFont.title(isSmall ? 16 : 18))
                    .foregroundStyle(UpdoWidgetPalette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 4)

                Text("\(mins) \(widgetLocalized("dk", "min"))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(UpdoWidgetPalette.textSecondary)
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
            }

            HStack(spacing: 5) {
                Text("\(hm(event.startMinute))–\(hm(event.startMinute + event.durationMinute))")
                    .focusHeroNumber(size: 12, accent: tint)
                Text("·").foregroundStyle(UpdoWidgetPalette.textTertiary)
                Text(widgetLocalized("Sıradaki", "Next"))
                    .font(WidgetFont.caption(11))
                    .foregroundStyle(UpdoWidgetPalette.textTertiary)
            }
        }
    }

    private func metaRow(event: WidgetEvent, showLocation: Bool, tint: Color) -> some View {
        HStack(spacing: 5) {
            Text("\(hm(event.startMinute))–\(hm(event.startMinute + event.durationMinute))")
                .focusHeroNumber(size: 12, accent: hexColor(event.colorHex))

            if let loc = event.location, !loc.isEmpty, showLocation {
                Text("·").foregroundStyle(UpdoWidgetPalette.textTertiary)
                Image(systemName: "mappin")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(tint)
                Text(loc)
                    .font(WidgetFont.caption())
                    .foregroundStyle(UpdoWidgetPalette.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Empty

    private var emptySection: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(UpdoWidgetPalette.fillSoft)
                    .frame(width: 36, height: 36)
                Image(systemName: "moon.stars")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(brandAccent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(widgetLocalized("Bugün sakin", "Clear day"))
                    .font(WidgetFont.title(15))
                    .foregroundStyle(UpdoWidgetPalette.textPrimary)

                Text(widgetLocalized("Planlanmış ders yok", "No classes scheduled"))
                    .font(WidgetFont.caption())
                    .foregroundStyle(UpdoWidgetPalette.textSecondary)
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

        return VStack(alignment: .leading, spacing: 0) {
            if !rows.isEmpty {
                Rectangle()
                    .fill(UpdoWidgetPalette.hairline)
                    .frame(height: 1)
                    .padding(.bottom, isSmall ? 7 : 9)
            }
            VStack(alignment: .leading, spacing: isSmall ? 7 : 9) {
                ForEach(rows, id: \.id) { lessonRow(for: $0) }
            }
        }
    }

    private func lessonRow(for event: WidgetEvent) -> some View {
        let tint = hexColor(event.colorHex)
        return HStack(spacing: 9) {
            Capsule()
                .fill(tint.opacity(0.9))
                .frame(width: 3, height: 13)

            Text(event.title)
                .font(WidgetFont.body(isSmall ? 12 : 13))
                .foregroundStyle(UpdoWidgetPalette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 6)

            Text(hm(event.startMinute))
                .focusHeroNumber(size: isSmall ? 11 : 12, accent: tint)
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
            Circle().fill(color.opacity(0.22)).frame(width: 12, height: 12)
            Circle().fill(color).frame(width: 6, height: 6)
        }
    }
}

// MARK: - Updo Background

extension View {
    /// Calm, single-surface widget background: a deep vertical gradient with one
    /// restrained accent glow in the lower-right and a hairline edge. No rainbow,
    /// no heavy halos — the Apple/Updo look.
    @ViewBuilder
    func widgetUpdoBackground(accent: Color) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) { widgetSurface(accent: accent) }
        } else {
            self.background(widgetSurface(accent: accent))
        }
    }

    private func widgetSurface(accent: Color) -> some View {
        ZStack {
            LinearGradient(
                colors: [UpdoWidgetPalette.surfaceTop, UpdoWidgetPalette.surfaceBottom],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [accent.opacity(0.10), .clear],
                center: .bottomTrailing, startRadius: 10, endRadius: 220
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

