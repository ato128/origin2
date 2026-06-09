//
//  FocusCompletionRecorder.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 27.04.2026.
//

import Foundation
import SwiftData

extension Notification.Name {
    static let focusSessionRecordSaved = Notification.Name("focusSessionRecordSaved")
}

@MainActor
final class FocusCompletionRecorder {
    static let shared = FocusCompletionRecorder()
    private init() {}

    private struct PendingFocusRecord: Codable, Hashable {
        let id: UUID
        let ownerUserID: String?
        let title: String
        let startedAt: Date
        let endedAt: Date
        let totalSeconds: Int
        let completedSeconds: Int
        let isCompleted: Bool

        var stableKey: String {
            [
                ownerUserID ?? "anonymous",
                title,
                "\(Int(startedAt.timeIntervalSince1970))",
                "\(Int(endedAt.timeIntervalSince1970))",
                "\(totalSeconds)",
                "\(completedSeconds)"
            ].joined(separator: "|")
        }
    }

    private let pendingStorageKey = "pending_focus_completion_records_v1"
    private let savedStableKeysKey = "saved_focus_completion_record_keys_v1"

    var container: ModelContainer?

    func configure(container: ModelContainer) {
        self.container = container
        retryPendingRecords(reason: "configure")
    }

    func saveCompletedSession(
        ownerUserID: String?,
        title: String,
        startedAt: Date,
        endedAt: Date,
        totalSeconds: Int,
        completedSeconds: Int,
        isCompleted: Bool
    ) {
        let pending = PendingFocusRecord(
            id: UUID(),
            ownerUserID: ownerUserID,
            title: title,
            startedAt: startedAt,
            endedAt: endedAt,
            totalSeconds: totalSeconds,
            completedSeconds: completedSeconds,
            isCompleted: isCompleted
        )

        savePendingIfNeeded(pending)
        persistPendingRecordIfPossible(pending, reason: "saveCompletedSession")
    }

    func retryPendingRecords(reason: String) {
        let records = loadPendingRecords()

        guard !records.isEmpty else { return }

        print("🟡 FOCUS RECORD RETRY:", reason, "count:", records.count)

        for record in records {
            persistPendingRecordIfPossible(record, reason: reason)
        }
    }

    private func persistPendingRecordIfPossible(
        _ pending: PendingFocusRecord,
        reason: String
    ) {
        guard let container else {
            print("⏳ FOCUS RECORD WAITING FOR CONTAINER:", reason)
            return
        }

        if hasAlreadySaved(pending) {
            removePending(pending)
            print("⚪️ FOCUS RECORD DUPLICATE SKIPPED:", pending.title)
            return
        }

        let context = ModelContext(container)

        let record = FocusSessionRecord(
            ownerUserID: pending.ownerUserID,
            title: pending.title,
            startedAt: pending.startedAt,
            endedAt: pending.endedAt,
            totalSeconds: pending.totalSeconds,
            completedSeconds: pending.completedSeconds,
            isCompleted: pending.isCompleted
        )

        context.insert(record)

        do {
            try context.save()

            markSaved(pending)
            removePending(pending)

            print("✅ FOCUS RECORD SAVED:", pending.title, pending.completedSeconds)

            NotificationCenter.default.post(
                name: .focusSessionRecordSaved,
                object: record
            )
        } catch {
            print("❌ FOCUS RECORD SAVE ERROR:", error.localizedDescription)
            savePendingIfNeeded(pending)
        }
    }

    private func savePendingIfNeeded(_ record: PendingFocusRecord) {
        if hasAlreadySaved(record) { return }

        var records = loadPendingRecords()

        if records.contains(where: { $0.stableKey == record.stableKey }) {
            return
        }

        records.append(record)
        storePendingRecords(records)

        print("🟡 FOCUS RECORD PENDING STORED:", record.title)
    }

    private func removePending(_ record: PendingFocusRecord) {
        var records = loadPendingRecords()
        records.removeAll { $0.stableKey == record.stableKey }
        storePendingRecords(records)
    }

    private func loadPendingRecords() -> [PendingFocusRecord] {
        guard let data = UserDefaults.standard.data(forKey: pendingStorageKey) else {
            return []
        }

        return (try? JSONDecoder().decode([PendingFocusRecord].self, from: data)) ?? []
    }

    private func storePendingRecords(_ records: [PendingFocusRecord]) {
        let limited = Array(records.suffix(40))

        if let data = try? JSONEncoder().encode(limited) {
            UserDefaults.standard.set(data, forKey: pendingStorageKey)
        }
    }

    private func hasAlreadySaved(_ record: PendingFocusRecord) -> Bool {
        let keys = savedStableKeys()
        return keys.contains(record.stableKey)
    }

    private func markSaved(_ record: PendingFocusRecord) {
        var keys = savedStableKeys()
        keys.insert(record.stableKey)

        let limited = Array(keys.suffix(120))
        UserDefaults.standard.set(limited, forKey: savedStableKeysKey)
    }

    private func savedStableKeys() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: savedStableKeysKey) ?? []
        return Set(array)
    }
}
