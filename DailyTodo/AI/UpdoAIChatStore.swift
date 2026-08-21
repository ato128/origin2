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
            let usesBYO = BYOKeyStore.shared.readKey() != nil
            let replyText: String

            if usesBYO {
                // BYO key path stays on the non-streaming endpoint (the stream
                // endpoint uses our own OpenAI key). Typewriter-reveal the result.
                let (fullText, tool) = try await AIService.shared.coachChat(
                    system: contextPrompt, messages: history, maxTokens: 300
                )
                credits.noteMessageSent()
                if let tool {
                    replyText = onTool(tool)
                } else {
                    guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw AIServiceError.invalidResponse
                    }
                    replyText = fullText
                }
                await revealReply(replyText)
                streamingText = ""
            } else {
                // Real token-by-token streaming (OpenAI-first via our key). The
                // chat renders `streamingText` live as deltas arrive.
                streamingText = ""
                var toolToApply: AIToolCall? = nil
                for try await event in AIService.shared.coachChatStream(
                    system: contextPrompt, messages: history, maxTokens: 300
                ) {
                    switch event {
                    case .delta(let chunk):
                        streamingText += chunk
                    case .tool(let tool):
                        toolToApply = tool
                    case .done:
                        break
                    }
                }

                // Only deduct credits on success (optimistic; backend is truth).
                credits.noteMessageSent()

                if let tool = toolToApply {
                    // Action call → no streamed text; apply + reveal confirmation.
                    streamingText = ""
                    let confirmation = onTool(tool)
                    await revealReply(confirmation)
                    streamingText = ""
                    replyText = confirmation
                } else {
                    // Guard: a blank reply must not land as an empty bubble.
                    guard !streamingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw AIServiceError.invalidResponse
                    }
                    replyText = streamingText
                    streamingText = ""
                }
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

    /// Reveals `full` word-by-word into `streamingText` for a live typing feel.
    /// Bounded: a one-word reply still shows briefly, a long plan doesn't drag.
    /// Newlines stay attached to their words, so plan formatting is preserved.
    private func revealReply(_ full: String) async {
        let words = full.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        guard words.count > 1 else {
            streamingText = full
            try? await Task.sleep(nanoseconds: 130_000_000)
            return
        }
        let perWord = min(0.05, max(0.012, 0.9 / Double(words.count)))
        var acc = ""
        for (i, w) in words.enumerated() {
            acc += (i == 0 ? "" : " ") + w
            streamingText = acc
            if Task.isCancelled { break }
            try? await Task.sleep(nanoseconds: UInt64(perWord * 1_000_000_000))
        }
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

// MARK: - AIStudyMemory
//
//  Lightweight, on-device long-term memory for Updo AI. The coach normally
//  starts each conversation cold (only the last few messages travel to the
//  model). This store lets the assistant remember durable facts the student
//  states about themselves — goals, exams they're worried about, subjects they
//  struggle with, preferred study times — so the coaching feels continuous
//  instead of amnesiac. Facts are written by the model via the `remember` tool
//  and injected back into every context prompt.
//
//  Purely local (UserDefaults): no tokens, no network, no backend row. One
//  signed-in user per device, mirroring UpdoAIChatStore's storage model.

@MainActor
final class AIStudyMemory: ObservableObject {
    static let shared = AIStudyMemory()

    private let storageKey = "updo_ai_study_memory_v1"
    private let maxNotes = 8
    private let maxNoteLength = 140

    /// Most-recent-first. Newest durable facts push out the oldest.
    @Published private(set) var notes: [String] = []

    private init() { load() }

    /// Store a durable fact about the student. Deduplicates (diacritic- and
    /// case-insensitive) and caps the list so the context stays small.
    func remember(_ raw: String) {
        let clean = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxNoteLength))
        guard clean.count >= 3 else { return }

        let folded = fold(clean)
        notes.removeAll { fold($0) == folded }
        notes.insert(clean, at: 0)
        if notes.count > maxNotes { notes = Array(notes.prefix(maxNotes)) }
        persist()
    }

    func forget(_ note: String) {
        let folded = fold(note)
        notes.removeAll { fold($0) == folded }
        persist()
    }

    func clear() {
        notes = []
        persist()
    }

    /// A compact block for the system prompt, or nil when there's nothing to
    /// remember yet. Model-facing scaffolding — bilingual inline like the rest
    /// of the AI layer (never a user-visible string).
    func contextBlock(en: Bool) -> String? {
        guard !notes.isEmpty else { return nil }
        let header = en
            ? "What you already know about this student (use it to personalize; never read it back verbatim)"
            : "Bu öğrenci hakkında bildiklerin (kişiselleştirmek için kullan; asla birebir tekrar etme)"
        return header + ":\n" + notes.map { "• \($0)" }.joined(separator: "\n")
    }

    private func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive],
                  locale: Locale(identifier: "tr"))
         .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func load() {
        notes = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
    }

    private func persist() {
        UserDefaults.standard.set(notes, forKey: storageKey)
    }
}
