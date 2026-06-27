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

    @Query(sort: \ExamItem.examDate, order: .forward)
    var allExams: [ExamItem]

    @Query(sort: \ExamStudyPlanItem.examDate, order: .forward)
    private var examPlanItems: [ExamStudyPlanItem]

    @State private var selectedFilter: TasksFilter = .today
    @State private var showAddTask = false

    @State private var recentlyCompletedTaskKey: String?
    @State private var pendingRemovalTaskKeys: Set<String> = []

    @State private var selectedTask: DTTaskItem?
    @State private var selectedTaskForSchedule: DTTaskItem?
    @State private var selectedExamForActions: ExamItem?
    @State private var expandedExamIDs: Set<UUID> = []

    enum TasksFilter: String, CaseIterable, Identifiable {
        case today = "today"
        case all = "all"
        case done = "done"
        case exams = "exams"

        var id: String { rawValue }

        var localizedTitle: String {
            switch self {
            case .today: return tr("common_today")
            case .all: return tr("tv_all")
            case .done: return "Biten"
            case .exams: return tr("tv_exams")
            }
        }

        var icon: String {
            switch self {
            case .today: return "sun.max.fill"
            case .all: return "checklist"
            case .done: return "checkmark.seal.fill"
            case .exams: return "graduationcap.fill"
            }
        }
    }

    private var pageAccent: Color {
        switch selectedFilter {
        case .today: return Color(arenaHex: AppArenaPalette.cyan)
        case .all: return Color(arenaHex: AppArenaPalette.blue)
        case .done: return Color(arenaHex: AppArenaPalette.green)
        case .exams: return Color(arenaHex: AppArenaPalette.gold)
        }
    }

    private var secondaryAccent: Color {
        Color(arenaHex: AppArenaPalette.purple)
    }

    var filteredTasks: [DTTaskItem] {
        let tasks: [DTTaskItem]

        switch selectedFilter {
        case .today:
            tasks = store.items.filter { task in
                (isToday(task) && !task.isDone) || pendingRemovalTaskKeys.contains(taskKey(task))
            }

        case .all:
            tasks = store.items.filter { task in
                task.taskType.lowercased() != "exam_study" &&
                (!task.isDone || pendingRemovalTaskKeys.contains(taskKey(task)))
            }

        case .done:
            tasks = store.items.filter(\.isDone)

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

    var userScopedExamPlans: [ExamStudyPlanItem] {
        guard let currentUserID = session.currentUser?.id.uuidString else { return [] }

        return examPlanItems.filter {
            $0.ownerUserID == currentUserID
        }
    }

    var examScheduleGroups: [(key: String, value: [ExamStudyPlanItem])] {
        Dictionary(grouping: userScopedExamPlans) {
            "\($0.examGroupID?.uuidString ?? $0.courseName)-\($0.examTypeRaw)-\($0.examDate.timeIntervalSince1970)"
        }
        .map { ($0.key, $0.value.sorted { $0.studyDate < $1.studyDate }) }
        .sorted {
            ($0.value.first?.examDate ?? .distantFuture) < ($1.value.first?.examDate ?? .distantFuture)
        }
    }

    var hasExamSchedule: Bool {
        !examScheduleGroups.isEmpty
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
            ArenaBackground(
                primaryGlow: pageAccent,
                secondaryGlow: secondaryAccent,
                warmGlow: Color(arenaHex: AppArenaPalette.coral),
                intensity: 0.94
            )

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 16) {
                    header
                    heroSummaryCard
                    filterSegment

                    if selectedFilter == .exams {
                        if hasExamSchedule {
                            examScheduleSection
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
                                        .transition(
                                            .asymmetric(
                                                insertion: .opacity,
                                                removal: .opacity
                                                    .combined(with: .offset(y: 18))
                                                    .combined(with: .scale(scale: 0.96))
                                            )
                                        )
                                }
                            }
                        }
                    }

                    Color.clear.frame(height: 82)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
        .preferredColorScheme(.dark)
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
            selectedExamForActions?.title ?? tr("at_kind_exam"),
            isPresented: Binding(
                get: { selectedExamForActions != nil },
                set: { if !$0 { selectedExamForActions = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(tr("tv_add_task_for_exam")) {
                showAddTask = true
            }

            Button(tr("tv_start_focus")) {
                selectedExamForActions = nil
            }

            Button(tr("common_cancel"), role: .cancel) {
                selectedExamForActions = nil
            }
        } message: {
            if let exam = selectedExamForActions {
                Text(tr("tv_quick_action_for", exam.courseName.isEmpty ? exam.title : exam.courseName))
            }
        }
    }
}

// MARK: - Main UI

private extension TasksView {

    var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left").accessibilityLabel(tr("a11y_back"))
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(arenaCircleBackground(tint: .white.opacity(0.50)))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(pageAccent)
                        .frame(width: 20, height: 1)

                    Text(tr("tv_task_flow_caps"))
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(2.3)
                        .foregroundStyle(pageAccent)
                        .lineLimit(1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(tr("at_kind_task"))
                        .font(.system(size: 38, weight: .black))
                        .foregroundStyle(.white)

                    Text(tr("tv_flow_word"))
                        .font(.system(size: 35, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    pageAccent,
                                    secondaryAccent
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .lineLimit(1)
                .minimumScaleFactor(0.72)

                Text(tr("tv_header_sub"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button {
                showAddTask = true
            } label: {
                Image(systemName: "plus").accessibilityLabel(tr("common_add"))
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(pageAccent)
                            .shadow(color: pageAccent.opacity(0.22), radius: 12, y: 6)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    var heroSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(pageAccent)
                            .frame(width: 18, height: 1)

                        Text(tr("tv_academic_flow_caps"))
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.7)
                            .foregroundStyle(pageAccent)
                    }

                    Text(summaryTitle)
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.76)

                    Text(summarySubtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                        .lineLimit(2)
                }

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(pageAccent.opacity(0.14))
                        .frame(width: 58, height: 58)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(pageAccent.opacity(0.18), lineWidth: 1)
                        )

                    Image(systemName: selectedFilter.icon)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(pageAccent)
                }
            }

            HStack(spacing: 8) {
                summaryChip(title: tr("tv_open"), value: "\(openCount)", tint: Color(arenaHex: AppArenaPalette.blue))
                summaryChip(title: tr("tasks_summary_done"), value: "\(doneCount)", tint: Color(arenaHex: AppArenaPalette.green))
                summaryChip(title: tr("common_today"), value: "\(todayOpenCount)", tint: Color(arenaHex: AppArenaPalette.gold))
            }
        }
        .padding(18)
        .background(arenaCardBackground(tint: pageAccent, radius: 30, strength: 0.74))
    }

    var summarySubtitle: String {
        switch selectedFilter {
        case .today:
            return todayOpenCount == 0 ? tr("tv_calm_title") : tr("tv_calm_sub")
        case .all:
            return tr("tv_all_sub")
        case .done:
            return tr("tv_done_sub")
        case .exams:
            return tr("tv_exams_sub")
        }
    }

    var filterSegment: some View {
        HStack(spacing: 7) {
            ForEach(TasksFilter.allCases) { filter in
                let isSelected = selectedFilter == filter
                let tint = filterTint(filter)

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selectedFilter = filter
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: filter.icon)
                            .font(.system(size: 13, weight: .black))

                        Text(filter.localizedTitle)
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .tracking(0.2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.48))
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isSelected ? tint.opacity(0.16) : Color.white.opacity(0.035))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isSelected ? tint.opacity(0.24) : Color.white.opacity(0.065), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.045),
                            Color.white.opacity(0.020),
                            Color.black.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.075), lineWidth: 1)
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
                HStack(spacing: 13) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(task.isDone ? 0.08 : 0.12))
                            .frame(width: 42, height: 42)

                        Circle()
                            .stroke(task.isDone ? Color(arenaHex: AppArenaPalette.green).opacity(0.35) : accent.opacity(0.70), lineWidth: 2.4)
                            .frame(width: 29, height: 29)

                        if task.isDone {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(Color(arenaHex: AppArenaPalette.green))
                        } else if isTopPriority {
                            Circle()
                                .fill(accent)
                                .frame(width: 8, height: 8)
                        }
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 7) {
                            Text(task.title)
                                .font(.system(size: 17, weight: .black))
                                .foregroundStyle(task.isDone ? .white.opacity(0.42) : .white.opacity(0.96))
                                .strikethrough(task.isDone, color: .white.opacity(0.42))
                                .lineLimit(1)

                            if isTopPriority && !task.isDone {
                                smallTag(tr("tv_priority"), tint: accent)
                            }
                        }

                        Text(taskSubtitle(for: task))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.46))
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            if !course.isEmpty {
                                miniMeta(icon: "book.closed.fill", text: course, tint: accent.opacity(0.95))
                            }

                            miniMeta(icon: taskTypeSymbol(for: task), text: taskTypeTitle(for: task), tint: accent)

                            if let mins = task.workoutDurationMinutes ?? task.scheduledWeekDurationMinutes {
                                miniMeta(icon: "timer", text: "\(mins) dk", tint: Color(arenaHex: AppArenaPalette.gold))
                            }
                        }
                    }

                    Spacer(minLength: 8)

                    if task.isDone {
                        statusBadge(icon: "checkmark.circle.fill", text: tr("common_completed"), tint: Color(arenaHex: AppArenaPalette.green))
                    } else if isOverdueTask {
                        statusBadge(icon: "exclamationmark.triangle.fill", text: tr("common_overdue"), tint: Color(arenaHex: AppArenaPalette.coral))
                    } else {
                        statusBadge(icon: "calendar", text: dueText(for: task), tint: accent)
                    }
                }
                .padding(16)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accent.opacity(isTopPriority && !task.isDone ? 0.090 : 0.060),
                                        secondaryAccent.opacity(0.032),
                                        Color(arenaHex: AppArenaPalette.surface).opacity(0.94)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        accent.opacity(isTopPriority && !task.isDone ? 0.120 : 0.070),
                                        Color.clear
                                    ],
                                    center: .topTrailing,
                                    startRadius: 8,
                                    endRadius: 180
                                )
                            )

                        if isRecentlyCompleted {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color(arenaHex: AppArenaPalette.green).opacity(0.18))
                                .transition(.opacity)
                        }

                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(
                                isRecentlyCompleted
                                ? Color(arenaHex: AppArenaPalette.green).opacity(0.34)
                                : (isTopPriority && !task.isDone ? accent.opacity(0.26) : Color.white.opacity(0.075)),
                                lineWidth: 1
                            )
                    }
                )
                .shadow(
                    color: isTopPriority && !task.isDone ? accent.opacity(0.10) : Color.black.opacity(0.18),
                    radius: isTopPriority && !task.isDone ? 11 : 8,
                    y: 5
                )

                if isRecentlyCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.black)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color(arenaHex: AppArenaPalette.green))
                        )
                        .shadow(color: Color(arenaHex: AppArenaPalette.green).opacity(0.22), radius: 8, y: 3)
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
                    task.isDone ? tr("common_reopen") : tr("tv_mark_done"),
                    systemImage: task.isDone ? "arrow.uturn.backward.circle" : "checkmark.circle"
                )
            }

            Button {
                selectedTaskForSchedule = task
            } label: {
                Label(tr("tv_plan"), systemImage: "calendar.badge.plus")
            }

            Button(role: .destructive) {
                deleteTask(task)
            } label: {
                Label("Sil", systemImage: "trash")
            }
        }
    }

    var examScheduleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                eyebrow: tr("tv_exam_schedule_caps"),
                title: tr("at_kind_exam"),
                italic: "takvimi",
                subtitle: tr("tv_exam_section_sub"),
                icon: "calendar.badge.clock",
                tint: Color(arenaHex: AppArenaPalette.gold)
            )

            VStack(spacing: 10) {
                ForEach(examScheduleGroups, id: \.key) { group in
                    if let first = group.value.first {
                        examScheduleRow(items: group.value, first: first)
                    }
                }
            }
        }
        .padding(18)
        .background(arenaCardBackground(tint: Color(arenaHex: AppArenaPalette.gold), radius: 30, strength: 0.70))
    }

    func examScheduleRow(items: [ExamStudyPlanItem], first: ExamStudyPlanItem) -> some View {
        let completed = items.filter(\.isCompleted).count
        let total = max(items.count, 1)
        let ratio = Double(completed) / Double(total)
        let accent = examPlanAccent(first)

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(accent.opacity(0.18), lineWidth: 5)
                    .frame(width: 50, height: 50)

                Circle()
                    .trim(from: 0, to: ratio)
                    .stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))

                Image(systemName: examPlanIcon(first))
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(first.courseName)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(first.examType.title.uppercased())
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(accent)
                        .padding(.horizontal, 7)
                        .frame(height: 22)
                        .background(
                            Capsule()
                                .fill(accent.opacity(0.14))
                        )
                }

                HStack(spacing: 8) {
                    miniMeta(icon: "calendar", text: examPlanDateText(first.examDate), tint: accent)
                    miniMeta(icon: "clock.fill", text: examPlanCountdownText(first.examDate), tint: Color(arenaHex: AppArenaPalette.gold))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(completed)/\(total)")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(accent)

                Text(tr("tv_prep_caps"))
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(.white.opacity(0.40))
            }
        }
        .padding(15)
        .background(rowBackground(tint: accent, radius: 22))
    }

    var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(pageAccent.opacity(0.13))
                    .frame(width: 76, height: 76)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(pageAccent.opacity(0.16), lineWidth: 1)
                    )

                Image(systemName: selectedFilter == .exams ? "calendar.badge.clock" : "checklist")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(pageAccent)
            }

            Text(emptyTitle)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.white)

            Text(emptySubtitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.52))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
        .background(arenaCardBackground(tint: pageAccent, radius: 30, strength: 0.46))
    }
}

