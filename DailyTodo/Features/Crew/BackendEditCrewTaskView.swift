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

    @State private var originalTitle: String
    @State private var originalDetails: String
    @State private var originalAssignedAssigneeID: UUID?
    @State private var originalPriority: String
    @State private var originalStatus: String
    @State private var originalShowOnWeek: Bool
    @State private var originalPlannedDate: Date
    @State private var originalDurationMinute: Int
    @State private var originalIsDone: Bool

    private let priorityOptions = ["low", "medium", "high", "urgent"]
    private let statusOptions = ["todo", "inProgress", "review", "done"]

    init(crew: CrewDTO, task: CrewTaskDTO) {
        self.crew = crew
        self.task = task

        let initialTitle = task.title
        let initialDetails = task.details ?? ""
        let initialAssignedTo = task.assigned_to
        let initialPriority = task.priority
        let initialStatus = task.status
        let initialShowOnWeek = task.show_on_week
        let initialPlannedDate = Self.makeInitialDate(from: task)
        let initialDuration = task.scheduled_duration_minute ?? 60
        let initialIsDone = task.is_done

        _title = State(initialValue: initialTitle)
        _details = State(initialValue: initialDetails)
        _selectedAssigneeID = State(initialValue: initialAssignedTo)
        _priority = State(initialValue: initialPriority)
        _status = State(initialValue: initialStatus)
        _showOnWeek = State(initialValue: initialShowOnWeek)
        _plannedDate = State(initialValue: initialPlannedDate)
        _durationMinute = State(initialValue: initialDuration)
        _isDone = State(initialValue: initialIsDone)

        _originalTitle = State(initialValue: initialTitle)
        _originalDetails = State(initialValue: initialDetails)
        _originalAssignedAssigneeID = State(initialValue: initialAssignedTo)
        _originalPriority = State(initialValue: initialPriority)
        _originalStatus = State(initialValue: initialStatus)
        _originalShowOnWeek = State(initialValue: initialShowOnWeek)
        _originalPlannedDate = State(initialValue: initialPlannedDate)
        _originalDurationMinute = State(initialValue: initialDuration)
        _originalIsDone = State(initialValue: initialIsDone)
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

                        ForEach(filteredCrewMembers) { member in
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
                        .onChange(of: isDone) { _, newValue in
                            if newValue {
                                status = "done"
                            } else if status == "done" {
                                status = "todo"
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

                        Stepper("Duration: \(durationMinute) min", value: $durationMinute, in: 15...240, step: 15)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
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

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await saveTask()
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 17, weight: .bold))
                        }
                    }
                    .disabled(!hasChanges || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                    .opacity((!hasChanges || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving) ? 0.45 : 1)
                }
            }
        }
    }

    private var filteredCrewMembers: [CrewMemberDTO] {
        crewStore.crewMembers.filter { $0.crew_id == crew.id }
    }

    private var hasChanges: Bool {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalCleanTitle = originalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalCleanDetails = originalDetails.trimmingCharacters(in: .whitespacesAndNewlines)

        let plannedDateChanged: Bool = {
            guard showOnWeek || originalShowOnWeek else { return false }
            return abs(plannedDate.timeIntervalSince(originalPlannedDate)) > 60
        }()

        return cleanTitle != originalCleanTitle ||
        cleanDetails != originalCleanDetails ||
        selectedAssigneeID != originalAssignedAssigneeID ||
        priority != originalPriority ||
        resolvedStatusForSave != originalResolvedStatus ||
        showOnWeek != originalShowOnWeek ||
        (showOnWeek && durationMinute != originalDurationMinute) ||
        plannedDateChanged ||
        isDone != originalIsDone
    }

    private var resolvedStatusForSave: String {
        isDone ? "done" : status
    }

    private var originalResolvedStatus: String {
        originalIsDone ? "done" : originalStatus
    }

    @MainActor
    private func saveTask() async {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        isSaving = true
        errorMessage = nil

        let schedule = makeSchedule()

        do {
            try await crewStore.updateTask(
                taskID: task.id,
                title: cleanTitle,
                assignedTo: selectedAssigneeID,
                isDone: isDone,
                details: details.trimmingCharacters(in: .whitespacesAndNewlines),
                priority: priority,
                status: resolvedStatusForSave,
                showOnWeek: showOnWeek,
                scheduledWeekday: schedule.weekday,
                scheduledStartMinute: schedule.startMinute,
                scheduledDurationMinute: showOnWeek ? durationMinute : nil
            )

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
