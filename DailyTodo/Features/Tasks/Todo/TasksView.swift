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

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue

    @State private var selectedFilter: TasksFilter = .today
    @State private var showAddTask = false

    @State private var recentlyCompletedTaskKey: String?
    @State private var pendingRemovalTaskKeys: Set<String> = []

    @State private var selectedTask: DTTaskItem?
    @State private var selectedTaskForSchedule: DTTaskItem?

    private let palette = ThemePalette()

    enum TasksFilter: String, CaseIterable, Identifiable {
        case today = "today"
        case all = "all"
        case done = "done"

        var id: String { rawValue }

        var localizedTitle: String {
            switch self {
            case .today:
                return "Bugün"
            case .all:
                return "Tümü"
            case .done:
                return "Biten"
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
        }

        return tasks.sorted(by: taskSort)
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    heroSummaryCard
                    filterSegment

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
