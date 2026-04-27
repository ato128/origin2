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
    var totalXP: Int

    var focusSessions: Int
    var completedTasks: Int
    var streakDays: Int

    var currentLevel: Int
    var updatedAt: Date

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
        self.level = level
        self.totalXP = totalXP
        self.focusSessions = focusSessions
        self.completedTasks = completedTasks
        self.streakDays = streakDays
        self.currentLevel = currentLevel
        self.updatedAt = updatedAt
    }
}
