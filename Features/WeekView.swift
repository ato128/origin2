//
//  WeekView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import SwiftUI
import SwiftData
import UIKit
import Combine

struct WeekView: View {

    @Environment(\.modelContext) private var context

    @Query(sort: \EventItem.startMinute, order: .forward)
    private var allEvents: [EventItem]

    @State private var selectedDay: Int = 0
    @State private var showingAdd: Bool = false
    @State private var editingEvent: EventItem? = nil

    // Toast
    @State private var showCopied: Bool = false

    // Auto-scroll
    @State private var didInitialAutoScroll: Bool = false
    @State private var lastAutoScrollTargetID: UUID? = nil

    // İlk girişte bugünü seç
    @State private var didSetInitialDay: Bool = false

    private let liveTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private let dayTitles = ["Pzt","Sal","Çar","Per","Cum","Cmt","Paz"]

    // ✅ onChange’i hafifletmek için
    private var allEventIDs: [UUID] { allEvents.map(\.id) }
    private var eventsForDay: [EventItem] {
        allEvents
            .filter { $0.weekday == selectedDay }
            .sorted { $0.startMinute < $1.startMinute }
    }
    private var eventsForDayIDs: [UUID] { eventsForDay.map(\.id) }

    var body: some View {
        ScrollViewReader { proxy in
            mainList(proxy: proxy)
                .navigationTitle("Week")
                .toolbar { toolbarContent }
                .sheet(isPresented: $showingAdd) {
                    NavigationStack { AddEventView(defaultWeekday: selectedDay) }
                        .presentationDetents([.medium, .large])
                }
                .sheet(item: $editingEvent) { ev in
                    NavigationStack { EditEventView(event: ev) }
                        .presentationDetents([.medium, .large])
                }
                .overlay(toastView, alignment: .bottom)
                .onAppear { onAppear(proxy: proxy) }
                .onChange(of: selectedDay) { _, _ in onDayChanged(proxy: proxy) }
                .onChange(of: eventsForDayIDs) { _, _ in autoScrollIfNeeded(proxy: proxy) }
                .onChange(of: allEventIDs) { _, _ in
                    Task { await NotificationManager.shared.rescheduleAll(events: allEvents) }
                }
                .onReceive(liveTimer) { _ in
                    Task { await LiveActivityManager.shared.autoSyncIfNeeded(events: allEvents) }
                }
        }
    }
}

// MARK: - Main List
private extension WeekView {

    @ViewBuilder
    func mainList(proxy: ScrollViewProxy) -> some View {
        List {
            

            pickerSection

            if eventsForDay.isEmpty {
                emptySection
            } else {
                eventsSection
            }
        }
        .listStyle(.insetGrouped)
    }

    var pickerSection: some View {
        Section {
            Picker("Gün", selection: $selectedDay) {
                ForEach(0..<7, id: \.self) { i in
                    Text(dayTitles[i]).tag(i)
                }
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 6)
        }
    }

    var emptySection: some View {
        ContentUnavailableView(
            "Bu güne ders yok",
            systemImage: "calendar.badge.plus",
            description: Text("Sağ üstteki + ile ders ekleyebilirsin.")
        )
        .listRowSeparator(.hidden)
    }

    var statsHeader: some View {
        let totalMinutes = eventsForDay.reduce(0) { $0 + $1.durationMinute }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        return HStack {
            Text("\(eventsForDay.count) ders")
            Spacer()
            Text("\(hours)s \(minutes)dk toplam")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.vertical, 4)
    }

    // ✅ EventRow’ları AnyView yapıyoruz (type-check fix)
    var eventsSection: some View {
        Section {
            statsHeader

            let now = currentMinuteOfDay()
            let isTodaySelected = (selectedDay == weekdayIndexToday())

            ForEach(eventsForDay) { ev in
                AnyView(
                    EventRow(
                        event: ev,
                        timeText: timeText(for: ev),
                        hasConflict: hasConflict(ev),
                        nowMinute: now,
                        isTodaySelected: isTodaySelected,
                        onTap: { editingEvent = ev },
                        onEdit: { editingEvent = ev },
                        onDelete: { delete(ev) }
                    )
                    .id(ev.id)
                )
            }
        }
    }

