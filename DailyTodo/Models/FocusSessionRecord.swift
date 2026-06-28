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
    var ownerUserID: String?

    var title: String
    var startedAt: Date
    var endedAt: Date
    var totalSeconds: Int
    var completedSeconds: Int
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        ownerUserID: String? = nil,
        title: String,
        startedAt: Date,
        endedAt: Date,
        totalSeconds: Int,
        completedSeconds: Int,
        isCompleted: Bool
    ) {
        self.id = id
        self.ownerUserID = ownerUserID
        self.title = title
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.totalSeconds = totalSeconds
        self.completedSeconds = completedSeconds
        self.isCompleted = isCompleted
    }
}

extension FocusSessionRecord {
    /// Minimum meaningful focus duration (seconds) for a session to count toward stats.
    static let minimumMeaningfulSeconds = 60

    /// Single source of truth: a session counts toward focus stats/history when the
    /// user actually focused for at least a minute — regardless of whether the full
    /// planned duration was reached. Early-stopped sessions still count.
    var countsTowardStats: Bool {
        completedSeconds >= FocusSessionRecord.minimumMeaningfulSeconds
    }

    /// Whole minutes actually focused.
    var focusMinutes: Int {
        completedSeconds / 60
    }

    /// True only when the user reached (almost) the full planned duration.
    /// Used for the "completed" badge, not for counting.
    var reachedGoal: Bool {
        isCompleted
    }
}
