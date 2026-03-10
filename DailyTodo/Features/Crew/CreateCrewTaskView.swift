//
//  CreateCrewTaskView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 10.03.2026.
//

import SwiftUI
import SwiftData

struct CreateCrewTaskView: View {

    let crew: Crew
    let members: [CrewMember]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title: String = ""
    @State private var details: String = ""

    @State private var assignedTo: String = ""
    @State private var createdBy: String = "Atakan"

    @State private var priority: String = "medium"
    @State private var status: String = "todo"

    @State private var showOnWeek: Bool = false
    @State private var scheduledWeekday: Int = 0
    @State private var scheduledHour: Int = 18
    @State private var scheduledMinute: Int = 0
    @State private var scheduledDurationMinute: Int = 60

    @State private var addPoll: Bool = false
    @State private var pollQuestion: String = ""

    @State private var firstNote: String = ""

    private let priorityOptions = ["low", "medium", "high", "urgent"]
    private let statusOptions = ["todo", "inProgress", "review", "done"]
    private let weekdayTitles = ["Pzt","Sal","Çar","Per","Cum","Cmt","Paz"]
    private let durationOptions = [15,30,45,60,90,120]

    var body: some View {
        NavigationStack {

            Form {

                Section("Task") {
                    TextField("Task title", text: $title)

                    TextField("Details / description", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Assignment") {

                    Picker("Assign Member", selection: $assignedTo) {

                        Text("Unassigned").tag("")

                        ForEach(members, id:\.id) { member in
                            Text(member.name).tag(member.name)
                        }

                    }

                    TextField("Created by", text: $createdBy)

                }

                Section("Priority & Status") {

                    Picker("Priority", selection: $priority) {

                        ForEach(priorityOptions, id:\.self) { item in
                            Text(priorityTitle(item)).tag(item)
                        }

                    }

                    Picker("Status", selection: $status) {

                        ForEach(statusOptions, id:\.self) { item in
                            Text(statusTitle(item)).tag(item)
                        }

                    }

                }

                Section("Week Planning") {

                    Toggle("Show on Week page", isOn: $showOnWeek)

                    if showOnWeek {

                        Picker("Day", selection: $scheduledWeekday) {

                            ForEach(0..<weekdayTitles.count, id:\.self) { index in
                                Text(weekdayTitles[index]).tag(index)
                            }

                        }

                        HStack {

                            Picker("Hour", selection: $scheduledHour) {

                                ForEach(0..<24, id:\.self) { hour in
                                    Text(String(format:"%02d",hour)).tag(hour)
                                }

                            }

                            Picker("Minute", selection: $scheduledMinute) {

                                ForEach([0,5,10,15,20,30,40,45,50,55], id:\.self) { minute in
                                    Text(String(format:"%02d",minute)).tag(minute)
                                }

                            }

                        }

                        Picker("Duration", selection: $scheduledDurationMinute) {

                            ForEach(durationOptions, id:\.self) { duration in
                                Text("\(duration) min").tag(duration)
                            }

                        }

                    }

                }

                Section("Discussion") {

                    TextField("First note / idea", text: $firstNote, axis: .vertical)
                        .lineLimit(2...4)

                    Toggle("Add poll", isOn: $addPoll)

                    if addPoll {

                        TextField("Poll question", text: $pollQuestion)

                    }

                }

                Section {

                    Button("Create Task") {

                        saveTask()

                    }
                    .frame(maxWidth:.infinity)

                }

            }

            .navigationTitle("Create Task")
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(placement:.topBarLeading) {

                    Button("Cancel") {
                        dismiss()
                    }

                }

                ToolbarItem(placement:.topBarTrailing) {

                    Button("Save") {
                        saveTask()
                    }
                    .disabled(title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)

                }

            }

        }
    }

    private func saveTask() {

        let cleanTitle = title.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        let startMinute = scheduledHour * 60 + scheduledMinute

        let task = CrewTask(

            crewID: crew.id,
            title: cleanTitle,
            details: details,
            assignedTo: assignedTo,
            createdBy: createdBy,
            priority: priority,
            status: status,
            showOnWeek: showOnWeek,
            scheduledWeekday: showOnWeek ? scheduledWeekday : nil,
            scheduledStartMinute: showOnWeek ? startMinute : nil,
            scheduledDurationMinute: showOnWeek ? scheduledDurationMinute : nil,
            isDone: status == "done"

        )

        modelContext.insert(task)

        if addPoll {

            let cleanPoll = pollQuestion.trimmingCharacters(in:.whitespacesAndNewlines)

            if !cleanPoll.isEmpty {

                let poll = CrewTaskPoll(
                    taskID: task.id,
                    question: cleanPoll
                )

                modelContext.insert(poll)

            }

        }

        if !firstNote.isEmpty {

            let comment = CrewTaskComment(
                taskID: task.id,
                authorName: createdBy,
                message: firstNote
            )

            modelContext.insert(comment)

        }

        let activity = CrewActivity(
            crewID: crew.id,
            memberName: createdBy,
            actionText: "created task \(cleanTitle)"
        )

        modelContext.insert(activity)

        try? modelContext.save()

        dismiss()

    }

    private func priorityTitle(_ value:String) -> String {

        switch value {

        case "low": return "Low"
        case "medium": return "Medium"
        case "high": return "High"
        case "urgent": return "Urgent"

        default: return value
        }

    }

    private func statusTitle(_ value:String) -> String {

        switch value {

        case "todo": return "Todo"
        case "inProgress": return "In Progress"
        case "review": return "Review"
        case "done": return "Done"

        default: return value
        }

    }

}