    var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                Button {
                    Haptics.impact(.light)
                    shareDay()
                } label: {
                    Label("Bu günü paylaş", systemImage: "square.and.arrow.up")
                }

                Button {
                    Haptics.impact(.light)
                    shareWeek()
                } label: {
                    Label("Tüm haftayı paylaş", systemImage: "calendar")
                }

                Button {
                    UIPasteboard.general.string = shareTextForSelectedDay()
                    Haptics.notify(.success)
                    showCopiedToast()
                } label: {
                    Label("Kopyala", systemImage: "doc.on.doc")
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }

            Button {
                Haptics.impact(.medium)
                showingAdd = true
            } label: {
                Image(systemName: "plus")
            }
        }
    }

    var toastView: some View {
        Group {
            if showCopied {
                Text("Kopyalandı")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(radius: 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 30)
            }
        }
    }
}

// MARK: - Lifecycle
private extension WeekView {

    func onAppear(proxy: ScrollViewProxy) {
        if !didSetInitialDay {
            didSetInitialDay = true
            selectedDay = weekdayIndexToday()
        }

        if !didInitialAutoScroll {
            didInitialAutoScroll = true
            autoScrollIfNeeded(proxy: proxy)
        }

        Task {
            await NotificationManager.shared.rescheduleAll(events: allEvents)
        }
    }

    func onDayChanged(proxy: ScrollViewProxy) {
        lastAutoScrollTargetID = nil
        autoScrollIfNeeded(proxy: proxy)
    }
}

// MARK: - Logic
private extension WeekView {

    func delete(_ ev: EventItem) {
        context.delete(ev)
        try? context.save()
        WidgetAppSync.refreshFromSwiftData(context: context)

        Task {
            await NotificationManager.shared.rescheduleAll(events: allEvents.filter { $0.id != ev.id })
        }
    }

    func timeText(for ev: EventItem) -> String {
        let start = ev.startMinute
        let end = ev.startMinute + ev.durationMinute
        return "\(hm(start)) – \(hm(end))"
    }

    func hm(_ minute: Int) -> String {
        let m = max(0, min(1439, minute))
        let h = m / 60
        let mm = m % 60
        return String(format: "%02d:%02d", h, mm)
    }

    func currentMinuteOfDay() -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    func weekdayIndexToday() -> Int {
        let w = Calendar.current.component(.weekday, from: Date()) // 1=Paz ... 7=Cmt
        return (w + 5) % 7 // 0=Pzt ... 6=Paz
    }

    func hasConflict(_ ev: EventItem) -> Bool {
        for other in eventsForDay {
            if other.id == ev.id { continue }
            if overlaps(ev, other) { return true }
        }
        return false
    }

    func overlaps(_ a: EventItem, _ b: EventItem) -> Bool {
        let aStart = a.startMinute
        let aEnd = a.startMinute + a.durationMinute
        let bStart = b.startMinute
        let bEnd = b.startMinute + b.durationMinute
        return max(aStart, bStart) < min(aEnd, bEnd)
    }

    // Auto Scroll
    func autoScrollTarget(now: Int) -> EventItem? {
        guard !eventsForDay.isEmpty else { return nil }

        if selectedDay == weekdayIndexToday() {
            if let live = eventsForDay.first(where: { ev in
                let s = ev.startMinute
                let e = ev.startMinute + ev.durationMinute
                return now >= s && now < e
            }) { return live }

            if let next = eventsForDay.first(where: { $0.startMinute > now }) {
                return next
            }
        }
        return eventsForDay.first
    }

    func autoScrollIfNeeded(proxy: ScrollViewProxy) {
        let now = currentMinuteOfDay()
        guard let target = autoScrollTarget(now: now) else { return }

        if lastAutoScrollTargetID == target.id { return }
        lastAutoScrollTargetID = target.id

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(target.id, anchor: .center)
            }
        }
    }
}

