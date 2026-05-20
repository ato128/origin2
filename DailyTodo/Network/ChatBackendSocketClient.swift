//
//  ChatBackendSocketClient.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 6.05.2026.
//

import Foundation
import Supabase
import Combine
import UIKit

@MainActor
final class ChatBackendSocketClient: NSObject, ObservableObject {
    static let shared = ChatBackendSocketClient()

    private override init() {
        super.init()
        observeAppLifecycle()
    }

    private let baseSocketURL = ChatBackendEnvironment.websocketBaseURL

    private var webSocketTask: URLSessionWebSocketTask?
    private var activeConversationID: UUID?

    private var onMessageCreated: ((ChatBackendMessageDTO) -> Void)?
        private var onMessageSeen: ((ChatBackendMessageSeenPayload) -> Void)?
        private var onMessageDelivered: ((ChatBackendMessageDeliveredPayload) -> Void)?

    private var shouldReconnect = false
    private var isManuallyDisconnected = false
    private var reconnectAttempt = 0
    private let maxReconnectAttempt = 5

    private var pingTimer: Timer?

    private lazy var urlSession: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()

    // MARK: - Public API

    func connect(
            conversationID: UUID,
            onMessageCreated: @escaping (ChatBackendMessageDTO) -> Void,
            onMessageSeen: ((ChatBackendMessageSeenPayload) -> Void)? = nil,
            onMessageDelivered: ((ChatBackendMessageDeliveredPayload) -> Void)? = nil
        ) async {
            self.activeConversationID = conversationID
            self.onMessageCreated = onMessageCreated
            self.onMessageSeen = onMessageSeen
            self.onMessageDelivered = onMessageDelivered
            self.shouldReconnect = true
            self.isManuallyDisconnected = false

            await openSocket()
        }

    func disconnect() {
        isManuallyDisconnected = true
        shouldReconnect = false
        reconnectAttempt = 0

        stopHeartbeat()

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
                onMessageDelivered = nil

                ChatBackendLogger.log("🔴 WS DISCONNECT")
    }

    func reconnectCurrentConversationIfNeeded() async {
        guard activeConversationID != nil else { return }
        guard webSocketTask == nil else { return }

        shouldReconnect = true
        isManuallyDisconnected = false

        await openSocket()
    }

    // MARK: - Socket Open

