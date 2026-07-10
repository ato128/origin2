//
//  FriendFocusBackendClient.swift
//  DailyTodo
//
//  1-on-1 friend focus sessions on our own backend:
//    POST /v1/friend-focus                  — host starts (invite is pushed)
//    POST /v1/friend-focus/:id/join         — invited friend joins
//    POST /v1/friend-focus/:id/decline
//    POST /v1/friend-focus/:id/end          — host ends / friend leaves
//    GET  /v1/friend-focus/:id              — state
//

import Foundation
import Supabase

struct FriendFocusSessionDTO: Decodable, Identifiable {
    let id: UUID
    let host_id: UUID
    let host_name: String
    let friend_id: UUID
    let friend_name: String
    let goal: String
    let duration_minutes: Int
    let started_at: String
    let friend_status: String
    let is_active: Bool
    let ended_at: String?

    var startedAtDate: Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: started_at) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: started_at)
    }
}

final class FriendFocusBackendClient {
    static let shared = FriendFocusBackendClient()

    private init() {}

    private let baseURL = ChatBackendEnvironment.httpBaseURL

    private struct SessionResponse: Decodable {
        let ok: Bool
        let session: FriendFocusSessionDTO?
        let error: String?
    }

    private func makeRequest(path: String, method: String) async throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else { throw URLError(.badURL) }

        let token = try await SupabaseManager.shared.client.auth.session.accessToken

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    func create(
        friendID: UUID,
        friendName: String,
        hostName: String,
        goal: String,
        durationMinutes: Int
    ) async -> FriendFocusSessionDTO? {
        do {
            var request = try await makeRequest(path: "/v1/friend-focus", method: "POST")

            let body: [String: Any] = [
                "friend_id": friendID.uuidString,
                "friend_name": friendName,
                "host_name": hostName,
                "goal": goal,
                "duration_minutes": durationMinutes
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(SessionResponse.self, from: data)

            Log.debug("FRIEND FOCUS CREATE:", decoded.ok, decoded.session?.id.uuidString ?? "-")
            return decoded.ok ? decoded.session : nil
        } catch {
            Log.debug("FRIEND FOCUS CREATE ERROR:", error.localizedDescription)
            return nil
        }
    }

    func join(sessionID: UUID) async -> FriendFocusSessionDTO? {
        do {
            let request = try await makeRequest(
                path: "/v1/friend-focus/\(sessionID.uuidString)/join",
                method: "POST"
            )
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(SessionResponse.self, from: data)
            return decoded.ok ? decoded.session : nil
        } catch {
            Log.debug("FRIEND FOCUS JOIN ERROR:", error.localizedDescription)
            return nil
        }
    }

    func decline(sessionID: UUID) async {
        do {
            let request = try await makeRequest(
                path: "/v1/friend-focus/\(sessionID.uuidString)/decline",
                method: "POST"
            )
            _ = try await URLSession.shared.data(for: request)
        } catch {
            Log.debug("FRIEND FOCUS DECLINE ERROR:", error.localizedDescription)
        }
    }

    func end(sessionID: UUID) async {
        do {
            let request = try await makeRequest(
                path: "/v1/friend-focus/\(sessionID.uuidString)/end",
                method: "POST"
            )
            _ = try await URLSession.shared.data(for: request)
        } catch {
            Log.debug("FRIEND FOCUS END ERROR:", error.localizedDescription)
        }
    }

    func fetch(sessionID: UUID) async -> FriendFocusSessionDTO? {
        do {
            let request = try await makeRequest(
                path: "/v1/friend-focus/\(sessionID.uuidString)",
                method: "GET"
            )
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoded = try JSONDecoder().decode(SessionResponse.self, from: data)
            return decoded.ok ? decoded.session : nil
        } catch {
            Log.debug("FRIEND FOCUS FETCH ERROR:", error.localizedDescription)
            return nil
        }
    }
}
