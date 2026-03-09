//
//  ImportScheduleView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 3.03.2026.
//

import SwiftUI
import SwiftData

struct ImportScheduleView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let export: ScheduleExport

    @State private var importing = false

    var body: some View {
        NavigationStack {
            List {
                Section("Özet") {
                    Text("Etkinlik sayısı: \(export.events.count)")
                    Text("Oluşturulma: \(export.createdAt.formatted(date: .abbreviated, time: .shortened))")
                }

                Section("Önizleme") {
                    ForEach(previewItems, id: \.id) { row in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(row.title).font(.headline)
                            Text(row.meta).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Button {
                        Haptics.notify(.success)
                        importAll()
                    } label: {
                        Label(importing ? "İçe aktarılıyor..." : "İçe aktar", systemImage: "tray.and.arrow.down.fill")
                    }
                    .disabled(importing || export.events.isEmpty)

                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Text("Vazgeç")
                    }
                }
            }
            .navigationTitle("Programı İçe Aktar")
        }
    }

    private var previewItems: [(id: String, title: String, meta: String)] {
        export.events.prefix(12).map { ev in
            let start = hm(ev.startMinute)
            let end = hm(ev.startMinute + ev.durationMinute)
            let day = dayTitle(ev.weekday)
            let loc = (ev.location ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let locText = loc.isEmpty ? "" : " • \(loc)"
            return (UUID().uuidString, ev.title, "\(day) • \(start)–\(end)\(locText)")
        }
    }

    private func importAll() {
        importing = true

        for ev in export.events {
            let item = EventItem(
                title: ev.title,
                weekday: max(0, min(6, ev.weekday)),
                startMinute: max(0, min(1439, ev.startMinute)),
                durationMinute: max(15, ev.durationMinute),
                location: ev.location,
                notes: ev.notes,
                colorHex: ev.colorHex.isEmpty ? "#3B82F6" : ev.colorHex
            )
            context.insert(item)
        }

        try? context.save()
        WidgetAppSync.refreshFromSwiftData(context: context)
        importing = false
        dismiss()
    }

    private func hm(_ minute: Int) -> String {
        let m = max(0, min(1439, minute))
        let h = m / 60
        let mm = m % 60
        return String(format: "%02d:%02d", h, mm)
    }

    private func dayTitle(_ i: Int) -> String {
        let titles = ["Pzt","Sal","Çar","Per","Cum","Cmt","Paz"]
        return titles[max(0, min(6, i))]
    }
}
