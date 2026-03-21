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

    

    // MARK: - Read

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
            completedAt: nil
        )

        context.insert(newItem)
        saveAndReload()
    }

    // MARK: - Update

    func toggleDone(_ item: DTTaskItem) {
        guard item.ownerUserID == currentUserID else { return }
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
        guard target.ownerUserID == currentUserID else { return }

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        target.title = trimmed
        target.dueDate = dueDate
        saveAndReload()
    }

    // MARK: - Delete

    func delete(_ item: DTTaskItem) {
        guard item.ownerUserID == currentUserID else { return }
        context.delete(item)
        saveAndReload()
    }
}
