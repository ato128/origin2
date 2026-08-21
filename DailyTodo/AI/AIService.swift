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

    /// Coach sohbeti + fonksiyon çağırma (tool-use). Metin VE opsiyonel bir tool
    /// döner. Tool gelirse istemci aksiyonu uygular + onayı yerelde üretir (2. LLM
    /// turu yok). Token'sız yorumlayıcı yakalayamazsa devreye giren "her şeyi anla"
    /// katmanı.
    func coachChat(
        system: String,
        messages: [[String: String]],
        maxTokens: Int = 300
    ) async throws -> (text: String, tool: AIToolCall?) {
        let body: [String: Any] = [
            "system": system,
            "messages": messages,
            "maxTokens": maxTokens
        ]
        let data = try await rawPost(feature: "coach", body: body)

        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIServiceError.invalidResponse
        }
        let text = (obj["text"] as? String) ?? ""

        var tool: AIToolCall? = nil
        if let t = obj["tool"] as? [String: Any],
           let name = t["name"] as? String, !name.isEmpty {
            tool = AIToolCall(name: name, args: (t["args"] as? [String: Any]) ?? [:])
        }
        return (text, tool)
    }

    // MARK: - Streaming coach (real token-by-token SSE)

    /// Streams the coach reply from `/ai/coach/stream`. Yields text deltas as they
    /// arrive, a single `.tool` if the model calls an action, and `.done` at the
    /// end. Non-200 responses (auth / quota / rate) are mapped to `AIServiceError`
    /// exactly like the non-streaming path, so callers can fall back.
    nonisolated func coachChatStream(
        system: String,
        messages: [[String: String]],
        maxTokens: Int = 300
    ) -> AsyncThrowingStream<CoachStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let token = try await self.authToken()
                    guard let url = URL(string: "\(self.baseURL)/coach/stream") else {
                        throw AIServiceError.invalidResponse
                    }

                    var req = URLRequest(url: url)
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    req.timeoutInterval = 60

                    var finalBody: [String: Any] = [
                        "system": system,
                        "messages": messages,
                        "maxTokens": maxTokens
                    ]
                    let isEN = await MainActor.run { appLanguageIsEnglish() }
                    finalBody["language"] = isEN ? "en" : "tr"
                    req.httpBody = try JSONSerialization.data(withJSONObject: finalBody)

                    let (bytes, response) = try await URLSession.shared.bytes(for: req)
                    guard let http = response as? HTTPURLResponse else {
                        throw AIServiceError.invalidResponse
                    }

                    if http.statusCode != 200 {
                        // Drain the small JSON error body and map it.
                        var data = Data()
                        for try await b in bytes { data.append(b) }
                        let code = (try? JSONDecoder().decode(BackendAIError.self, from: data))?.code
                        switch http.statusCode {
                        case 402:
                            if code == "daily_free_limit" { throw AIServiceError.dailyFreeLimitReached }
                            throw AIServiceError.insufficientCredits
                        case 429:
                            throw AIServiceError.rateLimited
                        default:
                            throw AIServiceError.httpError(http.statusCode)
                        }
                    }

                    for try await line in bytes.lines {
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        guard trimmed.hasPrefix("data:") else { continue }
                        let payload = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        if payload.isEmpty || payload == "[DONE]" { continue }
                        guard let d = payload.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                              let type = obj["type"] as? String else { continue }

                        switch type {
                        case "delta":
                            if let t = obj["text"] as? String, !t.isEmpty {
                                continuation.yield(.delta(t))
                            }
                        case "tool":
                            if let name = obj["name"] as? String, !name.isEmpty {
                                continuation.yield(.tool(AIToolCall(
                                    name: name,
                                    args: (obj["args"] as? [String: Any]) ?? [:]
                                )))
                            }
                        case "done":
                            continuation.yield(.done(creditsRemaining: obj["creditsRemaining"] as? Int))
                        case "error":
                            throw AIServiceError.apiError((obj["message"] as? String) ?? "AI error")
                        default:
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func postToBackend(feature: String, body: [String: Any]) async throws -> BackendAIResponse {
        let data = try await rawPost(feature: feature, body: body)
        return try JSONDecoder().decode(BackendAIResponse.self, from: data)
    }

    /// Ortak istek + hata (402/429/BYO) işleme. Ham `Data` döner; çağıran karar verir.
    private func rawPost(feature: String, body: [String: Any]) async throws -> Data {
        let token = try await authToken()
        guard let url = URL(string: "\(baseURL)/\(feature)") else {
            throw AIServiceError.invalidResponse
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 60

        // Uygulama dilini her AI isteğine ekle — backend LLM'i bu dile zorlar
        // (kullanıcı ne yazarsa yazsın). İngilizce app'te Türkçe cevap dönmesini önler.
        var finalBody = body
        let isEN = await MainActor.run { appLanguageIsEnglish() }
        finalBody["language"] = isEN ? "en" : "tr"
        req.httpBody = try JSONSerialization.data(withJSONObject: finalBody)

        // BYO: kullanıcının kendi OpenAI anahtarı varsa coach isteğiyle taşınır;
        // backend anahtarı saklamaz, sadece o çağrı için OpenAI'a yönlendirir.
        if feature == "coach", let userKey = await MainActor.run(body: { BYOKeyStore.shared.readKey() }) {
            req.setValue(userKey, forHTTPHeaderField: "x-user-openai-key")
        }

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        if http.statusCode == 400 {
            let code = (try? JSONDecoder().decode(BackendAIError.self, from: data))?.code
            if code == "byo_key_invalid" { throw AIServiceError.byoKeyInvalid }
            if code == "byo_no_credits" { throw AIServiceError.byoNoCredits }
        }

        if http.statusCode == 402 {
            let code = (try? JSONDecoder().decode(BackendAIError.self, from: data))?.code
            if code == "daily_free_limit" { throw AIServiceError.dailyFreeLimitReached }
            throw AIServiceError.insufficientCredits
        }

        if http.statusCode == 429 { throw AIServiceError.rateLimited }

        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw AIServiceError.apiError(msg)
        }

        return data
    }
}

// MARK: - Tool call (function calling)

struct AIToolCall {
    let name: String
    let args: [String: Any]
}

/// One event from the streaming coach endpoint.
enum CoachStreamEvent {
    case delta(String)                     // incremental text
    case tool(AIToolCall)                  // model called an action (no text stream)
    case done(creditsRemaining: Int?)      // stream finished
}

// MARK: - Response model

private struct BackendAIResponse: Decodable {
    let ok: Bool
    let text: String
    let wasCached: Bool
    let creditsUsed: Int
    let creditsRemaining: Int?
}

private struct BackendAIError: Decodable {
    let code: String?
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case insufficientCredits
    case dailyFreeLimitReached
    case byoKeyInvalid
    case byoNoCredits
    case invalidResponse
    case rateLimited
    case httpError(Int)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .insufficientCredits: return tr("ai_monthly_limit")
        case .dailyFreeLimitReached: return tr("ai_free_over")
        case .byoKeyInvalid:       return tr("ai_byo_invalid")
        case .byoNoCredits:        return tr("ai_byo_no_credits")
        case .invalidResponse:     return tr("ai_invalid_response")
        case .rateLimited:         return tr("ai_too_many")
        case .httpError(let c):    return "\(tr("ai_http_error")): \(c)"
        case .apiError(let m):     return "\(tr("ai_api_error")): \(m)"
        }
    }
}
