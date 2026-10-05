//
//  UpdoAIChatStore.swift
//  DailyTodo
//

import Foundation
import Combine
import QuartzCore
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
    @Published var isSending: Bool = false
    @Published var error: String? = nil
    @Published var lastPreviewText: String = ""

    /// The live reply being written. Deliberately NOT a `@Published` property of
    /// this store: every token used to republish the whole store, re-evaluating
    /// the entire chat screen (background, toolbar, every materialized message
    /// row) dozens of times a second. Only the streaming bubble observes this.
    let stream = AIStreamPacer()

    /// The assistant message that was just committed from the live stream — the
    /// list shows it without an insertion transition so the hand-off is seamless.
    private(set) var streamedMessageID: UUID?

    /// Output ceiling per turn. The model is told to keep chat short and only go
    /// long for explanations/solutions, so this is headroom, not a target — the
    /// old 300 cut worked solutions off mid-step. (Backend caps coach at 1024.)
    private static let replyTokenBudget = 900
    private static let historyTurns = 20
    private static let historyCharsPerTurn = 1_500

    private let storageKey = "updo_ai_messages_v1"
    private let previewKey = "updo_ai_last_preview"
    /// Only the tail is ever shown (and only the last 8 travel to the model);
    /// an unbounded history made every persist() re-encode the whole chat.
    private let maxStoredMessages = 200

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

        // Last 20 turns so a longer explanation keeps its thread; each turn is
        // clipped so one very long old answer can't balloon the input cost.
        let history = Array(messages.suffix(Self.historyTurns)).compactMap { msg -> [String: String]? in
            guard msg.role == "user" || msg.role == "assistant" else { return nil }
            var m = msg.anthropicMessage
            if let content = m["content"], content.count > Self.historyCharsPerTurn {
                m["content"] = String(content.prefix(Self.historyCharsPerTurn)) + "…"
            }
            return m
        }

        do {
            let usesBYO = BYOKeyStore.shared.readKey() != nil
            var replyText = ""

            if usesBYO {
                // BYO key path stays on the non-streaming endpoint (the stream
                // endpoint uses our own OpenAI key). Typewriter-reveal the result.
                replyText = try await sendNonStreaming(
                    contextPrompt: contextPrompt, history: history, credits: credits, onTool: onTool
                )
            } else {
                // AGENTIC LOOP (Phase 2). Native OpenAI tool-calling across turns:
                // stream a turn; if the model calls a tool, apply it locally, append
                // the assistant tool-call + the tool RESULT (native format) and
                // stream again — until the model gives a final text reply. Capped.
                // Any continuation failure falls back to the last action's local
                // confirmation, so behaviour never regresses.
                var convo: [[String: Any]] = history.map {
                    ["role": $0["role"] ?? "user", "content": $0["content"] ?? ""]
                }
                var lastResult: String? = nil
                var producedText = ""
                let maxIterations = 4
                var iteration = 0

                while iteration < maxIterations {
                    iteration += 1
                    // The first turn was already credit-gated at the top of send();
                    // gate every continuation so a chain can't outrun the free pool.
                    if iteration > 1 {
                        guard credits.canSendChatMessage else { break }
                    }

                    stream.reset()
                    var turnText = ""
                    var turnTool: AIToolCall? = nil
                    var receivedAny = false
                    var streamError: Error? = nil
                    do {
                        for try await event in AIService.shared.coachChatStream(
                            system: contextPrompt, messages: convo, maxTokens: Self.replyTokenBudget
                        ) {
                            switch event {
                            case .delta(let chunk):
                                receivedAny = true
                                turnText += chunk
                                stream.append(chunk)
                            case .tool(let tool):
                                receivedAny = true
                                turnTool = tool
                            case .status(let label):
                                // Server is doing a silent round-trip (e.g. a web
                                // search). Show a live hint until the answer streams
                                // in and overwrites it; don't flip `receivedAny` so a
                                // status alone can't defeat the first-turn fallback.
                                if turnText.isEmpty, label == "web_search" {
                                    stream.setStatus(appLanguageIsEnglish()
                                        ? "Searching the web…"
                                        : "Web'de aranıyor…")
                                }
                            case .done:
                                break
                            }
                        }
                    } catch {
                        streamError = error
                    }

                    if let e = streamError {
                        // First turn, nothing produced, endpoint unavailable → the
                        // existing non-streaming fallback keeps chat working.
                        if iteration == 1, !receivedAny, Self.isStreamFallbackEligible(e) {
                            stream.reset()
                            replyText = try await sendNonStreaming(
                                contextPrompt: contextPrompt, history: history, credits: credits, onTool: onTool
                            )
                            commitReply(replyText)
                            isSending = false
                            return
                        }
                        // A quota/rate error on turn 1 must surface, not fall back.
                        if iteration == 1 { throw e }
                        // Continuation failure → stop; fall back to last confirmation.
                        break
                    }

                    // Deduct credits on each successful turn (optimistic; backend truth).
                    credits.noteMessageSent()

                    if let tool = turnTool {
                        // Apply the action, then feed the real result back natively so
                        // the model can chain the next action or write a smart closing.
                        let result = onTool(tool)
                        lastResult = result
                        let callID = "call_" + String(
                            UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12)
                        )
                        let argsJSON = (try? JSONSerialization.data(withJSONObject: tool.args))
                            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                        convo.append([
                            "role": "assistant",
                            "content": "",
                            "tool_calls": [[
                                "id": callID,
                                "type": "function",
                                "function": ["name": tool.name, "arguments": argsJSON],
                            ]],
                        ])
                        convo.append(["role": "tool", "tool_call_id": callID, "content": result])
                        continue
                    }

                    let trimmed = turnText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { producedText = trimmed }
                    break
                }

                if producedText.isEmpty {
                    // No final text (cap / failure) → typewriter the last action
                    // confirmation, or error if nothing was produced at all.
                    guard let r = lastResult else { throw AIServiceError.invalidResponse }
                    stream.reset()
                    await revealReply(r)
                    replyText = r
                } else {
                    // Let the paced reveal finish writing the tail before the
                    // bubble is swapped for the committed message.
                    await stream.drain()
                    replyText = producedText
                }
            }

            commitReply(replyText)
        } catch {
            stream.reset()
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

    /// Non-streaming coach call: used for BYO keys and as the fallback when the
    /// streaming endpoint is unavailable. Applies credits + typewriter-reveals;
    /// the caller commits the returned reply. Throws on quota/rate/blank.
    private func sendNonStreaming(
        contextPrompt: String,
        history: [[String: String]],
        credits: DailyCreditsManager,
        onTool: @MainActor (AIToolCall) -> String
    ) async throws -> String {
        let (fullText, tool) = try await AIService.shared.coachChat(
            system: contextPrompt, messages: history, maxTokens: Self.replyTokenBudget
        )
        credits.noteMessageSent()
        let replyText: String
        if let tool {
            replyText = onTool(tool)
        } else {
            guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AIServiceError.invalidResponse
            }
            replyText = fullText
        }
        await revealReply(replyText)
        return replyText
    }

    /// Appends the finished reply and clears the live bubble in the SAME main-
    /// actor turn, so SwiftUI renders one frame: the streaming row disappears and
    /// the committed row takes its place (no empty/typing flash in between).
    private func commitReply(_ text: String) {
        let reply = AIMessage(role: "assistant", text: text, timestamp: .now)
        streamedMessageID = stream.hasContent ? reply.id : nil
        messages.append(reply)
        stream.reset()
        lastPreviewText = text
        UserDefaults.standard.set(text, forKey: previewKey)
        persist()
    }

    /// A streaming failure is "endpoint unavailable" (backend not deployed yet,
    /// 404/5xx, transport) → fall back to non-streaming. A real quota/rate limit
    /// must surface to the user instead of silently retrying.
    private static func isStreamFallbackEligible(_ error: Error) -> Bool {
        switch error {
        case AIServiceError.insufficientCredits,
             AIServiceError.dailyFreeLimitReached,
             AIServiceError.rateLimited:
            return false
        default:
            return true
        }
    }

    /// Writes an already-complete reply (BYO key / non-streaming fallback /
    /// action confirmation) through the same paced reveal as a live stream.
    private func revealReply(_ full: String) async {
        stream.append(full)
        await stream.drain()
    }

    /// Appends an assistant-only line locally (no network, no credit spend).
    /// Used by the schedule-scan flow to talk the user through "send photos →
    /// added to your week".
    func appendAssistant(_ text: String) {
        messages.append(AIMessage(role: "assistant", text: text, timestamp: .now))
        lastPreviewText = text
        UserDefaults.standard.set(text, forKey: previewKey)
        persist()
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
        if messages.count > maxStoredMessages {
            messages.removeFirst(messages.count - maxStoredMessages)
        }
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func clearHistory() {
        messages = []
        stream.reset()
        persist()
    }
}

