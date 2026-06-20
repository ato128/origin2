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
            case "crew_focus_session_started":
                            postCrewFocusSessionEvent(.crewFocusSessionStarted, payload: event.payload)

                        case "crew_focus_session_begun":
                            postCrewFocusSessionEvent(.crewFocusSessionBegun, payload: event.payload)

                        case "crew_focus_session_paused":
                            postCrewFocusSessionEvent(.crewFocusSessionPaused, payload: event.payload)

                        case "crew_focus_session_resumed":
                            postCrewFocusSessionEvent(.crewFocusSessionResumed, payload: event.payload)

                        case "crew_focus_session_ended":
                            postCrewFocusSessionEvent(.crewFocusSessionEnded, payload: event.payload)

                        case "crew_focus_participant_joined":
                            postCrewFocusParticipantJoinedEvent(payload: event.payload)

                        case "crew_focus_participant_left":
                            postCrewFocusParticipantLeftEvent(payload: event.payload)
                
                // ════════════════════════════════════════════════════════════
                            // CREW TASKS / ACTIVITIES / MEMBERS / RECORDS
                            // ════════════════════════════════════════════════════════════

                            case "crew_task_created":
                                postCrewTaskEvent(.crewTaskCreated, payload: event.payload)

                            case "crew_task_updated":
                                postCrewTaskEvent(.crewTaskUpdated, payload: event.payload)

                            case "crew_task_toggled":
                                postCrewTaskEvent(.crewTaskToggled, payload: event.payload)

                            case "crew_task_completed_after_focus":
                                postCrewTaskEvent(.crewTaskCompletedAfterFocus, payload: event.payload)

                            case "crew_task_deleted":
                                postCrewTaskDeletedEvent(payload: event.payload)

                            case "crew_activity_created":
                                postCrewActivityEvent(payload: event.payload)

                            case "crew_member_added":
                                postCrewMemberEvent(.crewMemberAdded, payload: event.payload)

                            case "crew_member_removed":
                                postCrewMemberRemovedEvent(payload: event.payload)

                            case "crew_member_updated":
                                postCrewMemberEvent(.crewMemberUpdated, payload: event.payload)

                            case "crew_focus_record_created":
                                postCrewFocusRecordEvent(payload: event.payload)

            default:
                break
            }
        } catch {
            ChatBackendLogger.error("❌ INBOX WS DECODE ERROR:", error.localizedDescription)
        }
    }
    // MARK: - Crew Focus Event Helpers

    
    // MARK: - Crew Task/Activity/Member/Record Event Helpers

        private func postCrewTaskEvent(
            _ name: Notification.Name,
            payload: ChatBackendSocketPayload?
        ) {
            guard let task = payload?.task else {
                ChatBackendLogger.error("❌ INBOX WS:", name.rawValue, "missing task")
                return
            }

            NotificationCenter.default.post(
                name: name,
                object: task.crew_id,
                userInfo: [
                    "crewID": task.crew_id,
                    "task": task
                ]
            )
        }

        private func postCrewTaskDeletedEvent(payload: ChatBackendSocketPayload?) {
            guard
                let taskID = payload?.taskID,
                let crewID = payload?.crewID
            else {
                ChatBackendLogger.error("❌ INBOX WS: task_deleted missing payload")
                return
            }

            NotificationCenter.default.post(
                name: .crewTaskDeleted,
                object: crewID,
                userInfo: [
                    "taskID": taskID,
                    "crewID": crewID
                ]
            )
        }

        private func postCrewActivityEvent(payload: ChatBackendSocketPayload?) {
            guard let activity = payload?.activity else {
                ChatBackendLogger.error("❌ INBOX WS: activity_created missing activity")
                return
            }

            NotificationCenter.default.post(
                name: .crewActivityCreated,
                object: activity.crew_id,
                userInfo: [
                    "crewID": activity.crew_id,
                    "activity": activity
                ]
            )
        }

        private func postCrewMemberEvent(
            _ name: Notification.Name,
            payload: ChatBackendSocketPayload?
        ) {
            guard let member = payload?.member else {
                ChatBackendLogger.error("❌ INBOX WS:", name.rawValue, "missing member")
                return
            }

            NotificationCenter.default.post(
                name: name,
                object: member.crew_id,
                userInfo: [
                    "crewID": member.crew_id,
                    "member": member
                ]
            )
        }

        private func postCrewMemberRemovedEvent(payload: ChatBackendSocketPayload?) {
            guard
                let memberID = payload?.memberID,
                let crewID = payload?.crewID
            else {
                ChatBackendLogger.error("❌ INBOX WS: member_removed missing payload")
                return
            }

            NotificationCenter.default.post(
                name: .crewMemberRemoved,
                object: crewID,
                userInfo: [
                    "memberID": memberID,
                    "crewID": crewID,
                    "userID": payload?.userID as Any
                ]
            )
        }

        private func postCrewFocusRecordEvent(payload: ChatBackendSocketPayload?) {
            guard let record = payload?.record else {
                ChatBackendLogger.error("❌ INBOX WS: focus_record_created missing record")
                return
            }

            NotificationCenter.default.post(
                name: .crewFocusRecordCreated,
                object: record.crew_id,
                userInfo: [
                    "crewID": record.crew_id,
                    "record": record
                ]
            )
        }
        private func postCrewFocusSessionEvent(
            _ name: Notification.Name,
            payload: ChatBackendSocketPayload?
        ) {
            guard let session = payload?.session else {
                ChatBackendLogger.error("❌ INBOX WS:", name.rawValue, "missing session")
                return
            }

            NotificationCenter.default.post(
                name: name,
                object: session.crew_id,
                userInfo: [
                    "crewID": session.crew_id,
                    "session": session
                ]
            )
        }

        private func postCrewFocusParticipantJoinedEvent(payload: ChatBackendSocketPayload?) {
            guard
                let sessionID = payload?.sessionID,
                let participant = payload?.participant
            else {
                ChatBackendLogger.error("❌ INBOX WS: participant_joined missing payload")
                return
            }

            NotificationCenter.default.post(
                name: .crewFocusParticipantJoined,
                object: participant.crew_id,
                userInfo: [
                    "sessionID": sessionID,
                    "crewID": participant.crew_id,
                    "participant": participant
                ]
            )
        }

        private func postCrewFocusParticipantLeftEvent(payload: ChatBackendSocketPayload?) {
            guard
                let sessionID = payload?.sessionID,
                let userID = payload?.userID
            else {
                ChatBackendLogger.error("❌ INBOX WS: participant_left missing payload")
                return
            }

            NotificationCenter.default.post(
                name: .crewFocusParticipantLeft,
                object: nil,
                userInfo: [
                    "sessionID": sessionID,
                    "userID": userID
                ]
            )
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
        Log.debug("🟢 INBOX WS DID OPEN")
        #endif
    }

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        #if DEBUG
        Log.debug("🔴 INBOX WS DID CLOSE:", closeCode.rawValue)
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
