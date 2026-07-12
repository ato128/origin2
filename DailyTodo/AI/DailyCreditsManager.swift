//
//  DailyCreditsManager.swift
//  DailyTodo
//
//  Gerçek kaynak: backend GET /v1/ai/usage. Kredi ve limit muhasebesi tamamen
//  sunucuda tutulur (402/429 zorlaması orada); bu sınıf yalnızca görüntülenen
//  durumu çeker ve gönderim sonrası iyimser günceller.

import Foundation
import Combine
import SwiftUI
import Supabase

@MainActor
final class DailyCreditsManager: ObservableObject {
    static let shared = DailyCreditsManager()

    @Published var creditsRemaining: Int = 0
    @Published var creditsTotal: Int = 0
    /// Premium AI katmanı — backend, RevenueCat'ten sunucu tarafında doğrular.
    @Published var isPro: Bool = false
    @Published var coachUsedToday: Int = 0
    /// nil = günlük sınır yok (Premium AI)
    @Published var coachDailyLimit: Int? = nil
    @Published var isLoaded: Bool = false

    private var lastFetch: Date?
    private let baseURL = "https://updo-chat-backend-production.up.railway.app/v1/ai"

    /// Ana sayfa kartı eski adıyla okuyor.
    var tokensRemaining: Int { creditsRemaining }

    var messagesRemainingToday: Int? {
        guard let limit = coachDailyLimit else { return nil }
        return max(0, limit - coachUsedToday)
    }

    /// UX ön kontrolü — asıl zorlama backend'de. İlk yükleme gelmeden engelleme.
    var canSendChatMessage: Bool {
        guard isLoaded else { return true }
        if creditsRemaining <= 0 { return false }
        if let left = messagesRemainingToday, left <= 0 { return false }
        return true
    }

    /// Hangi limit dolduysa ona uygun mesaj.
    var limitMessage: String {
        if let left = messagesRemainingToday, left <= 0 { return tr("ai_daily_limit") }
        return tr("ai_monthly_limit")
    }

    /// Günlük hak dolduysa bir sonraki UTC gece yarısına kalan süre
    /// (backend günü UTC'ye göre sayar). Aylık limitte geri sayım yok.
    var timeUntilReset: String? {
        guard let left = messagesRemainingToday, left <= 0 else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        guard let midnight = cal.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else { return nil }
        let secs = Int(midnight.timeIntervalSince(Date()))
        let h = secs / 3600
        let m = (secs % 3600) / 60
        return h > 0 ? "\(h)sa \(m)dk" : "\(m) dk"
    }

    // MARK: - Fetch

    func refreshIfStale() async {
        if isLoaded, let last = lastFetch, Date().timeIntervalSince(last) < 60 { return }
        await refresh()
    }

    func refresh() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            guard let url = URL(string: "\(baseURL)/usage") else { return }

            var req = URLRequest(url: url)
            req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            req.timeoutInterval = 20

            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }

            let summary = try JSONDecoder().decode(UsageSummary.self, from: data)
            creditsRemaining = summary.creditsRemaining
            creditsTotal = summary.creditsTotal
            isPro = summary.isPremium
            coachUsedToday = summary.coachUsedToday ?? 0
            coachDailyLimit = summary.coachDailyLimit
            isLoaded = true
            lastFetch = Date()
        } catch {
            // Ağ hatasında son bilinen değerler kalır; backend zorlaması zaten devrede.
        }
    }

    /// Mesaj başarıyla gönderildiğinde iyimser düşüm + arka planda gerçek değer.
    func noteMessageSent() {
        coachUsedToday += 1
        if creditsRemaining > 0 { creditsRemaining -= 1 }
        Task { await refresh() }
    }

    private struct UsageSummary: Decodable {
        let isPremium: Bool
        let creditsTotal: Int
        let creditsUsed: Int
        let creditsRemaining: Int
        let coachUsedToday: Int?
        let coachDailyLimit: Int?
    }
}