// MARK: - Unused / Optional Existing Blocks Kept Compatible

private extension TasksView {

    var upcomingExamsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                eyebrow: tr("tv_upcoming_caps"),
                title: tr("tv_upcoming"),
                italic: tr("tv_exams_lc"),
                subtitle: tr("tv_start_early"),
                icon: "graduationcap.fill",
                tint: Color(arenaHex: AppArenaPalette.gold)
            )

            VStack(spacing: 10) {
                ForEach(visibleUpcomingExams, id: \.id) { exam in
                    upcomingExamRow(exam)
                }
            }
        }
        .padding(18)
        .background(arenaCardBackground(tint: Color(arenaHex: AppArenaPalette.gold), radius: 30, strength: 0.66))
    }

    var taskEmptyCompactState: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(pageAccent.opacity(0.12))
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(pageAccent)
                )

            Text(emptyTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            Text(emptySubtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.52))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
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
                            .frame(width: 46, height: 46)

                        Image(systemName: examSymbol(for: exam))
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(accent)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(exam.title)
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            smallTag(exam.examType, tint: accent)
                        }

                        Text(examReadinessText(for: exam))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.48))
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            miniMeta(icon: "calendar", text: examDateText(exam), tint: accent)
                            miniMeta(icon: "timer", text: tr("tv_study_suggestion", exam.preferredStudyMinutes), tint: Color(arenaHex: AppArenaPalette.gold))
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
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(.white.opacity(0.42))
                    }
                }
                .padding(16)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button {
                    addQuickStudyTask(for: exam, title: tr("tv_topic_review"), topic: exam.courseName)
                } label: {
                    Label(tr("tv_add_topic_review"), systemImage: "book.closed")
                }

                Button {
                    addQuickStudyTask(for: exam, title: tr("tv_solve_q"), topic: tr("tv_past_q"))
                } label: {
                    Label(tr("tv_add_solve"), systemImage: "pencil.and.list.clipboard")
                }

                Button {
                    addQuickStudyTask(for: exam, title: tr("tv_quick_review"), topic: "Son tekrar")
                } label: {
                    Label(tr("tv_add_quick_review"), systemImage: "bolt.fill")
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(examProgressText(for: exam))
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(accent)

                            Spacer()

                            Text(tr("tv_min_progress", completedLinkedMinutes(for: exam), exam.targetStudyMinutes))
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.46))
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
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(accent)

                            Text(tr("tv_no_steps"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.50))

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
        .background(rowBackground(tint: accent, radius: 24))
    }

    func examLinkedTaskRow(task: DTTaskItem, accent: Color) -> some View {
        Button {
            toggleLinkedExamTask(task)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(task.isDone ? Color(arenaHex: AppArenaPalette.green) : accent)

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(task.isDone ? .white.opacity(0.40) : .white.opacity(0.92))
                        .strikethrough(task.isDone, color: .white.opacity(0.40))
                        .lineLimit(1)

                    if !task.studyTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(task.studyTopic)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(task.isDone ? 0.34 : 0.48))
                            .lineLimit(1)
                    }
                }

                Spacer()

                if let mins = task.workoutDurationMinutes {
                    Text(tr("rel_min_short_n", mins))
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(task.isDone ? .white.opacity(0.40) : Color(arenaHex: AppArenaPalette.gold))
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
                        task.isDone ? Color.white.opacity(0.03) : accent.opacity(0.08),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Styles

private extension TasksView {

    func sectionHeader(
        eyebrow: String,
        title: String,
        italic: String,
        subtitle: String,
        icon: String,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(tint)
                        .frame(width: 18, height: 1)

                    Text(eyebrow)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.7)
                        .foregroundStyle(tint)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(title)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(.white)

                    Text(italic)
                        .font(.system(size: 23, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(tint)
                }

                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
            }

            Spacer()

            Image(systemName: icon)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(tint.opacity(0.13))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(tint.opacity(0.16), lineWidth: 1)
                        )
                )
        }
    }

    func arenaCircleBackground(tint: Color) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.100),
                        Color.black.opacity(0.26),
                        Color.white.opacity(0.050)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.28), radius: 14, y: 7)
    }

    func arenaCardBackground(tint: Color, radius: CGFloat, strength: Double) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.070 + strength * 0.035),
                        secondaryAccent.opacity(0.040),
                        Color(arenaHex: AppArenaPalette.surface).opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                tint.opacity(0.10 + strength * 0.075),
                                Color.clear
                            ],
                            center: .topTrailing,
                            startRadius: 8,
                            endRadius: 220
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(tint.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.20), radius: 13, y: 7)
    }

    func rowBackground(tint: Color, radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.075),
                        secondaryAccent.opacity(0.032),
                        Color.white.opacity(0.036)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(tint.opacity(0.13), lineWidth: 1)
            )
    }

    func filterTint(_ filter: TasksFilter) -> Color {
        switch filter {
        case .today: return Color(arenaHex: AppArenaPalette.cyan)
        case .all: return Color(arenaHex: AppArenaPalette.blue)
        case .done: return Color(arenaHex: AppArenaPalette.green)
        case .exams: return Color(arenaHex: AppArenaPalette.gold)
        }
    }

    func summaryChip(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
                .shadow(color: tint.opacity(0.24), radius: 6)

            Text("\(title) \(value)")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(0.25)
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            Capsule()
                .fill(tint.opacity(0.12))
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(0.15), lineWidth: 1)
                )
        )
    }

    func statusBadge(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .black))

            Text(text.uppercased())
                .lineLimit(1)
        }
        .font(.system(size: 9, weight: .black, design: .monospaced))
        .tracking(0.45)
        .padding(.horizontal, 9)
        .frame(height: 26)
        .background(
            Capsule()
                .fill(tint.opacity(0.14))
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(0.16), lineWidth: 1)
                )
        )
        .foregroundStyle(tint)
    }

    func miniMeta(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .black))

            Text(text.uppercased())
                .lineLimit(1)
        }
        .font(.system(size: 9, weight: .black, design: .monospaced))
        .tracking(0.35)
        .foregroundStyle(tint)
    }

    func smallTag(_ text: String, tint: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .tracking(0.55)
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(
                Capsule()
                    .fill(tint.opacity(0.14))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.16), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Exam Helpers

private extension TasksView {

    func examPlanAccent(_ item: ExamStudyPlanItem) -> Color {
        switch item.examType {
        case .quiz: return Color(arenaHex: AppArenaPalette.blue)
        case .midterm: return Color(arenaHex: AppArenaPalette.gold)
        case .final: return Color(arenaHex: AppArenaPalette.coral)
        }
    }

    func examPlanIcon(_ item: ExamStudyPlanItem) -> String {
        switch item.examType {
        case .quiz: return "pencil.and.list.clipboard"
        case .midterm: return "doc.text.fill"
        case .final: return "flag.fill"
        }
    }

    func examPlanDateText(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    func examPlanCountdownText(_ date: Date) -> String {
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: date)
        ).day ?? 0

        if days <= 0 { return tr("common_today") }
        if days == 1 { return tr("common_tomorrow") }
        return tr("rel_days_left", days)
    }

    func examAccent(for exam: ExamItem) -> Color {
        switch exam.examType.lowercased() {
        case "final": return Color(arenaHex: AppArenaPalette.coral)
        case "quiz": return Color(arenaHex: AppArenaPalette.blue)
        case "vize": return Color(arenaHex: AppArenaPalette.gold)
        default: return Color(arenaHex: AppArenaPalette.purple)
        }
    }

    func examSymbol(for exam: ExamItem) -> String {
        switch exam.examType.lowercased() {
        case "final": return "flag.fill"
        case "quiz": return "pencil.and.list.clipboard"
        case "vize": return "doc.text.fill"
        default: return "graduationcap.fill"
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

        if days <= 0 { return tr("common_today") }
        if days == 1 { return tr("common_tomorrow") }
        return tr("rel_days_left", days)
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
        return tr("rel_steps_done", done, total)
    }

    func examReadinessText(for exam: ExamItem) -> String {
        let days = daysUntilExam(exam)
        let completedMinutes = completedLinkedMinutes(for: exam)
        let linkedDone = completedLinkedTaskCount(for: exam)

        if days <= 1 && linkedDone >= 2 {
            return tr("tv_ready")
        }

        if completedMinutes >= exam.targetStudyMinutes {
            return tr("tv_prep_good")
        }

        if linkedDone >= 1 {
            return tr("tv_rhythm")
        }

        if days <= 2 {
            return tr("tv_short_review")
        }

        return tr("tv_start_early")
    }

    func examRowSubtitle(for exam: ExamItem) -> String {
        let course = exam.courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = exam.notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if !course.isEmpty, !note.isEmpty { return "\(course) • \(note)" }
        if !course.isEmpty { return course }
        if !note.isEmpty { return note }
        return tr("tv_upcoming_exam")
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
                Log.debug("❌ linked exam task toggle error:", error.localizedDescription)
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
            notes: tr("tv_study_step_for", exam.title),
            suggestedMinutes: exam.preferredStudyMinutes,
            dueDate: nil
        )
    }
}

