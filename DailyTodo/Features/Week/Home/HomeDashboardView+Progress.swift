//
//  HomeDashboardView+Progress.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI
import SwiftData
import Combine

extension HomeDashboardView {
    var todayBoardTasks: [DTTaskItem] {
        let calendar = Calendar.current

        return userScopedTasks
            .filter { task in
                if let due = task.dueDate, calendar.isDateInToday(due) {
                    return true
                }

                if let completedAt = task.completedAt, calendar.isDateInToday(completedAt) {
                    return true
                }

                return false
            }
            .sorted { lhs, rhs in
                let lhsDoneRank = lhs.isDone ? 1 : 0
                let rhsDoneRank = rhs.isDone ? 1 : 0
                if lhsDoneRank != rhsDoneRank {
                    return lhsDoneRank < rhsDoneRank
                }

                let lhsUrgency = todayTaskUrgencyScore(lhs)
                let rhsUrgency = todayTaskUrgencyScore(rhs)
                if lhsUrgency != rhsUrgency {
                    return lhsUrgency > rhsUrgency
                }

                let lhsDate = lhs.dueDate ?? lhs.completedAt ?? .distantFuture
                let rhsDate = rhs.dueDate ?? rhs.completedAt ?? .distantFuture
                return lhsDate < rhsDate
            }
    }

    var todayTasksCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bugünün Görevleri")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Text("\(completedTodayBoardCount)/\(max(todayBoardTasks.count, completedTodayBoardCount))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer()

