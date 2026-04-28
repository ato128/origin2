//
//  IdentityXPLevelEngine.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 27.04.2026.
//
import Foundation
import SwiftUI
import SwiftData

struct IdentityLevelSnapshot {
    let level: Int
    let title: String
    let accent: Color

    let progress: Double
    let taskRatio: Double
    let focusRatio: Double
    let streakRatio: Double

    let focusSessions: Int
    let focusMinutes: Int
    let completedTasks: Int
    let streakDays: Int

    let currentRequirement: IdentityLevelInfo
    let nextRequirement: IdentityLevelInfo

    let isMaxLevel: Bool
    let isReadyForLevelUp: Bool

    var percentText: String {
        "\(Int(round(progress * 100)))%"
    }

    var levelRangeText: String {
        isMaxLevel ? "Lv.\(level)" : "Lv.\(level) → Lv.\(nextRequirement.level)"
    }

    var statusText: String {
        if isMaxLevel { return "Maksimum seviye" }
        return isReadyForLevelUp ? "Yeni seviye hazır" : "İlerleme aktif"
    }
}

enum IdentityXPLevelEngine {

    static func snapshot(
        currentLevel: Int,
        tasks: [DTTaskItem],
        focusSessions: [FocusSessionRecord],
        streakDays: Int
    ) -> IdentityLevelSnapshot {

        let safeCurrentLevel = min(max(currentLevel, 1), InsightsIdentityLevelSystem.maxLevel)

        let completedTasks = tasks.filter(\.isDone).count

        let completedFocusRecords = focusSessions.filter {
            $0.isCompleted && $0.completedSeconds >= 60
        }

        let focusCount = completedFocusRecords.count
        let focusMinutes = completedFocusRecords.reduce(0) {
            $0 + max(1, $1.completedSeconds / 60)
        }

        let current = InsightsIdentityLevelSystem.info(for: safeCurrentLevel)
        let next = InsightsIdentityLevelSystem.info(for: min(safeCurrentLevel + 1, InsightsIdentityLevelSystem.maxLevel))

        let isMaxLevel = safeCurrentLevel >= InsightsIdentityLevelSystem.maxLevel

        let taskRatio = isMaxLevel ? 1 : requirementProgress(
            current: completedTasks,
            target: next.requiredCompletedTasks
        )

        let focusRatio = isMaxLevel ? 1 : requirementProgress(
            current: focusCount,
            target: next.requiredFocusSessions
        )

        let streakRatio = isMaxLevel ? 1 : requirementProgress(
            current: streakDays,
            target: next.requiredStreakDays
        )

        let ready = !isMaxLevel &&
        completedTasks >= next.requiredCompletedTasks &&
        focusCount >= next.requiredFocusSessions &&
        streakDays >= next.requiredStreakDays

        let progress = isMaxLevel ? 1 : ready ? 1 : min(max((taskRatio + focusRatio + streakRatio) / 3, 0), 1)

        return IdentityLevelSnapshot(
            level: safeCurrentLevel,
            title: current.title,
            accent: current.accent,
            progress: progress,
            taskRatio: taskRatio,
            focusRatio: focusRatio,
            streakRatio: streakRatio,
            focusSessions: focusCount,
            focusMinutes: focusMinutes,
            completedTasks: completedTasks,
            streakDays: streakDays,
            currentRequirement: current,
            nextRequirement: next,
            isMaxLevel: isMaxLevel,
            isReadyForLevelUp: ready
        )
    }

    private static func requirementProgress(
        current: Int,
        target: Int
    ) -> Double {
        guard target > 0 else { return 1 }
        return min(1, max(0, Double(current) / Double(target)))
    }
}
