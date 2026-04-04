//
//  TasksView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 17.03.2026.
//

import SwiftUI
import SwiftData

struct TasksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var store: TodoStore
    
    @EnvironmentObject var session: SessionStore
    @Query(sort: \ExamItem.examDate, order: .forward) var allExams: [ExamItem]

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue

    @State private var selectedFilter: TasksFilter = .today
    @State private var showAddTask = false

    @State private var recentlyCompletedTaskKey: String?
    @State private var pendingRemovalTaskKeys: Set<String> = []

    @State private var selectedTask: DTTaskItem?
    @State private var selectedTaskForSchedule: DTTaskItem?
    @State private var selectedExamForActions: ExamItem?
    @State private var expandedExamIDs: Set<UUID> = []

    private let palette = ThemePalette()

    enum TasksFilter: String, CaseIterable, Identifiable {
        case today = "today"
        case all = "all"
        case done = "done"
        case exams = "exams"

        var id: String { rawValue }

        var localizedTitle: String {
            switch self {
            case .today:
                return "Bugün"
            case .all:
                return "Tümü"
            case .done:
                return "Biten"
            case .exams:
                return "Sınavlar"
            }
        }
    }

    var filteredTasks: [DTTaskItem] {
        let tasks: [DTTaskItem]

        switch selectedFilter {
            case .today:
                tasks = store.items
                    .filter { task in
                        (isToday(task) && !task.isDone) || pendingRemovalTaskKeys.contains(taskKey(task))
                    }

            case .all:
                tasks = store.items
                    .filter { task in
                        !task.isDone || pendingRemovalTaskKeys.contains(taskKey(task))
                    }

            case .done:
                tasks = store.items
                    .filter(\.isDone)

            case .exams:
                tasks = []
            }

        return tasks.sorted(by: taskSort)
    }
    
    var userScopedExams: [ExamItem] {
        let currentUserID = session.currentUser?.id.uuidString

        if let currentUserID {
            let matched = allExams.filter { $0.ownerUserID == currentUserID }
            if !matched.isEmpty { return matched }
        }

        return allExams
    }

    var upcomingExams: [ExamItem] {
        userScopedExams
            .filter { !$0.isCompleted && $0.examDate >= Date() }
            .sorted { $0.examDate < $1.examDate }
    }

    var visibleUpcomingExams: [ExamItem] {
        Array(upcomingExams.prefix(3))
    }

    var hasVisibleUpcomingExams: Bool {
        !visibleUpcomingExams.isEmpty
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    heroSummaryCard
                    filterSegment

                    if selectedFilter == .exams {
                        if hasVisibleUpcomingExams {
                            upcomingExamsSection
                        } else {
                            emptyState
                        }
                    } else {
                        if filteredTasks.isEmpty {
                            emptyState
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(Array(filteredTasks.enumerated()), id: \.element.taskUUID) { index, task in
                                    taskCard(task, isTopPriority: index == 0 && !task.isDone)
                                        .transition(.asymmetric(
                                            insertion: .opacity,
                                            removal: .opacity
                                                .combined(with: .offset(y: 18))
                                                .combined(with: .scale(scale: 0.96))
                                        ))
                                }
                            }
                        }
                    }

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showAddTask) {
            AddTaskView()
                .environmentObject(store)
                .environmentObject(session)
                .presentationDetents([.large])
        }
        .sheet(item: $selectedTask) { task in
            NavigationStack {
                TaskDetailView(task: task)
            }
        }
        .sheet(item: $selectedTaskForSchedule) { task in
            NavigationStack {
                TaskScheduleSheet(task: task)
            }
        }
        .onAppear {
            store.reload()
        }
        .confirmationDialog(
            selectedExamForActions?.title ?? "Sınav",
            isPresented: Binding(
                get: { selectedExamForActions != nil },
                set: { if !$0 { selectedExamForActions = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Bu sınav için görev ekle") {
                showAddTask = true
            }

            Button("Focus başlat") {
                // şimdilik placeholder
            }

            Button("İptal", role: .cancel) {
                selectedExamForActions = nil
            }
        } message: {
            if let exam = selectedExamForActions {
                Text("\(exam.courseName.isEmpty ? exam.title : exam.courseName) için hızlı bir işlem seç.")
            }
        }
    }
}

