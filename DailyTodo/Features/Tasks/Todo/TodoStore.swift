//
//  TodoStore.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import Foundation
import SwiftData
import SwiftUI
import Combine

@MainActor
final class TodoStore: ObservableObject {

    private let context: ModelContext

    @Published private(set) var items: [DTTaskItem] = []
    @Published private(set) var currentUserID: String?

    init(context: ModelContext, currentUserID: String? = nil) {
        self.context = context
        self.currentUserID = currentUserID
        reload()
    }

    func setCurrentUserID(_ userID: String?) {
        currentUserID = userID
        reload()
    }

    func reload() {
        do {
            let descriptor = FetchDescriptor<DTTaskItem>(
                sortBy: [SortDescriptor(\DTTaskItem.createdAt, order: .reverse)]
            )

            let fetched = try context.fetch(descriptor)

            if let currentUserID {
                items = fetched.filter { $0.ownerUserID == currentUserID }
            } else {
                items = fetched
            }
        } catch {
            print("❌ TodoStore.reload fetch failed:", error)
            items = []
        }
    }

    private func saveAndReload() {
        do {
            try context.save()
        } catch {
            print("❌ TodoStore.save failed:", error)
        }

        reload()
        objectWillChange.send()
    }

    func isOverdue(_ item: DTTaskItem) -> Bool {
        guard let due = item.dueDate else { return false }
        if item.isDone { return false }
        return due < Date()
    }

    func add(
        title: String,
        dueDate: Date?,
        notes: String = "",
        taskType: String = "standard",
        colorName: String = "blue",
        courseName: String = "",
        scheduledWeekDate: Date? = nil,
        scheduledWeekDurationMinutes: Int? = nil,
        workoutDurationMinutes: Int? = nil
    ) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCourseName = courseName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return }

        guard let currentUserID else {
            print("❌ TodoStore.add blocked: currentUserID nil")
            return
        }

        let newItem = DTTaskItem(
            ownerUserID: currentUserID,
            title: trimmed,
            isDone: false,
            dueDate: dueDate,
            createdAt: Date(),
            completedAt: nil,
            notes: trimmedNotes,
            taskType: taskType,
            colorName: colorName,
            courseName: trimmedCourseName,
            workoutDay: nil,
            workoutDurationMinutes: workoutDurationMinutes,
            scheduledWeekDate: scheduledWeekDate,
            scheduledWeekDurationMinutes: scheduledWeekDurationMinutes
        )

        context.insert(newItem)
        saveAndReload()
    }

    func toggleDone(_ item: DTTaskItem) {
        guard item.ownerUserID == currentUserID else { return }
        item.isDone.toggle()
        item.completedAt = item.isDone ? Date() : nil
        saveAndReload()
    }

    func update(
        itemID: PersistentIdentifier,
        title: String,
        dueDate: Date?,
        notes: String = "",
        taskType: String = "standard",
        colorName: String = "blue",
        courseName: String = "",
        scheduledWeekDate: Date? = nil,
        scheduledWeekDurationMinutes: Int? = nil,
        workoutDurationMinutes: Int? = nil
    ) {
        guard let target = items.first(where: { $0.persistentModelID == itemID }) else { return }
        guard target.ownerUserID == currentUserID else { return }

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCourseName = courseName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return }

        target.title = trimmed
        target.dueDate = dueDate
        target.notes = trimmedNotes
        target.taskType = taskType
        target.colorName = colorName
        target.courseName = trimmedCourseName
        target.scheduledWeekDate = scheduledWeekDate
        target.scheduledWeekDurationMinutes = scheduledWeekDurationMinutes
        target.workoutDurationMinutes = workoutDurationMinutes

        saveAndReload()
    }

    func delete(_ item: DTTaskItem) {
        guard item.ownerUserID == currentUserID else { return }
        context.delete(item)
        saveAndReload()
    }
}
