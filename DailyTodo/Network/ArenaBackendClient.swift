//
//  ArenaBackendClient.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 29.05.2026.
//

import Foundation
import Supabase

enum ArenaBackendClientError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid arena backend URL"
        case .invalidResponse:
            return "Invalid arena backend response"
        case .apiError(let message):
            return message
        case .decodingFailed(let message):
            return "Arena decode failed: \(message)"
        }
    }
}

final class ArenaBackendClient {
    static let shared = ArenaBackendClient()

    private init() {}

    private let baseURL = ChatBackendEnvironment.httpBaseURL

    private var jsonDecoder: JSONDecoder {
        JSONDecoder()
    }

    private func accessToken() async throws -> String {
        let session = try await SupabaseManager.shared.client.auth.session
        return session.accessToken
    }

    private func makeURL(
        path: String,
        queryItems: [URLQueryItem] = []
    ) throws -> URL {
        guard var components = URLComponents(string: "\(baseURL)\(path)") else {
            throw ArenaBackendClientError.invalidURL
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw ArenaBackendClientError.invalidURL
        }

        return url
    }

    private func makeRequest(
        path: String,
        queryItems: [URLQueryItem] = [],
        timeout: TimeInterval = 20
    ) async throws -> URLRequest {
        let token = try await accessToken()
        let url = try makeURL(path: path, queryItems: queryItems)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        return request
    }

    private func perform<Response: Decodable>(
        _ request: URLRequest,
        responseType: Response.Type,
        debugName: String
    ) async throws -> Response {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ArenaBackendClientError.invalidResponse
        }

        #if DEBUG
        let responseText = String(data: data, encoding: .utf8) ?? ""
        print("✅ ARENA BACKEND \(debugName) STATUS:", http.statusCode)
        print("✅ ARENA BACKEND \(debugName) RESPONSE:", responseText)
        #endif

        do {
            let decoded = try jsonDecoder.decode(Response.self, from: data)

            if http.statusCode >= 200 && http.statusCode < 300 {
                return decoded
            }

            if let apiError = extractAPIError(from: data) {
                throw ArenaBackendClientError.apiError(apiError)
            }

            throw ArenaBackendClientError.apiError("Arena request failed with status \(http.statusCode)")
        } catch let error as ArenaBackendClientError {
            throw error
        } catch {
            throw ArenaBackendClientError.decodingFailed(error.localizedDescription)
        }
    }

    private func extractAPIError(from data: Data) -> String? {
        struct ErrorResponse: Decodable {
            let ok: Bool?
            let error: String?
        }

        return try? jsonDecoder.decode(ErrorResponse.self, from: data).error
    }

    // MARK: - API

    func fetchSummary(scope: ArenaBackendScope) async -> ArenaSummaryDTO? {
        do {
            let request = try await makeRequest(
                path: "/v1/arena/summary",
                queryItems: [
                    URLQueryItem(name: "scope", value: scope.rawValue)
                ],
                timeout: 20
            )

            let decoded = try await perform(
                request,
                responseType: ArenaSummaryResponse.self,
                debugName: "summary"
            )

            guard decoded.ok else {
                print("❌ ARENA summary API ERROR:", decoded.error ?? "unknown")
                return nil
            }

            return decoded.summary
        } catch {
            print("❌ ARENA summary ERROR:", error.localizedDescription)
            return nil
        }
    }

    func fetchLeaderboard(
        scope: ArenaBackendScope,
        range: ArenaBackendRange
    ) async -> [ArenaLeaderboardEntryDTO] {
        do {
            let request = try await makeRequest(
                path: "/v1/arena/leaderboard",
                queryItems: [
                    URLQueryItem(name: "scope", value: scope.rawValue),
                    URLQueryItem(name: "range", value: range.rawValue)
                ],
                timeout: 20
            )

            let decoded = try await perform(
                request,
                responseType: ArenaLeaderboardResponse.self,
                debugName: "leaderboard"
            )

            guard decoded.ok else {
                print("❌ ARENA leaderboard API ERROR:", decoded.error ?? "unknown")
                return []
            }

            return decoded.entries ?? []
        } catch {
            print("❌ ARENA leaderboard ERROR:", error.localizedDescription)
            return []
        }
    }

    func fetchTopCrews(
        scope: ArenaBackendScope,
        range: ArenaBackendRange
    ) async -> [ArenaCrewEntryDTO] {
        do {
            let request = try await makeRequest(
                path: "/v1/arena/top-crews",
                queryItems: [
                    URLQueryItem(name: "scope", value: scope.rawValue),
                    URLQueryItem(name: "range", value: range.rawValue)
                ],
                timeout: 20
            )

            let decoded = try await perform(
                request,
                responseType: ArenaTopCrewsResponse.self,
                debugName: "topCrews"
            )

            guard decoded.ok else {
                print("❌ ARENA topCrews API ERROR:", decoded.error ?? "unknown")
                return []
            }

            return decoded.crews ?? []
        } catch {
            print("❌ ARENA topCrews ERROR:", error.localizedDescription)
            return []
        }
    }

    func fetchWeeklyChallenge() async -> ArenaWeeklyChallengeDTO? {
        do {
            let request = try await makeRequest(
                path: "/v1/arena/weekly-challenge",
                timeout: 20
            )

            let decoded = try await perform(
                request,
                responseType: ArenaWeeklyChallengeResponse.self,
                debugName: "weeklyChallenge"
            )

            guard decoded.ok else {
                print("❌ ARENA weeklyChallenge API ERROR:", decoded.error ?? "unknown")
                return nil
            }

            return decoded.challenge
        } catch {
            print("❌ ARENA weeklyChallenge ERROR:", error.localizedDescription)
            return nil
        }
    }
}