// MARK: - AIStreamPacer
//
//  Turns a bursty token stream into a steady, ChatGPT/Claude-style write-on.
//  Network chunks land in a backlog; a display link reveals characters at an
//  adaptive rate (a calm base speed that accelerates with the backlog, so it
//  never lags far behind the model) and stamps each character's reveal time.
//  The bubble fades/settles the freshest characters in from those timestamps.
//  Ticks only while there's something to reveal or settle — idle costs nothing.

@MainActor
final class AIStreamPacer: ObservableObject {
    struct Frame: Equatable {
        /// Revealed text so far.
        var text: String = ""
        /// Settle progress (0…1) of the newest characters, newest first.
        var tail: [Double] = []
        /// A transient server-side status (e.g. web search) shown before text.
        var status: String? = nil
    }

    @Published private(set) var frame = Frame()

    /// Seconds a freshly revealed character takes to fully settle in.
    static let settleDuration: CFTimeInterval = 0.32

    private var chars: [Character] = []
    private var revealed = 0
    private var revealTimes: [CFTimeInterval] = []   // newest-last, trimmed
    private var carry: Double = 0
    private var finishing = false
    private var lastTick: CFTimeInterval = 0
    private var link: CADisplayLink?
    private var waiters: [CheckedContinuation<Void, Never>] = []

