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
        userID: String,
        onTool: @MainActor (AIToolCall) -> String
    ) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }
        guard credits.canSendChatMessage else {
            error = credits.limitMessage
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
            let (fullText, tool) = try await AIService.shared.coachChat(
                system: contextPrompt,
                messages: history,
                maxTokens: 300
            )

            // Only deduct credits on success (optimistic; backend is the source of truth)
            credits.noteMessageSent()
            streamingText = ""

            let replyText: String
            if let tool {
                // AI bir aksiyon çağırdı → istemci uygular + onay metnini döndürür.
                replyText = onTool(tool)
            } else {
                // Guard: a blank reply (provider returned empty content) must not
                // land as an empty bubble — surface a retry-flavored error instead.
                guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw AIServiceError.invalidResponse
                }
                replyText = fullText
            }

            let reply = AIMessage(role: "assistant", text: replyText, timestamp: .now)
            messages.append(reply)
            lastPreviewText = replyText
            UserDefaults.standard.set(replyText, forKey: previewKey)
            persist()
        } catch {
            streamingText = ""
            // Keep the user message visible — append an error reply instead of removing
            let errText: String
            switch error {
            case AIServiceError.insufficientCredits:
                errText = tr("ai_monthly_limit")
            case AIServiceError.dailyFreeLimitReached:
                errText = tr("ai_free_over")
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

    /// Appends a user message + an assistant confirmation locally, without any
    /// network call or credit spend. Used by the token-free command interpreter.
    func appendLocalExchange(userText: String, assistantText: String) {
        messages.append(AIMessage(role: "user", text: userText, timestamp: .now))
        messages.append(AIMessage(role: "assistant", text: assistantText, timestamp: .now))
        lastPreviewText = assistantText
        UserDefaults.standard.set(assistantText, forKey: previewKey)
        persist()
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
