//
//  TasksView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 17.03.2026.
//

import SwiftUI

struct TasksView: View {
    @Environment(\.dismiss) private var dismiss
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
                return String(localized: "tasks_filter_today")
            case .all:
                return String(localized: "tasks_filter_all")
            case .done:
                return String(localized: "tasks_filter_done")
            }
        }
    }

    var filteredTasks: [DTTaskItem] {
        let baseTasks: [DTTaskItem]

        switch selectedFilter {
        case .today:
            baseTasks = store.items
                .filter { task in
                    (isToday(task) && !task.isDone) || pendingRemovalTaskKeys.contains(taskKey(task))
                }
                .sorted { lhs, rhs in
                    (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
                }

        case .all:
            baseTasks = store.items
                .filter { task in
                    !task.isDone || pendingRemovalTaskKeys.contains(taskKey(task))
                }
                .sorted { lhs, rhs in
                    (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
                }

        case .done:
            baseTasks = store.items
                .filter { task in
                    task.isDone
                }
                .sorted { lhs, rhs in
                    (lhs.completedAt ?? .distantPast) > (rhs.completedAt ?? .distantPast)
                }
        }

        return baseTasks
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    filterSegment
                    summaryCard

                    if filteredTasks.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredTasks) { task in
                                taskCard(task)
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
                .presentationDetents([.medium, .large])
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

            Text(String(localized: "tasks_title"))
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
                        .font(.subheadline.weight(.semibold))
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

    var summaryCard: some View {
        HStack(spacing: 12) {
            summaryBox(
                title: String(localized: "tasks_summary_open"),
                value: "\(store.items.filter { !$0.isDone }.count)",
                icon: "circle"
            )

            summaryBox(
                title: String(localized: "tasks_summary_done"),
                value: "\(store.items.filter(\.isDone).count)",
                icon: "checkmark.circle.fill"
            )

            summaryBox(
                title: String(localized: "tasks_summary_today"),
                value: "\(store.items.filter { task in !task.isDone && isToday(task) }.count)",
                icon: "sun.max.fill"
            )
        }
    }

    func summaryBox(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)

            Text(value)
                .font(.title3.bold())
                .foregroundStyle(palette.primaryText)
                .monospacedDigit()

            Text(title)
                .font(.caption2)
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(palette.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
    }

    func taskCard(_ task: DTTaskItem) -> some View {
        let key = taskKey(task)
        let isRecentlyCompleted = recentlyCompletedTaskKey == key

        return Button {
            selectedTask = task
        } label: {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 12) {
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(task.isDone ? .green : palette.secondaryText)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(task.title)
                            .font(.headline)
                            .foregroundStyle(task.isDone ? palette.secondaryText : palette.primaryText)
                            .strikethrough(task.isDone, color: palette.secondaryText)

                        HStack(spacing: 8) {
                            if let due = task.dueDate {
                                Label {
                                    Text(due, style: .date)
                                } icon: {
                                    Image(systemName: "calendar")
                                }
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)

                                Text(due, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(palette.secondaryText)
                            } else {
                                Text(String(localized: "tasks_no_due_date"))
                                    .font(.caption)
                                    .foregroundStyle(palette.secondaryText)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(16)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(palette.cardFill)

                        if isRecentlyCompleted {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.green.opacity(0.18))
                                .transition(.opacity)
                        }

                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                isRecentlyCompleted ? Color.green.opacity(0.34) : palette.cardStroke,
                                lineWidth: 1
                            )
                    }
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
                        .scaleEffect(1.0)
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
                    task.isDone
                    ? String(localized: "tasks_mark_as_undone")
                    : String(localized: "tasks_mark_as_done"),
                    systemImage: task.isDone ? "arrow.uturn.backward.circle" : "checkmark.circle"
                )
            }

            Button {
                selectedTaskForSchedule = task
            } label: {
                Label(String(localized: "tasks_schedule"), systemImage: "calendar.badge.plus")
            }

            Button(role: .destructive) {
                deleteTask(task)
            } label: {
                Label(String(localized: "common_delete"), systemImage: "trash")
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
            return String(localized: "tasks_empty_today_title")
        case .all:
            return String(localized: "tasks_empty_all_title")
        case .done:
            return String(localized: "tasks_empty_done_title")
        }
    }

    var emptySubtitle: String {
        switch selectedFilter {
        case .today:
            return String(localized: "tasks_empty_today_subtitle")
        case .all:
            return String(localized: "tasks_empty_all_subtitle")
        case .done:
            return String(localized: "tasks_empty_done_subtitle")
        }
    }

    func taskKey(_ task: DTTaskItem) -> String {
        if let due = task.dueDate {
            return "\(task.title)-\(due.timeIntervalSince1970)"
        } else {
            return "\(task.title)-no-date"
        }
    }

    func isToday(_ task: DTTaskItem) -> Bool {
        guard let due = task.dueDate else { return false }
        return Calendar.current.isDateInToday(due)
    }

    func toggleTask(_ task: DTTaskItem) {
        guard let index = store.items.firstIndex(where: { $0.id == task.id }) else { return }

        let key = taskKey(task)

        store.items[index].isDone.toggle()

        if store.items[index].isDone {
            store.items[index].completedAt = Date()
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
                _ = withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
                    pendingRemovalTaskKeys.remove(key)
                }
            }
        } else {
            store.items[index].completedAt = nil

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
}
