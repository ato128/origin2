//
//  ChatBackendClient.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 6.05.2026.
//

import Foundation
import Supabase
import Auth
import UIKit

// MARK: - Backend Environment

enum ChatBackendEnvironment {
    static var httpBaseURL: String {
        return "https://updo-chat-backend-production.up.railway.app"
    }

    static var websocketBaseURL: String {
        return "wss://updo-chat-backend-production.up.railway.app"
    }

    static var apnsEnvironment: String {
        // NOT: Bu artık PushTokenStore'da runtime'da tespit edildiği için
        // burası fallback olarak kullanılıyor. Doğru değer PushTokenStore.detectAPNsEnvironment()
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }
}

// MARK: - Device ID

enum ChatBackendDeviceIDProvider {
    static var deviceID: String {
        let key = "updo_chat_backend_device_id"

        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }

        let newID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(newID, forKey: key)
        return newID
    }
}

// MARK: - Debug Logger

enum ChatBackendLogger {
    static func log(_ items: Any...) {
        #if DEBUG
        print(items.map { "\($0)" }.joined(separator: " "))
        #endif
    }

    static func error(_ items: Any...) {
        #if DEBUG
        print(items.map { "\($0)" }.joined(separator: " "))
        #endif
    }
}

// MARK: - Date Parser

enum ChatBackendDateParser {
    static func parse(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }

        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        if let date = withFractional.date(from: value) {
            return date
        }

        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]

        return fallback.date(from: value)
    }
}

// MARK: - DTOs

struct ChatBackendMessageDTO: Decodable, Identifiable, Equatable {
    let id: UUID
    let conversationID: UUID
    let senderID: UUID
    let clientID: String
    let text: String?
    let messageType: String
    let mediaURL: String?
    let fileName: String?
    let fileSizeBytes: Int?
    let mimeType: String?
    let deliveredAt: String?
    let seenAt: String?
    let createdAt: String
    let editedAt: String?
    let deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case conversationID
        case senderID
        case clientID
        case text
        case messageType
        case mediaURL
        case fileName
        case fileSizeBytes
        case mimeType
        case deliveredAt
        case seenAt
        case createdAt
        case editedAt
        case deletedAt
    }

    init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            id = try container.decode(UUID.self, forKey: .id)
            conversationID = try container.decode(UUID.self, forKey: .conversationID)
            senderID = try container.decode(UUID.self, forKey: .senderID)
            clientID = try container.decode(String.self, forKey: .clientID)

            text = try container.decodeIfPresent(String.self, forKey: .text)
            messageType = try container.decode(String.self, forKey: .messageType)
            mediaURL = try container.decodeIfPresent(String.self, forKey: .mediaURL)
            fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
            mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)

            deliveredAt = try container.decodeIfPresent(String.self, forKey: .deliveredAt)
            seenAt = try container.decodeIfPresent(String.self, forKey: .seenAt)

            createdAt = try container.decode(String.self, forKey: .createdAt)
            editedAt = try container.decodeIfPresent(String.self, forKey: .editedAt)
            deletedAt = try container.decodeIfPresent(String.self, forKey: .deletedAt)

            if let intValue = try? container.decodeIfPresent(Int.self, forKey: .fileSizeBytes) {
                fileSizeBytes = intValue
            } else if let stringValue = try? container.decodeIfPresent(String.self, forKey: .fileSizeBytes),
                      let intValue = Int(stringValue) {
                fileSizeBytes = intValue
            } else {
                fileSizeBytes = nil
            }
        }

    var createdDate: Date? {
        ChatBackendDateParser.parse(createdAt)
    }

    var editedDate: Date? {
        ChatBackendDateParser.parse(editedAt)
    }

    var deletedDate: Date? {
        ChatBackendDateParser.parse(deletedAt)
    }
}

struct ChatBackendSendMessageResponse: Decodable {
    let ok: Bool
    let message: ChatBackendMessageDTO?
    let error: String?
}

struct ChatBackendFetchMessagesResponse: Decodable {
    let ok: Bool
    let messages: [ChatBackendMessageDTO]?
    let error: String?
}

struct ChatBackendConversationDTO: Decodable, Identifiable, Equatable {
    let id: UUID
    let type: String
    let supabaseFriendshipId: UUID?
    let supabaseCrewId: UUID?
    let title: String?
    let lastMessageText: String?
    let lastMessageAt: String?
    let unreadCount: Int
    let isMuted: Bool
    let isArchived: Bool
    let isPinned: Bool
    let updatedAt: String?