// MARK: - Task Helpers

private extension TasksView {

    var emptyTitle: String {
        switch selectedFilter {
        case .today: return tr("tv_empty_today_title")
        case .all: return tr("tv_empty_none_title")
        case .done: return tr("tv_empty_done_title")
        case .exams: return tr("tv_empty_exams_title")
        }
    }

    var emptySubtitle: String {
        switch selectedFilter {
        case .today:
            return tr("tv_empty_today_sub")
        case .all:
            return tr("tv_empty_none_sub")
        case .done:
            return tr("tv_empty_done_sub")
        case .exams:
            return tr("tv_empty_exams_sub")
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
        case .today: return tr("tv_focus_today")
        case .all: return tr("tv_all_tasks")
        case .done: return "Tamamlananlar"
        case .exams: return tr("tv_your_exam_cal")
        }
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
            Log.debug("❌ TasksView toggle save error:", error)
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
                let animation: Animation = .spring(response: 0.30, dampingFraction: 0.88)

                withAnimation(animation) {
                    _ = pendingRemovalTaskKeys.remove(key)
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
            return Color(arenaHex: AppArenaPalette.coral)
        }

        switch task.colorName.lowercased() {
        case "green": return Color(arenaHex: AppArenaPalette.green)
        case "orange": return Color(arenaHex: AppArenaPalette.gold)
        case "pink": return Color(arenaHex: AppArenaPalette.coral)
        case "purple": return Color(arenaHex: AppArenaPalette.purple)
        default: return Color(arenaHex: AppArenaPalette.blue)
        }
    }

