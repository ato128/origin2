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
    // Tab switches re-create CrewView; a shared instance keeps the arena data
    // alive across visits so the section doesn't refetch and dim on every tap.
    static let shared = ArenaStore()

    @Published var summary: CrewCommunityScopeSummary?
    @Published var leaderboard: [CrewStudentLeaderboardEntry] = []
    @Published var topCrews: [CrewCommunityCrewEntry] = []
    @Published var weeklyChallenge: CrewWeeklyChallengeData?

    @Published var isLoading = false
    @Published var didLoadOnce = false
    @Published var lastError: String?

    private var lastScope: CrewCommunityScope?
    private var lastRange: CrewLeaderboardRange?
    private var lastLoadedAt: Date?
    private var isFetching = false

    /// Cached data younger than this is served as-is; older data is refreshed
    /// silently (no dimmed loading state) so the user never sees a reload.
    private let freshnessTTL: TimeInterval = 300

    func resetForUserChange() {
        summary = nil
        leaderboard = []
        topCrews = []
        weeklyChallenge = nil
        isLoading = false
        didLoadOnce = false
        lastError = nil
        lastScope = nil
        lastRange = nil
        lastLoadedAt = nil
    }

    func load(
        scope: CrewCommunityScope,
        range: CrewLeaderboardRange,
        force: Bool = false
    ) async {
        if isFetching { return }

        let sameSelection = didLoadOnce && lastScope == scope && lastRange == range
        let isFresh = lastLoadedAt.map { Date().timeIntervalSince($0) < freshnessTTL } ?? false

        if !force, sameSelection, isFresh {
            return
        }

        isFetching = true
        defer { isFetching = false }

        // Only dim the section when there's nothing (or the wrong scope) on
        // screen; a stale-data refresh happens silently behind current content.
        if !sameSelection || !didLoadOnce {
            isLoading = true
        }
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
        lastLoadedAt = Date()
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
