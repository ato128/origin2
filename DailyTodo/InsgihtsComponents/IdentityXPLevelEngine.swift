//
//  IdentityXPLevelEngine.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 27.04.2026.
//
import Foundation
import SwiftUI
import SwiftData

// MARK: - Snapshot

struct IdentityLevelSnapshot {
    let level: Int
    let title: String
    let accent: Color

    let progress: Double

    let focusSessions: Int
    let focusMinutes: Int
    let completedTasks: Int
    let streakDays: Int

    let currentRequirement: IdentityLevelInfo
    let nextRequirement: IdentityLevelInfo
}

// MARK: - Engine

enum IdentityXPLevelEngine {

    static func snapshot(
        tasks: [DTTaskItem],
        focusSessions: [FocusSessionRecord],
        streakDays: Int
    ) -> IdentityLevelSnapshot {

        let completedTasks = tasks.filter(\.isDone).count

        let completedFocusRecords = focusSessions.filter {
            $0.isCompleted && $0.completedSeconds >= 60
        }

        let focusCount = completedFocusRecords.count
        let focusMinutes = completedFocusRecords.reduce(0) {
            $0 + max(1, $1.completedSeconds / 60)
        }

        let level = calculatedLevel(
            focusSessions: focusCount,
            completedTasks: completedTasks,
            streakDays: streakDays
        )

        let current = InsightsIdentityLevelSystem.info(for: level)
        let next = InsightsIdentityLevelSystem.info(for: min(level + 1, 50))

        let progress: Double

        if level >= 50 {
            progress = 1
        } else {
            let focusProgress = requirementProgress(
                current: focusCount,
                target: next.requiredFocusSessions
            )

            let taskProgress = requirementProgress(
                current: completedTasks,
                target: next.requiredCompletedTasks
            )

            let streakProgress = requirementProgress(
                current: streakDays,
                target: next.requiredStreakDays
            )

            progress = min(
                1,
                max(
                    0,
                    (focusProgress + taskProgress + streakProgress) / 3
                )
            )
        }

        return IdentityLevelSnapshot(
            level: level,
            title: current.title,
            accent: current.accent,
            progress: progress,
            focusSessions: focusCount,
            focusMinutes: focusMinutes,
            completedTasks: completedTasks,
            streakDays: streakDays,
            currentRequirement: current,
            nextRequirement: next
        )
    }

    private static func calculatedLevel(
        focusSessions: Int,
        completedTasks: Int,
        streakDays: Int
    ) -> Int {
        for level in stride(from: 50, through: 1, by: -1) {
            let info = InsightsIdentityLevelSystem.info(for: level)

            if focusSessions >= info.requiredFocusSessions &&
                completedTasks >= info.requiredCompletedTasks &&
                streakDays >= info.requiredStreakDays {
                return level
            }
        }

        return 1
    }

    private static func requirementProgress(
        current: Int,
        target: Int
    ) -> Double {
        guard target > 0 else { return 1 }
        return min(1, max(0, Double(current) / Double(target)))
    }
}