// MARK: - Share
private extension WeekView {

    func shareDay() { presentShare(text: shareTextForSelectedDay()) }

    func shareWeek() {
        let parts: [String] = (0..<7).map { day in shareTextForDay(day) }
        presentShare(text: parts.joined(separator: "\n\n"))
    }

    func presentShare(text: String) {
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(vc, animated: true)
        }
    }

    func shareTextForSelectedDay() -> String { shareTextForDay(selectedDay) }

    func shareTextForDay(_ day: Int) -> String {
        let d = max(0, min(6, day))
        let dayName = dayTitles[d]

        let items = allEvents
            .filter { $0.weekday == d }
            .sorted { $0.startMinute < $1.startMinute }

        if items.isEmpty { return "📅 \(dayName) — Ders yok" }

        let lines = items.map { ev in
            let start = hm(ev.startMinute)
            let end = hm(ev.startMinute + ev.durationMinute)
            let loc = (ev.location ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let locText = loc.isEmpty ? "" : " • \(loc)"
            return "• \(start)–\(end)  \(ev.title)\(locText)"
        }

        return """
        📅 \(dayName) Programım

        \(lines.joined(separator: "\n"))

        (DailyTodo ile oluşturuldu)
        """
    }

    func showCopiedToast() {
        withAnimation { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { showCopied = false }
        }
    }
}

// MARK: - Next Class Section

// MARK: - Row (senin mevcut EventRow aynen kalsın)
private struct EventRow: View {

    @State private var pulse: Bool = false

    let event: EventItem
    let timeText: String
    let hasConflict: Bool
    let nowMinute: Int
    let isTodaySelected: Bool

    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var start: Int { event.startMinute }
    private var end: Int { event.startMinute + event.durationMinute }
    private var duration: Int { max(1, event.durationMinute) }

    private var isLive: Bool {
        guard isTodaySelected else { return false }
        return nowMinute >= start && nowMinute < end
    }

    private var isUpNext: Bool {
        guard isTodaySelected else { return false }
        return nowMinute < start && (start - nowMinute) <= 15
    }

    private var isSoon: Bool {
        guard isTodaySelected else { return false }
        let diff = start - nowMinute
        return diff > 0 && diff <= 5
    }

    private var isDone: Bool {
        guard isTodaySelected else { return false }
        return nowMinute >= end
    }

    private var progress: Double {
        guard isLive else { return 0 }
        return min(1, max(0, Double(nowMinute - start) / Double(duration)))
    }

    private var minutesLeft: Int { max(0, end - nowMinute) }
    private var minutesUntilStart: Int { max(0, start - nowMinute) }

    private func hm(_ minute: Int) -> String {
        let m = max(0, min(1439, minute))
        let h = m / 60
        let mm = m % 60
        return String(format: "%02d:%02d", h, mm)
    }

