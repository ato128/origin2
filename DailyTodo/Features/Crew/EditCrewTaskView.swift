//
//  EditCrewTaskView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 12.03.2026.
//

import SwiftUI
import SwiftData

struct EditCrewTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let crew: Crew
    let task: CrewTask

    @State private var title: String
    @State private var assignedTo: String
    @State private var priority: String
    @State private var status: String
    @State private var showOnWeek: Bool
    @State private var plannedDate: Date

    init(crew: Crew, task: CrewTask) {
        self.crew = crew
        self.task = task

        _title = State(initialValue: task.title)
        _assignedTo = State(initialValue: task.assignedTo)
        _priority = State(initialValue: task.priority)
        _status = State(initialValue: task.status)
        _showOnWeek = State(initialValue: task.showOnWeek)
        _plannedDate = State(initialValue: Self.makeInitialDate(from: task))
    }

    private let priorityOptions = ["low", "medium", "high", "urgent"]
    private let statusOptions = ["todo", "inProgress", "review", "done"]

    var body: some View {
        NavigationStack {
            ZStack {
                UpdoTheme.background
                    .ignoresSafeArea()

                Circle()
                    .fill(UpdoTheme.cyan.opacity(0.07))
                    .frame(width: 280, height: 280)
                    .blur(radius: 90)
                    .offset(x: 150, y: -260)
                    .ignoresSafeArea()

                Circle()
                    .fill(UpdoTheme.purple.opacity(0.09))
                    .frame(width: 320, height: 320)
                    .blur(radius: 100)
                    .offset(x: -170, y: 380)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        titleField
                        assignmentField
                        prioritySection
                        statusSection
                        weekSection
                        actionButtons
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(tr("edit_task_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("common_cancel")) { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(UpdoTheme.cyan)
    }

    // MARK: - Sections

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(tr("ct_task_caps"))

            TextField(tr("ct_task_title_ph"), text: $title)
                .font(.system(size: 17, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(fieldBackground)
        }
    }

    private var assignmentField: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(tr("ct_assignment_caps"))

            TextField(tr("ct_assignee_ph"), text: $assignedTo)
                .font(.system(size: 17, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(fieldBackground)
        }
    }

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(tr("ct_priority_caps"))

            HStack(spacing: 8) {
                ForEach(priorityOptions, id: \.self) { item in
                    chip(
                        title: priorityLabel(item),
                        isSelected: priority == item,
                        tint: priorityColor(item)
                    ) {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                            priority = item
                        }
                    }
                }
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(tr("ct_status_caps"))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(statusOptions, id: \.self) { item in
                    chip(
                        title: statusLabel(item),
                        isSelected: status == item,
                        tint: UpdoTheme.cyan
                    ) {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                            status = item
                        }
                    }
                }
            }
        }
    }

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(tr("ct_week_plan_caps"))

            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(tr("ct_show_on_week"))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.primary)

                        Text(tr("ct_week_hint"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $showOnWeek.animation())
                        .labelsHidden()
                }

                if showOnWeek {
                    DatePicker(
                        "",
                        selection: $plannedDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .tint(UpdoTheme.cyan)

                    HStack {
                        Text(tr("ct_selected"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(formattedPlannedDate(plannedDate))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(16)
            .background(cardBackground)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                saveTask()
            } label: {
                Text(tr("common_save_changes"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [UpdoTheme.cyan, Color(updoHex: "#22D3EE")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: UpdoTheme.cyan.opacity(0.3), radius: 14, y: 6)
            }
            .buttonStyle(.plain)

            Button {
                toggleComplete()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: task.isDone ? "arrow.uturn.backward" : "checkmark.circle.fill")
                    Text(task.isDone ? tr("ct_mark_todo") : tr("ct_mark_done"))
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(UpdoTheme.cyan)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    Capsule()
                        .fill(UpdoTheme.cyan.opacity(0.12))
                )
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                deleteTask()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                    Text(tr("edit_delete_task"))
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(updoHex: "#EF4444"))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    Capsule()
                        .fill(Color(updoHex: "#EF4444").opacity(0.12))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 6)
    }

    // MARK: - Building Blocks

    private func chip(title: String, isSelected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isSelected ? .black : .white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                    Capsule()
                        .fill(isSelected ? tint : Color.white.opacity(0.05))
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Color.clear : Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func priorityColor(_ raw: String) -> Color {
        switch raw {
        case "low": return UpdoTheme.cyan
        case "medium": return UpdoTheme.lime
        case "high": return UpdoTheme.orange
        case "urgent": return Color(updoHex: "#EF4444")
        default: return UpdoTheme.cyan
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(.secondary.opacity(0.82))
            .padding(.leading, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.045))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(0.045))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
    }

    private func saveTask() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        task.title = trimmedTitle
        task.assignedTo = assignedTo.trimmingCharacters(in: .whitespacesAndNewlines)
        task.priority = priority
        task.status = status
        task.showOnWeek = showOnWeek

        if showOnWeek {
            let cal = Calendar.current
            let comps = cal.dateComponents([.weekday, .hour, .minute], from: plannedDate)

            let systemWeekday = comps.weekday ?? 2
            let convertedWeekday = (systemWeekday + 5) % 7

            task.scheduledWeekday = convertedWeekday
            task.scheduledStartMinute = ((comps.hour ?? 0) * 60) + (comps.minute ?? 0)
        } else {
            task.scheduledWeekday = nil
            task.scheduledStartMinute = nil
        }

        let activity = CrewActivity(
            crewID: crew.id,
            memberName: "You",
            actionText: "updated task \(trimmedTitle)"
        )
        modelContext.insert(activity)

        try? modelContext.save()
        dismiss()
    }

    private func toggleComplete() {
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
        dismiss()
    }

    private func deleteTask() {
        let deletedTitle = task.title

        modelContext.delete(task)

        let activity = CrewActivity(
            crewID: crew.id,
            memberName: "You",
            actionText: "deleted task \(deletedTitle)"
        )
        modelContext.insert(activity)

        try? modelContext.save()
        dismiss()
    }

    private static func makeInitialDate(from task: CrewTask) -> Date {
        let now = Date()
        let cal = Calendar.current

        guard
            let scheduledWeekday = task.scheduledWeekday,
            let scheduledStartMinute = task.scheduledStartMinute
        else {
            return now
        }

        let targetWeekday = ((scheduledWeekday + 1) % 7) + 1
        let hour = scheduledStartMinute / 60
        let minute = scheduledStartMinute % 60

        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        comps.weekday = targetWeekday
        comps.hour = hour
        comps.minute = minute

        return cal.date(from: comps) ?? now
    }

    private func formattedPlannedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func priorityLabel(_ raw: String) -> String {
        switch raw {
        case "low": return tr("prio_low")
        case "medium": return tr("prio_medium")
        case "high": return tr("prio_high")
        case "urgent": return tr("prio_urgent")
        default: return raw.capitalized
        }
    }

    private func statusLabel(_ raw: String) -> String {
        switch raw {
        case "todo": return tr("status_todo")
        case "inProgress": return tr("status_in_progress")
        case "review": return tr("status_review")
        case "done": return tr("status_done")
        default: return raw.capitalized
        }
    }
}