    func taskTypeTitle(for task: DTTaskItem) -> String {
        switch task.taskType.lowercased() {
        case "homework": return tr("tt_homework")
        case "exam": return tr("at_kind_exam")
        case "study": return tr("tt_study")
        case "project": return "Proje"
        case "workout": return "Workout"
        case "exam_study": return tr("tv_exam_study")
        default: return tr("at_kind_task")
        }
    }

    func taskTypeSymbol(for task: DTTaskItem) -> String {
        switch task.taskType.lowercased() {
        case "homework": return "book.closed.fill"
        case "exam": return "doc.text.fill"
        case "study": return "brain.head.profile"
        case "project": return "folder.fill"
        case "workout": return "dumbbell.fill"
        case "exam_study": return "graduationcap.fill"
        default: return "checklist"
        }
    }

    func dueText(for task: DTTaskItem) -> String {
        guard let target = task.dueDate ?? task.scheduledWeekDate else {
            return taskTypeTitle(for: task)
        }

        if isOverdue(task) {
            return tr("common_overdue")
        }

        let diff = Int(target.timeIntervalSinceNow)
        let minutes = max(0, diff / 60)
        let hours = minutes / 60
        let days = minutes / 1440

        if task.taskType.lowercased() == "exam" {
            if days >= 1 { return tr("rel_days_left", days) }
            if hours >= 1 { return tr("rel_hours_left", hours) }
            return tr("rel_min_left", minutes)
        }

        if task.taskType.lowercased() == "homework" {
            if Calendar.current.isDateInToday(target) {
                return tr("due_today")
            }

            if Calendar.current.isDateInTomorrow(target) {
                return tr("due_tomorrow")
            }
        }

        if Calendar.current.isDateInToday(target) {
            if hours >= 1 { return "\(hours) sa sonra" }
            return "\(minutes) dk sonra"
        }

        if Calendar.current.isDateInTomorrow(target) {
            return tr("common_tomorrow")
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
}
