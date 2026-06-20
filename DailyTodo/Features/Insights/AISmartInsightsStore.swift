//
//  AISmartInsightsStore.swift
//  DailyTodo
//

import Foundation
import Combine
import SwiftUI

struct AIInsightItem: Identifiable, Codable {
    var id = UUID()
    let title: String
    let body: String
    let icon: String
    let accent: String

    enum CodingKeys: String, CodingKey {
        case title, body, icon, accent
    }
}

@MainActor
final class AISmartInsightsStore: ObservableObject {
    @Published var insights: [AIInsightItem] = []
    @Published var isLoading = false
    @Published var error: String? = nil

    private let cacheKey = "ai_smart_insights_cache"
    private let cacheDateKey = "ai_smart_insights_date"

    func loadIfNeeded(
        sessions: [FocusSessionRecord],
        tasks: [DTTaskItem],
        userID: String?,
        languageCode: String
    ) {
        if let cached = loadCache(), isCacheFresh() {
            insights = cached
            return
        }
        Task { await fetch(sessions: sessions, tasks: tasks, userID: userID, languageCode: languageCode) }
    }

    func refresh(
        sessions: [FocusSessionRecord],
        tasks: [DTTaskItem],
        userID: String?,
        languageCode: String
    ) {
        Task { await fetch(sessions: sessions, tasks: tasks, userID: userID, languageCode: languageCode) }
    }

    private func fetch(
        sessions: [FocusSessionRecord],
        tasks: [DTTaskItem],
        userID: String?,
        languageCode: String
    ) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        let scopedSessions = userID == nil
            ? sessions
            : sessions.filter { $0.ownerUserID == userID || $0.ownerUserID == nil }

        let scopedTasks = userID == nil
            ? tasks
            : tasks.filter { $0.ownerUserID == userID }

        do {
            let system = PromptBuilder.smartInsightsSystem()
            let user = PromptBuilder.smartInsightsUser(
                sessions: scopedSessions,
                tasks: scopedTasks,
                languageCode: languageCode
            )

            let raw = try await AIService.shared.complete(system: system, user: user, maxTokens: 512)

            var json = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if json.hasPrefix("```") {
                json = json.components(separatedBy: "\n").dropFirst().dropLast().joined(separator: "\n")
            }

            guard let data = json.data(using: .utf8),
                  let items = try? JSONDecoder().decode([AIInsightItem].self, from: data) else {
                error = tr("asi_parse_failed")
                isLoading = false
                return
            }

            insights = items
            saveCache(items)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Cache

    private func isCacheFresh() -> Bool {
        guard let saved = UserDefaults.standard.object(forKey: cacheDateKey) as? Date else { return false }
        return Calendar.current.isDateInToday(saved)
    }

    private func loadCache() -> [AIInsightItem]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode([AIInsightItem].self, from: data)
    }

    private func saveCache(_ items: [AIInsightItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
        UserDefaults.standard.set(Date(), forKey: cacheDateKey)
    }
}
