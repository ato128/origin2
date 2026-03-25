//
//  EditEventView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import SwiftUI
import SwiftData

struct EditEventView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var friendStore: FriendStore

    private let colorPalette: [(nameKey: String, hex: String)] = [
        ("event_color_blue", "#3B82F6"),
        ("event_color_purple", "#8B5CF6"),
        ("event_color_pink", "#EC4899"),
        ("event_color_orange", "#F97316"),
        ("event_color_green", "#22C55E"),
        ("event_color_red", "#EF4444"),
        ("event_color_gray", "#64748B")
    ]

    let event: EventItem

    @State private var title: String = ""
    @State private var weekday: Int = 0
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var selectedColorHex: String = "#3B82F6"

    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()

    @State private var showConflictAlert: Bool = false
    @State private var conflictSummary: String = ""
    @State private var showDeleteConfirm: Bool = false

    var body: some View {
        formContent
            .navigationTitle("event_edit_title")
            .toolbar { toolbarContent }
            .onAppear { loadFromEvent() }
            .confirmationDialog(
                String(localized: "event_delete_confirm_title"),
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("event_delete", role: .destructive) {
                    Haptics.impact(.heavy)

                    Task {
                        await NotificationManager.shared.cancel(for: event)
                    }

                    context.delete(event)

                    do {
                        try context.save()
                        WidgetAppSync.refreshFromSwiftData(context: context)

                        Task {
                            await resyncSharedWeek()
                        }

                        dismiss()
                    } catch {
                        print("Delete error:", error)
                    }
                }

                Button("week_cancel", role: .cancel) { }
            }
            .alert("event_conflict_title", isPresented: $showConflictAlert) {
                Button("week_cancel", role: .cancel) { }
                Button("event_save_anyway") { saveIgnoringConflicts() }
            } message: {
                Text(conflictSummary)
            }
    }

    private var formContent: some View {
        Form {
            sectionMain
            sectionDayTime
            sectionColor
            sectionNotes
            sectionDuplicate
            sectionDelete
        }
    }

    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .topBarLeading) {
                Button("event_close") { dismiss() }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("event_save") { trySaveWithConflictCheck() }
                    .disabled(!canSave)
            }
        }
    }

    private var sectionMain: some View {
        Section("event_section_class_or_event") {
            TextField(String(localized: "event_title_placeholder"), text: $title)
            TextField(String(localized: "event_location_optional"), text: $location)
        }
    }

    private var sectionDayTime: some View {
        Section("event_section_day_time") {
            Picker("event_day", selection: $weekday) {
                ForEach(0..<7, id: \.self) { i in
                    Text(localizedDayTitle(i)).tag(i)
                }
            }

            DatePicker("event_start", selection: $startTime, displayedComponents: [.hourAndMinute])
            DatePicker("event_end", selection: $endTime, displayedComponents: [.hourAndMinute])

            Text("\(String(localized: "event_duration")): \(durationText)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var sectionColor: some View {
        Section("event_section_color") {
            Picker("event_color", selection: $selectedColorHex) {
                ForEach(colorPalette, id: \.hex) { c in
                    HStack {
                        Circle()
                            .fill(colorFromHex(c.hex))
                            .frame(width: 12, height: 12)

                        Text(LocalizedStringKey(c.nameKey))
                    }
                    .tag(c.hex)
                }
            }
        }
    }

    private var sectionNotes: some View {
        Section("event_section_note") {
            TextField(String(localized: "event_note_optional"), text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private var sectionDuplicate: some View {
        Section("event_duplicate_section") {
            Button {
                duplicateSameDay()
            } label: {
                Label("event_duplicate_same_day", systemImage: "doc.on.doc")
            }

            Menu {
                ForEach(0..<7, id: \.self) { d in
                    Button(localizedDayTitle(d)) { duplicateToDay(d) }
                }
            } label: {
                Label("event_duplicate_to_another_day", systemImage: "calendar.badge.plus")
            }
        }
    }

    private var sectionDelete: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("event_delete", systemImage: "trash")
            }
        }
    }

    private func loadFromEvent() {
        title = event.title
        weekday = event.weekday
        location = event.location ?? ""
        notes = event.notes ?? ""
        selectedColorHex = event.colorHex.isEmpty ? "#3B82F6" : event.colorHex

        startTime = dateFromMinutes(event.startMinute)
        endTime = dateFromMinutes(event.startMinute + event.durationMinute)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && durationMinute >= 15
    }

    private var durationMinute: Int {
        let s = minutesFrom(startTime)
        let e = minutesFrom(endTime)
        return max(0, e - s)
    }

    private var durationText: String {
        let d = durationMinute
        if d <= 0 { return "—" }

        let h = d / 60
        let m = d % 60

        if locale.language.languageCode?.identifier == "tr" {
            if h == 0 { return "\(m) dk" }
            if m == 0 { return "\(h) saat" }
            return "\(h) saat \(m) dk"
        } else {
            if h == 0 { return "\(m) min" }
            if m == 0 { return "\(h) hr" }
            return "\(h) hr \(m) min"
        }
    }

    private func localizedDayTitle(_ day: Int) -> String {
        let safeDay = max(0, min(6, day))
        let isTR = locale.language.languageCode?.identifier == "tr"

        if isTR {
            switch safeDay {
            case 0: return "Pzt"
            case 1: return "Sal"
            case 2: return "Çar"
            case 3: return "Per"
            case 4: return "Cum"
            case 5: return "Cmt"
            default: return "Paz"
            }
        } else {
            switch safeDay {
            case 0: return "Mon"
            case 1: return "Tue"
            case 2: return "Wed"
            case 3: return "Thu"
            case 4: return "Fri"
            case 5: return "Sat"
            default: return "Sun"
            }
        }
    }

    private func minutesFrom(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        let h = c.hour ?? 0
        let m = c.minute ?? 0
        return max(0, min(1439, h * 60 + m))
    }

    private func dateFromMinutes(_ minute: Int) -> Date {
        let m = max(0, min(1439, minute))
        let h = m / 60
        let mm = m % 60
        return Calendar.current.date(bySettingHour: h, minute: mm, second: 0, of: Date()) ?? Date()
    }

    private func buildScheduledDate(for weekday: Int, startMinute: Int) -> Date? {
        let calendar = Calendar.current
        let hour = startMinute / 60
        let minute = startMinute % 60

        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)
        let todayWeekday = (calendar.component(.weekday, from: today) + 5) % 7
        let diff = weekday - todayWeekday

        guard let targetDate = calendar.date(byAdding: .day, value: diff, to: startOfToday) else {
            return nil
        }

        return calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: targetDate
        )
    }

    private func trySaveWithConflictCheck() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let start = minutesFrom(startTime)
        let end = start + durationMinute

        let descriptor = FetchDescriptor<EventItem>(
            predicate: #Predicate { $0.weekday == weekday },
            sortBy: [SortDescriptor(\EventItem.startMinute, order: .forward)]
        )

        let sameDay = (try? context.fetch(descriptor)) ?? []

        let conflicts = sameDay.filter { ev in
            if ev.id == event.id { return false }

            let evStart = ev.startMinute
            let evEnd = ev.startMinute + ev.durationMinute
            return max(start, evStart) < min(end, evEnd)
        }

        if conflicts.isEmpty {
            applyAndSave(title: t, start: start, dur: durationMinute)
            Haptics.notify(.success)
            dismiss()
            return
        }

        conflictSummary = conflicts
            .prefix(4)
            .map { "\($0.title) (\(hm($0.startMinute))–\(hm($0.startMinute + $0.durationMinute)))" }
            .joined(separator: "\n")

        if conflicts.count > 4 {
            if locale.language.languageCode?.identifier == "tr" {
                conflictSummary += "\n+ \(conflicts.count - 4) daha"
            } else {
                conflictSummary += "\n+ \(conflicts.count - 4) more"
            }
        }

        showConflictAlert = true
    }

    private func saveIgnoringConflicts() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let start = minutesFrom(startTime)
        applyAndSave(title: t, start: start, dur: durationMinute)
        dismiss()
    }

    private func applyAndSave(title: String, start: Int, dur: Int) {
        event.title = title
        event.weekday = weekday
        event.startMinute = start
        event.durationMinute = dur
        event.scheduledDate = rebuiltScheduledDate(weekday: weekday, startMinute: start)
        event.location = location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : location
        event.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        event.colorHex = selectedColorHex

        do {
            try context.save()
            WidgetAppSync.refreshFromSwiftData(context: context)

            Task {
                await NotificationManager.shared.cancel(for: event)
                await NotificationManager.shared.schedule(for: event, minutesBefore: 10)
                await NotificationManager.shared.schedule(for: event, minutesBefore: 0)
            }

            Task {
                await resyncSharedWeek()
            }
        } catch {
            print("Edit save error:", error)
        }
    }

    private func duplicateSameDay() {
        let copy = EventItem(
            ownerUserID: event.ownerUserID,
            title: event.title,
            weekday: event.weekday,
            startMinute: event.startMinute,
            durationMinute: event.durationMinute,
            scheduledDate: buildScheduledDate(for: event.weekday, startMinute: event.startMinute),
            location: event.location,
            notes: event.notes,
            colorHex: event.colorHex
        )

        context.insert(copy)

        do {
            try context.save()
            WidgetAppSync.refreshFromSwiftData(context: context)

            Task {
                await NotificationManager.shared.cancel(for: copy)
                await NotificationManager.shared.schedule(for: copy, minutesBefore: 10)
                await NotificationManager.shared.schedule(for: copy, minutesBefore: 0)
            }

            Task {
                await resyncSharedWeek()
            }

            dismiss()
        } catch {
            print("Duplicate same day error:", error)
        }
    }

    private func duplicateToDay(_ day: Int) {
        let d = max(0, min(6, day))

        let copy = EventItem(
            ownerUserID: event.ownerUserID,
            title: event.title,
            weekday: d,
            startMinute: event.startMinute,
            durationMinute: event.durationMinute,
            scheduledDate: rebuiltScheduledDate(weekday: d, startMinute: event.startMinute),
            location: event.location,
            notes: event.notes,
            colorHex: event.colorHex
        )

        context.insert(copy)

        do {
            try context.save()
            WidgetAppSync.refreshFromSwiftData(context: context)

            Task {
                await NotificationManager.shared.cancel(for: copy)
                await NotificationManager.shared.schedule(for: copy, minutesBefore: 10)
                await NotificationManager.shared.schedule(for: copy, minutesBefore: 0)
            }

            Task {
                await resyncSharedWeek()
            }

            dismiss()
        } catch {
            print("Duplicate to day error:", error)
        }
    }

    private func resyncSharedWeek() async {
        guard let currentUserID = session.currentUser?.id else { return }

        let descriptor = FetchDescriptor<EventItem>(
            sortBy: [SortDescriptor(\EventItem.startMinute, order: .forward)]
        )

        let all = (try? context.fetch(descriptor)) ?? []
        let currentUserEvents = all.filter { $0.ownerUserID == currentUserID.uuidString }

        await friendStore.resyncSharedWeekIfNeeded(
            for: currentUserID,
            events: currentUserEvents
        )
    }

    private func hm(_ minute: Int) -> String {
        let m = max(0, minute)
        let h = m / 60
        let mm = m % 60
        return String(format: "%02d:%02d", h, mm)
    }

    private func colorFromHex(_ hex: String) -> Color {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        guard hexSanitized.count == 6 else { return .accentColor }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        return Color(red: r, green: g, blue: b)
    }

    private func rebuiltScheduledDate(weekday: Int, startMinute: Int) -> Date? {
        let calendar = Calendar.current
        let safeWeekday = max(0, min(6, weekday))
        let mondayOffset = (calendar.component(.weekday, from: Date()) + 5) % 7
        let startOfToday = calendar.startOfDay(for: Date())
        let mondayStart = calendar.date(byAdding: .day, value: -mondayOffset, to: startOfToday) ?? startOfToday

        guard let targetDay = calendar.date(byAdding: .day, value: safeWeekday, to: mondayStart) else {
            return nil
        }

        let hour = startMinute / 60
        let minute = startMinute % 60

        return calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: targetDay
        )
    }
}
