//
//  CreditManager.swift
//  DailyTodo
//

import Foundation
import Combine
import Supabase

// MARK: - CreditManager

final class CreditManager: ObservableObject {

    @Published var credits: Int = 10
    @Published var isPro: Bool = false
    @Published var isLoading: Bool = false

    init() { loadLocal() }

    // MARK: - Rate limit checks

    private var lastSentAt: Date? {
        get { UserDefaults.standard.object(forKey: "cm_last_sent") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "cm_last_sent") }
    }

    private var weeklyCount: Int {
        get { UserDefaults.standard.integer(forKey: "cm_weekly_\(currentWeekKey)") }
        set { UserDefaults.standard.set(newValue, forKey: "cm_weekly_\(currentWeekKey)") }
    }

    private var dailyCount: Int {
        get { UserDefaults.standard.integer(forKey: "cm_daily_\(currentDayKey)") }
        set { UserDefaults.standard.set(newValue, forKey: "cm_daily_\(currentDayKey)") }
    }

    var cooldownRemaining: TimeInterval {
        guard let last = lastSentAt else { return 0 }
        return max(0, 120 - Date().timeIntervalSince(last))
    }

    var sendBlockReason: String? {
        if credits <= 0 { return "credits_empty" }
        if cooldownRemaining > 0 { return "cooldown" }
        if isPro && dailyCount >= 3 { return "daily_limit" }
        if !isPro && weeklyCount >= 5 { return "weekly_limit" }
        return nil
    }

    var canSend: Bool { sendBlockReason == nil }

    var blockMessage: String? {
        switch sendBlockReason {
        case "credits_empty":   return "Krediniz bitti."
        case "cooldown":
            let secs = Int(cooldownRemaining)
            return "\(secs) saniye bekleyin."
        case "daily_limit":     return tr("cm_daily_limit")
        case "weekly_limit":    return tr("cm_weekly_limit")
        default:                return nil
        }
    }

    // MARK: - Record send

    func recordSend(wasCached: Bool) {
        lastSentAt = .now
        if !wasCached {
            credits = max(0, credits - 1)
            if isPro { dailyCount += 1 } else { weeklyCount += 1 }
        }
        saveLocal()
    }

    // MARK: - Supabase sync

    func loadCredits(userID: String) async {
        await MainActor.run { isLoading = true }
        do {
            let response = try await SupabaseManager.shared.client
                .from("profiles")
                .select("ai_credits, is_pro")
                .eq("id", value: userID)
                .single()
                .execute()
            if let row = try? JSONDecoder().decode(CreditsRow.self, from: response.data) {
                await MainActor.run {
                    credits = row.ai_credits ?? credits
                    isPro = row.is_pro ?? isPro
                    saveLocal()
                }
            }
        } catch { /* graceful fallback to local */ }
        await MainActor.run { isLoading = false }
    }

    func syncUsage(userID: String, feature: String, messageHash: String, wasCached: Bool) async {
        let log = AIUsageLog(
            user_id: userID,
            feature: feature,
            message_hash: messageHash,
            was_cached: wasCached,
            credits_used: wasCached ? 0 : 1,
            timestamp: Date()
        )
        let currentCredits = credits
        do {
            try await SupabaseManager.shared.client
                .from("ai_usage_logs")
                .insert(log)
                .execute()
            if !wasCached {
                try await SupabaseManager.shared.client
                    .from("profiles")
                    .update(["ai_credits": currentCredits])
                    .eq("id", value: userID)
                    .execute()
            }
        } catch { /* graceful fallback */ }
    }

    // MARK: - Local persistence

    private func saveLocal() {
        UserDefaults.standard.set(credits, forKey: "cm_credits")
        UserDefaults.standard.set(isPro, forKey: "cm_is_pro")
    }

    private func loadLocal() {
        let saved = UserDefaults.standard.integer(forKey: "cm_credits")
        credits = saved > 0 ? saved : 10
        isPro = UserDefaults.standard.bool(forKey: "cm_is_pro")
    }

    private var currentWeekKey: String {
        let c = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        return "\(c.yearForWeekOfYear ?? 0)-W\(c.weekOfYear ?? 0)"
    }

    private var currentDayKey: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: .now)
    }
}

// MARK: - Private models

private struct CreditsRow: Decodable {
    let ai_credits: Int?
    let is_pro: Bool?
}

private struct AIUsageLog: Encodable {
    let user_id: String
    let feature: String
    let message_hash: String
    let was_cached: Bool
    let credits_used: Int
    let timestamp: Date
}
