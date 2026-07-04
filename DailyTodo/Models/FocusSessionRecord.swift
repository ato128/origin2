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

/// THE single source of truth for focus statistics across the whole app — Home,
/// Insights, the widget/Live-Activity sync and notifications all read through here
/// so a finished session is counted identically everywhere.
enum FocusStats {

    /// Records belonging to the current user, with a fallback to un-owned records
    /// (saved before the session store was ready) so nothing is silently dropped.
    static func owned(_ records: [FocusSessionRecord], for ownerUserID: String?) -> [FocusSessionRecord] {
        let qualifying = records.filter { $0.countsTowardStats }
        guard let uid = ownerUserID else { return qualifying.filter { $0.ownerUserID == nil } }
        let mine = qualifying.filter { $0.ownerUserID == uid }
        let orphan = qualifying.filter { $0.ownerUserID == nil }
        return mine + orphan
    }

    static func todayMinutes(_ records: [FocusSessionRecord], for ownerUserID: String?, now: Date = Date()) -> Int {
        let cal = Calendar.current
        return owned(records, for: ownerUserID)
            .filter { cal.isDate($0.endedAt, inSameDayAs: now) }
            .reduce(0) { $0 + $1.completedSeconds } / 60
    }

    static func weekMinutes(_ records: [FocusSessionRecord], for ownerUserID: String?, now: Date = Date()) -> Int {
        let cal = Calendar.current
        let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        return owned(records, for: ownerUserID)
            .filter { $0.endedAt >= weekStart }
            .reduce(0) { $0 + $1.completedSeconds } / 60
    }

    static func sessionCount(_ records: [FocusSessionRecord], for ownerUserID: String?) -> Int {
        owned(records, for: ownerUserID).count
    }

    static func hasToday(_ records: [FocusSessionRecord], for ownerUserID: String?, now: Date = Date()) -> Bool {
        let cal = Calendar.current
        return owned(records, for: ownerUserID).contains { cal.isDate($0.endedAt, inSameDayAs: now) }
    }

    // NOTE: no streak helper here on purpose — the ONE app-wide streak rule
    // (a day needs BOTH a completed task and a focus) lives in
    // StreakProgressEngine / ProgressionManager.
}
