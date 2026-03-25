//
//  TaskDetailView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 17.03.2026.
//

import SwiftUI
import SwiftData

struct TaskDetailView: View {
    @Bindable var task: DTTaskItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var session: SessionStore

    @Query private var allWorkoutExercises: [WorkoutExerciseItem]
    @Query private var allExerciseHistory: [WorkoutExerciseHistoryItem]
    @Query private var allEvents: [EventItem]

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    @State private var showWorkoutTemplateSheet = false
    @State private var showWeekAddedToast = false
    @State private var showFinishWorkoutToast = false

    let workoutDays = [
        "Leg Day",
        "Push Day",
        "Pull Day",
        "Chest Day",
        "Back Day",
        "Shoulder Day",
        "Arm Day",
        "Full Body"
    ]

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    titleCard
                    notesCard
                    typeCard

                    if task.taskType == "workout" {
                        workoutCard
                    }

                    scheduleCard
                    actionCard

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)

            if showFinishWorkoutToast {
                VStack {
                    Spacer()

                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white)

                        Text(String(localized: "task_detail_workout_finished"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.green)
                    )
                    .shadow(color: Color.green.opacity(0.22), radius: 10, y: 4)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(5)
            }

            if showWeekAddedToast {
                VStack {
                    Spacer()

                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white)

                        Text(String(localized: "task_detail_added_to_week"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.green)
                    )
                    .shadow(color: Color.green.opacity(0.22), radius: 10, y: 4)
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(5)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showWorkoutTemplateSheet) {
            WorkoutTemplateSheet(task: task)
        }
    }
}

