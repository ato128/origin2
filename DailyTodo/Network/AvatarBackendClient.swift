//
//  AvatarBackendClient.swift
//  DailyTodo
//
//  Profile photo sync against our own backend (Railway):
//    PUT    /v1/avatar          — upload my avatar (base64 JPEG)
//    GET    /v1/avatar/:userID  — raw image bytes (404 = none)
//    DELETE /v1/avatar          — remove my avatar
//

import Foundation
import Supabase

final class AvatarBackendClient {
    static let shared = AvatarBackendClient()

    private init() {}

    private let baseURL = ChatBackendEnvironment.httpBaseURL

    private func accessToken() async throws -> String {
        let session = try await SupabaseManager.shared.client.auth.session
        return session.accessToken
    }

    private func makeRequest(
        path: String,
        method: String,
        timeout: TimeInterval = 25
    ) async throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw URLError(.badURL)
        }

        let token = try await accessToken()

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    /// Uploads the avatar; returns true on success.
    @discardableResult
    func upload(jpegData: Data) async -> Bool {
        do {
            var request = try await makeRequest(path: "/v1/avatar", method: "PUT")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: String] = [
                "image_base64": jpegData.base64EncodedString(),
                "content_type": "image/jpeg"
            ]
            request.httpBody = try JSONEncoder().encode(body)

            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0

            Log.debug("AVATAR UPLOAD STATUS:", status)
            return (200..<300).contains(status)
        } catch {
            Log.debug("AVATAR UPLOAD ERROR:", error.localizedDescription)
            return false
        }
    }

    /// Fetches a user's avatar bytes; nil when none exists (404) or on error.
    func fetch(userID: String) async -> Data? {
        do {
            let request = try await makeRequest(path: "/v1/avatar/\(userID)", method: "GET")
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  !data.isEmpty
            else { return nil }

            return data
        } catch {
            Log.debug("AVATAR FETCH ERROR:", error.localizedDescription)
            return nil
        }
    }

    @discardableResult
    func remove() async -> Bool {
        do {
            let request = try await makeRequest(path: "/v1/avatar", method: "DELETE")
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            return (200..<300).contains(status)
        } catch {
            Log.debug("AVATAR DELETE ERROR:", error.localizedDescription)
            return false
        }
    }
}