private extension TasksView {
    var header: some View {
        HStack(spacing: 12) {
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

            Text("Görevler")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            Spacer()

            Button {
                showAddTask = true
            } label: {
                Image(systemName: "plus")
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
        }
    }

    var heroSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Akademik Akışın")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.secondaryText)

                    Text(summaryTitle)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 50, height: 50)

                    Image(systemName: "checklist")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }

            HStack(spacing: 8) {
                summaryChip(title: "Açık", value: "\(openCount)", tint: .blue)
                summaryChip(title: "Biten", value: "\(doneCount)", tint: .green)
                summaryChip(title: "Bugün", value: "\(todayOpenCount)", tint: .orange)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(palette.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.accentColor.opacity(0.08),
                                    Color.clear
                                ],
                                center: .topTrailing,
                                startRadius: 10,
                                endRadius: 220
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
    }
    
    var upcomingExamsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Yaklaşan Sınavlar")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Text("Hazırlığını erkenden başlat")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer()

                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.orange)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.orange.opacity(0.12))
                    )
            }

            VStack(spacing: 10) {
                ForEach(visibleUpcomingExams, id: \.id) { exam in
                    upcomingExamRow(exam)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(palette.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.orange.opacity(0.08),
                                    Color.clear
                                ],
                                center: .topTrailing,
                                startRadius: 10,
                                endRadius: 220
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
    }

    var filterSegment: some View {
        HStack(spacing: 8) {
            ForEach(TasksFilter.allCases) { filter in
                let isSelected = selectedFilter == filter

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selectedFilter = filter
                    }
                } label: {
                    Text(filter.localizedTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? palette.primaryText : palette.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    isSelected
                                    ? Color.accentColor.opacity(appTheme == AppTheme.light.rawValue ? 0.14 : 0.18)
                                    : palette.secondaryCardFill
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    isSelected
                                    ? Color.accentColor.opacity(appTheme == AppTheme.light.rawValue ? 0.22 : 0.30)
                                    : palette.cardStroke.opacity(0.8),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
    }

    func taskCard(_ task: DTTaskItem, isTopPriority: Bool = false) -> some View {
        let key = taskKey(task)
        let isRecentlyCompleted = recentlyCompletedTaskKey == key
        let accent = taskAccent(for: task)
        let course = task.courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let isOverdueTask = isOverdue(task)

        return Button {
            selectedTask = task
        } label: {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(task.isDone ? Color.green.opacity(0.28) : accent, lineWidth: 2.4)
                            .frame(width: 28, height: 28)

                        if task.isDone {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.green)
                        } else if isTopPriority {
                            Circle()
                                .fill(accent)
                                .frame(width: 8, height: 8)
                        }
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(task.title)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(task.isDone ? palette.secondaryText : palette.primaryText)
                                .strikethrough(task.isDone, color: palette.secondaryText)

                            if isTopPriority && !task.isDone {
                                smallTag("Öncelikli", tint: accent)
                            }
                        }

                        Text(taskSubtitle(for: task))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            if !course.isEmpty {
                                miniMeta(icon: "book.closed.fill", text: course, tint: accent.opacity(0.95))
                            }

                            miniMeta(icon: taskTypeSymbol(for: task), text: taskTypeTitle(for: task), tint: accent)

                            if task.taskType.lowercased() == "study",
                               let mins = task.workoutDurationMinutes {
                                miniMeta(icon: "timer", text: "\(mins) dk", tint: .orange)
                            }
                        }
                    }

                    Spacer()

                    if task.isDone {
                        statusBadge(icon: "checkmark.circle.fill", text: "Tamamlandı", tint: .green)
                    } else if isOverdueTask {
                        statusBadge(icon: "exclamationmark.triangle.fill", text: "Gecikmiş", tint: .red)
                    } else {
                        statusBadge(icon: "calendar", text: dueText(for: task), tint: accent)
                    }
                }
                .padding(16)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                isTopPriority && !task.isDone
                                ? accent.opacity(0.08)
                                : palette.cardFill
                            )

                        if isRecentlyCompleted {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.green.opacity(0.18))
                                .transition(.opacity)
                        }

                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                isRecentlyCompleted
                                ? Color.green.opacity(0.34)
                                : (isTopPriority && !task.isDone ? accent.opacity(0.28) : palette.cardStroke),
                                lineWidth: 1
                            )
                    }
                )
                .shadow(
                    color: isTopPriority && !task.isDone ? accent.opacity(0.10) : .clear,
                    radius: isTopPriority && !task.isDone ? 10 : 0,
                    y: isTopPriority && !task.isDone ? 4 : 0
                )

                if isRecentlyCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.green)
                        )
                        .shadow(color: Color.green.opacity(0.22), radius: 8, y: 3)
                        .offset(x: -8, y: 8)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0.35) {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()

            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                toggleTask(task)
            }
        }
        .contextMenu {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    toggleTask(task)
                }
            } label: {
                Label(
                    task.isDone ? "Tekrar Aç" : "Tamamlandı Yap",
                    systemImage: task.isDone ? "arrow.uturn.backward.circle" : "checkmark.circle"
                )
            }

            Button {
                selectedTaskForSchedule = task
            } label: {
                Label("Planla", systemImage: "calendar.badge.plus")
            }

            Button(role: .destructive) {
                deleteTask(task)
            } label: {
                Label("Sil", systemImage: "trash")
            }
        }
    }
    
    var taskEmptyCompactState: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(palette.cardFill)
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(palette.secondaryText)
                )

            Text(emptyTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.primaryText)

            Text(emptySubtitle)
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
    }
    
    func examAccent(for exam: ExamItem) -> Color {
        switch exam.examType.lowercased() {
        case "final":
            return .pink
        case "quiz":
            return .blue
        case "vize":
            return .orange
        default:
            return .purple
        }
    }

    func examSymbol(for exam: ExamItem) -> String {
        switch exam.examType.lowercased() {
        case "final":
            return "flag.fill"
        case "quiz":
            return "pencil.and.list.clipboard"
        case "vize":
            return "doc.text.fill"
        default:
            return "graduationcap.fill"
        }
    }

    func daysUntilExam(_ exam: ExamItem) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: exam.examDate)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    func examCountdownText(_ exam: ExamItem) -> String {
        let days = daysUntilExam(exam)

        if days <= 0 {
            return "Bugün"
        } else if days == 1 {
            return "Yarın"
        } else {
            return "\(days) gün kaldı"
        }
    }

    func examDateText(_ exam: ExamItem) -> String {
        exam.examDate.formatted(date: .abbreviated, time: .shortened)
    }
    
    func linkedTasks(for exam: ExamItem) -> [DTTaskItem] {
        store.items
            .filter { $0.linkedExamID == exam.id }
            .sorted(by: taskSort)
    }

    func completedLinkedTaskCount(for exam: ExamItem) -> Int {
        linkedTasks(for: exam).filter(\.isDone).count
    }

    func totalLinkedTaskCount(for exam: ExamItem) -> Int {
        linkedTasks(for: exam).count
    }

    func completedLinkedMinutes(for exam: ExamItem) -> Int {
        linkedTasks(for: exam)
            .filter(\.isDone)
            .reduce(0) { $0 + ($1.workoutDurationMinutes ?? $1.scheduledWeekDurationMinutes ?? 0) }
    }

    func examProgressText(for exam: ExamItem) -> String {
        let done = completedLinkedTaskCount(for: exam)
        let total = max(exam.targetStudyTaskCount, totalLinkedTaskCount(for: exam))
        return "\(done)/\(total) adım tamamlandı"
    }

    func examReadinessText(for exam: ExamItem) -> String {
        let days = daysUntilExam(exam)
        let completedMinutes = completedLinkedMinutes(for: exam)
        let linkedDone = completedLinkedTaskCount(for: exam)

        if days <= 1 && linkedDone >= 2 {
            return "Sınava hazır görünüyorsun"
        }

        if completedMinutes >= exam.targetStudyMinutes {
            return "Hazırlık iyi gidiyor"
        }

        if linkedDone >= 1 {
            return "Ritim oluştu, devam et"
        }

        if days <= 2 {
            return "Kısa bir tekrar iyi olur"
        }

        return "Hazırlığını erkenden başlat"
    }

    func examRowSubtitle(for exam: ExamItem) -> String {
        let course = exam.courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = exam.notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if !course.isEmpty, !note.isEmpty {
            return "\(course) • \(note)"
        }

        if !course.isEmpty {
            return course
        }

        if !note.isEmpty {
            return note
        }

        return "Yaklaşan sınav"
    }
    
    func examLinkedTaskRow(task: DTTaskItem, accent: Color) -> some View {
        Button {
            toggleLinkedExamTask(task)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(task.isDone ? .green : accent)

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(task.isDone ? palette.secondaryText : palette.primaryText)
                        .strikethrough(task.isDone, color: palette.secondaryText.opacity(0.6))
                        .lineLimit(1)

                    if !task.studyTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(task.studyTopic)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(palette.secondaryText.opacity(task.isDone ? 0.7 : 1))
                            .lineLimit(1)
                    }
                }

                Spacer()

                if let mins = task.workoutDurationMinutes {
                    Text("\(mins) dk")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(task.isDone ? palette.secondaryText : .orange)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(task.isDone ? Color.white.opacity(0.025) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        task.isDone
                        ? Color.white.opacity(0.03)
                        : accent.opacity(0.08),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    func upcomingExamRow(_ exam: ExamItem) -> some View {
        let accent = examAccent(for: exam)
        let linked = linkedTasks(for: exam)
        let isExpanded = isExamExpanded(exam)
        let ratio = examProgressRatio(for: exam)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                toggleExamExpanded(exam)
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.14))
                            .frame(width: 44, height: 44)

                        Image(systemName: examSymbol(for: exam))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(accent)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(exam.title)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(palette.primaryText)
                                .lineLimit(1)

                            smallTag(exam.examType, tint: accent)
                        }

                        Text(examReadinessText(for: exam))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            miniMeta(icon: "calendar", text: examDateText(exam), tint: accent)
                            miniMeta(icon: "timer", text: "\(exam.preferredStudyMinutes) dk öneri", tint: .orange)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        statusBadge(
                            icon: "clock.fill",
                            text: examCountdownText(exam),
                            tint: accent
                        )

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(palette.secondaryText)
                    }
                }
                .padding(16)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button {
                    addQuickStudyTask(for: exam, title: "Konu tekrarı", topic: exam.courseName)
                } label: {
                    Label("Konu tekrarı ekle", systemImage: "book.closed")
                }

                Button {
                    addQuickStudyTask(for: exam, title: "Soru çözümü", topic: "Çıkmış sorular")
                } label: {
                    Label("Soru çözümü ekle", systemImage: "pencil.and.list.clipboard")
                }

                Button {
                    addQuickStudyTask(for: exam, title: "Hızlı tekrar", topic: "Son tekrar")
                } label: {
                    Label("Hızlı tekrar ekle", systemImage: "bolt.fill")
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(examProgressText(for: exam))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(accent)

                            Spacer()

                            Text("\(completedLinkedMinutes(for: exam))/\(exam.targetStudyMinutes) dk")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(palette.secondaryText)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.08))

                                Capsule()
                                    .fill(accent)
                                    .frame(width: max(12, geo.size.width * ratio))
                            }
                        }
                        .frame(height: 8)
                    }

                    if linked.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(accent)

                            Text("Henüz çalışma adımı yok. Uzun basıp hızlıca ekleyebilirsin.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(palette.secondaryText)

                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                        )
                    } else {
                        VStack(spacing: 8) {
                            ForEach(linked, id: \.taskUUID) { task in
                                examLinkedTaskRow(task: task, accent: accent)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(palette.secondaryCardFill)

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(accent.opacity(isExpanded ? 0.10 : (0.06 + (0.12 * ratio))))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(accent.opacity(isExpanded ? 0.18 : 0.10), lineWidth: 1)
        )
    }
    
    func isExamExpanded(_ exam: ExamItem) -> Bool {
        expandedExamIDs.contains(exam.id)
    }

    func toggleExamExpanded(_ exam: ExamItem) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            if expandedExamIDs.contains(exam.id) {
                expandedExamIDs.remove(exam.id)
            } else {
                expandedExamIDs.insert(exam.id)
            }
        }
    }

    func toggleLinkedExamTask(_ task: DTTaskItem) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            task.isDone.toggle()
            task.completedAt = task.isDone ? Date() : nil

            do {
                try modelContext.save()
                store.reload()
            } catch {
                print("❌ linked exam task toggle error:", error.localizedDescription)
            }
        }
    }

    func examProgressRatio(for exam: ExamItem) -> Double {
        let minuteRatio = Double(completedLinkedMinutes(for: exam)) / Double(max(exam.targetStudyMinutes, 1))
        let taskRatio = Double(completedLinkedTaskCount(for: exam)) / Double(max(exam.targetStudyTaskCount, 1))
        return min(1.0, max(minuteRatio, taskRatio))
    }
    
    func addQuickStudyTask(for exam: ExamItem, title: String, topic: String) {
        store.addExamStudyTask(
            exam: exam,
            title: "\(exam.courseName.isEmpty ? exam.title : exam.courseName) • \(title)",
            topic: topic,
            notes: "\(exam.title) için çalışma adımı",
            suggestedMinutes: exam.preferredStudyMinutes,
            dueDate: nil
        )
    }
    
    var emptyState: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(palette.cardFill)
                .frame(width: 72, height: 72)
                .overlay(
                    Image(systemName: "checklist")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(palette.secondaryText)
                )

            Text(emptyTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.primaryText)

            Text(emptySubtitle)
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    var emptyTitle: String {
        switch selectedFilter {
        case .today:
            return "Bugün için görev yok"
        case .all:
            return "Henüz görev eklenmedi"
        case .done:
            return "Tamamlanan görev görünmüyor"
        case .exams:
            return "Yaklaşan sınav yok"
        }
    }

    var emptySubtitle: String {
        switch selectedFilter {
        case .today:
            return "Bugün sakin görünüyor. Yeni bir görev ekleyebilirsin."
        case .all:
            return "İlk görevi ekleyerek akışını başlat."
        case .done:
            return "Tamamladığın görevler burada görünecek."
        case .exams:
            return "Eklediğin sınavlar burada görünecek."
        }
    }

    var openCount: Int {
        store.items.filter { !$0.isDone }.count
    }

    var doneCount: Int {
        store.items.filter(\.isDone).count
    }

    var todayOpenCount: Int {
        store.items.filter { task in !task.isDone && isToday(task) }.count
    }

    var summaryTitle: String {
        switch selectedFilter {
        case .today:
            return "Bugüne odaklan"
        case .all:
            return "Tüm görevlerin"
        case .done:
            return "Tamamlananlar"
        case .exams:
            return "Sınav Takvimin"
        }
    }

    func summaryChip(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)

            Text("\(title) \(value)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(tint.opacity(0.12))
        )
    }

    func taskKey(_ task: DTTaskItem) -> String {
        if let due = task.dueDate {
            return "\(task.taskUUID)-\(due.timeIntervalSince1970)"
        } else {
            return "\(task.taskUUID)-no-date"
        }
    }

    func isToday(_ task: DTTaskItem) -> Bool {
        if let due = task.dueDate {
            return Calendar.current.isDateInToday(due)
        }
        if let weekDate = task.scheduledWeekDate {
            return Calendar.current.isDateInToday(weekDate)
        }
        return false
    }

    func isOverdue(_ task: DTTaskItem) -> Bool {
        guard let due = task.dueDate else { return false }
        return !task.isDone && due < Date()
    }

    func taskSort(_ lhs: DTTaskItem, _ rhs: DTTaskItem) -> Bool {
        if lhs.isDone != rhs.isDone {
            return !lhs.isDone && rhs.isDone
        }

        let lhsUrgency = urgencyScore(for: lhs)
        let rhsUrgency = urgencyScore(for: rhs)
        if lhsUrgency != rhsUrgency {
            return lhsUrgency > rhsUrgency
        }

        let lhsCourse = lhs.courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let rhsCourse = rhs.courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !lhsCourse.isEmpty, !rhsCourse.isEmpty, lhsCourse != rhsCourse {
            return lhsCourse.localizedCaseInsensitiveCompare(rhsCourse) == .orderedAscending
        }

        let lhsDate = lhs.dueDate ?? lhs.scheduledWeekDate ?? lhs.createdAt
        let rhsDate = rhs.dueDate ?? rhs.scheduledWeekDate ?? rhs.createdAt
        return lhsDate < rhsDate
    }

    func urgencyScore(for task: DTTaskItem) -> Int {
        if task.isDone { return -1 }
        if isOverdue(task) { return 100 }

        if task.taskType.lowercased() == "exam" {
            if let due = task.dueDate {
                let minutes = Int(due.timeIntervalSinceNow / 60)
                if minutes <= 180 { return 95 }
                if minutes <= 1440 { return 85 }
            }
        }

        guard let due = task.dueDate ?? task.scheduledWeekDate else { return 10 }

        let minutes = Int(due.timeIntervalSinceNow / 60)
        if minutes <= 30 { return 90 }
        if minutes <= 120 { return 70 }
        if Calendar.current.isDateInToday(due) { return 50 }
        return 20
    }

    func toggleTask(_ task: DTTaskItem) {
        let key = taskKey(task)
        let willBeDone = !task.isDone

        task.isDone = willBeDone
        task.completedAt = willBeDone ? Date() : nil

        do {
            try modelContext.save()
            store.reload()
        } catch {
            print("❌ TasksView toggle save error:", error)
        }

        if willBeDone {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()

            recentlyCompletedTaskKey = key
            pendingRemovalTaskKeys.insert(key)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.22)) {
                    if recentlyCompletedTaskKey == key {
                        recentlyCompletedTaskKey = nil
                    }
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
                    pendingRemovalTaskKeys.remove(key)
                    return
                }
            }
        } else {
            if recentlyCompletedTaskKey == key {
                recentlyCompletedTaskKey = nil
            }
            pendingRemovalTaskKeys.remove(key)
        }
    }

    func deleteTask(_ task: DTTaskItem) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            store.delete(task)
        }
    }

    func taskAccent(for task: DTTaskItem) -> Color {
        if isOverdue(task) {
            return .red
        }

        switch task.colorName.lowercased() {
        case "green":
            return .green
        case "orange":
            return .orange
        case "pink":
            return .pink
        case "purple":
            return .purple
        default:
            return .blue
        }
    }

    func taskTypeTitle(for task: DTTaskItem) -> String {
        switch task.taskType.lowercased() {
        case "homework": return "Ödev"
        case "exam": return "Sınav"
        case "study": return "Çalışma"
        case "project": return "Proje"
        case "workout": return "Workout"
        case "exam_study": return "Sınav Çalışması"
        default: return "Görev"
        }
    }

    func taskTypeSymbol(for task: DTTaskItem) -> String {
        switch task.taskType.lowercased() {
        case "homework": return "book.closed.fill"
        case "exam": return "doc.text.fill"
        case "study": return "brain.head.profile"
        case "project": return "folder.fill"
        case "workout": return "dumbbell.fill"
        case "exam_study": return "gradutaioncap.fill"
        default: return "checklist"
        }
    }

    func dueText(for task: DTTaskItem) -> String {
        guard let target = task.dueDate ?? task.scheduledWeekDate else {
            return taskTypeTitle(for: task)
        }

        if isOverdue(task) {
            return "Gecikmiş"
        }

        let diff = Int(target.timeIntervalSinceNow)
        let minutes = max(0, diff / 60)
        let hours = minutes / 60
        let days = minutes / 1440

        if task.taskType.lowercased() == "exam" {
            if days >= 1 { return "\(days) gün kaldı" }
            if hours >= 1 { return "\(hours) sa kaldı" }
            return "\(minutes) dk kaldı"
        }

        if task.taskType.lowercased() == "homework" {
            if Calendar.current.isDateInToday(target) {
                return "Bugün teslim"
            }
            if Calendar.current.isDateInTomorrow(target) {
                return "Yarın teslim"
            }
        }

        if Calendar.current.isDateInToday(target) {
            if hours >= 1 { return "\(hours) sa sonra" }
            return "\(minutes) dk sonra"
        }

        if Calendar.current.isDateInTomorrow(target) {
            return "Yarın"
        }

        return target.formatted(date: .abbreviated, time: .shortened)
    }

    func taskSubtitle(for task: DTTaskItem) -> String {
        let course = task.courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = task.notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if !course.isEmpty, !note.isEmpty {
            return "\(course) • \(note)"
        }

        if !course.isEmpty {
            if let due = task.dueDate ?? task.scheduledWeekDate {
                return "\(course) • \(due.formatted(date: .omitted, time: .shortened))"
            }
            return course
        }

        if !note.isEmpty {
            return note
        }

        if let due = task.dueDate ?? task.scheduledWeekDate {
            return due.formatted(date: .omitted, time: .shortened)
        }

        return "Detay eklenmedi"
    }

    func statusBadge(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(tint.opacity(0.14)))
        .foregroundStyle(tint)
    }

    func miniMeta(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(tint)
    }

    func smallTag(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tint.opacity(0.14))
            )
    }
}
