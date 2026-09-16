//
//  ReferralBackendClient.swift
//  DailyTodo
//
//  Talks to /v1/referral — the referral programme (Model B): a newly-installed
//  user (account ≤ 14 days) who becomes your friend earns you a credit; 3 credits
//  → 1 month free Updo Premium (granted server-side via RevenueCat). No codes to
//  capture — this client only reads the current user's progress + share link.
//

import Foundation
import Supabase

@MainActor
final class ReferralBackendClient {
    static let shared = ReferralBackendClient()
    private init() {}

    private let baseURL = ChatBackendEnvironment.httpBaseURL

    struct Status: Decodable {
        let qualified: Int      // how many new-install friends brought (0…needed)
        let needed: Int         // 3
        let rewardGranted: Bool // the free month has been granted
        let link: String        // shareable download link
    }

    private func accessToken() async throws -> String {
        let session = try await SupabaseManager.shared.client.auth.session
        return session.accessToken
    }

    func status() async throws -> Status {
        guard let url = URL(string: "\(baseURL)/v1/referral") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Status.self, from: data)
    }
}
