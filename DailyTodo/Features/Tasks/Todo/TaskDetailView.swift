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
                    heroCard
                    identityCard
                    notesCard

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
                toastView(text: "Workout tamamlandı")
            }

            if showWeekAddedToast {
                toastView(text: "Week ekranına eklendi")
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

            Text("Görev Detayı")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
    }

    var heroCard: some View {
        let accent = taskAccentColor
        let course = task.courseName.trimmingCharacters(in: .whitespacesAndNewlines)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(taskTypeTitle)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(accent)

                        if task.isDone {
                            capsuleTag("Tamamlandı", tint: .green)
                        } else if isOverdue {
                            capsuleTag("Gecikmiş", tint: .red)
                        } else if !dueBadgeText.isEmpty {
                            capsuleTag(dueBadgeText, tint: accent)
                        }
                    }

                    Text(task.title.isEmpty ? "Başlıksız görev" : task.title)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(2)

                    if !course.isEmpty {
                        Text(course)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(accent.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: taskTypeSymbol)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(accent)
                }
            }

            HStack(spacing: 8) {
                if let due = task.dueDate {
                    infoChip(
                        icon: "calendar",
                        text: due.formatted(date: .abbreviated, time: .shortened),
                        tint: .secondary
                    )
                }

                if task.taskType.lowercased() == "study",
                   let mins = task.workoutDurationMinutes {
                    infoChip(
                        icon: "timer",
                        text: "\(mins) dk",
                        tint: accent
                    )
                }

                if !task.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    infoChip(
                        icon: "note.text",
                        text: "Not var",
                        tint: .secondary
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(palette.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    accent.opacity(0.10),
                                    Color.clear
                                ],
                                center: .topTrailing,
                                startRadius: 10,
                                endRadius: 240
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(accent.opacity(0.16), lineWidth: 1)
                )
        )
        .shadow(color: accent.opacity(0.08), radius: 12, y: 5)
    }

    var identityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Kimlik")

            VStack(spacing: 12) {
                labeledTextField(
                    title: "Başlık",
                    placeholder: "Görev başlığı",
                    text: $task.title
                )

                labeledTextField(
                    title: "Ders Adı",
                    placeholder: "Örn. Calculus, Physics",
                    text: Binding(
                        get: { task.courseName },
                        set: {
                            task.courseName = $0
                            try? modelContext.save()
                        }
                    )
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Görev Türü")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.secondaryText)

                    Picker("Görev Türü", selection: $task.taskType) {
                        Text("Görev").tag("standard")
                        Text("Ödev").tag("homework")
                        Text("Sınav").tag("exam")
                        Text("Çalışma").tag("study")
                        Text("Proje").tag("project")
                        Text("Workout").tag("workout")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: task.taskType) { _, _ in
                        try? modelContext.save()
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Renk")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.secondaryText)

                    HStack(spacing: 12) {
                        detailColorButton("blue", color: .blue)
                        detailColorButton("green", color: .green)
                        detailColorButton("orange", color: .orange)
                        detailColorButton("pink", color: .pink)
                        detailColorButton("purple", color: .purple)
                    }
                }
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Notlar")

            TextEditor(text: $task.notes)
                .frame(minHeight: 130)
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(palette.secondaryCardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(palette.cardStroke, lineWidth: 1)
                        )
                )
                .onChange(of: task.notes) { _, _ in
                    try? modelContext.save()
                }
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
                        historyMiniLine(title: "Son", value: historyText(for: latest))
                    }

                    if let best = bestHistory(for: exercise) {
                        historyMiniLine(title: "En iyi", value: historyText(for: best))
                    }
                }
            }

            HStack(spacing: 10) {
                stepCard(title: "Set", value: exercise.sets) {
                    if exercise.sets > 1 { exercise.sets -= 1 }
                    try? modelContext.save()
                } increment: {
                    exercise.sets += 1
                    try? modelContext.save()
                }

                stepCard(title: "Tekrar", value: exercise.reps) {
                    if exercise.reps > 1 { exercise.reps -= 1 }
                    try? modelContext.save()
                } increment: {
                    exercise.reps += 1
                    try? modelContext.save()
                }
            }

            HStack(spacing: 10) {
                stepCard(title: "KG", value: Int(exercise.weight)) {
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
                    Text("Superset")
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
                stepCard(title: "Saniye", value: exercise.durationSeconds) {
                    if exercise.durationSeconds >= 5 { exercise.durationSeconds -= 5 }
                    try? modelContext.save()
                } increment: {
                    exercise.durationSeconds += 5
                    try? modelContext.save()
                }

                stepCard(title: "Dinlenme", value: exercise.restSeconds) {
                    if exercise.restSeconds >= 5 { exercise.restSeconds -= 5 }
                    try? modelContext.save()
                } increment: {
                    exercise.restSeconds += 5
                    try? modelContext.save()
                }
            }

            TextField(
                "Opsiyonel not",
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
            return "\(item.sets) set × \(item.reps) tekrar"
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
            colorHex: eventHexColor,
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
                sectionLabel("Workout")

                Spacer()

                Button {
                    showWorkoutTemplateSheet = true
                } label: {
                    Text("Şablonlar")
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
                Text("Workout Day")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)

                Picker("Workout Day", selection: Binding(
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
                    Text("Önerilenler")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.primaryText)

                    flowExerciseButtons(recommendedExercises, tint: .green)
                }
            }

            if !otherExercises.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Diğer Egzersizler")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.primaryText)

                    flowExerciseButtons(otherExercises, tint: .blue)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Seçili Egzersizler")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.primaryText)

                if taskExercises.isEmpty {
                    Text("Henüz egzersiz eklenmedi")
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
                Text("Süre")
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
                    Text("\(task.workoutDurationMinutes ?? 45) dk")
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
            sectionLabel("Planlama")

            if let due = task.dueDate {
                infoChip(
                    icon: "calendar",
                    text: "Teslim: \(due.formatted(date: .abbreviated, time: .shortened))",
                    tint: taskAccentColor
                )
            }

            DatePicker(
                "Week zamanı",
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
                Text("Süre: \(task.scheduledWeekDurationMinutes ?? 60) dk")
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
                Text("Week’e Ekle")
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
            return task.isDone ? "Workout’u Geri Aç" : "Workout’u Bitir"
        } else {
            return task.isDone ? "Tekrar Aç" : "Tamamlandı Olarak İşaretle"
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

    var taskTypeTitle: String {
        switch task.taskType.lowercased() {
        case "homework": return "Ödev"
        case "exam": return "Sınav"
        case "study": return "Çalışma"
        case "project": return "Proje"
        case "workout": return "Workout"
        default: return "Görev"
        }
    }

    var taskTypeSymbol: String {
        switch task.taskType.lowercased() {
        case "homework": return "book.closed.fill"
        case "exam": return "doc.text.fill"
        case "study": return "brain.head.profile"
        case "project": return "folder.fill"
        case "workout": return "dumbbell.fill"
        default: return "checklist"
        }
    }

    var isOverdue: Bool {
        guard let due = task.dueDate else { return false }
        return !task.isDone && due < Date()
    }

    var dueBadgeText: String {
        guard let due = task.dueDate else { return "" }

        let diff = Int(due.timeIntervalSinceNow)
        let minutes = max(0, diff / 60)
        let hours = minutes / 60
        let days = minutes / 1440

        if task.taskType.lowercased() == "exam" {
            if days >= 1 { return "\(days) gün kaldı" }
            if hours >= 1 { return "\(hours) sa kaldı" }
            return "\(minutes) dk kaldı"
        }

        if task.taskType.lowercased() == "homework" {
            if Calendar.current.isDateInToday(due) {
                return "Bugün teslim"
            }
            if Calendar.current.isDateInTomorrow(due) {
                return "Yarın teslim"
            }
        }

        if Calendar.current.isDateInToday(due) {
            if hours >= 1 { return "\(hours) sa sonra" }
            return "\(minutes) dk sonra"
        }

        if Calendar.current.isDateInTomorrow(due) {
            return "Yarın"
        }

        return due.formatted(date: .abbreviated, time: .shortened)
    }

    var taskAccentColor: Color {
        if isOverdue { return .red }

        switch task.colorName.lowercased() {
        case "green": return .green
        case "orange": return .orange
        case "pink": return .pink
        case "purple": return .purple
        default: return .blue
        }
    }

    var eventHexColor: String {
        switch task.colorName.lowercased() {
        case "green": return "#22C55E"
        case "orange": return "#F59E0B"
        case "pink": return "#FF2D55"
        case "purple": return "#AF52DE"
        default: return "#3B82F6"
        }
    }

    func labeledTextField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.secondaryText)

            TextField(placeholder, text: text)
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
                .onChange(of: text.wrappedValue) { _, _ in
                    try? modelContext.save()
                }
        }
    }

    func detailColorButton(_ name: String, color: Color) -> some View {
        let isSelected = task.colorName.lowercased() == name.lowercased()

        return Button {
            task.colorName = name
            try? modelContext.save()
        } label: {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 28, height: 28)

                if isSelected {
                    Circle()
                        .stroke(Color.white.opacity(0.95), lineWidth: 2.2)
                        .frame(width: 36, height: 36)

                    Circle()
                        .stroke(color.opacity(0.22), lineWidth: 6)
                        .frame(width: 42, height: 42)
                }
            }
        }
        .buttonStyle(.plain)
        .shadow(
            color: isSelected ? color.opacity(0.16) : .clear,
            radius: isSelected ? 8 : 0,
            y: 2
        )
    }

    func infoChip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(tint.opacity(0.12))
        )
    }

    func capsuleTag(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
    }

    func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(.secondary.opacity(0.82))
            .padding(.leading, 2)
    }

    func toastView(text: String) -> some View {
        VStack {
            Spacer()

            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white)

                Text(text)
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
            .navigationTitle("Workout Şablonları")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
