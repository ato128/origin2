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
            ZStack {
                UpdoTheme.background
                    .ignoresSafeArea()

                Circle()
                    .fill(UpdoTheme.cyan.opacity(0.07))
                    .frame(width: 280, height: 280)
                    .blur(radius: 90)
                    .offset(x: 150, y: -260)
                    .ignoresSafeArea()

                Circle()
                    .fill(UpdoTheme.purple.opacity(0.09))
                    .frame(width: 320, height: 320)
                    .blur(radius: 100)
                    .offset(x: -170, y: 380)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        summaryCard
                        previewSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }

                VStack {
                    Spacer()
                    importBar
                }
            }
            .navigationTitle(tr("import_nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("common_cancel")) { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(UpdoTheme.cyan)
    }

    private var summaryCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(UpdoTheme.cyan.opacity(0.15))
                    .frame(width: 52, height: 52)

                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(UpdoTheme.cyan)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(export.events.count) \(tr("import_events"))")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("\(tr("import_created")): \(export.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(cardBackground)
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("import_preview_caps"))
                .font(.system(size: 12, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.secondary.opacity(0.82))
                .padding(.leading, 2)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                ForEach(previewItems, id: \.id) { row in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(UpdoTheme.cyan.opacity(0.7))
                            .frame(width: 3, height: 34)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(row.title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Text(row.meta)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(cardBackground)
                }

                if export.events.count > previewItems.count {
                    Text("+ \(export.events.count - previewItems.count) \(tr("import_more_events"))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                }
            }
        }
    }

    private var importBar: some View {
        Button {
            Haptics.notify(.success)
            importAll()
        } label: {
            HStack(spacing: 8) {
                if importing {
                    ProgressView().tint(.black)
                } else {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 16, weight: .bold))
                }

                Text(importing ? tr("import_importing") : tr("import_action"))
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [UpdoTheme.cyan, Color(arenaHex: "#22D3EE")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: UpdoTheme.cyan.opacity(0.3), radius: 14, y: 6)
            .opacity(export.events.isEmpty ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(importing || export.events.isEmpty)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [UpdoTheme.background.opacity(0), UpdoTheme.background.opacity(0.85), UpdoTheme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.045))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
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
        return localizedWeekdayShort(i)
    }
}