    var hasContent: Bool { !chars.isEmpty }

    func append(_ chunk: String) {
        guard !chunk.isEmpty else { return }
        chars.append(contentsOf: chunk)
        if frame.status != nil { frame.status = nil }
        startIfNeeded()
    }

    func setStatus(_ label: String) {
        guard chars.isEmpty else { return }
        frame.status = label
    }

    /// Resolves once every received character is revealed and settled. Speeds
    /// the remaining backlog up so the tail never takes more than ~½ s.
    func drain() async {
        guard revealed < chars.count || !frame.tail.isEmpty else { return }
        finishing = true
        startIfNeeded()
        await withCheckedContinuation { waiters.append($0) }
    }

    func reset() {
        stop()
        chars.removeAll(keepingCapacity: true)
        revealTimes.removeAll(keepingCapacity: true)
        revealed = 0
        carry = 0
        finishing = false
        if frame != Frame() { frame = Frame() }
        resumeWaiters()
    }

    // MARK: Display link

    private func startIfNeeded() {
        guard link == nil else { return }
        let target = AIStreamPacerLinkTarget(owner: self)
        let l = CADisplayLink(target: target, selector: #selector(AIStreamPacerLinkTarget.tick))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        l.add(to: .main, forMode: .common)
        link = l
        lastTick = CACurrentMediaTime()
    }

    private func stop() {
        link?.invalidate()
        link = nil
    }

    private func resumeWaiters() {
        let w = waiters
        waiters.removeAll()
        w.forEach { $0.resume() }
    }

    fileprivate func tick() {
        let now = CACurrentMediaTime()
        let dt = min(1.0 / 20.0, max(0, now - lastTick))
        lastTick = now

        var text = frame.text
        let backlog = chars.count - revealed
        if backlog > 0 {
            // ~45 chars/s when the model is slow, catching up proportionally to
            // the backlog (steady state ≈ a few tenths of a second behind).
            var rate = 45 + Double(backlog) * 3.2
            if finishing { rate = max(rate, Double(backlog) / 0.4) }
            carry += rate * dt
            let n = min(backlog, Int(carry))
            if n > 0 {
                carry -= Double(n)
                text.append(contentsOf: chars[revealed ..< revealed + n])
                // Spread the stamps across the frame so a multi-char step still
                // fades in as a gradient, not a block.
                for i in 0 ..< n {
                    revealTimes.append(now - dt * (1 - Double(i + 1) / Double(n)))
                }
                revealed += n
                if revealTimes.count > 160 { revealTimes.removeFirst(revealTimes.count - 160) }
            }
        } else {
            carry = 0
        }

        var tail: [Double] = []
        var k = revealTimes.count - 1
        while k >= 0 {
            let p = (now - revealTimes[k]) / Self.settleDuration
            if p >= 1 { break }
            tail.append(max(0, p))
            k -= 1
        }

        frame = Frame(text: text, tail: tail, status: nil)

        if revealed >= chars.count && tail.isEmpty {
            stop()
            if finishing {
                finishing = false
                resumeWaiters()
            }
        }
    }
}

/// CADisplayLink retains its target; this weak trampoline keeps the pacer free.
private final class AIStreamPacerLinkTarget: NSObject {
    weak var owner: AIStreamPacer?
    init(owner: AIStreamPacer) { self.owner = owner }

    @objc func tick() {
        MainActor.assumeIsolated { owner?.tick() }
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
