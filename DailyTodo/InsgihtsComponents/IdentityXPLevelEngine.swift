//
//  IdentityXPLevelEngine.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 27.04.2026.
//
import Foundation
import SwiftUI
import SwiftData
import Combine

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
        return isReadyForLevelUp ? tr("ixp_new_level_ready") : tr("ixp_progress_active")
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

// MARK: - Unified streak engine (single source of truth)
//
// Rule (user decision): a day keeps the streak alive only if it has BOTH
//   • at least one completed task (DTTaskItem.isDone with completedAt that day), AND
//   • at least one completed focus session (FocusSessionRecord.isCompleted, ≥60s).
// Missing either resets the streak. Callers pass already user-scoped arrays.

enum StreakProgressEngine {

    /// True if `day` satisfies the streak rule (a completed task AND a focus).
    static func dayQualifies(
        _ day: Date,
        tasks: [DTTaskItem],
        focusRecords: [FocusSessionRecord]
    ) -> Bool {
        let cal = Calendar.current

        let hasTask = tasks.contains { task in
            guard task.isDone, let done = task.completedAt else { return false }
            return cal.isDate(done, inSameDayAs: day)
        }
        guard hasTask else { return false }

        let hasFocus = focusRecords.contains { rec in
            // countsTowardStats: an early-stopped session of ≥1 real minute keeps
            // the streak alive, consistent with focus stats everywhere else.
            guard rec.countsTowardStats else { return false }
            return cal.isDate(rec.endedAt, inSameDayAs: day)
        }
        return hasFocus
    }

    /// Consecutive qualifying days counting back from `asOf` (default today).
    /// If today has not qualified yet, the streak is NOT broken — counting
    /// simply starts from yesterday (the user still has the day to finish).
    static func currentStreak(
        asOf reference: Date = Date(),
        tasks: [DTTaskItem],
        focusRecords: [FocusSessionRecord]
    ) -> Int {
        let cal = Calendar.current
        var cursor = cal.startOfDay(for: reference)
        var streak = 0

        if dayQualifies(cursor, tasks: tasks, focusRecords: focusRecords) {
            streak += 1
        }
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: cursor) else {
            return streak
        }
        cursor = yesterday

        for _ in 0..<366 {
            if dayQualifies(cursor, tasks: tasks, focusRecords: focusRecords) {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = prev
            } else {
                break
            }
        }

        return streak
    }

    /// The most recent day (≤ today) that qualified, or nil if none.
    static func lastQualifyingDay(
        asOf reference: Date = Date(),
        tasks: [DTTaskItem],
        focusRecords: [FocusSessionRecord]
    ) -> Date? {
        let cal = Calendar.current
        var cursor = cal.startOfDay(for: reference)
        for _ in 0..<366 {
            if dayQualifies(cursor, tasks: tasks, focusRecords: focusRecords) {
                return cursor
            }
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { return nil }
            cursor = prev
        }
        return nil
    }

    /// "yyyy-MM" key for the monthly restore cycle.
    static func cycleKey(for date: Date = Date()) -> String {
        let comps = Calendar.current.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
    }
}

// MARK: - Progression manager (central hub)
//
// Keeps the unified streak + level in sync everywhere (Home badge, Insights
// identity card, social stats). Owns the rules: a day needs BOTH a task and a
// focus; losing the streak drops the level by 1; Updo Pro restores 3× / month.

@MainActor
final class ProgressionManager: ObservableObject {

    static let shared = ProgressionManager()
    private init() {}

    static let monthlyRestoreLimit = 3

    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var longestStreak: Int = 0
    @Published private(set) var level: Int = 1
    @Published private(set) var pendingStreakBreak: Bool = false
    @Published private(set) var brokenStreakValue: Int = 0
    @Published private(set) var restoresLeftThisMonth: Int = ProgressionManager.monthlyRestoreLimit
    @Published private(set) var statsSharingEnabled: Bool = true

    private var ownerUserID: String?
    private var lastTotalFocusMinutes: Int = 0
    private var lastPushSignature: String?

    // MARK: Evaluate

