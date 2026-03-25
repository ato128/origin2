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
                Section(String(localized: "backend_create_task_section_task")) {
                    TextField(String(localized: "backend_create_task_title_placeholder"), text: $title)

                    TextField(String(localized: "backend_create_task_details_placeholder"), text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section(String(localized: "backend_create_task_section_assignment")) {
                    Picker(String(localized: "backend_create_task_member"), selection: $selectedAssigneeID) {
                        Text("backend_crew_unassigned").tag(UUID?.none)

                        ForEach(members) { member in
                            Text(displayName(for: member))
                                .tag(Optional(member.user_id))
                        }
                    }
                }

                Section(String(localized: "backend_create_task_section_priority_status")) {
                    Picker(String(localized: "backend_create_task_priority"), selection: $priority) {
                        ForEach(priorityOptions, id: \.self) { item in
                            Text(priorityLabel(item)).tag(item)
                        }
                    }

                    Picker(String(localized: "backend_create_task_status"), selection: $status) {
                        ForEach(statusOptions, id: \.self) { item in
                            Text(statusLabel(item)).tag(item)
                        }
                    }
                }

                Section(String(localized: "backend_create_task_section_week_planning")) {
                    Toggle(String(localized: "backend_create_task_show_on_week"), isOn: $showOnWeek)

                    if showOnWeek {
                        DatePicker(
                            String(localized: "backend_create_task_date_time"),
                            selection: $plannedDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )

                        Stepper(
                            String(format: String(localized: "backend_create_task_duration_format"), durationMinute),
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
            .navigationTitle("backend_create_task_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common_cancel")) {
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
                            Text("common_save")
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
            errorMessage = String(localized: "backend_create_task_user_session_not_found")
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
            return String(localized: "backend_crew_unknown_user")
        }

        if let fullName = profile.full_name,
           !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fullName
        }

        if let username = profile.username,
           !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return username
        }

        return profile.email ?? String(localized: "backend_crew_unknown_user")
    }

    private func priorityLabel(_ raw: String) -> String {
        let isTurkish = Locale.current.language.languageCode?.identifier == "tr"
        switch raw {
        case "low": return isTurkish ? "Düşük" : "Low"
        case "medium": return isTurkish ? "Orta" : "Medium"
        case "high": return isTurkish ? "Yüksek" : "High"
        case "urgent": return isTurkish ? "Acil" : "Urgent"
        default: return raw.capitalized
        }
    }

    private func statusLabel(_ raw: String) -> String {
        let isTurkish = Locale.current.language.languageCode?.identifier == "tr"
        switch raw {
        case "todo": return isTurkish ? "Yapılacak" : "Todo"
        case "inProgress": return isTurkish ? "Devam Ediyor" : "In Progress"
        case "review": return isTurkish ? "İncelemede" : "Review"
        case "done": return isTurkish ? "Tamamlandı" : "Done"
        default: return raw.capitalized
        }
    }
}