                HStack(spacing: 8) {
                    Menu {
                        Button {
                            onAddTask()
                        } label: {
                            Label("Yeni Görev", systemImage: "checklist")
                        }

                        Button {
                            onAddTask()
                        } label: {
                            Label("Yeni Ödev", systemImage: "book.closed.fill")
                        }

                        Button {
                            onAddTask()
                        } label: {
                            Label("Yeni Sınav", systemImage: "doc.text.fill")
                        }

                        Button {
                            onOpenWeek()
                        } label: {
                            Label("Haftaya Ekle", systemImage: "calendar.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(palette.primaryText)
                            .padding(10)
                            .background(Circle().fill(palette.secondaryCardFill))
                            .overlay(Circle().stroke(palette.cardStroke, lineWidth: 1))
                    }

                    Button {
                        showTasksShortcut = true
                    } label: {
                        HStack(spacing: 6) {
                            Text("Tümü")
                                .font(.system(size: 12, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(palette.primaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(palette.secondaryCardFill))
                        .overlay(Capsule().stroke(palette.cardStroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            if todayBoardTasks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bugün için görev görünmüyor")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.primaryText)

                    HStack(spacing: 8) {
                        smallStatsChip(title: "Seri", value: "\(streakCount)", tint: .orange)
                        smallStatsChip(title: "Biten", value: "0", tint: .green)
                        smallStatsChip(title: "Kalan", value: "0", tint: .blue)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(palette.secondaryCardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(todayBoardTasks.prefix(4))) { task in
                        todayTaskBoardRow(task: task)
                    }
                }

                HStack(spacing: 8) {
                    smallStatsChip(title: "Seri", value: "\(streakCount)", tint: .orange)
                    smallStatsChip(title: "Biten", value: "\(completedTodayBoardCount)", tint: .green)
                    smallStatsChip(title: "Kalan", value: "\(todayPendingBoardCount)", tint: .blue)
                }
                .padding(.top, 2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(palette.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
    }

    func todayTaskBoardRow(task: DTTaskItem) -> some View {
        let accent = todayTaskAccent(for: task)
        let isUpcoming = isUpcomingPriorityTask(task)
        let isOverdue = store.isOverdue(task) && !task.isDone

        return Button {
            toggleTodayBoardTask(task)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(task.isDone ? Color.green.opacity(0.28) : accent, lineWidth: 2.6)
                        .frame(width: 28, height: 28)

                    if task.isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.green)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(task.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(task.isDone ? palette.secondaryText : palette.primaryText)
                            .strikethrough(task.isDone, color: palette.secondaryText.opacity(0.75))
                            .lineLimit(1)

                        if isUpcoming && !task.isDone {
                            Circle()
                                .fill(accent)
                                .frame(width: 6, height: 6)
                        }
                    }

                    Text(taskRowSubtitle(for: task))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                if task.isDone {
                    miniBadge(icon: "checkmark.circle.fill", text: "Tamamlandı", tint: .green)
                } else if isOverdue {
                    miniBadge(icon: "exclamationmark.triangle.fill", text: "Gecikmiş", tint: .red)
                } else if isUpcoming {
                    miniBadge(icon: "clock.fill", text: "Yaklaşan", tint: accent)
                } else {
                    miniBadge(icon: "calendar", text: todayTaskLabel(for: task), tint: accent.opacity(0.95))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        isUpcoming && !task.isDone
                        ? accent.opacity(0.09)
                        : palette.secondaryCardFill
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        task.isDone
                        ? Color.green.opacity(0.14)
                        : (isUpcoming ? accent.opacity(0.34) : palette.cardStroke),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isUpcoming && !task.isDone ? accent.opacity(0.10) : .clear,
                radius: isUpcoming && !task.isDone ? 10 : 0,
                y: isUpcoming && !task.isDone ? 4 : 0
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    func toggleTodayBoardTask(_ task: DTTaskItem) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            task.isDone.toggle()
            task.completedAt = task.isDone ? Date() : nil

            do {
                try modelContext.save()
            } catch {
                print("❌ today board task toggle error:", error)
            }

            if task.isDone {
                completeLinkedWeekEvent(for: task)
            }
        }
    }

    var completedTodayBoardCount: Int {
        todayBoardTasks.filter(\.isDone).count
    }

    var todayPendingBoardCount: Int {
        todayBoardTasks.filter { !$0.isDone }.count
    }

    func todayTaskUrgencyScore(_ task: DTTaskItem) -> Int {
        if task.isDone { return -1 }
        if store.isOverdue(task) { return 100 }

        guard let due = task.dueDate else { return 10 }

        let minutes = Int(due.timeIntervalSinceNow / 60)

        if minutes <= 30 { return 90 }
        if minutes <= 120 { return 70 }
        if Calendar.current.isDateInToday(due) { return 50 }
        return 20
    }

    func isUpcomingPriorityTask(_ task: DTTaskItem) -> Bool {
        guard !task.isDone else { return false }
        guard let due = task.dueDate else { return false }

        let minutes = Int(due.timeIntervalSinceNow / 60)
        return minutes >= 0 && minutes <= 90
    }

    func todayTaskAccent(for task: DTTaskItem) -> Color {
        if store.isOverdue(task) && !task.isDone {
            return .red
        }

        switch task.colorName.lowercased() {
            case "green": return .green
            case "orange": return .orange
            case "pink": return .pink
            case "purple": return .purple
            default: return .blue
        }
    }

    func todayTaskLabel(for task: DTTaskItem) -> String {
        let type = task.taskType.lowercased()

        switch type {
        case "exam":
            return "Sınav"
        case "project":
            return "Proje"
        case "workout":
            return "Antrenman"
        case "study":
            return "Çalışma"
        case "homework":
            return "Ödev"
        default:
            return "Bugün"
        }
    }

    func taskRowSubtitle(for task: DTTaskItem) -> String {
        let course = task.courseName.trimmingCharacters(in: .whitespacesAndNewlines)

        if !course.isEmpty, let due = task.dueDate {
            return "\(course) • \(due.formatted(date: .omitted, time: .shortened))"
        }

        if !course.isEmpty {
            return course
        }

        if let due = task.dueDate {
            return due.formatted(date: .omitted, time: .shortened)
        }

        return task.taskType.isEmpty ? "Görev" : task.taskType.capitalized
    }

    func miniBadge(icon: String, text: String, tint: Color) -> some View {
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

    func smallStatsChip(title: String, value: String, tint: Color) -> some View {
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

    func localizedStreakText(_ count: Int) -> String {
        tr("insights_overview_streak_format", count)
    }

    func localizedCompletedTodayText(_ count: Int) -> String {
        tr("home_completed_today_format", count)
    }

    func localizedShowingCount(_ count: Int) -> String {
        tr("home_showing_count_format", count)
    }
}
