//
//  IdentityProgressState.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 27.04.2026.
//

import Foundation
import SwiftData

@Model
final class IdentityProgressState {
    var id: UUID
    var ownerUserID: String?

    var level: Int

    // Compatibility only. UI ve logic kullanmaz.
    var totalXP: Int

    var focusSessions: Int
    var completedTasks: Int
    var streakDays: Int

    var currentLevel: Int
    var updatedAt: Date

    // MARK: - Unified streak progression (Phase 1)

    /// Live streak — consecutive days with BOTH a completed task and a focus.
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    /// Last day that satisfied the streak rule.
    var lastStreakDay: Date? = nil
    /// Last day `ProgressionManager.evaluate` ran (break detection bookkeeping).
    var lastEvaluatedDay: Date? = nil

    /// Pro streak-restore budget (resets monthly via `restoreCycleKey`).
    var streakRestoresUsed: Int = 0
    /// "yyyy-MM" of the current restore cycle.
    var restoreCycleKey: String = ""

    /// Pro privacy switch — broadcast my stats to friends/crew.
    var statsSharingEnabled: Bool = true

    /// A streak break happened and can still be restored this session.
    var pendingStreakBreak: Bool = false
    /// The streak length that was lost (for restore).
    var brokenStreakValue: Int = 0

    init(
        id: UUID = UUID(),
        ownerUserID: String? = nil,
        level: Int = 1,
        totalXP: Int = 0,
        focusSessions: Int = 0,
        completedTasks: Int = 0,
        streakDays: Int = 0,
        currentLevel: Int = 1,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.ownerUserID = ownerUserID
        self.level = max(1, level)
        self.totalXP = 0
        self.focusSessions = max(0, focusSessions)
        self.completedTasks = max(0, completedTasks)
        self.streakDays = max(0, streakDays)
        self.currentLevel = max(1, currentLevel)
        self.updatedAt = updatedAt
    }
}