    private func openSocket() async {
        guard let activeConversationID else {
            ChatBackendLogger.error("❌ WS OPEN FAILED: missing activeConversationID")
            return
        }

        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let token = session.accessToken

            guard var components = URLComponents(string: "\(baseSocketURL)/v1/socket") else {
                ChatBackendLogger.error("❌ WS URL COMPONENTS FAILED")
                return
            }

            components.queryItems = [
                URLQueryItem(name: "token", value: token)
            ]

            guard let url = components.url else {
                ChatBackendLogger.error("❌ WS URL INVALID")
                return
            }

            closeCurrentTaskWithoutResettingState()

            let task = urlSession.webSocketTask(with: url)
            webSocketTask = task
            task.resume()

            ChatBackendLogger.log("🟢 WS CONNECT START")

            listen()
            sendJoin(conversationID: activeConversationID)
            startHeartbeat()

        } catch {
            ChatBackendLogger.error("❌ WS CONNECT ERROR:", error.localizedDescription)
            scheduleReconnectIfNeeded()
        }
    }

    private func closeCurrentTaskWithoutResettingState() {
        stopHeartbeat()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    // MARK: - Join / Leave / Ping

    private func sendJoin(conversationID: UUID) {
        sendRaw([
            "type": "join_conversation",
            "conversationID": conversationID.uuidString
        ])
    }

    private func sendPing() {
        sendRaw([
            "type": "ping"
        ])
    }

    private func sendRaw(_ object: [String: String]) {
        guard let webSocketTask else { return }

        do {
            let data = try JSONSerialization.data(withJSONObject: object)
            let text = String(data: data, encoding: .utf8) ?? "{}"

            webSocketTask.send(.string(text)) { error in
                if let error {
                    ChatBackendLogger.error("❌ WS SEND ERROR:", error.localizedDescription)
                } else {
                    ChatBackendLogger.log("📤 WS SEND:", text)
                }
            }
        } catch {
            ChatBackendLogger.error("❌ WS JSON ENCODE ERROR:", error.localizedDescription)
        }
    }

    // MARK: - Listen

    private func listen() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }

            Task { @MainActor in
                switch result {
                case .success(let message):
                    self.handleSocketMessage(message)
                    self.listen()

                case .failure(let error):
                    ChatBackendLogger.error("❌ WS RECEIVE ERROR:", error.localizedDescription)
                    self.webSocketTask = nil
                    self.stopHeartbeat()
                    self.scheduleReconnectIfNeeded()
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

        ChatBackendLogger.log("📩 WS RECEIVE:", text)

        guard let data = text.data(using: .utf8) else { return }

        do {
            let event = try JSONDecoder().decode(ChatBackendSocketEvent.self, from: data)

            switch event.event {
            case "connected":
                reconnectAttempt = 0
                ChatBackendLogger.log("🟢 WS CONNECTED")

            case "joined_conversation":
                reconnectAttempt = 0
                ChatBackendLogger.log("🟡 WS JOINED CONVERSATION")

            case "left_conversation":
                ChatBackendLogger.log("🟠 WS LEFT CONVERSATION")

            case "pong":
                ChatBackendLogger.log("🏓 WS PONG")

            case "message_created":
                guard let message = event.payload?.message else {
                    ChatBackendLogger.error("❌ WS MESSAGE_CREATED PAYLOAD MISSING")
                    return
                }

                onMessageCreated?(message)

                NotificationCenter.default.post(
                    name: .chatBackendMessageCreated,
                    object: message.conversationID,
                    userInfo: [
                        "conversationID": message.conversationID.uuidString,
                        "messageID": message.id.uuidString
                    ]
                )

            case "message_seen":
                guard let payload = event.payload?.asSeenPayload else {
                    ChatBackendLogger.error("❌ WS MESSAGE_SEEN PAYLOAD MISSING")
                    return
                }

                onMessageSeen?(payload)

                NotificationCenter.default.post(
                    name: .chatBackendMessageSeen,
                    object: payload.conversationID,
                    userInfo: [
                        "conversationID": payload.conversationID.uuidString,
                        "readerID": payload.readerID.uuidString
                    ]
                )

            case "message_delivered":
                            guard let payload = event.payload?.asDeliveredPayload else {
                                ChatBackendLogger.error("❌ WS MESSAGE_DELIVERED PAYLOAD MISSING")
                                return
                            }

                            onMessageDelivered?(payload)

                            NotificationCenter.default.post(
                                name: .chatBackendMessageDelivered,
                                object: payload.conversationID,
                                userInfo: [
                                    "conversationID": payload.conversationID.uuidString,
                                    "recipientID": payload.recipientID.uuidString
                                ]
                            )

                            ChatBackendLogger.log("✅ WS MESSAGE DELIVERED:", payload.messages.count)

            case "conversation_updated":
                let conversationID = event.payload?.conversationID ?? event.payload?.message?.conversationID

                ChatBackendLogger.log(
                    "🟣 WS CONVERSATION UPDATED EVENT RECEIVED:",
                    conversationID?.uuidString ?? "nil"
                )

                NotificationCenter.default.post(
                    name: .chatBackendConversationUpdated,
                    object: conversationID,
                    userInfo: [
                        "conversationID": conversationID?.uuidString ?? ""
                    ]
                )

            case "error":
                ChatBackendLogger.error("❌ WS SERVER ERROR:", event.payload?.message ?? "unknown")

            default:
                ChatBackendLogger.log("⚪️ WS UNKNOWN EVENT:", event.event)
            }
        } catch {
            ChatBackendLogger.error("❌ WS DECODE ERROR:", error.localizedDescription)
        }
    }

    // MARK: - Heartbeat

    private func startHeartbeat() {
        stopHeartbeat()

        pingTimer = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sendPing()
            }
        }
    }

    private func stopHeartbeat() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    // MARK: - Reconnect

    private func scheduleReconnectIfNeeded() {
        guard shouldReconnect else { return }
        guard !isManuallyDisconnected else { return }
        guard activeConversationID != nil else { return }

        reconnectAttempt += 1

        guard reconnectAttempt <= maxReconnectAttempt else {
            ChatBackendLogger.error("❌ WS RECONNECT STOPPED: max attempts reached")
            return
        }

        let delay = min(pow(2.0, Double(reconnectAttempt)), 20.0)

        ChatBackendLogger.log("🟡 WS RECONNECT SCHEDULED:", delay, "seconds")

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            guard self.shouldReconnect else { return }
            guard !self.isManuallyDisconnected else { return }
            guard self.webSocketTask == nil else { return }

            await self.openSocket()
        }
    }

    // MARK: - App Lifecycle

    private func observeAppLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func appDidEnterBackground() {
        ChatBackendLogger.log("🟠 WS APP DID ENTER BACKGROUND")

        stopHeartbeat()

        if let activeConversationID {
            sendRaw([
                "type": "leave_conversation",
                "conversationID": activeConversationID.uuidString
            ])
        }

        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    @objc private func appWillEnterForeground() {
        ChatBackendLogger.log("🟢 WS APP WILL ENTER FOREGROUND")

        guard activeConversationID != nil else { return }

        Task { @MainActor in
            await reconnectCurrentConversationIfNeeded()
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
        #if DEBUG
        print("🟢 WS DID OPEN")
        #endif
    }

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        #if DEBUG
        print("🔴 WS DID CLOSE:", closeCode.rawValue)
        #endif

        Task { @MainActor in
            if ChatBackendSocketClient.shared.webSocketTask === webSocketTask {
                ChatBackendSocketClient.shared.webSocketTask = nil
                ChatBackendSocketClient.shared.stopHeartbeat()
                ChatBackendSocketClient.shared.scheduleReconnectIfNeeded()
            }
        }
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
    let conversation: ChatBackendConversationDTO?
    let message: ChatBackendMessageDTO?
    let readerID: UUID?
    let recipientID: UUID?
    let messages: [ChatBackendSeenMessageDTO]?
    let code: String?
    let error: String?


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

    var asDeliveredPayload: ChatBackendMessageDeliveredPayload? {
        guard let conversationID, let recipientID else {
            return nil
        }

        return ChatBackendMessageDeliveredPayload(
            conversationID: conversationID,
            recipientID: recipientID,
            messages: messages ?? []
        )
    }
}

struct ChatBackendSeenMessageDTO: Decodable, Equatable {
    let id: UUID
    let conversationID: UUID
    let senderID: UUID
    let clientID: String
    let seenAt: String

    var seenDate: Date? {
        ChatBackendDateParser.parse(seenAt)
    }
}

struct ChatBackendMessageSeenPayload: Decodable, Equatable {
    let conversationID: UUID
    let readerID: UUID
    let messages: [ChatBackendSeenMessageDTO]
}

struct ChatBackendMessageDeliveredPayload: Decodable, Equatable {
    let conversationID: UUID
    let recipientID: UUID
    let messages: [ChatBackendSeenMessageDTO]
}

extension Notification.Name {
    static let chatBackendConversationUpdated = Notification.Name("chatBackendConversationUpdated")
    static let chatBackendMessageCreated = Notification.Name("chatBackendMessageCreated")
    static let chatBackendMessageSeen = Notification.Name("chatBackendMessageSeen")
    static let chatBackendMessageDelivered = Notification.Name("chatBackendMessageDelivered")
}
