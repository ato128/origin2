//
//  DailyCreditsManager.swift
//  DailyTodo
//
//  Gerçek kaynak: backend GET /v1/ai/usage. Kredi ve limit muhasebesi tamamen
//  sunucuda tutulur (402/429 zorlaması orada); bu sınıf yalnızca görüntülenen
//  durumu çeker ve gönderim sonrası iyimser günceller.
//
//  Ücretsiz model: ilk 3 gün içinde kullanılabilen TOPLAM 20 mesajlık havuz.
//  Havuz ya da süre bitince ücretsiz coach kapanır — Premium AI ya da
//  kullanıcının kendi OpenAI anahtarı (BYO) devralır.

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
    /// Ücretsiz havuzdan ömür boyu kullanılan coach mesajı sayısı.
    @Published var coachUsedTotal: Int = 0
    /// nil = sınırsız (Premium AI); değilse toplam ücretsiz havuz (20).
    @Published var coachTotalLimit: Int? = nil
    /// Ücretsiz pencerenin bittiği an (premium'da nil).
    @Published var freeTrialEndsAt: Date? = nil
    @Published var isLoaded: Bool = false

    private var lastFetch: Date?
    private let baseURL = "https://updo-chat-backend-production.up.railway.app/v1/ai"

    /// Ana sayfa kartı eski adıyla okuyor.
    var tokensRemaining: Int { creditsRemaining }

    /// Kullanıcı kendi OpenAI anahtarını eklediyse limitler bizi bağlamaz.
    var usesOwnKey: Bool { BYOKeyStore.shared.hasKey }

    /// Ücretsiz havuzdan kalan mesaj (premium'da nil = sınırsız).
    var messagesRemainingToday: Int? {
        guard let limit = coachTotalLimit else { return nil }
        return max(0, limit - coachUsedTotal)
    }

    private var trialWindowExpired: Bool {
        guard !isPro, let ends = freeTrialEndsAt else { return false }
        return ends < Date()
    }

    /// UX ön kontrolü — asıl zorlama backend'de. İlk yükleme gelmeden engelleme.
    var canSendChatMessage: Bool {
        if usesOwnKey { return true }
        guard isLoaded else { return true }
        if !isPro && trialWindowExpired { return false }
        if let left = messagesRemainingToday, left <= 0 { return false }
        if creditsRemaining <= 0 { return false }
        return true
    }

    /// Hangi limit dolduysa ona uygun mesaj.
    var limitMessage: String {
        if !isPro {
            if trialWindowExpired { return tr("ai_free_over") }
            if let left = messagesRemainingToday, left <= 0 { return tr("ai_free_over") }
        }
        return tr("ai_monthly_limit")
    }

    /// Günlük sıfırlama kalktı — havuz bitince geri sayım yok.
    var timeUntilReset: String? { nil }

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
            coachUsedTotal = summary.coachUsedTotal ?? 0
            coachTotalLimit = summary.coachTotalLimit
            freeTrialEndsAt = summary.freeTrialEndsAt.flatMap { Self.parseISO($0) }
            isLoaded = true
            lastFetch = Date()
        } catch {
            // Ağ hatasında son bilinen değerler kalır; backend zorlaması zaten devrede.
        }
    }

    /// Mesaj başarıyla gönderildiğinde iyimser düşüm + arka planda gerçek değer.
    /// BYO anahtar kullanılıyorsa hiçbir sayaç düşmez.
    func noteMessageSent() {
        guard !usesOwnKey else { return }
        coachUsedTotal += 1
        if creditsRemaining > 0 { creditsRemaining -= 1 }
        Task { await refresh() }
    }

    private static func parseISO(_ value: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: value)
    }

    private struct UsageSummary: Decodable {
        let isPremium: Bool
        let creditsTotal: Int
        let creditsUsed: Int
        let creditsRemaining: Int
        let coachUsedTotal: Int?
        let coachTotalLimit: Int?
        let freeTrialEndsAt: String?
    }
}
