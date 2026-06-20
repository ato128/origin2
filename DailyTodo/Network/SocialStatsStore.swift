//
//  SocialStatsStore.swift
//  DailyTodo
//
//  In-memory cache of friends'/crew members' shared stats. Only fetches when
//  the viewer is Pro (client-side gating); the backend additionally filters out
//  users who turned sharing off.
//

import Foundation
import Combine

@MainActor
final class SocialStatsStore: ObservableObject {
    static let shared = SocialStatsStore()
    private init() {}

    @Published private(set) var stats: [UUID: UserStatsDTO] = [:]

    private var lastRefresh: Date?
    private var inFlight = false

    func stat(for userID: UUID?) -> UserStatsDTO? {
        guard let userID else { return nil }
        return stats[userID]
    }

    func refresh(userIDs: [UUID], isPro: Bool, force: Bool = false) {
        guard isPro else { return }

        let ids = Array(Set(userIDs))
        guard !ids.isEmpty else { return }

        if !force, let last = lastRefresh, Date().timeIntervalSince(last) < 30 { return }
        guard !inFlight else { return }

        inFlight = true
        lastRefresh = Date()

        Task {
            let fetched = await UserStatsBackendClient.shared.fetchStats(userIDs: ids)
            var map = stats
            for dto in fetched {
                if let uid = UUID(uuidString: dto.userId) {
                    map[uid] = dto
                }
            }
            stats = map
            inFlight = false
        }
    }
}
