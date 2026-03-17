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

    private let palette = ThemePalette()

    enum TasksFilter: String, CaseIterable, Identifiable {
        case today = "Today"
        case all = "All"
        case done = "Done"

        var id: String { rawValue }
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
                                        removal: .opacity.combined(with: .move(edge: .bottom))
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

            Text("Tasks")
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
                    Text(filter.rawValue)
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
                title: "Open",
                value: "\(store.items.filter { !$0.isDone }.count)",
                icon: "circle"
            )

            summaryBox(
                title: "Done",
                value: "\(store.items.filter(\.isDone).count)",
                icon: "checkmark.circle.fill"
            )

            summaryBox(
                title: "Today",
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
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                toggleTask(task)
            }
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
                                Text("No due date")
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
                                .fill(Color.green.opacity(0.14))
                                .transition(.opacity)
                        }

                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                isRecentlyCompleted ? Color.green.opacity(0.28) : palette.cardStroke,
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
                        .shadow(color: Color.green.opacity(0.18), radius: 6, y: 2)
                        .offset(x: -8, y: 8)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
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
        case .today: return "No tasks for today"
        case .all: return "No open tasks"
        case .done: return "No completed tasks yet"
        }
    }

    var emptySubtitle: String {
        switch selectedFilter {
        case .today: return "Enjoy the day or add a new task."
        case .all: return "Your inbox is clear for now."
        case .done: return "Complete a task to see it here."
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

            recentlyCompletedTaskKey = key
            pendingRemovalTaskKeys.insert(key)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { () -> Void in
                _ = withAnimation(.easeOut(duration: 0.22)) {
                    if recentlyCompletedTaskKey == key {
                        recentlyCompletedTaskKey = nil
                    }
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) { () -> Void in
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
}
