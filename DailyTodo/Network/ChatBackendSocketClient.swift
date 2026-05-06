//
//  ChatBackendSocketClient.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 6.05.2026.
//

import Foundation
import Supabase
import Combine

@MainActor
final class ChatBackendSocketClient: NSObject, ObservableObject {
    static let shared = ChatBackendSocketClient()

    private override init() {
        super.init()
    }

    private let baseSocketURL = "wss://growing-toll-exchange-pacific.trycloudflare.com"

    private var webSocketTask: URLSessionWebSocketTask?
    private var activeConversationID: UUID?

    private var onMessageCreated: ((ChatBackendMessageDTO) -> Void)?
    private var onMessageSeen: ((ChatBackendMessageSeenPayload) -> Void)?

    private lazy var urlSession: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()

    func connect(
        conversationID: UUID,
        onMessageCreated: @escaping (ChatBackendMessageDTO) -> Void,
        onMessageSeen: ((ChatBackendMessageSeenPayload) -> Void)? = nil
    ) async {
        self.activeConversationID = conversationID
        self.onMessageCreated = onMessageCreated
        self.onMessageSeen = onMessageSeen

        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let token = session.accessToken

            guard var components = URLComponents(string: "\(baseSocketURL)/v1/socket") else {
                print("❌ WS URL COMPONENTS FAILED")
                return
            }

            components.queryItems = [
                URLQueryItem(name: "token", value: token)
            ]

            guard let url = components.url else {
                print("❌ WS URL INVALID")
                return
            }

            disconnect()

            let task = urlSession.webSocketTask(with: url)
            webSocketTask = task
            task.resume()

            print("🟢 WS CONNECT START:", url.absoluteString)

            listen()
            sendJoin(conversationID: conversationID)

        } catch {
            print("❌ WS CONNECT ERROR:", error.localizedDescription)
        }
    }

    func disconnect() {
        if let activeConversationID {
            sendRaw([
                "type": "leave_conversation",
                "conversationID": activeConversationID.uuidString
            ])
        }

        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        activeConversationID = nil
        onMessageCreated = nil
        onMessageSeen = nil

        print("🔴 WS DISCONNECT")
    }

    private func sendJoin(conversationID: UUID) {
        sendRaw([
            "type": "join_conversation",
            "conversationID": conversationID.uuidString
        ])
    }

    private func sendRaw(_ object: [String: String]) {
        guard let webSocketTask else { return }

        do {
            let data = try JSONSerialization.data(withJSONObject: object)
            let text = String(data: data, encoding: .utf8) ?? "{}"

            webSocketTask.send(.string(text)) { error in
                if let error {
                    print("❌ WS SEND ERROR:", error.localizedDescription)
                } else {
                    print("📤 WS SEND:", text)
                }
            }
        } catch {
            print("❌ WS JSON ENCODE ERROR:", error.localizedDescription)
        }
    }

    private func listen() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }

            Task { @MainActor in
                switch result {
                case .success(let message):
                    self.handleSocketMessage(message)
                    self.listen()

                case .failure(let error):
                    print("❌ WS RECEIVE ERROR:", error.localizedDescription)
                }
            }
        }
    }

    private func handleSocketMessage(_ message: URLSessionWebSocketTask.Message) {
        let text: String

        switch message {
        case .string(let value):
            text = value

        case .data(let data):
            text = String(data: data, encoding: .utf8) ?? ""

        @unknown default:
            return
        }

        print("📩 WS RECEIVE:", text)

        guard let data = text.data(using: .utf8) else { return }

        do {
            let event = try JSONDecoder().decode(ChatBackendSocketEvent.self, from: data)

            switch event.event {
            case "connected":
                print("🟢 WS CONNECTED")

            case "joined_conversation":
                print("🟡 WS JOINED CONVERSATION")

            case "message_created":
                guard let message = event.payload?.message else {
                    print("❌ WS MESSAGE_CREATED PAYLOAD MISSING")
                    return
                }

                onMessageCreated?(message)

            case "message_seen":
                guard let payload = event.payload?.asSeenPayload else {
                    print("❌ WS MESSAGE_SEEN PAYLOAD MISSING")
                    return
                }

                onMessageSeen?(payload)

            default:
                print("⚪️ WS UNKNOWN EVENT:", event.event)
            }
        } catch {
            print("❌ WS DECODE ERROR:", error.localizedDescription)
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension ChatBackendSocketClient: URLSessionWebSocketDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        print("🟢 WS DID OPEN")
    }

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        print("🔴 WS DID CLOSE:", closeCode.rawValue)
    }
}

// MARK: - Socket DTOs

struct ChatBackendSocketEvent: Decodable {
    let event: String
    let payload: ChatBackendSocketPayload?
}

struct ChatBackendSocketPayload: Decodable {
    let userID: UUID?
    let conversationID: UUID?
    let message: ChatBackendMessageDTO?
    let readerID: UUID?
    let messages: [ChatBackendSeenMessageDTO]?

    var asSeenPayload: ChatBackendMessageSeenPayload? {
        guard let conversationID, let readerID else {
            return nil
        }

        return ChatBackendMessageSeenPayload(
            conversationID: conversationID,
            readerID: readerID,
            messages: messages ?? []
        )
    }
}

struct ChatBackendSeenMessageDTO: Decodable {
    let id: UUID
    let conversationID: UUID
    let senderID: UUID
    let clientID: String
    let seenAt: String
}

struct ChatBackendMessageSeenPayload: Decodable {
    let conversationID: UUID
    let readerID: UUID
    let messages: [ChatBackendSeenMessageDTO]
}
