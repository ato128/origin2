//
//  ArenaDTO.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 29.05.2026.
//

import Foundation

// MARK: - Arena Scope / Range

enum ArenaBackendScope: String, CaseIterable {
    case department
    case university
    case country
    case global
}

enum ArenaBackendRange: String, CaseIterable {
    case week
    case month
    case all
}

// MARK: - Backend Responses

struct ArenaSummaryResponse: Decodable {
    let ok: Bool
    let scope: String?
    let userId: String?
    let summary: ArenaSummaryDTO?
    let error: String?
}

struct ArenaLeaderboardResponse: Decodable {
    let ok: Bool
    let scope: String?
    let range: String?
    let userId: String?
    let entries: [ArenaLeaderboardEntryDTO]?
    let error: String?
}

struct ArenaTopCrewsResponse: Decodable {
    let ok: Bool
    let scope: String?
    let range: String?
    let userId: String?
    let crews: [ArenaCrewEntryDTO]?
    let error: String?
}

struct ArenaWeeklyChallengeResponse: Decodable {
    let ok: Bool
    let userId: String?
    let challenge: ArenaWeeklyChallengeDTO?
    let error: String?
}

// MARK: - DTOs

struct ArenaSummaryDTO: Decodable, Equatable {
    let label: String
    let title: String
    let italicTitle: String
    let subtitle: String
    let icon: String
    let rankDeltaText: String
    let primaryLiveText: String
    let secondaryText: String
    let metrics: [ArenaMetricDTO]
}

struct ArenaMetricDTO: Decodable, Equatable {
    let value: String
    let title: String
    let accentHex: String
}

struct ArenaLeaderboardEntryDTO: Decodable, Identifiable, Equatable {
    let id: UUID?
    let rank: Int
    let displayName: String
    let universityShort: String
    let focusMinutes: Int
    let badges: [String]
    let colorHex: String
    let isCurrentUser: Bool
    let deltaRank: Int
}

struct ArenaCrewEntryDTO: Decodable, Identifiable, Equatable {
    let id: UUID?
    let rank: Int
    let name: String
    let icon: String
    let universityShort: String
    let focusMinutes: Int
    let memberCount: Int
    let capacity: Int
    let badges: [String]
    let colorHex: String
    let joinState: String
    let deltaRank: Int
    let isLive: Bool
}

struct ArenaWeeklyChallengeDTO: Decodable, Identifiable, Equatable {
    let id: UUID?
    let label: String
    let title: String
    let italicTitle: String
    let timeLeftText: String
    let participantText: String
    let rewardText: String
    let progress: Double
}
