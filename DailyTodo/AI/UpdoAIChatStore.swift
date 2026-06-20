//
//  UpdoAIChatStore.swift
//  DailyTodo
//

import Foundation
import Combine
import SwiftUI

struct AIMessage: Identifiable, Codable {
    var id = UUID()
    let role: String       // "user" | "assistant" | "action"
    var text: String
    let timestamp: Date
    var isStreaming: Bool = false
    var actionTitle: String? = nil   // for assistant messages with a tap-to-confirm action
    var actionPayload: String? = nil // JSON or simple string

    var anthropicMessage: [String: String] {
        ["role": role == "user" ? "user" : "assistant", "content": text]
    }
}

@MainActor
final class UpdoAIChatStore: ObservableObject {
    @Published var messages: [AIMessage] = []
    @Published var streamingText: String = ""
    @Published var isSending: Bool = false
    @Published var error: String? = nil
    @Published var lastPreviewText: String = ""

    private let storageKey = "updo_ai_messages_v1"
    private let previewKey = "updo_ai_last_preview"

    init() {
        load()
        lastPreviewText = UserDefaults.standard.string(forKey: previewKey) ?? ""
    }

    // MARK: - Send

    func send(
        text: String,
        contextPrompt: String,
        credits: DailyCreditsManager,
        userID: String
    ) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }
        guard credits.canAfford(AITokenCost.chatMessage) else {
            error = tr("ais_daily_limit")
            return
        }

        Analytics.shared.track("ai_message_sent")

        let userMsg = AIMessage(role: "user", text: trimmed, timestamp: .now)
        messages.append(userMsg)
        persist()
        isSending = true
        error = nil

        let history = Array(messages.suffix(8)).compactMap { msg -> [String: String]? in
            guard msg.role == "user" || msg.role == "assistant" else { return nil }
            return msg.anthropicMessage
        }

        do {
            var full = ""
            for try await chunk in await AIService.shared.streamMessages(
                system: contextPrompt,
                messages: history,
                maxTokens: 300
            ) {
                full += chunk
                streamingText = full
            }

            // Only deduct credits on success
            credits.spend(AITokenCost.chatMessage, userID: userID)

            streamingText = ""
            let reply = AIMessage(role: "assistant", text: full, timestamp: .now)
            messages.append(reply)
            lastPreviewText = full
            UserDefaults.standard.set(full, forKey: previewKey)
            persist()
        } catch {
            streamingText = ""
            // Keep the user message visible — append an error reply instead of removing
            let errText: String
            switch error {
            case AIServiceError.insufficientCredits:
                errText = "⚠️ Yeterli krediniz yok."
            case AIServiceError.rateLimited:
                errText = tr("ais_too_many")
            case is URLError:
                errText = tr("ais_conn")
            default:
                errText = tr("ais_generic")
            }
            let errMsg = AIMessage(role: "assistant", text: errText, timestamp: .now)
            messages.append(errMsg)
            self.error = errText
            persist()
        }

        isSending = false
    }

    // MARK: - Persistence

    func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([AIMessage].self, from: data) else { return }
        messages = saved
    }

    func persist() {
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func clearHistory() {
        messages = []
        streamingText = ""
        persist()
    }
}
