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
    @EnvironmentObject var friendStore: FriendStore
    @EnvironmentObject var studentStore: StudentStore

    let defaultWeekday: Int
    let defaultDate: Date?

    @State private var title = ""
    @State private var courseCode = ""
    @State private var weekday = 0
    @State private var location = ""
    @State private var notes = ""
    @State private var selectedColorHex = "#3B82F6"

    @State private var selectedCourseID: UUID?
    @State private var expandedCourseID: UUID?
    @State private var addedCourseIDs: Set<UUID> = []

    @State private var showManualCourse = false
    @State private var manualCourseCode = ""
    @State private var manualCourseName = ""

    @State private var showCustomEvent = false

    @State private var startTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endTime = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()

    @State private var showConflictAlert = false
    @State private var conflictSummary = ""
    @State private var pendingKeepOpen = false
    @State private var pendingAddedCourseID: UUID?

    var body: some View {
        Form {
            Section {
                livePreviewCard
            }

            Section {
                if studentStore.courses.isEmpty {
                    emptyCourseRow
                } else {
                    ForEach(uniqueCourses) { course in
                        courseRow(course)
                    }
                }
            } header: {
                Label("Derslerim", systemImage: "graduationcap.fill")
            }

            Section {
                DisclosureGroup(isExpanded: $showManualCourse) {
                    TextField("Kod", text: $manualCourseCode)
                        .textInputAutocapitalization(.characters)

                    TextField("Ders adı", text: $manualCourseName)

                    Button {
                        addManualCourse()
                    } label: {
                        Label("Dersi Listeye Ekle", systemImage: "plus.circle.fill")
                    }
                    .disabled(manualCourseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } label: {
                    Label("Ekstra ders", systemImage: "plus.circle")
                }
            }

            Section {
                DisclosureGroup(isExpanded: $showCustomEvent) {
                    TextField("Kod", text: $courseCode)
                        .textInputAutocapitalization(.characters)

                    TextField("Başlık", text: $title)

                    TextField("Konum (opsiyonel)", text: $location)

                    Picker("Gün", selection: $weekday) {
                        ForEach(0..<7, id: \.self) { i in
                            Text(localizedDayTitle(i)).tag(i)
                        }
                    }

                    DatePicker("Başlangıç", selection: $startTime, displayedComponents: [.hourAndMinute])
                    DatePicker("Bitiş", selection: $endTime, displayedComponents: [.hourAndMinute])

                    TextField("Not (opsiyonel)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } label: {
                    Label("Özel etkinlik", systemImage: "calendar.badge.plus")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("Ekle")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Bitti") { dismiss() }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Kaydet") {
                    trySaveWithConflictCheck()
                }
                .fontWeight(.bold)
                .disabled(!canSave)
            }
        }
        .onAppear {
            applyDefaultDateIfNeeded()
            studentStore.reload()
        }
        .onChange(of: courseCode) { _, newValue in
            autoFillFromCode(newValue)
        }
        .alert("Çakışma var", isPresented: $showConflictAlert) {
            Button("Vazgeç", role: .cancel) { }
            Button("Yine de ekle") {
                saveIgnoringConflicts()
            }
        } message: {
            Text(conflictSummary)
        }
    }

    private var livePreviewCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(colorFromHex(selectedColorHex).opacity(0.18))
                    .frame(width: 46, height: 46)

                Image(systemName: previewIcon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(colorFromHex(selectedColorHex))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(title.isEmpty ? "Ders seç" : title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if !courseCode.isEmpty {
                        Text(courseCode)
                    }

                    Text(localizedDayTitle(weekday))
                    Text("\(hm(minutesFrom(startTime)))–\(hm(minutesFrom(endTime)))")
                }
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(durationText)
                .font(.caption.bold())
                .foregroundStyle(colorFromHex(selectedColorHex))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(colorFromHex(selectedColorHex).opacity(0.14))
                )
        }
        .padding(.vertical, 4)
    }

    private var previewIcon: String {
        if selectedCourseID != nil { return "book.closed.fill" }
        if showCustomEvent { return "calendar" }
        return "sparkles"
    }

    private var uniqueCourses: [Course] {
        var seen = Set<String>()

        return studentStore.courses.filter { course in
            let key = "\(course.code.uppercased())-\(course.name.uppercased())"
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    private var emptyCourseRow: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text("Ders yok")
                    .font(.headline)

                Text("Profil > Öğrenci Bilgileri bölümünden ders ekleyebilirsin.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "graduationcap")
                .foregroundStyle(.blue)
        }
    }

    private func courseRow(_ course: Course) -> some View {
        let isExpanded = expandedCourseID == course.id
        let isAdded = addedCourseIDs.contains(course.id)
        let tint = colorFromHex(course.colorHex)

        return VStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    selectedCourseID = course.id
                    expandedCourseID = isExpanded ? nil : course.id
                    showCustomEvent = false
                    applyCourse(course)
                }
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(isAdded ? .green : tint)
                        .frame(width: 11, height: 11)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(course.name)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if !course.code.isEmpty {
                            Text(course.code)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: isAdded ? "checkmark.circle.fill" : (isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle"))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isAdded ? .green : .secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 12) {
                    Picker("Gün", selection: $weekday) {
                        ForEach(0..<7, id: \.self) { i in
                            Text(localizedDayTitle(i)).tag(i)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        DatePicker("", selection: $startTime, displayedComponents: [.hourAndMinute])
                            .labelsHidden()

                        Image(systemName: "arrow.right")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        DatePicker("", selection: $endTime, displayedComponents: [.hourAndMinute])
                            .labelsHidden()
                    }

                    HStack {
                        Label(durationText, systemImage: "clock.fill")
                            .font(.caption.bold())
                            .foregroundStyle(colorFromHex(selectedColorHex))

                        Spacer()

                        Label("Her hafta", systemImage: "repeat")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }

                    courseColorPicker()

                    Button {
                        title = course.name
                        courseCode = course.code

                        trySaveWithConflictCheck(
                            keepSheetOpen: true,
                            addedCourseID: course.id
                        )
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                            Text(isAdded ? "Eklendi" : "Haftaya Ekle")
                        }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(isAdded ? .green : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(isAdded ? Color.green.opacity(0.16) : colorFromHex(selectedColorHex))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isAdded || durationMinute < 15)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func courseColorPicker() -> some View {
        let colors = [
            "#3B82F6",
            "#22C55E",
            "#F59E0B",
            "#EF4444",
            "#A855F7",
            "#06B6D4",
            "#EC4899"
        ]

        return VStack(alignment: .leading, spacing: 10) {
            Text("Renk")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(colors, id: \.self) { hex in
                    let color = colorFromHex(hex)
                    let selected = selectedColorHex == hex

                    Button {
                        selectedColorHex = hex
                    } label: {
                        ZStack {
                            Circle()
                                .fill(color)
                                .frame(width: 28, height: 28)

                            if selected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(selected ? 0.8 : 0), lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 2)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && durationMinute >= 15
    }

    private var durationMinute: Int {
        max(0, minutesFrom(endTime) - minutesFrom(startTime))
    }

    private var durationText: String {
        let d = durationMinute
        if d <= 0 { return "—" }

        let h = d / 60
        let m = d % 60

        if h == 0 { return "\(m) dk" }
        if m == 0 { return "\(h) sa" }
        return "\(h) sa \(m) dk"
    }

    private func applyCourse(_ course: Course) {
        title = course.name
        courseCode = course.code
        selectedColorHex = course.colorHex
    }

    private func autoFillFromCode(_ code: String) {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return }

        if let match = studentStore.courses.first(where: {
            $0.code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == normalized
        }) {
            applyCourse(match)
            selectedCourseID = match.id
            expandedCourseID = match.id
        }
    }

    private func addManualCourse() {
        let name = manualCourseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = manualCourseCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !name.isEmpty else { return }

        studentStore.addCourse(
            name: name,
            code: code,
            colorHex: selectedColorHex,
            sourceType: "manual"
        )

        title = name
        courseCode = code
        manualCourseName = ""
        manualCourseCode = ""
        showManualCourse = false
        studentStore.reload()
        Haptics.notify(.success)
    }

    private func trySaveWithConflictCheck(
        keepSheetOpen: Bool = false,
        addedCourseID: UUID? = nil
    ) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let start = minutesFrom(startTime)
        let end = start + durationMinute

        pendingKeepOpen = keepSheetOpen
        pendingAddedCourseID = addedCourseID

        let descriptor = FetchDescriptor<EventItem>(
            predicate: #Predicate { $0.weekday == weekday },
            sortBy: [SortDescriptor(\EventItem.startMinute, order: .forward)]
        )

        let sameDayAll = (try? context.fetch(descriptor)) ?? []
        let sameDay = sameDayAll.filter {
            $0.ownerUserID == session.currentUser?.id.uuidString
        }

        let conflicts = sameDay.filter { ev in
            max(start, ev.startMinute) < min(end, ev.startMinute + ev.durationMinute)
        }

        if conflicts.isEmpty {
            insertEvent(title: t, start: start, dur: durationMinute)
            completeSaveFlow()
        } else {
            conflictSummary = conflicts
                .prefix(4)
                .map { "\($0.title) (\(hm($0.startMinute))–\(hm($0.startMinute + $0.durationMinute)))" }
                .joined(separator: "\n")

            showConflictAlert = true
        }
    }

    private func saveIgnoringConflicts() {
        insertEvent(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            start: minutesFrom(startTime),
            dur: durationMinute
        )
        completeSaveFlow()
    }

    private func completeSaveFlow() {
        if let id = pendingAddedCourseID {
            addedCourseIDs.insert(id)
        }

        Haptics.notify(.success)

        if !pendingKeepOpen {
            dismiss()
        }

        pendingKeepOpen = false
        pendingAddedCourseID = nil
    }

    private func insertEvent(title: String, start: Int, dur: Int) {
        let ev = EventItem(
            ownerUserID: session.currentUser?.id.uuidString,
            title: title,
            weekday: weekday,
            startMinute: start,
            durationMinute: dur,
            scheduledDate: nil,
            location: location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : location,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
            colorHex: selectedColorHex
        )

        context.insert(ev)

        do {
            try context.save()
            WidgetAppSync.refreshFromSwiftData(context: context)

            Task {
                await NotificationManager.shared.schedule(for: ev, minutesBefore: 10)
                await NotificationManager.shared.schedule(for: ev, minutesBefore: 0)
            }

            Task {
                guard let currentUserID = session.currentUser?.id else { return }
                await friendStore.resyncSharedWeekIfNeeded(
                    for: currentUserID,
                    events: currentUserEventsFromContext()
                )
            }
        } catch {
            print("Save error:", error)
        }
    }

    private func applyDefaultDateIfNeeded() {
        weekday = max(0, min(6, defaultWeekday))
    }

    private func currentUserEventsFromContext() -> [EventItem] {
        guard let currentUserID = session.currentUser?.id.uuidString else { return [] }

        let descriptor = FetchDescriptor<EventItem>(
            sortBy: [SortDescriptor(\EventItem.startMinute, order: .forward)]
        )

        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { $0.ownerUserID == currentUserID }
    }

    private func localizedDayTitle(_ day: Int) -> String {
        switch max(0, min(6, day)) {
        case 0: return "Pzt"
        case 1: return "Sal"
        case 2: return "Çar"
        case 3: return "Per"
        case 4: return "Cum"
        case 5: return "Cmt"
        default: return "Paz"
        }
    }

    private func minutesFrom(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return max(0, min(1439, (c.hour ?? 0) * 60 + (c.minute ?? 0)))
    }

    private func hm(_ minute: Int) -> String {
        let m = max(0, minute)
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

    private func colorFromHex(_ hex: String) -> Color {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        clean = clean.replacingOccurrences(of: "#", with: "")

        guard clean.count == 6 else { return .accentColor }

        var rgb: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&rgb)

        return Color(
            red: Double((rgb & 0xFF0000) >> 16) / 255,
            green: Double((rgb & 0x00FF00) >> 8) / 255,
            blue: Double(rgb & 0x0000FF) / 255
        )
    }
}
