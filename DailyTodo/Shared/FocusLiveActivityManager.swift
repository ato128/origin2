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
        pausedProgress: Double? = nil
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
            pausedProgress: pausedProgress
        )

        let content = ActivityContent(state: state, staleDate: endDate)

        do {
            _ = try Activity<FocusAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            print("❌ FocusLiveActivity start error:", error.localizedDescription)
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
        pausedProgress: Double? = nil
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
            pausedProgress: pausedProgress
        )

        let updatedContent = ActivityContent(state: newState, staleDate: endDate)
        await activity.update(updatedContent)
    }

    func end() async {
        for activity in Activity<FocusAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
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
        pausedProgress: Double? = nil
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
                pausedProgress: pausedProgress
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
                pausedProgress: pausedProgress
            )
        }
    }
}
