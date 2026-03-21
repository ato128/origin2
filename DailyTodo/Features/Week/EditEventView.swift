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
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var friendStore: FriendStore

    private let dayTitles = ["Pzt","Sal","Çar","Per","Cum","Cmt","Paz"]

    private let colorPalette: [(name: String, hex: String)] = [
        ("Mavi", "#3B82F6"),
        ("Mor", "#8B5CF6"),
        ("Pembe", "#EC4899"),
        ("Turuncu", "#F97316"),
        ("Yeşil", "#22C55E"),
        ("Kırmızı", "#EF4444"),
        ("Gri", "#64748B")
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
            .navigationTitle("Düzenle")
            .toolbar { toolbarContent }
            .onAppear { loadFromEvent() }
            .confirmationDialog(
                "Etkinlik silinsin mi?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Sil", role: .destructive) {
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

                Button("İptal", role: .cancel) { }
            }
            .alert("Çakışma var", isPresented: $showConflictAlert) {
                Button("İptal", role: .cancel) { }
                Button("Yine de Kaydet") { saveIgnoringConflicts() }
            } message: {
                Text(conflictSummary)
            }
    }

    // MARK: - UI pieces

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
                Button("Kapat") { dismiss() }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Kaydet") { trySaveWithConflictCheck() }
                    .disabled(!canSave)
            }
        }
    }

    private var sectionMain: some View {
        Section("Ders / Etkinlik") {
            TextField("Başlık", text: $title)
            TextField("Konum (opsiyonel)", text: $location)
        }
    }

    private var sectionDayTime: some View {
        Section("Gün & Saat") {
            Picker("Gün", selection: $weekday) {
                ForEach(0..<7, id: \.self) { i in
                    Text(dayTitles[i]).tag(i)
                }
            }

            DatePicker("Başlangıç", selection: $startTime, displayedComponents: [.hourAndMinute])
            DatePicker("Bitiş", selection: $endTime, displayedComponents: [.hourAndMinute])

            Text("Süre: \(durationText)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var sectionColor: some View {
        Section("Renk") {
            Picker("Renk", selection: $selectedColorHex) {
                ForEach(colorPalette, id: \.hex) { c in
                    HStack {
                        Circle()
                            .fill(colorFromHex(c.hex))
                            .frame(width: 12, height: 12)

                        Text(c.name)
                    }
                    .tag(c.hex)
                }
            }
        }
    }

    private var sectionNotes: some View {
        Section("Not") {
            TextField("Not (opsiyonel)", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private var sectionDuplicate: some View {
        Section("Kopyala") {
            Button {
                duplicateSameDay()
            } label: {
                Label("Aynısını kopyala", systemImage: "doc.on.doc")
            }

            Menu {
                ForEach(0..<7, id: \.self) { d in
                    Button(dayTitles[d]) { duplicateToDay(d) }
                }
            } label: {
                Label("Başka güne kopyala", systemImage: "calendar.badge.plus")
            }
        }
    }

    private var sectionDelete: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Sil", systemImage: "trash")
            }
        }
    }

    // MARK: - Load

    private func loadFromEvent() {
        title = event.title
        weekday = event.weekday
        location = event.location ?? ""
        notes = event.notes ?? ""
        selectedColorHex = event.colorHex.isEmpty ? "#3B82F6" : event.colorHex

        startTime = dateFromMinutes(event.startMinute)
        endTime = dateFromMinutes(event.startMinute + event.durationMinute)
    }

    // MARK: - Save helpers

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

        if h == 0 { return "\(m) dk" }
        if m == 0 { return "\(h) saat" }
        return "\(h) saat \(m) dk"
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

    // MARK: - Conflict Check

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
            conflictSummary += "\n+ \(conflicts.count - 4) daha"
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

    // MARK: - Duplicate

    private func duplicateSameDay() {
        let copy = EventItem(
            ownerUserID: event.ownerUserID,
            title: event.title,
            weekday: event.weekday,
            startMinute: event.startMinute,
            durationMinute: event.durationMinute,
            scheduledDate: event.scheduledDate,
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
            scheduledDate: event.scheduledDate,
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

    // MARK: - Shared week sync

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

    // MARK: - Small helpers

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
}
