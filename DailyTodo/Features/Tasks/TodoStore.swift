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

    init(context: ModelContext) {
        self.context = context
        reload()
    }

    // MARK: - Read

    func reload() {
        do {
            let descriptor = FetchDescriptor<DTTaskItem>(
                sortBy: [SortDescriptor(\DTTaskItem.createdAt, order: .reverse)]
            )
            items = try context.fetch(descriptor)
        } catch {
            print("❌ TodoStore.reload fetch failed:", error)
            items = []
        }
    }

    // MARK: - Helpers

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

    // MARK: - Create

    func add(
        title: String,
        dueDate: Date?
    ) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let newItem = DTTaskItem(
            title: trimmed,
            isDone: false,
            dueDate: dueDate,
            createdAt: Date(),
            completedAt: nil
        )

        context.insert(newItem)
        saveAndReload()
    }

    // MARK: - Update

    func toggleDone(_ item: DTTaskItem) {
        item.isDone.toggle()
        item.completedAt = item.isDone ? Date() : nil
        saveAndReload()
    }

    func update(
        itemID: PersistentIdentifier,
        title: String,
        dueDate: Date?
    ) {
        guard let target = items.first(where: { $0.persistentModelID == itemID }) else { return }

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        target.title = trimmed
        target.dueDate = dueDate
        saveAndReload()
    }

    // MARK: - Delete

    func delete(_ item: DTTaskItem) {
        context.delete(item)
        saveAndReload()
    }
}
