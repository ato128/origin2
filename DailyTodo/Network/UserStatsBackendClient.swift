//
//  UserStatsBackendClient.swift
//  DailyTodo
//
//  Syncs the unified social stats (level / streak / focus) to the backend so
//  friends & crew can see each other. Writes are scoped to the signed-in user;
//  batch reads only return users who left sharing enabled. Pro gating lives on
//  the client (callers simply don't fetch when the viewer isn't Pro).
//

import Foundation
import Supabase

struct UserStatsDTO: Decodable, Identifiable, Equatable {
    let userId: String
    let level: Int
    let currentStreak: Int
    let longestStreak: Int
    let totalFocusMinutes: Int
    let isFocusing: Bool
    let sharingEnabled: Bool

    var id: String { userId }
}

enum UserStatsBackendError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid user-stats URL"
        case .invalidResponse: return "Invalid user-stats response"
        case .apiError(let m): return m
        }
    }
}

final class UserStatsBackendClient {
    static let shared = UserStatsBackendClient()
    private init() {}

    private let baseURL = ChatBackendEnvironment.httpBaseURL

    private func accessToken() async throws -> String {
        let session = try await SupabaseManager.shared.client.auth.session
        return session.accessToken
    }

    private func makeRequest(path: String, method: String, body: Data?) async throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw UserStatsBackendError.invalidURL
        }

        let token = try await accessToken()
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        return request
    }

    // MARK: - Write my own stats

    func putMyStats(
        level: Int,
        currentStreak: Int,
        longestStreak: Int,
        totalFocusMinutes: Int,
        isFocusing: Bool?,
        focusUntil: Date?,
        sharingEnabled: Bool
    ) async {
        var payload: [String: Any] = [
            "level": level,
            "currentStreak": currentStreak,
            "longestStreak": longestStreak,
            "totalFocusMinutes": totalFocusMinutes,
            "sharingEnabled": sharingEnabled
        ]
        if let isFocusing { payload["isFocusing"] = isFocusing }
        if let focusUntil {
            payload["focusUntil"] = ISO8601DateFormatter().string(from: focusUntil)
        }

        do {
            let body = try JSONSerialization.data(withJSONObject: payload)
            let request = try await makeRequest(path: "/v1/user-stats", method: "PUT", body: body)
            _ = try? await URLSession.shared.data(for: request)
        } catch {
            Log.debug("🔴 putMyStats error:", error.localizedDescription)
        }
    }

    /// Lightweight focus-state update (currently focusing + until when it ends).
    func putFocusState(isFocusing: Bool, focusUntil: Date?) async {
        var payload: [String: Any] = ["isFocusing": isFocusing]
        if let focusUntil {
            payload["focusUntil"] = ISO8601DateFormatter().string(from: focusUntil)
        } else {
            payload["focusUntil"] = NSNull()
        }

        do {
            let body = try JSONSerialization.data(withJSONObject: payload)
            let request = try await makeRequest(path: "/v1/user-stats", method: "PUT", body: body)
            _ = try? await URLSession.shared.data(for: request)
        } catch {
            Log.debug("🔴 putFocusState error:", error.localizedDescription)
        }
    }

    // MARK: - Read friends'/crew stats

    func fetchStats(userIDs: [UUID]) async -> [UserStatsDTO] {
        guard !userIDs.isEmpty else { return [] }

        struct BatchResponse: Decodable {
            let ok: Bool?
            let stats: [UserStatsDTO]?
        }

        do {
            let payload: [String: Any] = ["user_ids": userIDs.map { $0.uuidString.lowercased() }]
            let body = try JSONSerialization.data(withJSONObject: payload)
            let request = try await makeRequest(path: "/v1/user-stats/batch", method: "POST", body: body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return []
            }

            let decoded = try JSONDecoder().decode(BatchResponse.self, from: data)
            return decoded.stats ?? []
        } catch {
            Log.debug("🔴 fetchStats error:", error.localizedDescription)
            return []
        }
    }
}
