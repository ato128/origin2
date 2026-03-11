//
//  CrewTaskDetailView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 10.03.2026.
//
import SwiftUI
import SwiftData

struct CrewTaskDetailView: View {
    let task: CrewTask
    let crew: Crew

    @Environment(\.modelContext) private var modelContext

    @Query private var comments: [CrewTaskComment]
    @Query private var polls: [CrewTaskPoll]
    @Query private var reactions: [CrewTaskReaction]

    @State private var newComment: String = ""
    @State private var commentAuthor: String = "Atakan"

    private let reactionOptions = ["👍", "🔥", "✅", "👀", "💡"]
    private let statusOptions = ["todo", "inProgress", "review", "done"]

    var body: some View {
        let taskComments = comments
            .filter { $0.taskID == task.id }
            .sorted { $0.createdAt > $1.createdAt }

        let taskPoll = polls.first { $0.taskID == task.id }
        let taskReactions = reactions.filter { $0.taskID == task.id }

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard

                quickActionsCard

                statusSection

                if !task.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    detailCard
                }

                scheduleSection

                if let poll = taskPoll {
                    pollSection(poll)
                }

                reactionsSection(taskReactions)

                discussionComposer

                commentsSection(taskComments)
            }
            .padding(16)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Task Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension CrewTaskDetailView {

    var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(.title3.bold())

                    HStack(spacing: 8) {
                        badge(
                            text: priorityTitle(task.priority),
                            tint: priorityColor(task.priority)
                        )

                        badge(
                            text: statusTitle(task.status),
                            tint: statusColor(task.status)
                        )
                    }
                }

                Spacer()

                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isDone ? .green : priorityColor(task.priority))
            }

            HStack(spacing: 10) {
                infoPill(
                    text: task.assignedTo.isEmpty ? "Unassigned" : task.assignedTo,
                    icon: "person.fill",
                    tint: hexColor(crew.colorHex)
                )

                infoPill(
                    text: task.createdBy.isEmpty ? "Unknown" : task.createdBy,
                    icon: "plus.circle.fill",
                    tint: .secondary
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 10) {
                Button {
                    toggleDone()
                } label: {
                    HStack {
                        Image(systemName: task.isDone ? "arrow.uturn.backward.circle.fill" : "checkmark.circle.fill")
                        Text(task.isDone ? "Reopen" : "Mark Done")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(task.isDone ? Color.orange.opacity(0.15) : Color.green.opacity(0.15))
                    .foregroundStyle(task.isDone ? .orange : .green)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.headline)

            HStack(spacing: 10) {
                ForEach(statusOptions, id: \.self) { status in
                    Button {
                        updateStatus(status)
                    } label: {
                        Text(statusTitle(status))
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(task.status == status
                                          ? statusColor(status).opacity(0.18)
                                          : Color.secondary.opacity(0.08))
                            )
                            .foregroundStyle(task.status == status ? statusColor(status) : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    var detailCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Details")
                .font(.headline)

            Text(task.details)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schedule")
                .font(.headline)

            if task.showOnWeek,
               let weekday = task.scheduledWeekday,
               let start = task.scheduledStartMinute {
                VStack(alignment: .leading, spacing: 8) {
                    scheduleRow(icon: "calendar", text: weekdayFull(weekday))
                    scheduleRow(icon: "clock.fill", text: hm(start))

                    if let duration = task.scheduledDurationMinute {
                        scheduleRow(icon: "timer", text: "\(duration) min")
                    }
                }
            } else {
                Text("This task is not scheduled on the Week page.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    func pollSection(_ poll: CrewTaskPoll) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Poll")
                    .font(.headline)

                Spacer()

                Text(poll.isOpen ? "Open" : "Closed")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill((poll.isOpen ? Color.green : Color.gray).opacity(0.12))
                    )
                    .foregroundStyle(poll.isOpen ? .green : .gray)
            }

            Text(poll.question)
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 12) {
                voteCard(title: "Yes", value: poll.yesVotes, tint: .green)
                voteCard(title: "No", value: poll.noVotes, tint: .red)
            }

            if poll.isOpen {
                HStack(spacing: 10) {
                    Button {
                        voteYes(poll)
                    } label: {
                        HStack {
                            Image(systemName: "hand.thumbsup.fill")
                            Text("Vote Yes")
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        voteNo(poll)
                    } label: {
                        HStack {
                            Image(systemName: "hand.thumbsdown.fill")
                            Text("Vote No")
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.15))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    func reactionsSection(_ taskReactions: [CrewTaskReaction]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reactions")
                .font(.headline)

            HStack(spacing: 10) {
                ForEach(reactionOptions, id: \.self) { emoji in
                    let count = reactionCount(for: emoji, in: taskReactions)

                    Button {
                        addReaction(emoji)
                    } label: {
                        HStack(spacing: 6) {
                            Text(emoji)
                            Text("\(count)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.secondary.opacity(0.10))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    var discussionComposer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Discussion")
                .font(.headline)

            TextField("Your name", text: $commentAuthor)

            TextField("Add note or opinion...", text: $newComment, axis: .vertical)
                .lineLimit(3...5)

            Button {
                addComment()
            } label: {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("Send Comment")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(hexColor(crew.colorHex))
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    func commentsSection(_ taskComments: [CrewTaskComment]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Notes & Comments")
                    .font(.headline)

                Spacer()

                Text("\(taskComments.count)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.12))
                    )
                    .foregroundStyle(.secondary)
            }

            if taskComments.isEmpty {
                Text("No notes yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(taskComments) { comment in
                        commentBubble(comment)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }
    func commentBubble(_ comment: CrewTaskComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(hexColor(crew.colorHex).opacity(0.16))
                    .frame(width: 34, height: 34)

                Text(initialLetter(comment.authorName))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(hexColor(crew.colorHex))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(comment.authorName)
                        .font(.caption.weight(.bold))

                    Spacer()

                    Text(comment.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(comment.message)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
        }
    }
    
    func initialLetter(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(1)).uppercased()
    }
    
    
    func addComment() {
        let cleanMessage = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanMessage.isEmpty else { return }

        let cleanAuthor = commentAuthor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Unknown"
            : commentAuthor.trimmingCharacters(in: .whitespacesAndNewlines)

        let comment = CrewTaskComment(
            taskID: task.id,
            authorName: cleanAuthor,
            message: cleanMessage
        )

        modelContext.insert(comment)

        let activity = CrewActivity(
            crewID: crew.id,
            memberName: cleanAuthor,
            actionText: "commented on task \(task.title)"
        )
        modelContext.insert(activity)

        try? modelContext.save()
        newComment = ""
    }

    func addReaction(_ emoji: String) {
        let existing = reactions.first { $0.taskID == task.id && $0.emoji == emoji }

        if let existing {
            existing.count += 1
        } else {
            let reaction = CrewTaskReaction(
                taskID: task.id,
                emoji: emoji,
                count: 1
            )
            modelContext.insert(reaction)
        }

        try? modelContext.save()
    }

    func voteYes(_ poll: CrewTaskPoll) {
        poll.yesVotes += 1

        let activity = CrewActivity(
            crewID: crew.id,
            memberName: "Atakan",
            actionText: "voted yes on task \(task.title)"
        )
        modelContext.insert(activity)

        try? modelContext.save()
    }

    func voteNo(_ poll: CrewTaskPoll) {
        poll.noVotes += 1

        let activity = CrewActivity(
            crewID: crew.id,
            memberName: "Atakan",
            actionText: "voted no on task \(task.title)"
        )
        modelContext.insert(activity)

        try? modelContext.save()
    }

    func toggleDone() {
        task.isDone.toggle()
        task.status = task.isDone ? "done" : "todo"

        let activity = CrewActivity(
            crewID: crew.id,
            memberName: "Atakan",
            actionText: task.isDone ? "completed task \(task.title)" : "reopened task \(task.title)"
        )
        modelContext.insert(activity)

        try? modelContext.save()
    }

    func updateStatus(_ newStatus: String) {
        task.status = newStatus
        task.isDone = newStatus == "done"

        let activity = CrewActivity(
            crewID: crew.id,
            memberName: "Atakan",
            actionText: "changed task \(task.title) status to \(statusTitle(newStatus))"
        )
        modelContext.insert(activity)

        try? modelContext.save()
    }

    func reactionCount(for emoji: String, in taskReactions: [CrewTaskReaction]) -> Int {
        taskReactions.first(where: { $0.emoji == emoji })?.count ?? 0
    }

    func voteCard(title: String, value: Int, tint: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("\(value)")
                .font(.title3.bold())
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.08))
        )
    }

    func scheduleRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(hexColor(crew.colorHex))

            Text(text)
                .font(.subheadline)
        }
    }

    func badge(text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
            .foregroundStyle(tint)
    }

    func infoPill(text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(tint.opacity(0.12))
        )
        .foregroundStyle(tint)
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

    func statusColor(_ value: String) -> Color {
        switch value {
        case "todo": return .gray
        case "inProgress": return .blue
        case "review": return .orange
        case "done": return .green
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

    func weekdayFull(_ weekday: Int) -> String {
        let days = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"]
        return days[max(0, min(6, weekday))]
    }

    func hm(_ minute: Int) -> String {
        let h = max(0, min(23, minute / 60))
        let m = max(0, min(59, minute % 60))
        return String(format: "%02d:%02d", h, m)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}
