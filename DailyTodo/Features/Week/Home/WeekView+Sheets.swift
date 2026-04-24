//
//  WeekView+Sheets.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 24.03.2026.
//

import SwiftUI
import SwiftData

extension WeekView {

    var addEventSheet: some View {
        NavigationStack {
            AddEventView(
                defaultWeekday: selectedDay,
                defaultDate: planAheadDate
            )
            .environmentObject(studentStore)
            .environmentObject(session)
            .environmentObject(friendStore)
        }
        .presentationDetents([.medium, .large])
    }

    var planAheadSheet: some View {
        NavigationStack {
            PlanAheadView(
                selectedDate: $planAheadDate,
                mode: $planAheadMode,
                onContinue: {
                    showPlanAheadSheet = false

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        if planAheadMode == .crew {
                            if selectedCrew != nil {
                                showingCreateCrewTask = true
                            } else {
                                showCrewPickerSheet = true
                            }
                        } else {
                            showingAdd = true
                        }
                    }
                }
            )
        }
        .presentationDetents([.medium, .large])
    }

    var crewPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(allCrews) { crew in
                    Button {
                        selectedCrewID = crew.id
                        showCrewPickerSheet = false

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            showingCreateCrewTask = true
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(hexColor(crew.colorHex).opacity(0.16))
                                    .frame(width: 42, height: 42)

                                Image(systemName: crew.icon)
                                    .foregroundStyle(hexColor(crew.colorHex))
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(crew.name)
                                    .font(.headline)

                                Text("\(allCrewMembersForCrew(crew.id).count) members")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Choose Crew")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showCrewPickerSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    var createCrewTaskSheet: some View {
        NavigationStack {
            if let crew = selectedCrew,
               let crewDTO = crewStore.crews.first(where: { $0.id == crew.id }) {
                BackendCreateCrewTaskSheet(
                    crew: crewDTO,
                    members: crewStore.crewMembers.filter { $0.crew_id == crew.id },
                    memberProfiles: crewStore.memberProfiles
                )
                .environmentObject(crewStore)
                .environmentObject(session)
            } else {
                Text("No crew selected")
                    .padding()
            }
        }
        .presentationDetents([.medium, .large])
    }

    func editingEventSheet(_ ev: EventItem) -> some View {
        NavigationStack {
            EditEventView(event: ev)
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    func selectedCrewTaskSheet(_ task: WeekCrewTaskItem) -> some View {
        if let crewDTO = crewStore.crews.first(where: { $0.id == task.crewID }),
           let taskDTO = crewStore.crewTasks.first(where: { $0.id == task.id }) {
            NavigationStack {
                BackendCrewTaskDetailView(task: taskDTO, crew: crewDTO)
                    .environmentObject(crewStore)
                    .environmentObject(session)
            }
        } else {
            Text("Task not found")
                .padding()
        }
    }

    @ViewBuilder
    func selectedTaskForEditSheet(_ task: WeekCrewTaskItem) -> some View {
        if let crewDTO = crewStore.crews.first(where: { $0.id == task.crewID }),
           let taskDTO = crewStore.crewTasks.first(where: { $0.id == task.id }) {
            NavigationStack {
                BackendEditCrewTaskView(crew: crewDTO, task: taskDTO)
                    .environmentObject(crewStore)
                    .environmentObject(session)
            }
        } else {
            Text("Task not found")
                .padding()
        }
    }

    func selectedEventDetailSheet(_ event: EventItem) -> some View {
        NavigationStack {
            WeekEventDetailView(event: event)
        }
    }
}
