//
//  CrewDetailView+TasksSection.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 14.03.2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

extension CrewDetailView {

    func crewTaskRow(_ task: CrewTask) -> some View {
        let commentCount = comments.filter { $0.taskID == task.id }.count
        let taskPoll = polls.first { $0.taskID == task.id }
        let reactionTotal = reactions
            .filter { $0.taskID == task.id }
            .reduce(0) { $0 + $1.count }

        return HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(priorityColor(task.priority).opacity(0.18))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(task.isDone ? .green : priorityColor(task.priority))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .strikethrough(task.isDone, color: .secondary)
                    .opacity(task.isDone ? 0.65 : 1.0)
                    .lineLimit(2)

                if !task.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(task.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .opacity(task.isDone ? 0.7 : 1.0)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if !task.assignedTo.isEmpty {
                        miniMeta(icon: "person.fill", text: task.assignedTo)
                    }

                    taskPill(
                        text: priorityTitle(task.priority),
                        tint: priorityColor(task.priority)
                    )

                    taskPill(
                        text: statusTitle(task.status),
                        tint: task.isDone ? .green : .secondary
                    )

                    if task.showOnWeek,
                       let weekday = task.scheduledWeekday,
                       let start = task.scheduledStartMinute {
                        miniMeta(
                            icon: "calendar",
                            text: "\(weekdayShort(weekday)) \(hm(start))"
                        )
                    }
                }

                HStack(spacing: 12) {
                    if commentCount > 0 {
                        socialMeta(icon: "text.bubble.fill", text: "\(commentCount)")
                    }

                    if reactionTotal > 0 {
                        socialMeta(icon: "face.smiling.fill", text: "\(reactionTotal)")
                    }

                    if taskPoll != nil {
                        socialMeta(icon: "chart.bar.fill", text: "Poll")
                    }
                }
                .padding(.top, 4)
            }

            Spacer()

            if isReorderMode {
                Image(systemName: "line.3.horizontal")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary.opacity(0.8))
            }
        }
        .contentShape(Rectangle())
    }

    func moveTask(from source: CrewTask, to destination: CrewTask) {
        guard source.id != destination.id,
              let fromIndex = editableTasks.firstIndex(where: { $0.id == source.id }),
              let toIndex = editableTasks.firstIndex(where: { $0.id == destination.id }) else { return }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            let movedTask = editableTasks.remove(at: fromIndex)
            editableTasks.insert(movedTask, at: toIndex)
            refreshOrderIndexes()
        }

        try? dbContext.save()
    }

    func refreshOrderIndexes() {
        for (index, task) in editableTasks.enumerated() {
            task.orderIndex = index
        }
    }

    func taskPill(text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
            .foregroundStyle(tint)
    }

    func miniMeta(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    func socialMeta(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
    }

    func priorityColor(_ value: String) -> Color {
        switch value {
        case "low": return .gray
        case "medium": return .blue
        case "high": return .orange
        case "urgent": return .red
        default: return .secondary
        }
    }

    func priorityTitle(_ value: String) -> String {
        switch value {
        case "low": return "Low"
        case "medium": return "Medium"
        case "high": return "High"
        case "urgent": return "Urgent"
        default: return value.capitalized
        }
    }

    func statusTitle(_ value: String) -> String {
        switch value {
        case "todo": return "Todo"
        case "inProgress": return "In Progress"
        case "review": return "Review"
        case "done": return "Done"
        default: return value.capitalized
        }
    }

    func weekdayShort(_ weekday: Int) -> String {
        let titles = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
        return titles[max(0, min(6, weekday))]
    }

    func hm(_ minute: Int) -> String {
        let h = max(0, min(23, minute / 60))
        let m = max(0, min(59, minute % 60))
        return String(format: "%02d:%02d", h, m)
    }

    func toggleTaskDone(_ task: CrewTask) {
        task.isDone.toggle()
        task.status = task.isDone ? "done" : "todo"

        let activity = CrewActivity(
            crewID: crew.id,
            memberName: "You",
            actionText: task.isDone
            ? "completed task \(task.title)"
            : "reopened task \(task.title)"
        )

        dbContext.insert(activity)
        try? dbContext.save()
    }

    func deleteTask(_ task: CrewTask) {
        let deletedTitle = task.title

       dbContext.delete(task)

        let activity = CrewActivity(
            crewID: crew.id,
            memberName: "You",
            actionText: "deleted task \(deletedTitle)"
        )

       dbContext.insert(activity)
        try? dbContext.save()
    }

    @ViewBuilder
    func taskCardView(_ task: CrewTask) -> some View {
        let baseCard = crewTaskRow(task)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        draggedTask?.id == task.id
                        ? hexColor(crew.colorHex).opacity(0.35)
                        : Color.white.opacity(0.05),
                        lineWidth: 1
                    )
            )
            .scaleEffect(draggedTask?.id == task.id ? 1.02 : 1.0)
            .opacity(draggedTask?.id == task.id ? 0.88 : 1.0)
            .shadow(
                color: draggedTask?.id == task.id
                ? hexColor(crew.colorHex).opacity(0.18)
                : .clear,
                radius: 12,
                y: 6
            )

        if isReorderMode {
            baseCard
                .onDrag {
                    draggedTask = task
                    return NSItemProvider(object: NSString(string: task.id.uuidString))
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: CrewTaskDropDelegate(
                        current: task,
                        items: $editableTasks,
                        draggedItem: $draggedTask,
                        onMove: { source, destination in
                            moveTask(from: source, to: destination)
                        }
                    )
                )
        } else {
            NavigationLink {
                CrewTaskDetailView(task: task, crew: crew)
            } label: {
                baseCard
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button {
                    selectedTaskForEdit = task
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button {
                    toggleTaskDone(task)
                } label: {
                    Label(
                        task.isDone ? "Mark as Todo" : "Mark as Completed",
                        systemImage: task.isDone ? "arrow.uturn.backward.circle" : "checkmark.circle"
                    )
                }

                Button(role: .destructive) {
                    deleteTask(task)
                } label: {
                    Label("Delete Task", systemImage: "trash")
                }
            }
        }
    }

    func tasksSection(_ crewTasks: [CrewTask]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            tasksSectionHeader

            if editableTasks.isEmpty {
                emptyMiniState(text: "No shared tasks yet")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(editableTasks) { task in
                        taskCardView(task)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    var tasksSectionHeader: some View {
        HStack {
            Text("Shared Tasks")
                .font(.headline)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    isReorderMode.toggle()
                    if !isReorderMode {
                        draggedTask = nil
                        refreshOrderIndexes()
                        try? dbContext.save()
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isReorderMode ? "checkmark" : "arrow.up.arrow.down")
                    Text(isReorderMode ? "Done" : "Reorder")
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                )
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Button {
                showCreateTask = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("New")
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(hexColor(crew.colorHex).opacity(0.12))
                )
                .foregroundStyle(hexColor(crew.colorHex))
            }
            .buttonStyle(.plain)
        }
    }
}

struct CrewTaskDropDelegate: DropDelegate {
    let current: CrewTask
    @Binding var items: [CrewTask]
    @Binding var draggedItem: CrewTask?
    let onMove: (CrewTask, CrewTask) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedItem, draggedItem.id != current.id else { return }
        onMove(draggedItem, current)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