    var lastMessageDate: Date? {
        ChatBackendDateParser.parse(lastMessageAt)
    }

    var updatedDate: Date? {
        ChatBackendDateParser.parse(updatedAt)
    }
}

struct ChatBackendSyncFriendshipResponse: Decodable {
    let ok: Bool
    let conversation: ChatBackendConversationDTO?
    let error: String?
}

struct ChatBackendSyncCrewResponse: Decodable {
    let ok: Bool
    let conversation: ChatBackendConversationDTO?
    let error: String?
}

struct ChatBackendMarkReadResponse: Decodable {
    let ok: Bool
    let read: ChatBackendReadDTO?
    let error: String?
}

struct ChatBackendReadDTO: Decodable {
    let conversationID: UUID?
    let readerID: UUID?
    let seenCount: Int?
    let messages: [ChatBackendSeenMessageDTO]?
}

struct ChatBackendListConversationsResponse: Decodable {
    let ok: Bool
    let conversations: [ChatBackendConversationDTO]?
    let error: String?
}

struct ChatBackendMemberStateDTO: Decodable, Equatable {
    let conversationID: UUID
    let userID: UUID
    let unreadCount: Int
    let isMuted: Bool
    let isArchived: Bool
    let isPinned: Bool
    let updatedAt: String?

    var updatedDate: Date? {
        ChatBackendDateParser.parse(updatedAt)
    }
}

struct ChatBackendUpdateMemberStateResponse: Decodable {
    let ok: Bool
    let state: ChatBackendMemberStateDTO?
    let error: String?
}

struct ChatBackendSavePushTokenResponse: Decodable {
    let ok: Bool
    let token: ChatBackendSavedPushTokenDTO?
    let error: String?
}

struct ChatBackendSavedPushTokenDTO: Decodable, Equatable {
    let id: UUID
    let userID: UUID
    let environment: String
    let platform: String
    let deviceID: String
    let bundleID: String?
    let appVersion: String?
    let isActive: Bool
    let updatedAt: String?

    var updatedDate: Date? {
        ChatBackendDateParser.parse(updatedAt)
    }
}

// MARK: - Backend Error

enum ChatBackendClientError: LocalizedError {
    case invalidURL
    case missingAccessToken
    case apiError(String)
    case invalidResponse
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid backend URL"
        case .missingAccessToken:
            return "Missing access token"
        case .apiError(let message):
            return message
        case .invalidResponse:
            return "Invalid backend response"
        case .decodingFailed(let message):
            return "Decode failed: \(message)"
        }
    }
}

// MARK: - Client

final class ChatBackendClient {
    static let shared = ChatBackendClient()

    private init() {}

    private let baseURL = ChatBackendEnvironment.httpBaseURL

    private var jsonDecoder: JSONDecoder {
        JSONDecoder()
    }

    private func accessToken() async throws -> String {
        let session = try await SupabaseManager.shared.client.auth.session
        return session.accessToken
    }

    private func makeURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(string: "\(baseURL)\(path)") else {
            throw ChatBackendClientError.invalidURL
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw ChatBackendClientError.invalidURL
        }

