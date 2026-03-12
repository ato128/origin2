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
            Form {
                Section("Task") {
                    TextField("Task title", text: $title)
                }

                Section("Assignment") {
                    TextField("Assigned member", text: $assignedTo)
                }

                Section("Priority & Status") {
                    Picker("Priority", selection: $priority) {
                        ForEach(priorityOptions, id: \.self) { item in
                            Text(priorityLabel(item)).tag(item)
                        }
                    }

                    Picker("Status", selection: $status) {
                        ForEach(statusOptions, id: \.self) { item in
                            Text(statusLabel(item)).tag(item)
                        }
                    }
                }

                Section("Week Planning") {
                    Toggle("Show on Week page", isOn: $showOnWeek)

                    if showOnWeek {
                        DatePicker(
                            "Date & Time",
                            selection: $plannedDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.graphical)

                        HStack {
                            Text("Selected")
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(formattedPlannedDate(plannedDate))
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }

                Section {
                    Button("Save Changes") {
                        saveTask()
                    }

                    Button(task.isDone ? "Mark as Todo" : "Mark as Completed") {
                        toggleComplete()
                    }
                    .foregroundStyle(.blue)

                    Button("Delete Task", role: .destructive) {
                        deleteTask()
                    }
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
        }
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
        case "low": return "Low"
        case "medium": return "Medium"
        case "high": return "High"
        case "urgent": return "Urgent"
        default: return raw.capitalized
        }
    }

    private func statusLabel(_ raw: String) -> String {
        switch raw {
        case "todo": return "Todo"
        case "inProgress": return "In Progress"
        case "review": return "Review"
        case "done": return "Done"
        default: return raw.capitalized
        }
    }
}
