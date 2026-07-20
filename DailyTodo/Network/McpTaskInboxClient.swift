//
//  McpTaskInboxClient.swift
//  DailyTodo
//
//  ChatGPT (MCP bağlayıcısı) üzerinden eklenen görevleri backend'deki
//  gelen-kutusundan çeker, SwiftData'ya yazar ve tüketildi işaretler.
//  Uygulama öne geldiğinde çalışır; 2 dakikalık kısma ile spam yapmaz.
//

import Foundation
import SwiftData
import Supabase

@MainActor
enum McpTaskInbox {

    private static var lastSyncAt: Date?

    private struct InboxResponse: Decodable {
        let ok: Bool
        let tasks: [InboxTaskDTO]
    }

    private struct InboxTaskDTO: Decodable {
        let id: String
        let title: String
        let note: String?
        let dueDay: String?
        let durationMinutes: Int?
    }

    static func syncIfNeeded(container: ModelContainer, ownerUserID: String?) async {
        guard let ownerUserID, !ownerUserID.isEmpty else { return }

        if let last = lastSyncAt, Date().timeIntervalSince(last) < 120 { return }
        lastSyncAt = Date()

        guard let accessToken = try? await SupabaseManager.shared.client.auth.session.accessToken,
              let url = URL(string: "\(ChatBackendEnvironment.httpBaseURL)/v1/mcp/task-inbox")
        else { return }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }

            let decoded = try JSONDecoder().decode(InboxResponse.self, from: data)
            guard decoded.ok, !decoded.tasks.isEmpty else { return }

            let context = ModelContext(container)
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "yyyy-MM-dd"
            dayFormatter.timeZone = .current

            for task in decoded.tasks {
                let dueDate = task.dueDay.flatMap { dayFormatter.date(from: $0) }

                let item = DTTaskItem(
                    ownerUserID: ownerUserID,
                    title: task.title,
                    dueDate: dueDate,
                    notes: task.note ?? "",
                    scheduledWeekDate: dueDate,
                    scheduledWeekDurationMinutes: task.durationMinutes
                )
                context.insert(item)
            }

            try context.save()

            await consume(ids: decoded.tasks.map(\.id), accessToken: accessToken)

            Log.debug("🟢 MCP INBOX SYNCED:", decoded.tasks.count)
            NotificationCenter.default.post(name: .mcpTasksImported, object: decoded.tasks.count)
        } catch {
            Log.debug("MCP INBOX SYNC ERROR:", error.localizedDescription)
        }
    }

    private static func consume(ids: [String], accessToken: String) async {
        guard !ids.isEmpty,
              let url = URL(string: "\(ChatBackendEnvironment.httpBaseURL)/v1/mcp/task-inbox/consume")
        else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["ids": ids])

        _ = try? await URLSession.shared.data(for: request)
    }
}

extension Notification.Name {
    /// ChatGPT'den gelen görevler içe aktarıldığında yayınlanır (obj = adet).
    static let mcpTasksImported = Notification.Name("mcpTasksImported")
}
