//
//  AddTaskView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import SwiftUI
import SwiftData

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var store: TodoStore
    @EnvironmentObject private var session: SessionStore

    @State private var entryKind: AddEntryKind = .task

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var courseName: String = ""

    @State private var selectedType: StudentTaskType = .task
    @State private var selectedColor: StudentTaskColor = .blue

    @State private var hasDueDate: Bool = true
    @State private var dueDate: Date = Date()

    @State private var estimatedStudyMinutes: Int = 60

    @State private var addToWeek: Bool = false
    @State private var scheduledWeekDate: Date = Date()

    @State private var selectedExamType: StudentExamType = .midterm
    @State private var examDate: Date = Date().addingTimeInterval(60 * 60 * 24 * 7)
    @State private var preferredExamStudyMinutes: Int = 40

    @FocusState private var titleFocused: Bool
    @FocusState private var courseFocused: Bool
    @FocusState private var notesFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        headerSection
                        entryKindSection
                        titleSection

                        if entryKind == .task {
                            taskTypeSection
                            taskDetailsSection
                            taskScheduleSection
                            taskWeekSection
                        } else {
                            examTypeSection
                            examDetailsSection
                            examScheduleSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Yeni Kayıt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Vazgeç") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ekle") {
                        add()
                    }
                    .fontWeight(.semibold)
                    .disabled(trimmedTitle.isEmpty)
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(entryKind == .task ? "Ne eklemek istiyorsun?" : "Sınavını ekle")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(
                entryKind == .task
                ? "Görevini sade şekilde oluştur, sonra istersen detaylandır."
                : "Yaklaşan sınavını ekle, sonra Home ve Week içinde akıllı şekilde gösterelim."
            )
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    summaryPill(
                        icon: entryKind == .task ? selectedType.icon : "graduationcap.fill",
                        text: entryKind == .task ? selectedType.title : selectedExamType.title,
                        tint: selectedColor.color
                    )

                    if !trimmedCourseName.isEmpty {
                        summaryPill(
                            icon: "book.closed.fill",
                            text: trimmedCourseName,
                            tint: .secondary
                        )
                    }

                    if entryKind == .task, hasDueDate {
                        summaryPill(
                            icon: "calendar",
                            text: dueDate.formatted(date: .abbreviated, time: .shortened),
                            tint: .secondary
                        )
                    }

                    if entryKind == .exam {
                        summaryPill(
                            icon: "calendar",
                            text: examDate.formatted(date: .abbreviated, time: .shortened),
                            tint: .secondary
                        )
                    }

                    if showsStudyDuration {
                        summaryPill(
                            icon: "timer",
                            text: "\(entryKind == .task ? estimatedStudyMinutes : preferredExamStudyMinutes) dk",
                            tint: .orange
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var entryKindSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Kayıt Türü")

            HStack(spacing: 10) {
                entryKindButton(.task, title: "Görev", subtitle: "Bugün yapılacak", icon: "checklist")
                entryKindButton(.exam, title: "Sınav", subtitle: "Tarih ve hazırlık", icon: "graduationcap.fill")
            }
        }
    }

    private func entryKindButton(
        _ kind: AddEntryKind,
        title: String,
        subtitle: String,
        icon: String
    ) -> some View {
        let isSelected = entryKind == kind
        let tint = kind == .task ? Color.blue : Color.orange

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                entryKind = kind
                if kind == .exam {
                    selectedColor = .orange
                    selectedType = .exam
                }
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(isSelected ? 0.18 : 0.10))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(tint)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.045))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                isSelected
                                ? tint.opacity(0.34)
                                : Color.white.opacity(0.05),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(
                color: isSelected ? tint.opacity(0.12) : .clear,
                radius: isSelected ? 8 : 0,
                y: isSelected ? 2 : 0
            )
        }
        .buttonStyle(.plain)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(entryKind == .task ? "Başlık" : "Sınav Başlığı")

            TextField(titlePlaceholder, text: $title)
                .focused($titleFocused)
                .textInputAutocapitalization(.sentences)
                .font(.system(size: 17, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Task Sections

    private var taskTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Tür")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ForEach(StudentTaskType.allCases.filter { $0 != .exam }) { type in
                    let typeColor = type.suggestedColor.color
                    let isSelected = selectedType == type

                    Button {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                            selectedType = type
                            selectedColor = type.suggestedColor
                        }
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(typeColor.opacity(isSelected ? 0.18 : 0.10))
                                    .frame(width: 40, height: 40)

                                Image(systemName: type.icon)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(typeColor)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.title)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Text(type.shortSubtitle)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(typeColor)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.045))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(
                                            isSelected
                                            ? typeColor.opacity(0.34)
                                            : Color.white.opacity(0.05),
                                            lineWidth: 1
                                        )
                                )
                        )
                        .shadow(
                            color: isSelected ? typeColor.opacity(0.12) : .clear,
                            radius: isSelected ? 8 : 0,
                            y: isSelected ? 2 : 0
                        )
                        .scaleEffect(isSelected ? 1.01 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var taskDetailsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Detaylar")

            VStack(spacing: 12) {
                inputBlock(
                    title: "Ders Adı",
                    placeholder: "Örn. Calculus, Physics, Biology",
                    text: $courseName,
                    focused: $courseFocused,
                    capitalization: .words
                )

                notesBlock

                colorBlock

                if showsStudyDuration {
                    studyDurationBlock(
                        minutes: $estimatedStudyMinutes,
                        tint: selectedColor.color
                    )
                }
            }
            .padding(16)
            .background(sectionCardBackground)
        }
    }

    private var taskScheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Planlama")

            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Tarih ve saat")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)

                        Text("Göreve zaman ver")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $hasDueDate.animation())
                        .labelsHidden()
                }

                if hasDueDate {
                    DatePicker(
                        "Zaman",
                        selection: $dueDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            quickDateButton("Bugün Akşam") { setTodayEvening() }
                            quickDateButton("Yarın") { setTomorrow() }
                            quickDateButton("Haftaya") { setNextWeek() }
                            quickDateButton("2 Saat Sonra") { setAfterHours(2) }
                            quickDateButton("Bu Hafta Sonu") { setThisWeekend() }
                        }
                    }
                }
            }
            .padding(16)
            .background(sectionCardBackground)
        }
    }

    private var taskWeekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Week")

            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Week ekranına da ekle")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)

                        Text("Planlı çalışmalarda kullanışlı")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $addToWeek.animation())
                        .labelsHidden()
                }

                if addToWeek {
                    DatePicker(
                        "Hafta zamanı",
                        selection: $scheduledWeekDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                }
            }
            .padding(16)
            .background(sectionCardBackground)
        }
    }

    // MARK: - Exam Sections

    private var examTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Sınav Türü")

            HStack(spacing: 10) {
                ForEach(StudentExamType.allCases) { type in
                    let isSelected = selectedExamType == type

                    Button {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                            selectedExamType = type
                            selectedColor = type.suggestedColor
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: type.icon)
                                .font(.system(size: 13, weight: .bold))

                            Text(type.title)
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(isSelected ? .white : type.suggestedColor.color)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule()
                                .fill(isSelected ? type.suggestedColor.color : type.suggestedColor.color.opacity(0.12))
                        )
                        .overlay(
                            Capsule()
                                .stroke(type.suggestedColor.color.opacity(isSelected ? 0.0 : 0.14), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var examDetailsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Sınav Detayları")

            VStack(spacing: 12) {
                inputBlock(
                    title: "Ders Adı",
                    placeholder: "Örn. Calculus, Physics, Biology",
                    text: $courseName,
                    focused: $courseFocused,
                    capitalization: .words
                )

                notesBlock

                colorBlock

                studyDurationBlock(
                    minutes: $preferredExamStudyMinutes,
                    tint: selectedColor.color
                )
            }
            .padding(16)
            .background(sectionCardBackground)
        }
    }

    private var examScheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Sınav Tarihi")

            VStack(spacing: 14) {
                DatePicker(
                    "Sınav zamanı",
                    selection: $examDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        quickExamDateButton("3 Gün Sonra", days: 3)
                        quickExamDateButton("5 Gün Sonra", days: 5)
                        quickExamDateButton("1 Hafta Sonra", days: 7)
                        quickExamDateButton("2 Hafta Sonra", days: 14)
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(selectedColor.color)

                    Text("Bu sınav Home ve Week içinde özel olarak gösterilebilir.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(selectedColor.color.opacity(0.10))
                )
            }
            .padding(16)
            .background(sectionCardBackground)
        }
    }

    // MARK: - Shared Blocks

    private var notesBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Not")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("İstersen kısa bir açıklama ekle", text: $notes, axis: .vertical)
                .focused($notesFocused)
                .lineLimit(3, reservesSpace: true)
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

    private var colorBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Renk")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(StudentTaskColor.allCases) { item in
                    Button {
                        selectedColor = item
                    } label: {
                        ZStack {
                            Circle()
                                .fill(item.color)
                                .frame(width: 28, height: 28)

                            if selectedColor == item {
                                Circle()
                                    .stroke(Color.white.opacity(0.95), lineWidth: 2.2)
                                    .frame(width: 36, height: 36)

                                Circle()
                                    .stroke(item.color.opacity(0.22), lineWidth: 6)
                                    .frame(width: 42, height: 42)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .shadow(
                        color: selectedColor == item ? item.color.opacity(0.16) : .clear,
                        radius: selectedColor == item ? 8 : 0,
                        y: 2
                    )
                }
            }
            .padding(.top, 2)
        }
    }

    private func studyDurationBlock(
        minutes: Binding<Int>,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(entryKind == .task ? "Tahmini Çalışma" : "Önerilen Çalışma Süresi")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(minutes.wrappedValue) dk")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
            }

            Slider(
                value: Binding(
                    get: { Double(minutes.wrappedValue) },
                    set: { minutes.wrappedValue = Int($0) }
                ),
                in: 15...240,
                step: 15
            )
            .tint(tint)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    quickMinuteChip(30, minutes: minutes, tint: tint)
                    quickMinuteChip(45, minutes: minutes, tint: tint)
                    quickMinuteChip(60, minutes: minutes, tint: tint)
                    quickMinuteChip(90, minutes: minutes, tint: tint)
                    quickMinuteChip(120, minutes: minutes, tint: tint)
                }
            }
        }
    }

    private var sectionCardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(0.045))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
    }

    // MARK: - Derived

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNotes: String {
        notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedCourseName: String {
        courseName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var showsStudyDuration: Bool {
        if entryKind == .exam { return true }
        return selectedType == .study || selectedType == .homework
    }

    private var titlePlaceholder: String {
        if entryKind == .exam {
            return "Örn. Calculus Vizesi"
        }

        switch selectedType {
        case .task: return "Örn. Sunum slaytlarını düzenle"
        case .homework: return "Örn. Fizik ödevi 3. bölüm"
        case .exam: return "Örn. Calculus vize tekrarı"
        case .study: return "Örn. Biyoloji tekrar"
        case .project: return "Örn. DailyTodo UI düzeltmeleri"
        }
    }

    // MARK: - Actions

    private func add() {
        if entryKind == .exam {
            addExam()
        } else {
            addTask()
        }
    }

    private func addTask() {
        store.add(
            title: trimmedTitle,
            dueDate: hasDueDate ? dueDate : nil,
            notes: trimmedNotes,
            taskType: selectedType.storeValue,
            colorName: selectedColor.rawValue,
            courseName: trimmedCourseName,
            scheduledWeekDate: addToWeek ? scheduledWeekDate : nil,
            scheduledWeekDurationMinutes: addToWeek ? estimatedStudyMinutes : nil,
            workoutDurationMinutes: selectedType == .study ? estimatedStudyMinutes : nil
        )
        dismiss()
    }

    private func addExam() {
        let currentUserID = session.currentUser?.id.uuidString

        let exam = ExamItem(
            title: trimmedTitle,
            courseName: trimmedCourseName,
            examType: selectedExamType.storeValue,
            examDate: examDate,
            notes: trimmedNotes,
            colorHex: selectedColor.hex,
            preferredStudyMinutes: preferredExamStudyMinutes,
            isCompleted: false,
            createdAt: Date(),
            ownerUserID: currentUserID
        )

        modelContext.insert(exam)

        store.add(
            title: trimmedTitle,
            dueDate: examDate,
            notes: trimmedNotes,
            taskType: "exam",
            colorName: selectedColor.rawValue,
            courseName: trimmedCourseName,
            scheduledWeekDate: nil,
            scheduledWeekDurationMinutes: preferredExamStudyMinutes,
            workoutDurationMinutes: nil
        )

        do {
            try modelContext.save()
            print("✅ EXAM + DTTaskItem SAVED")
            dismiss()
        } catch {
            print("❌ EXAM SAVE ERROR:", error.localizedDescription)
        }
    }

    private func inputBlock(
        title: String,
        placeholder: String,
        text: Binding<String>,
        focused: FocusState<Bool>.Binding,
        capitalization: TextInputAutocapitalization
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField(placeholder, text: text)
                .focused(focused)
                .textInputAutocapitalization(capitalization)
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

    private func quickMinuteChip(_ value: Int, minutes: Binding<Int>, tint: Color) -> some View {
        Button {
            minutes.wrappedValue = value
        } label: {
            Text("\(value) dk")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(minutes.wrappedValue == value ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(minutes.wrappedValue == value ? tint : Color.white.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
    }

    private func quickDateButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
    }

    private func quickExamDateButton(_ title: String, days: Int) -> some View {
        Button {
            examDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? examDate
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
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
    }

    private func setTodayEvening() {
        hasDueDate = true
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 20
        comps.minute = 0
        dueDate = Calendar.current.date(from: comps) ?? Date()
    }

    private func setTomorrow() {
        hasDueDate = true
        dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }

    private func setNextWeek() {
        hasDueDate = true
        dueDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    }

    private func setAfterHours(_ hours: Int) {
        hasDueDate = true
        dueDate = Calendar.current.date(byAdding: .hour, value: hours, to: Date()) ?? Date()
    }

    private func setThisWeekend() {
        hasDueDate = true
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysUntilSaturday = (7 - weekday + 7) % 7
        let saturday = calendar.date(byAdding: .day, value: daysUntilSaturday, to: today) ?? today
        dueDate = calendar.date(bySettingHour: 11, minute: 0, second: 0, of: saturday) ?? saturday
    }
}

// MARK: - Enums

private enum AddEntryKind: String, CaseIterable, Identifiable {
    case task
    case exam

    var id: String { rawValue }
}

private enum StudentTaskType: String, CaseIterable, Identifiable {
    case task
    case homework
    case exam
    case study
    case project

    var id: String { rawValue }

    var title: String {
        switch self {
        case .task: return "Görev"
        case .homework: return "Ödev"
        case .exam: return "Sınav"
        case .study: return "Çalışma"
        case .project: return "Proje"
        }
    }

    var shortSubtitle: String {
        switch self {
        case .task: return "Yapılacak"
        case .homework: return "Teslim"
        case .exam: return "Hazırlık"
        case .study: return "Odak"
        case .project: return "Uzun iş"
        }
    }

    var icon: String {
        switch self {
        case .task: return "checklist"
        case .homework: return "book.closed.fill"
        case .exam: return "doc.text.fill"
        case .study: return "brain.head.profile"
        case .project: return "folder.fill"
        }
    }

    var storeValue: String {
        switch self {
        case .task: return "standard"
        case .homework: return "homework"
        case .exam: return "exam"
        case .study: return "study"
        case .project: return "project"
        }
    }

    var suggestedColor: StudentTaskColor {
        switch self {
        case .task: return .blue
        case .homework: return .pink
        case .exam: return .orange
        case .study: return .green
        case .project: return .purple
        }
    }
}

private enum StudentExamType: String, CaseIterable, Identifiable {
    case midterm
    case final
    case quiz

    var id: String { rawValue }

    var title: String {
        switch self {
        case .midterm: return "Vize"
        case .final: return "Final"
        case .quiz: return "Quiz"
        }
    }

    var storeValue: String {
        switch self {
        case .midterm: return "Vize"
        case .final: return "Final"
        case .quiz: return "Quiz"
        }
    }

    var icon: String {
        switch self {
        case .midterm: return "doc.text.fill"
        case .final: return "flag.fill"
        case .quiz: return "pencil.and.list.clipboard"
        }
    }

    var suggestedColor: StudentTaskColor {
        switch self {
        case .midterm: return .orange
        case .final: return .pink
        case .quiz: return .blue
        }
    }
}

private enum StudentTaskColor: String, CaseIterable, Identifiable {
    case blue
    case green
    case orange
    case pink
    case purple

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .pink: return .pink
        case .purple: return .purple
        }
    }

    var hex: String {
        switch self {
        case .blue: return "#3B82F6"
        case .green: return "#22C55E"
        case .orange: return "#F59E0B"
        case .pink: return "#EC4899"
        case .purple: return "#8B5CF6"
        }
    }
}
