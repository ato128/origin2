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

    @Namespace private var daySelectionNamespace

    var body: some View {
        NavigationStack {
            ZStack {
                // Updo identity background: deep navy + soft accent glows
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
                        headerSection
                        mainSection
                        dayTimeSection
                        colorSection
                        notesSection
                        duplicateSection
                        deleteSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(tr("event_edit_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onAppear { loadFromEvent() }
            .confirmationDialog(
                String(localized: "event_delete_confirm_title"),
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(tr("event_delete"), role: .destructive) {
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
                        Log.debug("Delete error:", error)
                    }
                }

                Button(tr("week_cancel"), role: .cancel) { }
            }
            .alert("event_conflict_title", isPresented: $showConflictAlert) {
                Button(tr("week_cancel"), role: .cancel) { }
                Button(tr("event_save_anyway")) { saveIgnoringConflicts() }
            } message: {
                Text(conflictSummary)
            }
        }
        .preferredColorScheme(.dark)
        .tint(UpdoTheme.cyan)
    }

    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .topBarLeading) {
                Button(tr("event_close")) { dismiss() }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(tr("event_save")) { trySaveWithConflictCheck() }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("event_edit_title"))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    summaryPill(
                        icon: "calendar",
                        text: localizedDayTitle(weekday),
                        tint: colorFromHex(selectedColorHex)
                    )

                    summaryPill(
                        icon: "clock",
                        text: "\(hm(minutesFrom(startTime)))–\(hm(minutesFrom(endTime)))",
                        tint: .secondary
                    )

                    summaryPill(
                        icon: "timer",
                        text: durationText,
                        tint: .orange
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mainSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel(String(localized: "event_section_class_or_event"))

            VStack(spacing: 12) {
                styledField(String(localized: "event_title_placeholder"), text: $title)
                styledField(String(localized: "event_location_optional"), text: $location)
            }
            .padding(16)
            .background(sectionCardBackground)
        }
    }

    private var dayTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(String(localized: "event_section_day_time"))

            VStack(spacing: 14) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0..<7, id: \.self) { i in
                            dayChip(i)
                        }
                    }
                    .padding(.horizontal, 2)
                }

                Divider().overlay(Color.white.opacity(0.06))

                DatePicker(
                    "event_start",
                    selection: $startTime,
                    displayedComponents: [.hourAndMinute]
                )
                .font(.system(size: 15, weight: .semibold))

                DatePicker(
                    "event_end",
                    selection: $endTime,
                    displayedComponents: [.hourAndMinute]
                )
                .font(.system(size: 15, weight: .semibold))

                HStack {
                    Text(tr("event_duration"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(durationText)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                }
            }
            .padding(16)
            .background(sectionCardBackground)
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(String(localized: "event_section_color"))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(colorPalette, id: \.hex) { c in
                        let isSelected = selectedColorHex == c.hex

                        Button {
                            HapticManager.shared.selection()
                            selectedColorHex = c.hex
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(colorFromHex(c.hex))
                                    .frame(width: 30, height: 30)

                                if isSelected {
                                    Circle()
                                        .stroke(Color.white.opacity(0.95), lineWidth: 2.2)
                                        .frame(width: 38, height: 38)

                                    Circle()
                                        .stroke(colorFromHex(c.hex).opacity(0.22), lineWidth: 6)
                                        .frame(width: 44, height: 44)
                                }
                            }
                            .frame(width: 46, height: 46)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(String(localized: "event_section_note"))

            TextField(
                String(localized: "event_note_optional"),
                text: $notes,
                axis: .vertical
            )
            .lineLimit(3...6)
            .textInputAutocapitalization(.sentences)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.04), lineWidth: 1)
                    )
            )
        }
    }

    private var duplicateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(String(localized: "event_duplicate_section"))

            VStack(spacing: 10) {
                Button {
                    duplicateSameDay()
                } label: {
                    actionRow(icon: "doc.on.doc", titleKey: "event_duplicate_same_day", tint: UpdoTheme.cyan)
                }
                .buttonStyle(.plain)

                Menu {
                    ForEach(0..<7, id: \.self) { d in
                        Button(localizedDayTitle(d)) { duplicateToDay(d) }
                    }
                } label: {
                    actionRow(icon: "calendar.badge.plus", titleKey: "event_duplicate_to_another_day", tint: UpdoTheme.cyan)
                }
            }
        }
    }

    private var deleteSection: some View {
        Button(role: .destructive) {
            HapticManager.shared.selection()
            showDeleteConfirm = true
        } label: {
            actionRow(icon: "trash", titleKey: "event_delete", tint: Color(arenaHex: "#EF4444"))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - Building Blocks

    private func dayChip(_ i: Int) -> some View {
        let isSelected = weekday == i

        return Button {
            HapticManager.shared.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                weekday = i
            }
        } label: {
            Text(localizedDayTitle(i))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isSelected ? .black : .white.opacity(0.6))
                .frame(width: 52, height: 40)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(UpdoTheme.cyan)
                            .matchedGeometryEffect(id: "day-selection-pill", in: daySelectionNamespace)
                    } else {
                        Capsule()
                            .fill(Color.white.opacity(0.05))
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func styledField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 16, weight: .semibold))
            .textInputAutocapitalization(.sentences)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.04), lineWidth: 1)
                    )
            )
    }

    private func actionRow(icon: String, titleKey: LocalizedStringKey, tint: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 38, height: 38)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Text(titleKey)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(sectionCardBackground)
    }

    private func summaryPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))

            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(tint.opacity(0.14))
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(0.16), lineWidth: 1)
                )
        )
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(.secondary.opacity(0.82))
            .padding(.leading, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sectionCardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(0.045))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
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

        if !appLanguageIsEnglish() {
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
        let isTR = !appLanguageIsEnglish()

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
            if !appLanguageIsEnglish() {
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
            Log.debug("Edit save error:", error)
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
            Log.debug("Duplicate same day error:", error)
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
            Log.debug("Duplicate to day error:", error)
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