private extension TaskDetailView {
    var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(palette.primaryText)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(palette.cardFill)
                            .overlay(
                                Circle()
                                    .stroke(palette.cardStroke, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Text(String(localized: "task_detail_title"))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
    }

    var titleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "task_detail_section_title"))
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            TextField(String(localized: "task_detail_task_title_placeholder"), text: $task.title)
                .textFieldStyle(.plain)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(palette.secondaryCardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(palette.cardStroke, lineWidth: 1)
                        )
                )

            if let dueDate = task.dueDate {
                Text("\(String(localized: "task_detail_due_prefix")): \(dueDate.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "task_detail_notes"))
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            TextEditor(text: $task.notes)
                .frame(minHeight: 120)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(palette.secondaryCardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(palette.cardStroke, lineWidth: 1)
                        )
                )
        }
        .padding(18)
        .background(cardBackground)
    }

    var typeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "task_detail_task_type"))
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            Picker(String(localized: "task_detail_task_type"), selection: $task.taskType) {
                Text(String(localized: "task_type_standard")).tag("standard")
                Text(String(localized: "task_type_study")).tag("study")
                Text(String(localized: "task_type_workout")).tag("workout")
            }
            .pickerStyle(.segmented)
        }
        .padding(18)
        .background(cardBackground)
    }

    var selectedWorkoutDay: String {
        task.workoutDay ?? "Leg Day"
    }

    var taskExercises: [WorkoutExerciseItem] {
        allWorkoutExercises
            .filter { $0.taskUUID == task.taskUUID }
            .sorted { lhs, rhs in
                if lhs.orderIndex != rhs.orderIndex {
                    return lhs.orderIndex < rhs.orderIndex
                }
                return lhs.createdAt < rhs.createdAt
            }
    }

    func saveWorkoutHistoryIfNeeded() {
        guard task.taskType == "workout" else { return }

        let exercises = allWorkoutExercises
            .filter { $0.taskUUID == task.taskUUID }
            .sorted { lhs, rhs in
                if lhs.orderIndex != rhs.orderIndex {
                    return lhs.orderIndex < rhs.orderIndex
                }
                return lhs.createdAt < rhs.createdAt
            }

        guard !exercises.isEmpty else { return }

        for exercise in exercises {
            let item = WorkoutExerciseHistoryItem(
                taskUUID: task.taskUUID,
                exerciseName: exercise.name,
                sets: exercise.sets,
                reps: exercise.reps,
                weight: exercise.weight,
                durationSeconds: exercise.durationSeconds,
                restSeconds: exercise.restSeconds
            )
            modelContext.insert(item)
        }

        try? modelContext.save()
    }

    var recommendedExercises: [String] {
        WorkoutExerciseLibrary.recommended(for: selectedWorkoutDay)
            .filter { name in
                !taskExercises.contains(where: { $0.name == name })
            }
    }

    var otherExercises: [String] {
        WorkoutExerciseLibrary.all(for: selectedWorkoutDay)
            .filter { name in
                !taskExercises.contains(where: { $0.name == name })
            }
    }

    func addExercise(_ name: String) {
        let item = WorkoutExerciseItem(
            taskUUID: task.taskUUID,
            name: name,
            sets: 3,
            reps: 10,
            durationSeconds: 0,
            restSeconds: 60,
            orderIndex: taskExercises.count
        )
        modelContext.insert(item)
        try? modelContext.save()
    }

    @ViewBuilder
    func flowExerciseButtons(_ items: [String], tint: Color) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
            ForEach(items, id: \.self) { name in
                Button {
                    addExercise(name)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text(name)
                            .lineLimit(1)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(tint.opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    func exerciseRow(_ exercise: WorkoutExerciseItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(exercise.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.primaryText)

                Spacer()

                Button(role: .destructive) {
                    removeExercise(exercise)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            if latestHistory(for: exercise) != nil || bestHistory(for: exercise) != nil {
                VStack(alignment: .leading, spacing: 6) {
                    if let latest = latestHistory(for: exercise) {
                        historyMiniLine(
                            title: String(localized: "task_detail_history_last"),
                            value: historyText(for: latest)
                        )
                    }

                    if let best = bestHistory(for: exercise) {
                        historyMiniLine(
                            title: String(localized: "task_detail_history_best"),
                            value: historyText(for: best)
                        )
                    }
                }
            }

            HStack(spacing: 10) {
                stepCard(title: String(localized: "task_detail_sets"), value: exercise.sets) {
                    if exercise.sets > 1 { exercise.sets -= 1 }
                } increment: {
                    exercise.sets += 1
                    try? modelContext.save()
                }

                stepCard(title: String(localized: "task_detail_reps"), value: exercise.reps) {
                    if exercise.reps > 1 { exercise.reps -= 1 }
                } increment: {
                    exercise.reps += 1
                    try? modelContext.save()
                }
            }

            HStack(spacing: 10) {
                stepCard(title: String(localized: "task_detail_kg"), value: Int(exercise.weight)) {
                    if exercise.weight >= 2.5 { exercise.weight -= 2.5 }
                    try? modelContext.save()
                } increment: {
                    exercise.weight += 2.5
                    try? modelContext.save()
                }

                Toggle(
                    isOn: Binding(
                        get: { exercise.isSuperset },
                        set: {
                            exercise.isSuperset = $0
                            try? modelContext.save()
                        }
                    )
                ) {
                    Text(String(localized: "task_detail_superset"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.secondaryText)
                }
                .toggleStyle(.switch)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(palette.cardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(palette.cardStroke, lineWidth: 1)
                        )
                )
            }

            HStack(spacing: 10) {
                stepCard(title: String(localized: "task_detail_seconds_short"), value: exercise.durationSeconds) {
                    if exercise.durationSeconds >= 5 { exercise.durationSeconds -= 5 }
                    try? modelContext.save()
                } increment: {
                    exercise.durationSeconds += 5
                    try? modelContext.save()
                }

                stepCard(title: String(localized: "task_detail_rest"), value: exercise.restSeconds) {
                    if exercise.restSeconds >= 5 { exercise.restSeconds -= 5 }
                    try? modelContext.save()
                } increment: {
                    exercise.restSeconds += 5
                    try? modelContext.save()
                }
            }

            TextField(
                String(localized: "task_detail_notes_optional"),
                text: Binding(
                    get: { exercise.notes },
                    set: {
                        exercise.notes = $0
                        try? modelContext.save()
                    }
                )
            )
            .font(.caption)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(palette.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(palette.cardStroke, lineWidth: 1)
                    )
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.secondaryCardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
    }

    func historyText(for item: WorkoutExerciseHistoryItem) -> String {
        if item.weight > 0 {
            return "\(Int(item.weight)) kg × \(item.reps)"
        } else {
            return "\(item.sets) set × \(item.reps) rep"
        }
    }

    func markRelatedWeekEventsCompleted() {
        let relatedEvents = allEvents.filter { $0.sourceTaskUUID == task.taskUUID }

        for event in relatedEvents {
            event.isCompleted = task.isDone
        }

        try? modelContext.save()
    }

    func historyMiniLine(title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.green)

            Text(value)
                .font(.caption2)
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.green.opacity(0.10))
        )
    }

    @ViewBuilder
    func stepCard(title: String, value: Int, decrement: @escaping () -> Void, increment: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryText)

            HStack {
                Text("\(value)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(palette.primaryText)

                Spacer()

                HStack(spacing: 12) {
                    Button(action: decrement) {
                        Image(systemName: "minus")
                            .font(.caption.bold())
                    }

                    Divider()
                        .frame(height: 18)

                    Button(action: increment) {
                        Image(systemName: "plus")
                            .font(.caption.bold())
                    }
                }
                .foregroundStyle(palette.primaryText)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
    }

    func removeExercise(_ exercise: WorkoutExerciseItem) {
        modelContext.delete(exercise)
        try? modelContext.save()
    }

    func addTaskToWeek() {
        guard let user = session.currentUser else { return }
        let currentUserID = user.id.uuidString
        let selectedDate = task.scheduledWeekDate ?? Date()

        let existing = allEvents.first {
            $0.sourceTaskUUID == task.taskUUID &&
            Calendar.current.isDate($0.scheduledDate ?? .distantPast, inSameDayAs: selectedDate)
        }

        if existing != nil {
            return
        }

        let calendar = Calendar.current
        let weekdayFromCalendar = calendar.component(.weekday, from: selectedDate)
        let mappedWeekday = (weekdayFromCalendar + 5) % 7
        let hour = calendar.component(.hour, from: selectedDate)
        let minute = calendar.component(.minute, from: selectedDate)
        let startMinute = hour * 60 + minute

        let duration = task.scheduledWeekDurationMinutes
            ?? task.workoutDurationMinutes
            ?? 60

        let event = EventItem(
            ownerUserID: currentUserID,
            title: task.title,
            weekday: mappedWeekday,
            startMinute: startMinute,
            durationMinute: duration,
            scheduledDate: selectedDate,
            location: nil,
            notes: task.notes.isEmpty ? nil : task.notes,
            colorHex: task.taskType == "workout" ? "#22C55E" : "#3B82F6",
            sourceTaskUUID: task.taskUUID
        )

        modelContext.insert(event)
        try? modelContext.save()
    }

    func historyItems(for exercise: WorkoutExerciseItem) -> [WorkoutExerciseHistoryItem] {
        allExerciseHistory
            .filter { $0.exerciseName == exercise.name }
            .sorted { $0.recordedAt > $1.recordedAt }
    }

    func latestHistory(for exercise: WorkoutExerciseItem) -> WorkoutExerciseHistoryItem? {
        historyItems(for: exercise).first
    }

    func bestHistory(for exercise: WorkoutExerciseItem) -> WorkoutExerciseHistoryItem? {
        historyItems(for: exercise)
            .max { lhs, rhs in
                if lhs.weight == rhs.weight {
                    return lhs.reps < rhs.reps
                }
                return lhs.weight < rhs.weight
            }
    }

    var workoutCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(String(localized: "task_detail_workout_plan"))
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)

                Spacer()

                Button {
                    showWorkoutTemplateSheet = true
                } label: {
                    Text(String(localized: "task_detail_templates"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.14))
                        )
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "task_detail_workout_day"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)

                Picker(String(localized: "task_detail_workout_day"), selection: Binding(
                    get: { task.workoutDay ?? "Leg Day" },
                    set: {
                        task.workoutDay = $0
                        try? modelContext.save()
                    }
                )) {
                    ForEach(workoutDays, id: \.self) { day in
                        Text(day).tag(day)
                    }
                }
                .pickerStyle(.menu)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(palette.secondaryCardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(palette.cardStroke, lineWidth: 1)
                        )
                )
            }

            if !recommendedExercises.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(localized: "task_detail_most_recommended"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.primaryText)

                    flowExerciseButtons(recommendedExercises, tint: .green)
                }
            }

            if !otherExercises.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(localized: "task_detail_other_exercises"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.primaryText)

                    flowExerciseButtons(otherExercises, tint: .blue)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "task_detail_selected_exercises"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.primaryText)

                if taskExercises.isEmpty {
                    Text(String(localized: "task_detail_no_exercises"))
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                        .padding(.vertical, 6)
                } else {
                    ForEach(taskExercises) { exercise in
                        exerciseRow(exercise)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "task_detail_duration"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)

                Stepper(
                    value: Binding(
                        get: { task.workoutDurationMinutes ?? 45 },
                        set: {
                            task.workoutDurationMinutes = $0
                            try? modelContext.save()
                        }
                    ),
                    in: 10...180,
                    step: 5
                ) {
                    Text("\(task.workoutDurationMinutes ?? 45) min")
                        .foregroundStyle(palette.primaryText)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(palette.secondaryCardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(palette.cardStroke, lineWidth: 1)
                        )
                )
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "task_detail_schedule_on_week"))
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            DatePicker(
                String(localized: "task_detail_week_date"),
                selection: Binding(
                    get: { task.scheduledWeekDate ?? Date() },
                    set: {
                        task.scheduledWeekDate = $0
                        try? modelContext.save()
                    }
                ),
                displayedComponents: [.date, .hourAndMinute]
            )
            .foregroundStyle(palette.primaryText)

            Stepper(
                value: Binding(
                    get: { task.scheduledWeekDurationMinutes ?? 60 },
                    set: {
                        task.scheduledWeekDurationMinutes = $0
                        try? modelContext.save()
                    }
                ),
                in: 15...240,
                step: 15
            ) {
                Text("\(String(localized: "task_detail_duration")): \(task.scheduledWeekDurationMinutes ?? 60) min")
                    .foregroundStyle(palette.primaryText)
            }

            Button {
                addTaskToWeek()

                withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                    showWeekAddedToast = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    withAnimation(.easeOut(duration: 0.22)) {
                        showWeekAddedToast = false
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    dismiss()
                }
            } label: {
                Text(String(localized: "task_detail_add_to_week"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.blue)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(cardBackground)
    }

    var actionCard: some View {
        VStack(spacing: 12) {
            Button {
                let willBeDone = !task.isDone

                task.isDone = willBeDone
                task.completedAt = willBeDone ? Date() : nil
                try? modelContext.save()

                if willBeDone && task.taskType == "workout" {
                    saveWorkoutHistoryIfNeeded()
                }

                markRelatedWeekEventsCompleted()

                if willBeDone && task.taskType == "workout" {
                    let generator = UINotificationFeedbackGenerator()
                    generator.prepare()
                    generator.notificationOccurred(.success)

                    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                        showFinishWorkoutToast = true
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                        withAnimation(.easeOut(duration: 0.22)) {
                            showFinishWorkoutToast = false
                        }
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        dismiss()
                    }
                } else {
                    dismiss()
                }
            } label: {
                Text(primaryActionTitle)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(primaryActionColor)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(cardBackground)
    }

    var primaryActionTitle: String {
        if task.taskType == "workout" {
            return task.isDone
            ? String(localized: "task_detail_reopen_workout")
            : String(localized: "task_detail_finish_workout")
        } else {
            return task.isDone
            ? String(localized: "task_detail_mark_undone")
            : String(localized: "task_detail_mark_done")
        }
    }

    var primaryActionColor: Color {
        task.isDone ? .orange : .green
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }
}

private struct WorkoutTemplateSheet: View {
    @Bindable var task: DTTaskItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let templates: [(day: String, exercises: [String], duration: Int)] = [
        ("Leg Day", ["Squat", "Leg Press", "Romanian Deadlift", "Walking Lunge", "Calf Raise"], 75),
        ("Push Day", ["Bench Press", "Incline Dumbbell Press", "Shoulder Press", "Lateral Raise", "Triceps Pushdown"], 70),
        ("Pull Day", ["Deadlift", "Lat Pulldown", "Barbell Row", "Seated Cable Row", "Biceps Curl"], 75),
        ("Full Body", ["Squat", "Bench Press", "Row", "Shoulder Press", "Walking Lunge"], 80)
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(templates, id: \.day) { template in
                    Button {
                        task.taskType = "workout"
                        task.workoutDay = template.day
                        task.workoutDurationMinutes = template.duration

                        let currentTaskUUID = task.taskUUID

                        let existingExercises = try? modelContext.fetch(
                            FetchDescriptor<WorkoutExerciseItem>(
                                predicate: #Predicate<WorkoutExerciseItem> { item in
                                    item.taskUUID == currentTaskUUID
                                }
                            )
                        )

                        existingExercises?.forEach { modelContext.delete($0) }

                        for (index, name) in template.exercises.enumerated() {
                            let item = WorkoutExerciseItem(
                                taskUUID: currentTaskUUID,
                                name: name,
                                sets: 3,
                                reps: 10,
                                durationSeconds: 0,
                                restSeconds: 60,
                                orderIndex: index
                            )
                            modelContext.insert(item)
                        }

                        try? modelContext.save()
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(template.day)
                                .font(.headline)

                            Text(template.exercises.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(4)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(String(localized: "task_detail_workout_templates"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
