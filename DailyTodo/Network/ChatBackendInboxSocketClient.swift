//
//  ChatBackendInboxSocketClient.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.05.2026.
//

import Foundation
import Supabase
import UIKit
import Combine

@MainActor
final class ChatBackendInboxSocketClient: NSObject, ObservableObject {
    static let shared = ChatBackendInboxSocketClient()

    private override init() {
        super.init()
        observeAppLifecycle()
    }

    private let baseSocketURL = ChatBackendEnvironment.websocketBaseURL

    private var webSocketTask: URLSessionWebSocketTask?
    private var shouldReconnect = false
    private var isManuallyDisconnected = false
    private var reconnectAttempt = 0
    private let maxReconnectAttempt = 8

    private var pingTimer: Timer?

    private var onMessageCreated: ((ChatBackendMessageDTO, ChatBackendConversationDTO?) -> Void)?
    private var onConversationUpdated: ((ChatBackendConversationDTO?) -> Void)?
    private var onMessageSeen: ((ChatBackendMessageSeenPayload) -> Void)?

    private lazy var urlSession: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()

    func connect(
        onMessageCreated: @escaping (ChatBackendMessageDTO, ChatBackendConversationDTO?) -> Void,
        onConversationUpdated: @escaping (ChatBackendConversationDTO?) -> Void,
        onMessageSeen: ((ChatBackendMessageSeenPayload) -> Void)? = nil
    ) async {
        self.onMessageCreated = onMessageCreated
        self.onConversationUpdated = onConversationUpdated
        self.onMessageSeen = onMessageSeen

        shouldReconnect = true
        isManuallyDisconnected = false

        guard webSocketTask == nil else {
            ChatBackendLogger.log("⚪️ INBOX WS CONNECT SKIPPED: already connected")
            return
        }

        await openSocket()
    }

    func disconnect() {
        isManuallyDisconnected = true
        shouldReconnect = false
        reconnectAttempt = 0

        stopHeartbeat()

        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil

        ChatBackendLogger.log("🔴 INBOX WS DISCONNECT")
    }

    private func openSocket() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let token = session.accessToken

            guard var components = URLComponents(string: "\(baseSocketURL)/v1/socket") else {
                ChatBackendLogger.error("❌ INBOX WS URL COMPONENTS FAILED")
                return
            }

            components.queryItems = [
                URLQueryItem(name: "token", value: token)
            ]

            guard let url = components.url else {
                ChatBackendLogger.error("❌ INBOX WS URL INVALID")
                return
            }

            closeCurrentTaskWithoutResettingState()

            let task = urlSession.webSocketTask(with: url)
            webSocketTask = task
            task.resume()

            ChatBackendLogger.log("🟢 INBOX WS CONNECT START")

            listen()
            startHeartbeat()
        } catch {
            ChatBackendLogger.error("❌ INBOX WS CONNECT ERROR:", error.localizedDescription)
            scheduleReconnectIfNeeded()
        }
    }

    private func closeCurrentTaskWithoutResettingState() {
        stopHeartbeat()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
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
                    ChatBackendLogger.error("❌ INBOX WS SEND ERROR:", error.localizedDescription)
                }
            }
        } catch {
            ChatBackendLogger.error("❌ INBOX WS JSON ERROR:", error.localizedDescription)
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
                    ChatBackendLogger.error("❌ INBOX WS RECEIVE ERROR:", error.localizedDescription)
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

        ChatBackendLogger.log("📩 INBOX WS RECEIVE:", text)

        guard let data = text.data(using: .utf8) else { return }

        do {
            let event = try JSONDecoder().decode(ChatBackendSocketEvent.self, from: data)

            switch event.event {
            case "connected":
                reconnectAttempt = 0
                ChatBackendLogger.log("🟢 INBOX WS CONNECTED")

            case "pong":
                ChatBackendLogger.log("🏓 INBOX WS PONG")

            case "message_created":
                guard let message = event.payload?.message else {
                    ChatBackendLogger.error("❌ INBOX MESSAGE_CREATED MISSING")
                    return
                }

                let conversation = event.payload?.conversation

                onMessageCreated?(message, conversation)

                NotificationCenter.default.post(
                    name: .chatBackendMessageCreated,
                    object: message.conversationID,
                    userInfo: [
                        "conversationID": message.conversationID.uuidString,
                        "messageID": message.id.uuidString,
                        "conversation": conversation as Any
                    ]
                )

            case "conversation_updated":
                let conversation = event.payload?.conversation
                let conversationID = event.payload?.conversationID ?? conversation?.id

                onConversationUpdated?(conversation)

                NotificationCenter.default.post(
                    name: .chatBackendConversationUpdated,
                    object: conversationID,
                    userInfo: [
                        "conversationID": conversationID?.uuidString ?? "",
                        "conversation": conversation as Any
                    ]
                )
                
            case "message_seen":
                guard let payload = event.payload?.asSeenPayload else {
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

            default:
                break
            }
        } catch {
            ChatBackendLogger.error("❌ INBOX WS DECODE ERROR:", error.localizedDescription)
        }
    }

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

    private func scheduleReconnectIfNeeded() {
        guard shouldReconnect else { return }
        guard !isManuallyDisconnected else { return }

        reconnectAttempt += 1

        guard reconnectAttempt <= maxReconnectAttempt else {
            ChatBackendLogger.error("❌ INBOX WS RECONNECT STOPPED")
            return
        }

        let delay = min(pow(2.0, Double(reconnectAttempt)), 30.0)

        ChatBackendLogger.log("🟡 INBOX WS RECONNECT SCHEDULED:", delay)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            guard self.shouldReconnect else { return }
            guard !self.isManuallyDisconnected else { return }
            guard self.webSocketTask == nil else { return }

            await self.openSocket()
        }
    }

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
        ChatBackendLogger.log("🟠 INBOX WS APP DID ENTER BACKGROUND")
        stopHeartbeat()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    @objc private func appWillEnterForeground() {
        ChatBackendLogger.log("🟢 INBOX WS APP WILL ENTER FOREGROUND")

        guard shouldReconnect else { return }
        guard webSocketTask == nil else { return }

        Task { @MainActor in
            await openSocket()
        }
    }
}

extension ChatBackendInboxSocketClient: URLSessionWebSocketDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        #if DEBUG
        print("🟢 INBOX WS DID OPEN")
        #endif
    }

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        #if DEBUG
        print("🔴 INBOX WS DID CLOSE:", closeCode.rawValue)
        #endif

        Task { @MainActor in
            if ChatBackendInboxSocketClient.shared.webSocketTask === webSocketTask {
                ChatBackendInboxSocketClient.shared.webSocketTask = nil
                ChatBackendInboxSocketClient.shared.stopHeartbeat()
                ChatBackendInboxSocketClient.shared.scheduleReconnectIfNeeded()
            }
        }
    }
}
