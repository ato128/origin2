//
//  CrewDetailView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 10.03.2026.
//

import SwiftUI
import SwiftData

struct CrewDetailView: View {
    let crew: Crew
    
    @Environment(\.modelContext) private var modelContext
    
    @State private var showCreateTask = false
    @State private var showAddMemberSheet = false
    @State private var selectedTaskForEdit: CrewTask?
    @State private var showShareSheet = false
    
    @Query private var members: [CrewMember]
    @Query private var tasks: [CrewTask]
    
    @Query(sort: \CrewActivity.createdAt, order: .reverse)
    private var activities: [CrewActivity]
    
    @Query private var comments: [CrewTaskComment]
    @Query private var polls: [CrewTaskPoll]
    @Query private var reactions: [CrewTaskReaction]
    
    var body: some View {
        let crewMembers = members.filter { $0.crewID == crew.id }
        let crewTasks = tasks
            .filter { $0.crewID == crew.id }
            .sorted { lhs, rhs in
                if lhs.isDone != rhs.isDone {
                    return !lhs.isDone && rhs.isDone
                }

                let priorityRank: [String: Int] = [
                    "urgent": 0,
                    "high": 1,
                    "medium": 2,
                    "low": 3
                ]

                let lhsPriority = priorityRank[lhs.priority, default: 99]
                let rhsPriority = priorityRank[rhs.priority, default: 99]

                if lhsPriority != rhsPriority {
                    return lhsPriority < rhsPriority
                }

                let lhsMinute = lhs.scheduledStartMinute ?? 9999
                let rhsMinute = rhs.scheduledStartMinute ?? 9999

                if lhsMinute != rhsMinute {
                    return lhsMinute < rhsMinute
                }

                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        let crewActivities = activities.filter { $0.crewID == crew.id }

        let completedTasks = crewTasks.filter(\.isDone).count
        let pendingTasks = max(0, crewTasks.count - completedTasks)
        let progress = crewTasks.isEmpty ? 0 : Double(completedTasks) / Double(crewTasks.count)

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroCard(
                    memberCount: crewMembers.count,
                    totalTasks: crewTasks.count,
                    progress: progress
                )

                quickStatsRow(
                    completed: completedTasks,
                    pending: pendingTasks,
                    memberCount: crewMembers.count
                )

                membersSection(crewMembers)

                tasksSection(crewTasks)

                focusSection(memberCount: crewMembers.count)

                activitySection(crewActivities)
            }
            .padding(16)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(crew.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCreateTask) {
            CreateCrewTaskView(
                crew: crew,
                members: crewMembers
            )
        }
        .sheet(isPresented: $showAddMemberSheet) {
            AddMemberView(crew: crew)
        }
        .sheet(item: $selectedTaskForEdit) { task in
            EditCrewTaskView(crew: crew, task: task)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(
                items: [
                    "Join my crew '\(crew.name)' on DailyTodo 🚀"
                ]
            )
        }
    }
}

// MARK: - Sections

private extension CrewDetailView {

    func heroCard(memberCount: Int, totalTasks: Int, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(hexColor(crew.colorHex).opacity(0.18))
                        .frame(width: 60, height: 60)

                    Image(systemName: crew.icon)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(hexColor(crew.colorHex))
                }

