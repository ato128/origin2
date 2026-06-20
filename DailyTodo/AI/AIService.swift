//
//  AIService.swift
//  DailyTodo
//

import Foundation
import Supabase

actor AIService {
    static let shared = AIService()

    private let baseURL = "https://updo-chat-backend-production.up.railway.app/v1/ai"

    // MARK: - Non-streaming (returns full response text)

    func complete(
        system: String,
        user: String,
        maxTokens: Int = 2048,
        feature: String = "insights"
    ) async throws -> String {
        let body: [String: Any] = [
            "system": system,
            "messages": [["role": "user", "content": user]],
            "maxTokens": maxTokens
        ]
        let response = try await postToBackend(feature: feature, body: body)
        return response.text
    }

    // MARK: - Multi-turn (full conversation history, non-streaming)

    func chat(
        system: String,
        messages: [[String: String]],
        maxTokens: Int = 1024,
        feature: String = "insights"
    ) async throws -> String {
        let body: [String: Any] = [
            "system": system,
            "messages": messages,
            "maxTokens": maxTokens
        ]
        let response = try await postToBackend(feature: feature, body: body)
        return response.text
    }

    // MARK: - Streaming single-turn (yields full response as one chunk via backend)

    func stream(
        system: String,
        user: String,
        maxTokens: Int = 2048
    ) -> AsyncThrowingStream<String, Error> {
        streamMessages(system: system, messages: [["role": "user", "content": user]], maxTokens: maxTokens)
    }

    // MARK: - Streaming multi-turn (coach — backend returns full text, yielded as one chunk)

    func streamMessages(
        system: String,
        messages: [[String: String]],
        maxTokens: Int = 1024
    ) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let body: [String: Any] = [
                        "system": system,
                        "messages": messages,
                        "maxTokens": maxTokens
                    ]
                    let response = try await postToBackend(feature: "coach", body: body)
                    continuation.yield(response.text)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private helpers

    private func authToken() async throws -> String {
        let session = try await SupabaseManager.shared.client.auth.session
        return session.accessToken
    }

    private func postToBackend(feature: String, body: [String: Any]) async throws -> BackendAIResponse {
        let token = try await authToken()
        guard let url = URL(string: "\(baseURL)/\(feature)") else {
            throw AIServiceError.invalidResponse
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 60
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        if http.statusCode == 402 {
            throw AIServiceError.insufficientCredits
        }

        if http.statusCode == 429 {
            throw AIServiceError.rateLimited
        }

        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw AIServiceError.apiError(msg)
        }

        return try JSONDecoder().decode(BackendAIResponse.self, from: data)
    }
}

// MARK: - Response model

private struct BackendAIResponse: Decodable {
    let ok: Bool
    let text: String
    let wasCached: Bool
    let creditsUsed: Int
    let creditsRemaining: Int?
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case insufficientCredits
    case invalidResponse
    case rateLimited
    case httpError(Int)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .insufficientCredits: return "Yeterli krediniz yok."
        case .invalidResponse:     return tr("ai_invalid_response")
        case .rateLimited:         return tr("ai_too_many")
        case .httpError(let c):    return "\(tr("ai_http_error")): \(c)"
        case .apiError(let m):     return "\(tr("ai_api_error")): \(m)"
        }
    }
}
