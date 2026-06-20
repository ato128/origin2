//
//  StudyCoachStore.swift
//  DailyTodo
//

import Foundation
import Combine
import UserNotifications

struct CoachMessage: Identifiable, Codable {
    var id = UUID()
    let role: String   // "user" or "assistant"
    let text: String
    let timestamp: Date
    var wasCached: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, role, text, timestamp, wasCached
    }

    var anthropicMessage: [String: String] {
        ["role": role, "content": text]
    }
}

struct CoachRoutineItem: Identifiable, Codable {
    var id = UUID()
    let time: String
    let activity: String
    let duration: Int
    let course: String
}

struct CoachRoutine: Codable {
    let title: String
    let items: [CoachRoutineItem]
}

@MainActor
final class StudyCoachStore: ObservableObject {
    @Published var messages: [CoachMessage] = []
    @Published var currentRoutine: CoachRoutine? = nil
    @Published var isThinking = false
    @Published var streamingText = ""
    @Published var error: String? = nil
    @Published var lastWasCached = false

    private let messagesKey = "study_coach_messages_v2"
    private let routineKey = "study_coach_routine_v2"

    init() { loadPersisted() }

    // MARK: - Send (returns wasCached)

    @discardableResult
    func sendMessage(_ text: String) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 10 else { return false }

        let hash = MessageCacheManager.shared.hash(for: trimmed)

        // Cache hit
        if let cached = MessageCacheManager.shared.lookup(hash) {
            let userMsg = CoachMessage(role: "user", text: trimmed, timestamp: .now)
            let assistMsg = CoachMessage(role: "assistant", text: cached, timestamp: .now, wasCached: true)
            messages.append(userMsg)
            messages.append(assistMsg)
            lastWasCached = true
            persist()
            return true
        }

        // Cache miss — stream from API
        let userMsg = CoachMessage(role: "user", text: trimmed, timestamp: .now)
        messages.append(userMsg)
        isThinking = true
        streamingText = ""
        error = nil
        lastWasCached = false
        persist()

        // Limit to last 3 messages (including the one just appended)
        let history = Array(messages.suffix(3)).map(\.anthropicMessage)
        let system = PromptBuilder.studyCoachSystemCompressed()

        do {
            var fullText = ""
            for try await chunk in await AIService.shared.streamMessages(
                system: system,
                messages: history,
                maxTokens: 150
            ) {
                fullText += chunk
                streamingText = fullText
            }

            streamingText = ""
            MessageCacheManager.shared.store(hash: hash, response: fullText)

            let assistMsg = CoachMessage(role: "assistant", text: fullText, timestamp: .now)
            messages.append(assistMsg)

            if let routine = extractRoutine(from: fullText) {
                currentRoutine = routine
                scheduleRoutineNotification(routine)
            }

            persist()
        } catch {
            self.error = error.localizedDescription
            messages.removeLast() // remove the user message on failure
            persist()
        }

        isThinking = false
        return false
    }

    // MARK: - First message

    func startCoaching(courses: [String], goals: String, languageCode: String) async {
        guard messages.isEmpty else { return }
        let text = PromptBuilder.studyCoachFirstMessage(
            courses: courses,
            goals: goals,
            languageCode: languageCode
        )
        await sendMessage(text)
    }

    func clearHistory() {
        messages = []
        currentRoutine = nil
        streamingText = ""
        error = nil
        persist()
    }

    // MARK: - Routine extraction

    private func extractRoutine(from text: String) -> CoachRoutine? {
        guard let start = text.range(of: "<routine>"),
              let end = text.range(of: "</routine>") else { return nil }
        let json = String(text[start.upperBound..<end.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(CoachRoutine.self, from: data)
    }

    // MARK: - Push notification

    private func scheduleRoutineNotification(_ routine: CoachRoutine) {
        guard let first = routine.items.first else { return }
        let parts = first.time.split(separator: ":").map { Int($0) }
        guard parts.count == 2, let hour = parts[0], let minute = parts[1] else { return }

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Çalışma Koçu"
            content.body = "\(first.time) — \(first.activity) (\(first.duration) dk)"
            content.sound = .default
            var comps = DateComponents()
            comps.hour = hour; comps.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let req = UNNotificationRequest(identifier: "study_coach_daily", content: content, trigger: trigger)
            center.add(req)
        }
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: messagesKey)
        }
        if let r = currentRoutine, let data = try? JSONEncoder().encode(r) {
            UserDefaults.standard.set(data, forKey: routineKey)
        }
    }

    private func loadPersisted() {
        if let data = UserDefaults.standard.data(forKey: messagesKey),
           let saved = try? JSONDecoder().decode([CoachMessage].self, from: data) {
            messages = saved
        }
        if let data = UserDefaults.standard.data(forKey: routineKey),
           let saved = try? JSONDecoder().decode(CoachRoutine.self, from: data) {
            currentRoutine = saved
        }
    }
}
