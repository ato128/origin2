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

struct ChatBackendMessageDTO: Decodable {
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
    let createdAt: String
    let editedAt: String?
    let deletedAt: String?
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

struct ChatBackendConversationDTO: Decodable {
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
}

struct ChatBackendSyncFriendshipResponse: Decodable {
    let ok: Bool
    let conversation: ChatBackendConversationDTO?
    let error: String?
}

struct ChatBackendMarkReadResponse: Decodable {
    let ok: Bool
    let error: String?
}

struct ChatBackendListConversationsResponse: Decodable {
    let ok: Bool
    let conversations: [ChatBackendConversationDTO]?
    let error: String?
}

struct ChatBackendMemberStateDTO: Decodable {
    let conversationID: UUID
    let userID: UUID
    let unreadCount: Int
    let isMuted: Bool
    let isArchived: Bool
    let isPinned: Bool
    let updatedAt: String?
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

struct ChatBackendSavedPushTokenDTO: Decodable {
    let id: UUID
    let userID: UUID
    let environment: String
    let platform: String
    let deviceID: String
    let bundleID: String?
    let appVersion: String?
    let isActive: Bool
    let updatedAt: String?
}

final class ChatBackendClient {
    static let shared = ChatBackendClient()
    private init() {}

    private let baseURL = "https://growing-toll-exchange-pacific.trycloudflare.com"

    func testMe() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let accessToken = session.accessToken

            guard let url = URL(string: "\(baseURL)/v1/me") else {
                print("❌ CHAT BACKEND URL INVALID")
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 15
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let text = String(data: data, encoding: .utf8) ?? ""

            print("✅ CHAT BACKEND /v1/me STATUS:", status)
            print("✅ CHAT BACKEND /v1/me RESPONSE:", text)
        } catch {
            print("❌ CHAT BACKEND /v1/me ERROR:", error.localizedDescription)
        }
    }

    @discardableResult
    func syncFriendship(
        friendshipID: UUID,
        friendUserID: UUID
    ) async -> ChatBackendConversationDTO? {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let accessToken = session.accessToken

            print("🟡 CHAT SYNC DEBUG")
            print("currentUser:", session.user.id.uuidString)
            print("friendshipID:", friendshipID.uuidString)
            print("friendUserID:", friendUserID.uuidString)

            guard let url = URL(string: "\(baseURL)/v1/conversations/sync-friendship") else {
                print("❌ CHAT BACKEND SYNC URL INVALID")
                return nil
            }

            let body: [String: String] = [
                "friendshipID": friendshipID.uuidString,
                "friendUserID": friendUserID.uuidString
            ]

            let bodyData = try JSONSerialization.data(withJSONObject: body)

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 15
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.httpBody = bodyData

            let (data, response) = try await URLSession.shared.data(for: request)

            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let text = String(data: data, encoding: .utf8) ?? ""

            print("✅ CHAT BACKEND syncFriendship STATUS:", status)
            print("✅ CHAT BACKEND syncFriendship RESPONSE:", text)

            let decoded = try JSONDecoder().decode(ChatBackendSyncFriendshipResponse.self, from: data)

            if decoded.ok {
                return decoded.conversation
            } else {
                print("❌ CHAT BACKEND syncFriendship API ERROR:", decoded.error ?? "unknown")
                return nil
            }
        } catch {
            print("❌ CHAT BACKEND syncFriendship ERROR:", error.localizedDescription)
            return nil
        }
    }

