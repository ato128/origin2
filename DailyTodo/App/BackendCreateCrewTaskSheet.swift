//
//  BackendCreateCrewTaskSheet.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 22.03.2026.
//

import SwiftUI

struct BackendCreateCrewTaskSheet: View {
    let crew: CrewDTO
    let members: [CrewMemberDTO]
    let memberProfiles: [ProfileDTO]

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var session: SessionStore

    @State private var title = ""
    @State private var details = ""
    @State private var selectedAssigneeID: UUID?
    @State private var priority = "medium"
    @State private var status = "todo"
    @State private var showOnWeek = false
    @State private var plannedDate = Date()
    @State private var durationMinute = 60

    @State private var isSaving = false
    @State private var errorMessage: String?

    private let priorityOptions = ["low", "medium", "high", "urgent"]
    private let statusOptions = ["todo", "inProgress", "review", "done"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Task title", text: $title)

                    TextField("Details", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Assignment") {
                    Picker("Member", selection: $selectedAssigneeID) {
                        Text("Unassigned").tag(UUID?.none)

                        ForEach(members) { member in
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
                }

                Section("Week Planning") {
                    Toggle("Show on Week page", isOn: $showOnWeek)

                    if showOnWeek {
                        DatePicker(
                            "Date & Time",
                            selection: $plannedDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )

                        Stepper(
                            "Duration: \(durationMinute) min",
                            value: $durationMinute,
                            in: 15...240,
                            step: 15
                        )
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Task")
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
                            Text("Save")
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }

    @MainActor
    private func saveTask() async {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        guard let user = session.currentUser else {
            errorMessage = "User session not found."
            return
        }

        isSaving = true
        errorMessage = nil

        let schedule = makeSchedule()

        do {
            try await crewStore.createTask(
                title: cleanTitle,
                crewID: crew.id,
                userID: user.id,
                assignedTo: selectedAssigneeID,
                details: details.trimmingCharacters(in: .whitespacesAndNewlines),
                priority: priority,
                status: status,
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

    private func displayName(for member: CrewMemberDTO) -> String {
        guard let profile = memberProfiles.first(where: { $0.id == member.user_id }) else {
            return "Unknown user"
        }

        if let fullName = profile.full_name,
           !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fullName
        }

        if let username = profile.username,
           !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return username
        }

        return profile.email ?? "Unknown user"
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
