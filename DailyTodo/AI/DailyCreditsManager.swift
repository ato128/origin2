//
//  DailyCreditsManager.swift
//  DailyTodo
//

import Foundation
import Combine
import SwiftUI
import Supabase

// Token costs per feature
enum AITokenCost {
    static let chatMessage = 10
    static let smartInsights = 30
    static let examPlanner = 50
    static let freeAction = 0  // week edit, add task, focus history
}

@MainActor
final class DailyCreditsManager: ObservableObject {
    static let shared = DailyCreditsManager()

    @Published var tokensRemaining: Int = 100
    @Published var todayBudget: Int = 100
    @Published var isPro: Bool = false
    @Published var isLoaded: Bool = false

    private let defaultsKey = "updo_daily_token_v1"
    private let baseBudgetFree = 500
    private let baseBudgetPro = 15000
    private let maxRolloverBonus = 30000  // pro: 3-day rollover max = 15000 × 3 = 45000

    // MARK: - Load

    func load(isPro: Bool, userID: String) {
        self.isPro = isPro
        let saved = loadSaved()
        let today = Calendar.current.startOfDay(for: Date())

        if let saved, Calendar.current.isDate(saved.date, inSameDayAs: today) {
            todayBudget = saved.budget
            tokensRemaining = max(0, saved.budget - saved.used)
        } else {
            let base = isPro ? baseBudgetPro : baseBudgetFree
            var newBudget = base

            if isPro, let saved {
                let remaining = max(0, saved.budget - saved.used)
                let rollover = min(remaining, maxRolloverBonus)
                newBudget = min(base + rollover, base + maxRolloverBonus)
            }

            todayBudget = newBudget
            tokensRemaining = newBudget
            persist(budget: newBudget, used: 0)
        }

        isLoaded = true
        Task { await syncToSupabase(userID: userID) }
    }

    // MARK: - Spend

    func canAfford(_ cost: Int) -> Bool {
        tokensRemaining >= cost
    }

    @discardableResult
    func spend(_ cost: Int, userID: String) -> Bool {
        guard cost > 0 else { return true }
        guard tokensRemaining >= cost else { return false }
        tokensRemaining -= cost
        let used = todayBudget - tokensRemaining
        persist(budget: todayBudget, used: used)
        Task { await syncToSupabase(userID: userID) }
        return true
    }

    // MARK: - Reset countdown

    var timeUntilReset: String? {
        guard tokensRemaining <= 0 else { return nil }
        guard let midnight = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else { return nil }
        let secs = Int(midnight.timeIntervalSince(Date()))
        let h = secs / 3600
        let m = (secs % 3600) / 60
        return h > 0 ? "\(h)sa \(m)dk" : "\(m) dk"
    }

    // MARK: - Persistence

    private struct DailyUsage: Codable {
        let date: Date
        let budget: Int
        let used: Int
    }

    private func loadSaved() -> DailyUsage? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let saved = try? JSONDecoder().decode(DailyUsage.self, from: data) else { return nil }
        return saved
    }

    private func persist(budget: Int, used: Int) {
        let usage = DailyUsage(date: Calendar.current.startOfDay(for: Date()), budget: budget, used: used)
        if let data = try? JSONEncoder().encode(usage) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    // MARK: - Supabase sync (fire-and-forget analytics)

    private func syncToSupabase(userID: String) async {
        let used = todayBudget - tokensRemaining
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: Date())

        _ = try? await SupabaseManager.shared.client
            .from("daily_token_usage")
            .upsert([
                "user_id": userID,
                "date": dateStr,
                "tokens_used": String(used),
                "tokens_budget": String(todayBudget)
            ], onConflict: "user_id,date")
            .execute()
    }
}
