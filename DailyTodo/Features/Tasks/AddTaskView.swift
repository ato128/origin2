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

    /// When true (Week context) the entry is locked to a task and the
    /// task/exam segmented switch is hidden.
    private let lockedToTask: Bool

    init(
        defaultAddToWeek: Bool = false,
        defaultWeekDate: Date? = nil,
        lockedToTask: Bool = false
    ) {
        self.lockedToTask = lockedToTask
        _addToWeek = State(initialValue: defaultAddToWeek)
        if let defaultWeekDate {
            _scheduledWeekDate = State(initialValue: defaultWeekDate)
            _dueDate = State(initialValue: defaultWeekDate)
        }
    }

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

    @Namespace private var entryKindNamespace

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
                        if !lockedToTask {
                            entryKindSection
                        }
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
            .navigationTitle(tr("at_nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("common_cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("common_add")) {
                        add()
                    }
                    .fontWeight(.semibold)
                    .disabled(trimmedTitle.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(UpdoTheme.cyan)
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(entryKind == .task ? tr("at_header_task") : tr("at_header_exam"))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(
                entryKind == .task
                ? tr("at_sub_task")
                : tr("at_sub_exam")
            )
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    summaryPill(
                        icon: entryKind == .task ? selectedType.icon : "graduationcap",
                        text: entryKind == .task ? selectedType.title : selectedExamType.title,
                        tint: selectedColor.color
                    )

                    if !trimmedCourseName.isEmpty {
                        summaryPill(
                            icon: "book.closed",
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
                            text: "\(entryKind == .task ? estimatedStudyMinutes : preferredExamStudyMinutes) \(tr("common_min_short"))",
                            tint: .orange
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Top-level record kind: a clean two-way segmented control.
    /// tr("at_kind_task") vs tr("at_kind_exam") — subtypes appear below only for Görev.
    private var entryKindSection: some View {
        HStack(spacing: 4) {
            entryKindSegment(.task, title: tr("at_kind_task"), icon: "checklist")
            entryKindSegment(.exam, title: tr("at_kind_exam"), icon: "graduationcap")
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.045))
                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    private func entryKindSegment(_ kind: AddEntryKind, title: String, icon: String) -> some View {
        let isSelected = entryKind == kind

        return Button {
            HapticManager.shared.selection()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                entryKind = kind
                if kind == .exam {
                    selectedColor = .orange
                    selectedType = .exam
                } else if selectedType == .exam {
                    selectedType = .task
                    selectedColor = .blue
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))

                Text(title)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(isSelected ? .black : .white.opacity(0.55))
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background {
                if isSelected {
                    Capsule()
                        .fill(UpdoTheme.cyan)
                        .matchedGeometryEffect(id: "entry-kind-segment", in: entryKindNamespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(entryKind == .task ? tr("at_title") : tr("at_exam_title"))

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
            sectionLabel(tr("at_task_type"))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ForEach(StudentTaskType.allCases.filter { $0 != .exam }) { type in
                    let typeColor = type.suggestedColor.color
                    let isSelected = selectedType == type

                    Button {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                            selectedType = type
                            selectedColor = type.suggestedColor
                        }
                    } label: {
                        HStack(spacing: 10) {
                            // Monochrome SF Symbol on a subtle tinted circle —
                            // unified treatment, no filled colored squares.
                            ZStack {
                                Circle()
                                    .fill(typeColor.opacity(0.15))
                                    .frame(width: 40, height: 40)

                                Image(systemName: type.icon)
                                    .font(.system(size: 20, weight: .medium))
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
                                    .foregroundStyle(UpdoTheme.cyan)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.045))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(
                                            isSelected ? UpdoTheme.cyan : Color.white.opacity(0.08),
                                            lineWidth: isSelected ? 1.5 : 1
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var taskDetailsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel(tr("at_details"))

            VStack(spacing: 12) {
                inputBlock(
                    title: tr("at_course"),
                    placeholder: tr("at_course_ph"),
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
            sectionLabel(tr("at_planning"))

            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tr("at_datetime"))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)

                        Text(tr("at_give_time"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $hasDueDate.animation())
                        .labelsHidden()
                }

                if hasDueDate {
                    DatePicker(
                        tr("at_time"),
                        selection: $dueDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            quickDateButton(tr("at_quick_tonight")) { setTodayEvening() }
                            quickDateButton(tr("at_quick_tomorrow")) { setTomorrow() }
                            quickDateButton(tr("at_quick_nextweek")) { setNextWeek() }
                            quickDateButton(tr("at_quick_2h")) { setAfterHours(2) }
                            quickDateButton(tr("at_quick_weekend")) { setThisWeekend() }
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
            sectionLabel(tr("at_week_section"))

            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tr("at_add_to_week"))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)

                        Text(tr("at_week_hint"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $addToWeek.animation())
                        .labelsHidden()
                }

                if addToWeek {
                    DatePicker(
                        tr("at_week_time"),
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
            sectionLabel(tr("at_exam_type"))

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
            sectionLabel(tr("at_exam_details"))

            VStack(spacing: 12) {
                inputBlock(
                    title: tr("at_course"),
                    placeholder: tr("at_course_ph"),
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
            sectionLabel(tr("at_exam_date"))

            VStack(spacing: 14) {
                DatePicker(
                    tr("at_exam_time"),
                    selection: $examDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        quickExamDateButton(tr("at_quick_3d"), days: 3)
                        quickExamDateButton(tr("at_quick_5d"), days: 5)
                        quickExamDateButton(tr("at_quick_1w"), days: 7)
                        quickExamDateButton(tr("at_quick_2w"), days: 14)
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(selectedColor.color)

                    Text(tr("at_exam_hint"))
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
            Text(tr("at_note"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField(tr("at_notes_ph"), text: $notes, axis: .vertical)
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
            Text(tr("at_color"))
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
                Text(entryKind == .task ? tr("at_est_study") : tr("at_sugg_study"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(minutes.wrappedValue) \(tr("common_min_short"))")
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
            return tr("at_ph_exam_title")
        }

        switch selectedType {
        case .task: return tr("at_ph_task")
        case .homework: return tr("at_ph_homework")
        case .exam: return tr("at_ph_exam")
        case .study: return tr("at_ph_study")
        case .project: return tr("at_ph_project")
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
            Log.debug("✅ EXAM + DTTaskItem SAVED")
            dismiss()
        } catch {
            Log.debug("❌ EXAM SAVE ERROR:", error.localizedDescription)
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
            Text("\(value) \(tr("common_min_short"))")
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
        case .task: return tr("at_kind_task")
        case .homework: return tr("tt_homework")
        case .exam: return tr("at_kind_exam")
        case .study: return tr("tt_study")
        case .project: return tr("tt_project")
        }
    }

    var shortSubtitle: String {
        switch self {
        case .task: return tr("tt_sub_todo")
        case .homework: return tr("tt_sub_due")
        case .exam: return tr("tt_sub_prep")
        case .study: return tr("tt_sub_focus")
        case .project: return tr("tt_sub_long")
        }
    }

    var icon: String {
        switch self {
        case .task: return "checklist"
        case .homework: return "book.closed"
        case .exam: return "graduationcap"
        case .study: return "brain.head.profile"
        case .project: return "folder"
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
        case .midterm: return tr("et_midterm")
        case .final: return tr("et_final")
        case .quiz: return tr("et_quiz")
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