                Spacer()

                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(hexColor(crew.colorHex))
                        )
                }
                .buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(crew.name)
                    .font(.title2.bold())

                Text("Manage members, shared tasks, and project activity in one place.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                infoPill(text: "\(memberCount) members", tint: hexColor(crew.colorHex))
                infoPill(text: "\(totalTasks) tasks", tint: .secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Crew Progress")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(Int(progress * 100))%")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: progress)
                    .tint(hexColor(crew.colorHex))
                    .scaleEffect(y: 1.8)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    func quickStatsRow(completed: Int, pending: Int, memberCount: Int) -> some View {
        HStack(spacing: 10) {
            statCard(
                value: "\(completed)",
                title: "Done",
                icon: "checkmark.circle.fill",
                tint: .green
            )

            statCard(
                value: "\(pending)",
                title: "Pending",
                icon: "clock.fill",
                tint: .orange
            )

            statCard(
                value: "\(memberCount)",
                title: "Members",
                icon: "person.3.fill",
                tint: hexColor(crew.colorHex)
            )
        }
    }

    func statCard(value: String, title: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            Text(value)
                .font(.headline.bold())

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(cardBackground)
    }

    func membersSection(_ crewMembers: [CrewMember]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Members")
                    .font(.headline)

                Spacer()

                Button {
                    showAddMemberSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(0.14))
                        )
                }
                .buttonStyle(.plain)

                Text("\(crewMembers.count)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.12))
                    )
                    .foregroundStyle(.secondary)
            }

            if crewMembers.isEmpty {
                emptyMiniState(text: "No members yet • Tap + to add one")
            } else {
                ForEach(crewMembers) { member in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.secondary.opacity(0.12))
                                .frame(width: 42, height: 42)

                            Image(systemName: member.avatarSymbol)
                                .foregroundStyle(.primary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.name)
                                .font(.subheadline.weight(.semibold))

                            Text(member.role)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            Circle()
                                .fill(member.isOnline ? Color.green : Color.gray.opacity(0.4))
                                .frame(width: 8, height: 8)

                            Text(member.isOnline ? "Online" : "Away")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }
    
    func crewTaskRow(_ task: CrewTask) -> some View {
        let commentCount = comments.filter { $0.taskID == task.id }.count
        let taskPoll = polls.first { $0.taskID == task.id }
        let reactionTotal = reactions
            .filter { $0.taskID == task.id }
            .reduce(0) { $0 + $1.count }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(priorityColor(task.priority).opacity(0.18))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(task.isDone ? Color.green : priorityColor(task.priority))
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

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary.opacity(0.8))
            }
        }
        .contentShape(Rectangle())
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
        modelContext.insert(activity)

        try? modelContext.save()
    }

    func deleteTask(_ task: CrewTask) {
        let deletedTitle = task.title

        modelContext.delete(task)

        let activity = CrewActivity(
            crewID: crew.id,
            memberName: "You",
            actionText: "deleted task \(deletedTitle)"
        )
        modelContext.insert(activity)

        try? modelContext.save()
    }

    func tasksSection(_ crewTasks: [CrewTask]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Shared Tasks")
                    .font(.headline)

                Spacer()

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

            if crewTasks.isEmpty {
                emptyMiniState(text: "No shared tasks yet")
            } else {
                ForEach(crewTasks) { task in
                    NavigationLink {
                        CrewTaskDetailView(task: task, crew: crew)
                    } label: {
                        crewTaskRow(task)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.white.opacity(0.03))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            )
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
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    func focusSection(memberCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Focus Together")
                    .font(.headline)

                Spacer()

                Image(systemName: "timer")
                    .foregroundStyle(hexColor(crew.colorHex))
            }

            Text("Start a shared focus session and keep your crew productive together.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                infoPill(text: "\(memberCount) participants", tint: hexColor(crew.colorHex))
                infoPill(text: "25 min", tint: .secondary)
            }

            Button {
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Group Focus")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(hexColor(crew.colorHex))
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }
    
    func activityIcon(for text: String) -> String {
        let lower = text.lowercased()

        if lower.contains("comment") {
            return "text.bubble.fill"
        } else if lower.contains("vote") {
            return "hand.thumbsup.fill"
        } else if lower.contains("complete") || lower.contains("done") {
            return "checkmark.circle.fill"
        } else if lower.contains("status") {
            return "arrow.triangle.2.circlepath.circle.fill"
        } else if lower.contains("create") {
            return "plus.circle.fill"
        } else if lower.contains("reaction") {
            return "face.smiling.fill"
        } else {
            return "bolt.fill"
        }
    }
    
    func activityRow(_ item: CrewActivity) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(hexColor(crew.colorHex).opacity(0.14))
                    .frame(width: 34, height: 34)

                Image(systemName: activityIcon(for: item.actionText))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(hexColor(crew.colorHex))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.memberName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(item.actionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(item.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    func activitySection(_ crewActivities: [CrewActivity]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Activity")
                Text("Recent team updates")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .font(.headline)

                Spacer()

                Text("\(crewActivities.count)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.12))
                    )
                    .foregroundStyle(.secondary)
            }

            if crewActivities.isEmpty {
                emptyMiniState(text: "No activity yet")
            } else {
                ForEach(crewActivities.prefix(5)) { item in
                    activityRow(item)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    func infoPill(text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
            .foregroundStyle(tint)
    }

    func emptyMiniState(text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(.secondary)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
    struct ShareSheet: UIViewControllerRepresentable {
        var items: [Any]

        func makeUIViewController(context: Context) -> UIActivityViewController {
            UIActivityViewController(
                activityItems: items,
                applicationActivities: nil
            )
        }

        func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    }
}