    @discardableResult
    func listConversations() async -> [ChatBackendConversationDTO] {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let accessToken = session.accessToken

            guard let url = URL(string: "\(baseURL)/v1/conversations") else {
                print("❌ CHAT BACKEND conversations URL INVALID")
                return []
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 15
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseText = String(data: data, encoding: .utf8) ?? ""

            print("✅ CHAT BACKEND conversations STATUS:", status)
            print("✅ CHAT BACKEND conversations RESPONSE:", responseText)

            let decoded = try JSONDecoder().decode(ChatBackendListConversationsResponse.self, from: data)

            if decoded.ok {
                return decoded.conversations ?? []
            } else {
                print("❌ CHAT BACKEND conversations API ERROR:", decoded.error ?? "unknown")
                return []
            }
        } catch {
            print("❌ CHAT BACKEND conversations ERROR:", error.localizedDescription)
            return []
        }
    }
    @discardableResult
    func sendMessage(
        conversationID: UUID,
        text: String,
        clientID: String = UUID().uuidString
    ) async -> ChatBackendMessageDTO? {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let accessToken = session.accessToken

            guard let url = URL(string: "\(baseURL)/v1/conversations/\(conversationID.uuidString)/messages") else {
                print("❌ CHAT BACKEND SEND URL INVALID")
                return nil
            }

            let body: [String: String] = [
                "clientID": clientID,
                "text": text
            ]

            let bodyData = try JSONSerialization.data(withJSONObject: body)

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 15
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.httpBody = bodyData

            print("🟡 CHAT BACKEND SEND START")
            print("conversationID:", conversationID.uuidString)
            print("clientID:", clientID)
            print("text:", text)

            let (data, response) = try await URLSession.shared.data(for: request)

            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseText = String(data: data, encoding: .utf8) ?? ""

            print("✅ CHAT BACKEND sendMessage STATUS:", status)
            print("✅ CHAT BACKEND sendMessage RESPONSE:", responseText)

            let decoded = try JSONDecoder().decode(ChatBackendSendMessageResponse.self, from: data)

            if decoded.ok {
                return decoded.message
            } else {
                print("❌ CHAT BACKEND sendMessage API ERROR:", decoded.error ?? "unknown")
                return nil
            }
        } catch {
            print("❌ CHAT BACKEND sendMessage ERROR:", error.localizedDescription)
            return nil
        }
    }
    @discardableResult
    func fetchMessages(
        conversationID: UUID,
        limit: Int = 50
    ) async -> [ChatBackendMessageDTO] {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let accessToken = session.accessToken

            guard let url = URL(string: "\(baseURL)/v1/conversations/\(conversationID.uuidString)/messages?limit=\(limit)") else {
                print("❌ CHAT BACKEND FETCH URL INVALID")
                return []
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 15
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            print("🟡 CHAT BACKEND FETCH START")
            print("conversationID:", conversationID.uuidString)

            let (data, response) = try await URLSession.shared.data(for: request)

            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseText = String(data: data, encoding: .utf8) ?? ""

            print("✅ CHAT BACKEND fetchMessages STATUS:", status)
            print("✅ CHAT BACKEND fetchMessages RESPONSE:", responseText)

            let decoded = try JSONDecoder().decode(ChatBackendFetchMessagesResponse.self, from: data)

            if decoded.ok {
                return decoded.messages ?? []
            } else {
                print("❌ CHAT BACKEND fetchMessages API ERROR:", decoded.error ?? "unknown")
                return []
            }
        } catch {
            print("❌ CHAT BACKEND fetchMessages ERROR:", error.localizedDescription)
            return []
        }
    }
    
    @discardableResult
    func markConversationRead(
        conversationID: UUID
    ) async -> Bool {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let accessToken = session.accessToken

            guard let url = URL(string: "\(baseURL)/v1/conversations/\(conversationID.uuidString)/read") else {
                print("❌ CHAT BACKEND READ URL INVALID")
                return false
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 15
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.httpBody = Data("{}".utf8)

            let (data, response) = try await URLSession.shared.data(for: request)

            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseText = String(data: data, encoding: .utf8) ?? ""

            print("✅ CHAT BACKEND markRead STATUS:", status)
            print("✅ CHAT BACKEND markRead RESPONSE:", responseText)

            let decoded = try JSONDecoder().decode(ChatBackendMarkReadResponse.self, from: data)

            if decoded.ok {
                return true
            } else {
                print("❌ CHAT BACKEND markRead API ERROR:", decoded.error ?? "unknown")
                return false
            }
        } catch {
            print("❌ CHAT BACKEND markRead ERROR:", error.localizedDescription)
            return false
        }
    }
    @discardableResult
    func updateConversationMemberState(
        conversationID: UUID,
        isPinned: Bool? = nil,
        isMuted: Bool? = nil,
        isArchived: Bool? = nil
    ) async -> ChatBackendMemberStateDTO? {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let accessToken = session.accessToken

            guard let url = URL(string: "\(baseURL)/v1/conversations/\(conversationID.uuidString)/member-state") else {
                print("❌ CHAT BACKEND MEMBER STATE URL INVALID")
                return nil
            }

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

            let bodyData = try JSONSerialization.data(withJSONObject: body)

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.timeoutInterval = 15
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.httpBody = bodyData

            let (data, response) = try await URLSession.shared.data(for: request)

            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseText = String(data: data, encoding: .utf8) ?? ""

            print("✅ CHAT BACKEND memberState STATUS:", status)
            print("✅ CHAT BACKEND memberState RESPONSE:", responseText)

            let decoded = try JSONDecoder().decode(ChatBackendUpdateMemberStateResponse.self, from: data)

            if decoded.ok {
                return decoded.state
            } else {
                print("❌ CHAT BACKEND memberState API ERROR:", decoded.error ?? "unknown")
                return nil
            }
        } catch {
            print("❌ CHAT BACKEND memberState ERROR:", error.localizedDescription)
            return nil
        }
    }
    @discardableResult
    func savePushToken(
        apnsToken: String,
        environment: String,
        deviceID: String = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    ) async -> Bool {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let accessToken = session.accessToken

            guard let url = URL(string: "\(baseURL)/v1/push-token") else {
                print("❌ CHAT BACKEND PUSH TOKEN URL INVALID")
                return false
            }

            let bundleID = Bundle.main.bundleIdentifier
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

            let body: [String: Any] = [
                "apnsToken": apnsToken,
                "environment": environment,
                "platform": "ios",
                "deviceID": deviceID,
                "bundleID": bundleID ?? "",
                "appVersion": appVersion ?? ""
            ]

            let bodyData = try JSONSerialization.data(withJSONObject: body)

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 15
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.httpBody = bodyData

            let (data, response) = try await URLSession.shared.data(for: request)

            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseText = String(data: data, encoding: .utf8) ?? ""

            print("✅ CHAT BACKEND pushToken STATUS:", status)
            print("✅ CHAT BACKEND pushToken RESPONSE:", responseText)

            let decoded = try JSONDecoder().decode(ChatBackendSavePushTokenResponse.self, from: data)

            if decoded.ok {
                return true
            } else {
                print("❌ CHAT BACKEND pushToken API ERROR:", decoded.error ?? "unknown")
                return false
            }
        } catch {
            print("❌ CHAT BACKEND pushToken ERROR:", error.localizedDescription)
            return false
        }
    }
}
