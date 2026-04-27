//
//  FocusCompletionRecorder.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 27.04.2026.
//

//
// FocusCompletionRecorder.swift
// DailyTodo
//

import Foundation
import SwiftData

extension Notification.Name {
    static let focusSessionRecordSaved = Notification.Name("focusSessionRecordSaved")
}

@MainActor
final class FocusCompletionRecorder {
    static let shared = FocusCompletionRecorder()
    private init() {}

    var container: ModelContainer?

    func configure(container: ModelContainer) {
        self.container = container
    }

    func saveCompletedSession(
        ownerUserID: String?,
        title: String,
        startedAt: Date,
        endedAt: Date,
        totalSeconds: Int,
        completedSeconds: Int,
        isCompleted: Bool
    ) {
        guard let container else { return }

        let context = ModelContext(container)

        let record = FocusSessionRecord(
            ownerUserID: ownerUserID,
            title: title,
            startedAt: startedAt,
            endedAt: endedAt,
            totalSeconds: totalSeconds,
            completedSeconds: completedSeconds,
            isCompleted: isCompleted
        )

        context.insert(record)

        do {
            try context.save()

            NotificationCenter.default.post(
                name: .focusSessionRecordSaved,
                object: record
            )
        } catch {
            print("FOCUS RECORD SAVE ERROR:", error.localizedDescription)
        }
    }
}
