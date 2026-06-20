//
//  ArenaStore.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 29.05.2026.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class ArenaStore: ObservableObject {
    @Published var summary: CrewCommunityScopeSummary?
    @Published var leaderboard: [CrewStudentLeaderboardEntry] = []
    @Published var topCrews: [CrewCommunityCrewEntry] = []
    @Published var weeklyChallenge: CrewWeeklyChallengeData?

    @Published var isLoading = false
    @Published var didLoadOnce = false
    @Published var lastError: String?

    private var lastScope: CrewCommunityScope?
    private var lastRange: CrewLeaderboardRange?

    func load(
        scope: CrewCommunityScope,
        range: CrewLeaderboardRange,
        force: Bool = false
    ) async {
        if !force,
           didLoadOnce,
           lastScope == scope,
           lastRange == range {
            return
        }

        isLoading = true
        lastError = nil

        let backendScope = ArenaBackendScope(scope)
        let backendRange = ArenaBackendRange(range)

        async let summaryResult = ArenaBackendClient.shared.fetchSummary(scope: backendScope)
        async let leaderboardResult = ArenaBackendClient.shared.fetchLeaderboard(
            scope: backendScope,
            range: backendRange
        )
        async let topCrewsResult = ArenaBackendClient.shared.fetchTopCrews(
            scope: backendScope,
            range: backendRange
        )
        async let challengeResult = ArenaBackendClient.shared.fetchWeeklyChallenge()

        let resolvedSummary = await summaryResult
        let resolvedLeaderboard = await leaderboardResult
        let resolvedTopCrews = await topCrewsResult
        let resolvedChallenge = await challengeResult

        if let resolvedSummary {
            summary = resolvedSummary.asDisplayModel
        } else {
            summary = nil
            lastError = tr("as_summary_failed")
        }

        leaderboard = resolvedLeaderboard.map { $0.asDisplayModel }
        topCrews = resolvedTopCrews.map { $0.asDisplayModel }
        weeklyChallenge = resolvedChallenge?.asDisplayModel

        lastScope = scope
        lastRange = range
        didLoadOnce = true
        isLoading = false
    }
}

// MARK: - Mapping

private extension ArenaBackendScope {
    init(_ scope: CrewCommunityScope) {
        switch scope {
        case .department:
            self = .department
        case .university:
            self = .university
        case .country:
            self = .country
        case .global:
            self = .global
        }
    }
}

private extension ArenaBackendRange {
    init(_ range: CrewLeaderboardRange) {
        switch range {
        case .week:
            self = .week
        case .month:
            self = .month
        case .all:
            self = .all
        }
    }
}

private extension ArenaSummaryDTO {
    var asDisplayModel: CrewCommunityScopeSummary {
        CrewCommunityScopeSummary(
            label: label,
            title: title,
            italicTitle: italicTitle,
            subtitle: subtitle,
            icon: icon,
            rankDeltaText: rankDeltaText,
            primaryLiveText: primaryLiveText,
            secondaryText: secondaryText,
            metrics: metrics.map { $0.asDisplayModel }
        )
    }
}

private extension ArenaMetricDTO {
    var asDisplayModel: CrewMetricData {
        CrewMetricData(
            value: value,
            title: title,
            accentHex: accentHex
        )
    }
}

private extension ArenaLeaderboardEntryDTO {
    var asDisplayModel: CrewStudentLeaderboardEntry {
        CrewStudentLeaderboardEntry(
            rank: rank,
            displayName: displayName,
            universityShort: universityShort,
            focusMinutes: focusMinutes,
            badges: badges,
            colorHex: colorHex,
            isCurrentUser: isCurrentUser,
            deltaRank: deltaRank
        )
    }
}

private extension ArenaCrewEntryDTO {
    var asDisplayModel: CrewCommunityCrewEntry {
        CrewCommunityCrewEntry(
            rank: rank,
            name: name,
            icon: icon,
            universityShort: universityShort,
            focusMinutes: focusMinutes,
            memberCount: memberCount,
            capacity: capacity,
            badges: badges,
            colorHex: colorHex,
            joinState: CrewJoinState(rawValue: joinState) ?? .member,
            deltaRank: deltaRank,
            isLive: isLive
        )
    }
}

private extension ArenaWeeklyChallengeDTO {
    var asDisplayModel: CrewWeeklyChallengeData {
        CrewWeeklyChallengeData(
            label: label,
            title: title,
            italicTitle: italicTitle,
            timeLeftText: timeLeftText,
            participantText: participantText,
            rewardText: rewardText,
            progress: min(max(progress, 0), 1)
        )
    }
}