        return url
    }

    private func makeRequest(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Any? = nil,
        timeout: TimeInterval = 15
    ) async throws -> URLRequest {
        let token = try await accessToken()
        let url = try makeURL(path: path, queryItems: queryItems)

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
        responseType: Response.Type,
        debugName: String
    ) async throws -> Response {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ChatBackendClientError.invalidResponse
        }

        #if DEBUG
        let responseText = String(data: data, encoding: .utf8) ?? ""
        ChatBackendLogger.log("✅ CHAT BACKEND \(debugName) STATUS:", http.statusCode)
        ChatBackendLogger.log("✅ CHAT BACKEND \(debugName) RESPONSE:", responseText)
        #endif

        do {
            let decoded = try jsonDecoder.decode(Response.self, from: data)

            if http.statusCode >= 200 && http.statusCode < 300 {
                return decoded
            }

            if let apiError = extractAPIError(from: data) {
                throw ChatBackendClientError.apiError(apiError)
            }

            throw ChatBackendClientError.apiError("Backend request failed with status \(http.statusCode)")
        } catch let error as ChatBackendClientError {
            throw error
        } catch {
            throw ChatBackendClientError.decodingFailed(error.localizedDescription)
        }
    }

    private func extractAPIError(from data: Data) -> String? {
        struct ErrorResponse: Decodable {
            let ok: Bool?
            let error: String?
        }

        return try? jsonDecoder.decode(ErrorResponse.self, from: data).error
    }

    private func isCancelledError(_ error: Error) -> Bool {
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }

        return (error as NSError).code == NSURLErrorCancelled
    }

    // MARK: - Debug

    func testMe() async {
        do {
            let request = try await makeRequest(
                path: "/v1/me",
                method: "GET",
                timeout: 20
            )

            let _: GenericBackendResponse = try await perform(
                request,
                responseType: GenericBackendResponse.self,
                debugName: "/v1/me"
            )
        } catch {
            if isCancelledError(error) {
                ChatBackendLogger.log("⚪️ CHAT BACKEND /v1/me CANCELLED")
                return
            }

            ChatBackendLogger.error("⚠️ CHAT BACKEND /v1/me WARNING:", error.localizedDescription)
        }
    }

    // MARK: - Conversations

    @discardableResult
    func syncFriendship(
        friendshipID: UUID,
        friendUserID: UUID
    ) async -> ChatBackendConversationDTO? {
        do {
            ChatBackendLogger.log("🟡 CHAT SYNC DEBUG")
            ChatBackendLogger.log("friendshipID:", friendshipID.uuidString)
            ChatBackendLogger.log("friendUserID:", friendUserID.uuidString)

            let body: [String: String] = [
                "friendshipID": friendshipID.uuidString,
                "friendUserID": friendUserID.uuidString
            ]

            let request = try await makeRequest(
                path: "/v1/conversations/sync-friendship",
                method: "POST",
                body: body,
                timeout: 25
            )

            let decoded = try await perform(
                request,
                responseType: ChatBackendSyncFriendshipResponse.self,
                debugName: "syncFriendship"
            )

            guard decoded.ok else {
                ChatBackendLogger.error("❌ CHAT BACKEND syncFriendship API ERROR:", decoded.error ?? "unknown")
                return nil
            }

            return decoded.conversation
        } catch {
            ChatBackendLogger.error("❌ CHAT BACKEND syncFriendship ERROR:", error.localizedDescription)
            return nil
        }
    }
    
    @discardableResult
    func syncCrew(
        crewID: UUID,
        crewName: String? = nil,
        memberUserIDs: [UUID] = []
    ) async -> ChatBackendConversationDTO? {
        do {
            ChatBackendLogger.log("🟡 CHAT CREW SYNC DEBUG")
            ChatBackendLogger.log("crewID:", crewID.uuidString)
            ChatBackendLogger.log("crewName:", crewName ?? "nil")
            ChatBackendLogger.log("memberUserIDs:", memberUserIDs.map(\.uuidString).joined(separator: ","))

            var body: [String: Any] = [
                "crewID": crewID.uuidString,
                "memberUserIDs": memberUserIDs.map(\.uuidString)
            ]

            if let crewName,
               !crewName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                body["crewName"] = crewName
            }

            let request = try await makeRequest(
                path: "/v1/conversations/sync-crew",
                method: "POST",
                body: body,
                timeout: 25
            )

            let decoded = try await perform(
                request,
                responseType: ChatBackendSyncCrewResponse.self,
                debugName: "syncCrew"
            )

            guard decoded.ok else {
                ChatBackendLogger.error("❌ CHAT BACKEND syncCrew API ERROR:", decoded.error ?? "unknown")
                return nil
            }

            guard let conversation = decoded.conversation else {
                ChatBackendLogger.error("❌ CHAT BACKEND syncCrew ERROR: conversation nil")
                return nil
            }

            return conversation
        } catch {
            ChatBackendLogger.error("❌ CHAT BACKEND syncCrew ERROR:", error.localizedDescription)
            return nil
        }
    }

    @discardableResult
    func listConversations() async -> [ChatBackendConversationDTO] {
        do {
            let request = try await makeRequest(
                path: "/v1/conversations",
                method: "GET",
                timeout: 20
            )

            let decoded = try await perform(
                request,
                responseType: ChatBackendListConversationsResponse.self,
                debugName: "conversations"
            )

            guard decoded.ok else {
                ChatBackendLogger.error("❌ CHAT BACKEND conversations API ERROR:", decoded.error ?? "unknown")
                return []
            }

            return decoded.conversations ?? []
        } catch {
            if isCancelledError(error) {
                ChatBackendLogger.log("⚪️ CHAT BACKEND conversations CANCELLED")
                return []
            }

            ChatBackendLogger.error("❌ CHAT BACKEND conversations ERROR:", error.localizedDescription)
            return []
        }
    }
    
    struct ChatBackendSendMessagePayload: Encodable {
        let clientID: String
        let text: String
        let messageType: String
        let mediaURL: String?
        let fileName: String?
        let fileSizeBytes: Int?
        let mimeType: String?
    }

    // MARK: - Messages

    @discardableResult
    func sendMessage(
        conversationID: UUID,
        text: String,
        clientID: String,
        messageType: String = "text",
        mediaURL: String? = nil,
        fileName: String? = nil,
        fileSizeBytes: Int? = nil,
        mimeType: String? = nil
    ) async -> ChatBackendMessageDTO? {
        do {
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanMessageType = messageType.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                ChatBackendLogger.error("❌ CHAT BACKEND sendMessage ERROR: empty clientID")
                return nil
            }

            guard !cleanMessageType.isEmpty else {
                ChatBackendLogger.error("❌ CHAT BACKEND sendMessage ERROR: empty messageType")
                return nil
            }

            if cleanMessageType == "text", trimmedText.isEmpty {
                ChatBackendLogger.error("❌ CHAT BACKEND sendMessage ERROR: empty text")
                return nil
            }

            if cleanMessageType != "text", mediaURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                ChatBackendLogger.error("❌ CHAT BACKEND sendMessage ERROR: missing mediaURL")
                return nil
            }

            let payload = ChatBackendSendMessagePayload(
                clientID: clientID,
                text: trimmedText,
                messageType: cleanMessageType,
                mediaURL: mediaURL,
                fileName: fileName,
                fileSizeBytes: fileSizeBytes,
                mimeType: mimeType
            )

            let encoder = JSONEncoder()
            let data = try encoder.encode(payload)
            let object = try JSONSerialization.jsonObject(with: data)

            let request = try await makeRequest(
                path: "/v1/conversations/\(conversationID.uuidString)/messages",
                method: "POST",
                body: object,
                timeout: 35
            )

            ChatBackendLogger.log("🟡 CHAT BACKEND SEND START")
            ChatBackendLogger.log("conversationID:", conversationID.uuidString)
            ChatBackendLogger.log("clientID:", clientID)
            ChatBackendLogger.log("messageType:", cleanMessageType)

            let decoded = try await perform(
                request,
                responseType: ChatBackendSendMessageResponse.self,
                debugName: "sendMessage"
            )

            guard decoded.ok else {
                ChatBackendLogger.error("❌ CHAT BACKEND sendMessage API ERROR:", decoded.error ?? "unknown")
                return nil
            }

            return decoded.message
        } catch {
            ChatBackendLogger.error("❌ CHAT BACKEND sendMessage ERROR:", error.localizedDescription)
            return nil
        }
    }
    
    @discardableResult
    func sendMessage(
        conversationID: UUID,
        text: String
    ) async -> ChatBackendMessageDTO? {
        await sendMessage(
            conversationID: conversationID,
            text: text,
            clientID: UUID().uuidString
        )
    }

    @discardableResult
    func fetchMessages(
        conversationID: UUID,
        limit: Int = 50,
        before: String? = nil
    ) async -> [ChatBackendMessageDTO] {
        do {
            let safeLimit = min(max(limit, 1), 100)

            var queryItems: [URLQueryItem] = [
                URLQueryItem(name: "limit", value: "\(safeLimit)")
            ]

            if let before, !before.isEmpty {
                queryItems.append(URLQueryItem(name: "before", value: before))
            }

            let request = try await makeRequest(
                path: "/v1/conversations/\(conversationID.uuidString)/messages",
                method: "GET",
                queryItems: queryItems,
                timeout: 25
            )

            ChatBackendLogger.log("🟡 CHAT BACKEND FETCH START")
            ChatBackendLogger.log("conversationID:", conversationID.uuidString)

            let decoded = try await perform(
                request,
                responseType: ChatBackendFetchMessagesResponse.self,
                debugName: "fetchMessages"
            )

            guard decoded.ok else {
                ChatBackendLogger.error("❌ CHAT BACKEND fetchMessages API ERROR:", decoded.error ?? "unknown")
                return []
            }

            return decoded.messages ?? []
        } catch {
            ChatBackendLogger.error("❌ CHAT BACKEND fetchMessages ERROR:", error.localizedDescription)
            return []
        }
    }

    // MARK: - Read

    @discardableResult
    func markConversationRead(
        conversationID: UUID
    ) async -> Bool {
        do {
            let request = try await makeRequest(
                path: "/v1/conversations/\(conversationID.uuidString)/read",
                method: "POST",
                body: [:] as [String: String],
                timeout: 20
            )

            let decoded = try await perform(
                request,
                responseType: ChatBackendMarkReadResponse.self,
                debugName: "markRead"
            )

            guard decoded.ok else {
                ChatBackendLogger.error("❌ CHAT BACKEND markRead API ERROR:", decoded.error ?? "unknown")
                return false
            }

            return true
        } catch {
            ChatBackendLogger.error("❌ CHAT BACKEND markRead ERROR:", error.localizedDescription)
            return false
        }
    }

    // MARK: - Member State

    @discardableResult
    func updateConversationMemberState(
        conversationID: UUID,
        isPinned: Bool? = nil,
        isMuted: Bool? = nil,
        isArchived: Bool? = nil
    ) async -> ChatBackendMemberStateDTO? {
        do {
            var body: [String: Bool] = [:]

            if let isPinned {
                body["isPinned"] = isPinned
            }

            if let isMuted {
                body["isMuted"] = isMuted
            }

            if let isArchived {
                body["isArchived"] = isArchived
            }

            let request = try await makeRequest(
                path: "/v1/conversations/\(conversationID.uuidString)/member-state",
                method: "PATCH",
                body: body,
                timeout: 20
            )

            let decoded = try await perform(
                request,
                responseType: ChatBackendUpdateMemberStateResponse.self,
                debugName: "memberState"
            )

            guard decoded.ok else {
                ChatBackendLogger.error("❌ CHAT BACKEND memberState API ERROR:", decoded.error ?? "unknown")
                return nil
            }

            return decoded.state
        } catch {
            ChatBackendLogger.error("❌ CHAT BACKEND memberState ERROR:", error.localizedDescription)
            return nil
        }
    }

    // MARK: - Push Token

    @discardableResult
    func savePushToken(
        apnsToken: String,
        environment: String = ChatBackendEnvironment.apnsEnvironment,
        deviceID: String = ChatBackendDeviceIDProvider.deviceID
    ) async -> Bool {
        do {
            let cleanToken = apnsToken.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !cleanToken.isEmpty else {
                ChatBackendLogger.error("❌ CHAT BACKEND pushToken ERROR: empty token")
                return false
            }

            let bundleID = Bundle.main.bundleIdentifier ?? ""
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

            let body: [String: Any] = [
                "apnsToken": cleanToken,
                "environment": environment,
                "platform": "ios",
                "deviceID": deviceID,
                "bundleID": bundleID,
                "appVersion": appVersion
            ]

            let request = try await makeRequest(
                path: "/v1/push-token",
                method: "POST",
                body: body,
                timeout: 25
            )

            let decoded = try await perform(
                request,
                responseType: ChatBackendSavePushTokenResponse.self,
                debugName: "pushToken"
            )

            guard decoded.ok else {
                ChatBackendLogger.error("❌ CHAT BACKEND pushToken API ERROR:", decoded.error ?? "unknown")
                return false
            }

            return true
        } catch {
            if isCancelledError(error) {
                ChatBackendLogger.log("⚪️ CHAT BACKEND pushToken CANCELLED")
                return false
            }

            ChatBackendLogger.error("❌ CHAT BACKEND pushToken ERROR:", error.localizedDescription)
            return false
        }
    }

    @discardableResult
    func savePushTokenWithRetry(
        apnsToken: String,
        environment: String = ChatBackendEnvironment.apnsEnvironment,
        deviceID: String = ChatBackendDeviceIDProvider.deviceID,
        maxAttempts: Int = 4
    ) async -> Bool {
        let safeAttempts = max(1, maxAttempts)

        for attempt in 1...safeAttempts {
            let success = await savePushToken(
                apnsToken: apnsToken,
                environment: environment,
                deviceID: deviceID
            )

            if success {
                return true
            }

            if Task.isCancelled {
                return false
            }

            guard attempt < safeAttempts else {
                break
            }

            let delaySeconds = min(Double(attempt) * 1.2, 5.0)
            let delayNanos = UInt64(delaySeconds * 1_000_000_000)

            ChatBackendLogger.error(
                "⚠️ CHAT BACKEND pushToken RETRY:",
                "\(attempt)/\(safeAttempts)",
                "delay:",
                "\(delaySeconds)s"
            )

            try? await Task.sleep(nanoseconds: delayNanos)
        }

        return false
    }
}

// MARK: - Generic Response

private struct GenericBackendResponse: Decodable {
    let ok: Bool?
    let error: String?
}
