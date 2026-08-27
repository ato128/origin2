//
//  FriendBackendClient.swift
//  DailyTodo
//
//  Friend graph now lives on OUR backend (Railway Postgres `friend_edges`), not
//  Supabase. This client talks to /v1/friends/* — the single source of truth for
//  friendships + requests. Live delivery (request/accept/remove) arrives over the
//  persistent inbox WebSocket, so this REST client only handles reads + mutations.
//

import Foundation
import Supabase

@MainActor
final class FriendBackendClient {
    static let shared = FriendBackendClient()

    private init() {}

    private let baseURL = ChatBackendEnvironment.httpBaseURL

    // MARK: - Responses

    struct ListResponse: Decodable {
        let ok: Bool
        let friendships: [FriendshipDTO]
        let profiles: [FriendProfileDTO]
    }

    private struct EdgeResponse: Decodable {
        let ok: Bool
        let edge: FriendshipDTO?
        let autoAccepted: Bool?
        let error: String?
    }

    private struct OkResponse: Decodable {
        let ok: Bool
        let error: String?
    }

    private struct FriendAPIErrorBody: Decodable {
        let error: String?
    }

    enum FriendBackendError: LocalizedError {
        case invalidURL
        case invalidResponse
        case api(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL"
            case .invalidResponse: return "Invalid response"
            case .api(let message): return message
            }
        }
    }

    // MARK: - Request builder

    private func accessToken() async throws -> String {
        let session = try await SupabaseManager.shared.client.auth.session
        return session.accessToken
    }

    private func makeRequest(
        path: String,
        method: String,
        body: [String: Any]? = nil,
        timeout: TimeInterval = 15
    ) async throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw FriendBackendError.invalidURL
        }

        let token = try await accessToken()

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        return request
    }

    private func perform<Response: Decodable>(
        _ request: URLRequest,
        as responseType: Response.Type
    ) async throws -> Response {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw FriendBackendError.invalidResponse
        }

        if http.statusCode < 200 || http.statusCode >= 300 {
            let message = (try? JSONDecoder().decode(FriendAPIErrorBody.self, from: data))?.error
            throw FriendBackendError.api(message ?? "Backend request failed (\(http.statusCode))")
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }

    // MARK: - Endpoints

    func listFriends() async throws -> (friendships: [FriendshipDTO], profiles: [FriendProfileDTO]) {
        let request = try await makeRequest(path: "/v1/friends", method: "GET")
        let response = try await perform(request, as: ListResponse.self)
        return (response.friendships, response.profiles)
    }

    @discardableResult
    func sendRequest(toUserID: UUID?, username: String?) async throws -> FriendshipDTO? {
        var body: [String: Any] = [:]
        if let toUserID { body["toUserID"] = toUserID.uuidString }
        if let username, !username.isEmpty { body["username"] = username }

        let request = try await makeRequest(path: "/v1/friends/request", method: "POST", body: body)
        let response = try await perform(request, as: EdgeResponse.self)

        if !response.ok, let error = response.error {
            throw FriendBackendError.api(error)
        }
        return response.edge
    }

    @discardableResult
    func accept(edgeID: UUID) async throws -> FriendshipDTO? {
        let request = try await makeRequest(
            path: "/v1/friends/accept",
            method: "POST",
            body: ["edgeID": edgeID.uuidString]
        )
        let response = try await perform(request, as: EdgeResponse.self)
        if !response.ok, let error = response.error {
            throw FriendBackendError.api(error)
        }
        return response.edge
    }

    func decline(edgeID: UUID) async throws {
        let request = try await makeRequest(
            path: "/v1/friends/decline",
            method: "POST",
            body: ["edgeID": edgeID.uuidString]
        )
        _ = try await perform(request, as: OkResponse.self)
    }

    func remove(edgeID: UUID) async throws {
        let request = try await makeRequest(
            path: "/v1/friends/remove",
            method: "POST",
            body: ["edgeID": edgeID.uuidString]
        )
        _ = try await perform(request, as: OkResponse.self)
    }

    func setState(
        edgeID: UUID,
        isPinned: Bool? = nil,
        isMuted: Bool? = nil,
        isArchived: Bool? = nil
    ) async throws {
        var body: [String: Any] = [:]
        if let isPinned { body["isPinned"] = isPinned }
        if let isMuted { body["isMuted"] = isMuted }
        if let isArchived { body["isArchived"] = isArchived }

        let request = try await makeRequest(
            path: "/v1/friends/\(edgeID.uuidString)/state",
            method: "POST",
            body: body
        )
        _ = try await perform(request, as: OkResponse.self)
    }

    func markRead(edgeID: UUID) async throws {
        let request = try await makeRequest(
            path: "/v1/friends/\(edgeID.uuidString)/read",
            method: "POST"
        )
        _ = try await perform(request, as: OkResponse.self)
    }
}