    var body: some View {

        let baseColor = Color(hex: event.colorHex)

        let accent: Color = {
            if isDone { return Color.secondary.opacity(0.55) }
            if isSoon { return .orange }
            return baseColor
        }()

        let bg: Color = {
            if isDone { return Color.secondary.opacity(0.06) }
            return accent.opacity(isLive ? 0.16 : (isUpNext ? 0.13 : 0.10))
        }()

        let strokeColor: Color = {
            if hasConflict { return .red.opacity(0.40) }
            if isDone { return .secondary.opacity(0.14) }
            if isLive { return accent.opacity(0.55) }
            if isSoon { return .orange.opacity(0.70) }
            if isUpNext { return accent.opacity(0.35) }
            return .secondary.opacity(0.10)
        }()

        let strokeWidth: CGFloat =
            hasConflict ? 1.6 :
            (isLive ? 2.0 :
             (isSoon ? 2.0 :
              (isUpNext ? 1.4 : 1.0)))

        let mainTextOpacity: Double = isDone ? 0.55 : 1.0
        let secondaryTextOpacity: Double = isDone ? 0.55 : 1.0

        HStack(spacing: 12) {

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(1.0), accent.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: isLive ? 10 : 8)
                .shadow(radius: isLive ? 10 : 6)
                .padding(.vertical, 10)
                .opacity(isDone ? 0.75 : 1.0)

            VStack(alignment: .leading, spacing: 10) {

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(event.title)
                        .font(.headline)
                        .lineLimit(1)
                        .opacity(mainTextOpacity)

                    if isLive {
                        Text("Şu an")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(accent.opacity(0.25)))
                            .overlay(Capsule().stroke(accent.opacity(0.45), lineWidth: 1))
                    } else if isSoon {
                        Text("5 dk kaldı")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.orange.opacity(0.22)))
                            .overlay(Capsule().stroke(Color.orange.opacity(0.55), lineWidth: 1))
                    } else if isDone {
                        Text("Bitti")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.secondary.opacity(0.12)))
                            .overlay(Capsule().stroke(Color.secondary.opacity(0.18), lineWidth: 1))
                            .opacity(0.9)
                    }

                    Spacer()

                    if hasConflict {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                            .accessibilityLabel("Çakışma var")
                    }

                    Text(timeText)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(isDone ? Color.secondary.opacity(0.10) : accent.opacity(isLive ? 0.25 : 0.18)))
                        .overlay(Capsule().stroke(isDone ? Color.secondary.opacity(0.16) : accent.opacity(isLive ? 0.40 : 0.25), lineWidth: 1))
                        .opacity(secondaryTextOpacity)
                }

                HStack(spacing: 8) {
                    if let loc = event.location,
                       !loc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Label(loc, systemImage: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.secondary.opacity(0.10)))
                            .opacity(secondaryTextOpacity)
                    }

                    Spacer()

                    Text("\(max(15, event.durationMinute)) dk")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .opacity(secondaryTextOpacity)
                }

                if isLive {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: progress)
                            .tint(baseColor)
                            .animation(.smooth, value: progress)

                        HStack(spacing: 8) {
                            Image(systemName: "hourglass")
                                .font(.caption2)
                                .foregroundStyle(baseColor)

                            Text("%\(Int(progress * 100)) tamamlandı")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text("\(minutesLeft) dk kaldı")
                                .font(.caption2.weight(.semibold))

                            Text("• bitiyor: \(hm(end))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if isUpNext {
                    HStack(spacing: 8) {
                        Text("\(minutesUntilStart) dk")
                            .font(.caption2.weight(.bold))
                            .monospacedDigit()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill((isDone ? Color.secondary.opacity(0.10) : accent.opacity(0.18))))
                            .overlay(Capsule().stroke((isDone ? Color.secondary.opacity(0.16) : accent.opacity(0.28)), lineWidth: 1))
                            .opacity(secondaryTextOpacity)

                        Text("sonra (\(hm(start))) başlıyor")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .opacity(secondaryTextOpacity)

                        Spacer()
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(bg)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isLive ? 0.14 : 0.10),
                                    Color.white.opacity(0.00)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(strokeColor, lineWidth: strokeWidth)
        )
        .shadow(color: isLive ? baseColor.opacity(0.40) : .clear, radius: isLive ? 14 : 0)
        .shadow(color: isSoon ? Color.orange.opacity(0.30) : .clear, radius: isSoon ? 10 : 0)
        .shadow(radius: isLive ? 8 : 0)
        .scaleEffect(isLive && pulse ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = isLive }
        .onChange(of: isLive) { _, newValue in pulse = newValue }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowSeparator(.hidden)
        .contentShape(Rectangle())
        .onTapGesture { Haptics.impact(.light); onTap() }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button { Haptics.impact(.light); onEdit() } label: {
                Label("Düzenle", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Haptics.impact(.heavy)
                onDelete()
            } label: {
                Label("Sil", systemImage: "trash")
            }
        }
    }
}

// MARK: - Hex Color
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
