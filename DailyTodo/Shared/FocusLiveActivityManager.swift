//
//  FocusLiveActivityManager.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 24.03.2026.
//

import Foundation
import ActivityKit

@MainActor
final class FocusLiveActivityManager {
    static let shared = FocusLiveActivityManager()
    private init() {}

    func start(
        title: String,
        subtitle: String,
        modeRaw: String,
        startDate: Date,
        endDate: Date,
        isPaused: Bool,
        isResting: Bool,
        pausedRemainingSeconds: Int? = nil,
        pausedProgress: Double? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = FocusAttributes(name: title)

        let state = FocusAttributes.ContentState(
            title: title,
            subtitle: subtitle,
            startDate: startDate,
            endDate: endDate,
            modeRaw: modeRaw,
            isPaused: isPaused,
            isResting: isResting,
            pausedRemainingSeconds: pausedRemainingSeconds,
            pausedProgress: pausedProgress,
            isCompleted: isCompleted,
            completedAt: completedAt
        )

        let content = ActivityContent(state: state, staleDate: endDate)

        do {
            _ = try Activity<FocusAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            Log.debug("❌ FocusLiveActivity start error:", error.localizedDescription)
        }
    }

    func update(
        title: String,
        subtitle: String,
        modeRaw: String,
        startDate: Date,
        endDate: Date,
        isPaused: Bool,
        isResting: Bool,
        pausedRemainingSeconds: Int? = nil,
        pausedProgress: Double? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) async {
        guard let activity = Activity<FocusAttributes>.activities.first else { return }

        let newState = FocusAttributes.ContentState(
            title: title,
            subtitle: subtitle,
            startDate: startDate,
            endDate: endDate,
            modeRaw: modeRaw,
            isPaused: isPaused,
            isResting: isResting,
            pausedRemainingSeconds: pausedRemainingSeconds,
            pausedProgress: pausedProgress,
            isCompleted: isCompleted,
            completedAt: completedAt
        )

        let updatedContent = ActivityContent(
            state: newState,
            staleDate: isCompleted ? Date().addingTimeInterval(8) : endDate
        )

        await activity.update(updatedContent)
    }

    func startOrUpdate(
        title: String,
        subtitle: String,
        modeRaw: String,
        startDate: Date,
        endDate: Date,
        isPaused: Bool,
        isResting: Bool,
        pausedRemainingSeconds: Int? = nil,
        pausedProgress: Double? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) async {
        if Activity<FocusAttributes>.activities.first != nil {
            await update(
                title: title,
                subtitle: subtitle,
                modeRaw: modeRaw,
                startDate: startDate,
                endDate: endDate,
                isPaused: isPaused,
                isResting: isResting,
                pausedRemainingSeconds: pausedRemainingSeconds,
                pausedProgress: pausedProgress,
                isCompleted: isCompleted,
                completedAt: completedAt
            )
        } else {
            await start(
                title: title,
                subtitle: subtitle,
                modeRaw: modeRaw,
                startDate: startDate,
                endDate: endDate,
                isPaused: isPaused,
                isResting: isResting,
                pausedRemainingSeconds: pausedRemainingSeconds,
                pausedProgress: pausedProgress,
                isCompleted: isCompleted,
                completedAt: completedAt
            )
        }
    }

    func finishThenEnd(
        title: String,
        subtitle: String = "Focus tamamlandı",
        modeRaw: String,
        startDate: Date,
        completedAt: Date = Date()
    ) async {
        let endDate = completedAt

        for activity in Activity<FocusAttributes>.activities {
            let completedState = FocusAttributes.ContentState(
                title: title,
                subtitle: subtitle,
                startDate: startDate,
                endDate: endDate,
                modeRaw: modeRaw,
                isPaused: false,
                isResting: false,
                pausedRemainingSeconds: nil,
                pausedProgress: 1.0,
                isCompleted: true,
                completedAt: completedAt
            )

            let completedContent = ActivityContent(
                state: completedState,
                staleDate: completedAt.addingTimeInterval(8)
            )

            await activity.update(completedContent)

            try? await Task.sleep(nanoseconds: 750_000_000)

            await activity.end(
                completedContent,
                dismissalPolicy: .after(completedAt.addingTimeInterval(2))
            )
        }
    }

    func end() async {
        for activity in Activity<FocusAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
