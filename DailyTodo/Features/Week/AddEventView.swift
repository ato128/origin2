//
//  AddEventView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import SwiftUI
import SwiftData

struct AddEventView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject var session: SessionStore

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

    let defaultWeekday: Int
    let defaultDate: Date?

    @State private var title: String = ""
    @State private var weekday: Int = 0
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var selectedColorHex: String = "#3B82F6"

    @State private var startTime: Date =
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()

    @State private var endTime: Date =
        Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()

    @State private var showConflictAlert: Bool = false
    @State private var conflictSummary: String = ""

    var body: some View {
        Form {

            Section("Ders / Etkinlik") {
                TextField("Başlık", text: $title)
                TextField("Konum (opsiyonel)", text: $location)
            }

            Section("Gün & Saat") {
                Picker("Gün", selection: $weekday) {
                    ForEach(0..<7, id: \.self) { i in
                        Text(dayTitles[i]).tag(i)
                    }
                }

                DatePicker(
                    "Başlangıç",
                    selection: $startTime,
                    displayedComponents: [.hourAndMinute]
                )

                DatePicker(
                    "Bitiş",
                    selection: $endTime,
                    displayedComponents: [.hourAndMinute]
                )

                Text("Süre: \(durationText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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

            Section("Not") {
                TextField("Not (opsiyonel)", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle("Ekle")
        .toolbar {

            ToolbarItem(placement: .topBarLeading) {
                Button("İptal") { dismiss() }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Kaydet") {
                    trySaveWithConflictCheck()
                }
                .disabled(!canSave)
            }
        }
        .onAppear {
            applyDefaultDateIfNeeded()

            if selectedColorHex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                selectedColorHex = "#3B82F6"
            }
        }
        .alert("Çakışma var", isPresented: $showConflictAlert) {

            Button("İptal", role: .cancel) { }

            Button("Yine de Kaydet") {
                saveIgnoringConflicts()
            }

        } message: {
            Text(conflictSummary)
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && durationMinute >= 15
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

    private func applyDefaultDateIfNeeded() {
        let calendar = Calendar.current

        if let defaultDate {
            let comps = calendar.dateComponents([.weekday, .hour, .minute], from: defaultDate)

            let systemWeekday = comps.weekday ?? 2
            weekday = (systemWeekday + 5) % 7

            let hour = comps.hour ?? 9
            let minute = comps.minute ?? 0

            startTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: defaultDate) ?? defaultDate
            endTime = calendar.date(byAdding: .minute, value: 60, to: startTime) ?? startTime.addingTimeInterval(3600)
        } else {
            weekday = max(0, min(6, defaultWeekday))
        }
    }

    private func trySaveWithConflictCheck() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let start = minutesFrom(startTime)
        let end = start + durationMinute

        let descriptor = FetchDescriptor<EventItem>(
            predicate: #Predicate { $0.weekday == weekday },
            sortBy: [SortDescriptor(\EventItem.startMinute, order: .forward)]
        )

        let sameDayAll: [EventItem] = (try? context.fetch(descriptor)) ?? []
        let sameDay: [EventItem]

        if let currentUserID = session.currentUser?.id {
            sameDay = sameDayAll.filter { $0.ownerUserID == currentUserID }
        } else {
            sameDay = []
        }

        let conflicts = sameDay.filter { ev in
            let evStart = ev.startMinute
            let evEnd = ev.startMinute + ev.durationMinute

            return intervalsOverlap(
                startA: start,
                endA: end,
                startB: evStart,
                endB: evEnd
            )
        }

        if conflicts.isEmpty {
            insertEvent(title: t, start: start, dur: durationMinute)
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

        insertEvent(title: t, start: start, dur: durationMinute)
        dismiss()
    }

    private func insertEvent(title: String, start: Int, dur: Int) {
        let scheduledDate = buildScheduledDate(startMinute: start)

        let ev = EventItem(
            ownerUserID: session.currentUser?.id,
            title: title,
            weekday: weekday,
            startMinute: start,
            durationMinute: dur,
            scheduledDate: scheduledDate,
            location: location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : location,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
            colorHex: selectedColorHex
        )

        context.insert(ev)

        do {
            try context.save()

            WidgetAppSync.refreshFromSwiftData(context: context)

            Task {
                await NotificationManager.shared.schedule(for: ev, minutesBefore: 5)
            }

        } catch {
            print("Save error:", error)
        }
    }

    private func buildScheduledDate(startMinute: Int) -> Date? {
        let calendar = Calendar.current
        let hour = startMinute / 60
        let minute = startMinute % 60

        if let defaultDate {
            return calendar.date(
                bySettingHour: hour,
                minute: minute,
                second: 0,
                of: defaultDate
            )
        }

        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start,
              let targetDate = calendar.date(byAdding: .day, value: weekday, to: startOfWeek)
        else {
            return nil
        }

        return calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: targetDate
        )
    }

    private func intervalsOverlap(
        startA: Int,
        endA: Int,
        startB: Int,
        endB: Int
    ) -> Bool {
        return max(startA, startB) < min(endA, endB)
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
}