    func evaluate(
        context: ModelContext,
        ownerUserID: String?,
        tasks: [DTTaskItem],
        focusRecords: [FocusSessionRecord],
        isPro: Bool
    ) {
        self.ownerUserID = ownerUserID

        let scopedTasks = tasks.filter { $0.ownerUserID == ownerUserID || $0.ownerUserID == nil }
        let scopedFocus = focusRecords.filter { $0.ownerUserID == ownerUserID || $0.ownerUserID == nil }

        let state = resolveState(context: context, ownerUserID: ownerUserID)

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        let key = StreakProgressEngine.cycleKey()
        if state.restoreCycleKey != key {
            state.restoreCycleKey = key
            state.streakRestoresUsed = 0
        }

        let todayQ = StreakProgressEngine.dayQualifies(today, tasks: scopedTasks, focusRecords: scopedFocus)
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today

        if let last = state.lastStreakDay.map({ cal.startOfDay(for: $0) }) {
            if last == today {
                if todayQ, state.currentStreak == 0 { state.currentStreak = 1 }
            } else if last == yesterday {
                if todayQ {
                    state.currentStreak += 1
                    state.lastStreakDay = today
                }
            } else if last < yesterday {
                let dataStreak = StreakProgressEngine.currentStreak(tasks: scopedTasks, focusRecords: scopedFocus)
                let dataLast = StreakProgressEngine.lastQualifyingDay(tasks: scopedTasks, focusRecords: scopedFocus)

                if dataStreak >= state.currentStreak {
                    state.currentStreak = dataStreak
                    state.lastStreakDay = dataLast
                } else {
                    applyBreak(state: state, lostStreak: state.currentStreak)
                    state.currentStreak = dataStreak
                    state.lastStreakDay = dataLast
                }
            }
        } else {
            state.currentStreak = StreakProgressEngine.currentStreak(tasks: scopedTasks, focusRecords: scopedFocus)
            state.lastStreakDay = StreakProgressEngine.lastQualifyingDay(tasks: scopedTasks, focusRecords: scopedFocus)
        }

        if state.pendingStreakBreak, state.brokenStreakValue > 0, state.currentStreak >= state.brokenStreakValue {
            state.pendingStreakBreak = false
            state.brokenStreakValue = 0
        }

        state.longestStreak = max(state.longestStreak, state.currentStreak)
        state.streakDays = state.currentStreak
        state.lastEvaluatedDay = today
        state.updatedAt = Date()

        lastTotalFocusMinutes = scopedFocus
            .filter { $0.isCompleted && $0.completedSeconds >= 60 }
            .reduce(0) { $0 + $1.completedSeconds / 60 }

        try? context.save()
        publish(from: state)
        pushMyStats(from: state)
    }

    // MARK: Restore (Pro)

    @discardableResult
    func restoreStreak(context: ModelContext) -> Bool {
        guard let state = currentState(context: context) else { return false }
        guard state.pendingStreakBreak else { return false }
        guard state.streakRestoresUsed < Self.monthlyRestoreLimit else { return false }

        state.currentStreak = max(state.currentStreak, state.brokenStreakValue)
        state.longestStreak = max(state.longestStreak, state.currentStreak)
        state.level = min(state.level + 1, InsightsIdentityLevelSystem.maxLevel)
        state.currentLevel = state.level
        state.streakRestoresUsed += 1
        state.pendingStreakBreak = false
        state.brokenStreakValue = 0
        state.lastStreakDay = Calendar.current.startOfDay(for: Date())
        state.streakDays = state.currentStreak
        state.updatedAt = Date()

        try? context.save()
        publish(from: state)
        pushMyStats(from: state)
        return true
    }

    // MARK: Privacy (Pro)

    func setStatsSharing(_ enabled: Bool, context: ModelContext) {
        guard let state = currentState(context: context) else { return }
        state.statsSharingEnabled = enabled
        state.updatedAt = Date()
        try? context.save()
        publish(from: state)
        pushMyStats(from: state)
    }

    // MARK: Helpers

    private func applyBreak(state: IdentityProgressState, lostStreak: Int) {
        state.level = max(1, state.level - 1)
        state.currentLevel = state.level
        state.pendingStreakBreak = true
        state.brokenStreakValue = max(lostStreak, 1)
    }

    private func resolveState(context: ModelContext, ownerUserID: String?) -> IdentityProgressState {
        if let existing = currentState(context: context) {
            return existing
        }
        let created = IdentityProgressState(ownerUserID: ownerUserID)
        context.insert(created)
        return created
    }

    private func currentState(context: ModelContext) -> IdentityProgressState? {
        let all = (try? context.fetch(FetchDescriptor<IdentityProgressState>())) ?? []
        if let match = all.first(where: { $0.ownerUserID == ownerUserID }) {
            return match
        }
        return all.first(where: { $0.ownerUserID == nil })
    }

    private func publish(from state: IdentityProgressState) {
        currentStreak = state.currentStreak
        longestStreak = state.longestStreak
        level = state.level
        pendingStreakBreak = state.pendingStreakBreak
        brokenStreakValue = state.brokenStreakValue
        restoresLeftThisMonth = max(0, Self.monthlyRestoreLimit - state.streakRestoresUsed)
        statsSharingEnabled = state.statsSharingEnabled
    }

    /// Mirrors the current stats to the backend (deduped by signature). Focus
    /// state is left untouched here — FocusSessionManager pushes that live.
    private func pushMyStats(from state: IdentityProgressState) {
        let signature = [
            state.level, state.currentStreak, state.longestStreak, lastTotalFocusMinutes,
            state.statsSharingEnabled ? 1 : 0
        ].map(String.init).joined(separator: "-")

        guard signature != lastPushSignature else { return }
        lastPushSignature = signature

        let level = state.level
        let currentStreak = state.currentStreak
        let longestStreak = state.longestStreak
        let totalFocus = lastTotalFocusMinutes
        let sharing = state.statsSharingEnabled

        Task.detached {
            await UserStatsBackendClient.shared.putMyStats(
                level: level,
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                totalFocusMinutes: totalFocus,
                isFocusing: nil,
                focusUntil: nil,
                sharingEnabled: sharing
            )
        }
    }
}
