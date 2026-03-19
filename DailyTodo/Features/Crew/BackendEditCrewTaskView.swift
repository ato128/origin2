//
//  BackendEditCrewTaskView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import SwiftUI

struct BackendEditCrewTaskView: View {
    let crew: CrewDTO
    let task: CrewTaskDTO

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var session: SessionStore

    @State private var title: String
    @State private var details: String
    @State private var selectedAssigneeID: UUID?
    @State private var priority: String
    @State private var status: String
    @State private var showOnWeek: Bool
    @State private var plannedDate: Date
    @State private var durationMinute: Int
    @State private var isDone: Bool

    @State private var isSaving = false
    @State private var errorMessage: String?

    private let priorityOptions = ["low", "medium", "high", "urgent"]
    private let statusOptions = ["todo", "inProgress", "review", "done"]

    init(crew: CrewDTO, task: CrewTaskDTO) {
        self.crew = crew
        self.task = task

        _title = State(initialValue: task.title)
        _details = State(initialValue: task.details ?? "")
        _selectedAssigneeID = State(initialValue: task.assigned_to)
        _priority = State(initialValue: task.priority)
        _status = State(initialValue: task.status)
        _showOnWeek = State(initialValue: task.show_on_week)
        _plannedDate = State(initialValue: Self.makeInitialDate(from: task))
        _durationMinute = State(initialValue: task.scheduled_duration_minute ?? 60)
        _isDone = State(initialValue: task.is_done)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Task title", text: $title)

                    TextField("Details", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Assignment") {
                    Picker("Assigned member", selection: $selectedAssigneeID) {
                        Text("Unassigned").tag(UUID?.none)

                        ForEach(crewStore.crewMembers) { member in
                            Text(displayName(for: member))
                                .tag(Optional(member.user_id))
                        }
                    }
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

                    Toggle("Completed", isOn: $isDone)
                }

                Section("Week Planning") {
                    Toggle("Show on Week page", isOn: $showOnWeek)

                    if showOnWeek {
                        DatePicker(
                            "Date & Time",
                            selection: $plannedDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )

                        Stepper("Duration: \(durationMinute) min", value: $durationMinute, in: 15...240, step: 15)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task {
                            await saveTask()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Save Changes")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)

                    Button(isDone ? "Mark as Todo" : "Mark as Completed") {
                        isDone.toggle()
                        status = isDone ? "done" : "todo"
                    }
                    .foregroundStyle(.blue)
                    .disabled(isSaving)

                    Button("Delete Task", role: .destructive) {
                        Task {
                            await deleteTask()
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    @MainActor
    private func saveTask() async {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        isSaving = true
        errorMessage = nil

        let resolvedStatus = isDone ? "done" : status
        let schedule = makeSchedule()

        do {
            try await crewStore.updateTask(
                taskID: task.id,
                title: cleanTitle,
                assignedTo: selectedAssigneeID,
                isDone: isDone,
                details: details.trimmingCharacters(in: .whitespacesAndNewlines),
                priority: priority,
                status: resolvedStatus,
                showOnWeek: showOnWeek,
                scheduledWeekday: schedule.weekday,
                scheduledStartMinute: schedule.startMinute,
                scheduledDurationMinute: showOnWeek ? durationMinute : nil
            )
            await crewStore.loadTasks(for: crew.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    @MainActor
    private func deleteTask() async {
        isSaving = true
        errorMessage = nil

        do {
            try await crewStore.deleteTask(taskID: task.id, crewID: crew.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    private func makeSchedule() -> (weekday: Int?, startMinute: Int?) {
        guard showOnWeek else { return (nil, nil) }

        let cal = Calendar.current
        let comps = cal.dateComponents([.weekday, .hour, .minute], from: plannedDate)

        let systemWeekday = comps.weekday ?? 2
        let convertedWeekday = (systemWeekday + 5) % 7
        let startMinute = ((comps.hour ?? 0) * 60) + (comps.minute ?? 0)

        return (convertedWeekday, startMinute)
    }

    private static func makeInitialDate(from task: CrewTaskDTO) -> Date {
        let now = Date()
        let cal = Calendar.current

        guard
            let scheduledWeekday = task.scheduled_weekday,
            let scheduledStartMinute = task.scheduled_start_minute
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

    private func displayName(for member: CrewMemberDTO) -> String {
        guard let profile = crewStore.memberProfiles.first(where: { $0.id == member.user_id }) else {
            return "Unknown user"
        }

        if let fullName = profile.full_name, !fullName.isEmpty {
            return fullName
        }

        if let username = profile.username, !username.isEmpty {
            return username
        }

        return profile.email ?? "Unkown user"
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
