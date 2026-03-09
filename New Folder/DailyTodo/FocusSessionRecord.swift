//
//  FocusSessionRecord.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 8.03.2026.
//

import Foundation
import SwiftData

@Model
final class FocusSessionRecord {
    var id: UUID
    var title: String
    var startedAt: Date
    var endedAt: Date
    var totalSeconds: Int
    var completedSeconds: Int
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        title: String,
        startedAt: Date,
        endedAt: Date,
        totalSeconds: Int,
        completedSeconds: Int,
        isCompleted: Bool
    ) {
        self.id = id
        self.title = title
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.totalSeconds = totalSeconds
        self.completedSeconds = completedSeconds
        self.isCompleted = isCompleted
    }
}
