//
//  SmartNotificationScheduler.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 4.06.2026.
//

import Foundation
import SwiftData
import UserNotifications

@MainActor
final class SmartNotificationScheduler {
    static let shared = SmartNotificationScheduler()

    private init() {}

    private let smartPrefix = "smart."

    func reschedule(
        context: ModelContext,
        currentUserID: String?,
        reason: String
    ) async {
        guard let currentUserID, !currentUserID.isEmpty else {
            Log.debug("SMART NOTIFICATIONS SKIPPED: missing currentUserID")
            return
        }

        await NotificationManager.shared.requestPermissionIfNeeded()

        let tasks = fetchTasks(context: context, currentUserID: currentUserID)
        let exams = fetchExams(context: context, currentUserID: currentUserID)
        let events = fetchEvents(context: context, currentUserID: currentUserID)
        let focusRecords = fetchFocusRecords(context: context, currentUserID: currentUserID)

        let candidates = SmartNotificationBrain.makeCandidates(
            tasks: tasks,
            exams: exams,
            events: events,
            focusRecords: focusRecords
        )

        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let pendingIDs = Set(pending.map(\.identifier))

        // A pending smart notification whose condition no longer holds must
        // die here — e.g. the streak-risk nudge after the user already saved
        // today's streak. The brain regenerates every still-valid candidate
        // with the same day-keyed ID, so anything pending but absent is stale.
        let validIDs = Set(candidates.map(\.id))
        let staleIDs = pendingIDs.filter { $0.hasPrefix(smartPrefix) && !validIDs.contains($0) }
        if !staleIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(staleIDs))
            Log.debug("SMART NOTIFICATIONS CANCELLED (stale):", staleIDs.joined(separator: ", "))
        }

        guard !candidates.isEmpty else {
            Log.debug("SMART NOTIFICATIONS: no candidates - \(reason)")
            return
        }

        var scheduledCount = 0

        for candidate in candidates {
            if pendingIDs.contains(candidate.id) {
                // Still valid — re-add with the same identifier so the body
                // reflects the current numbers (streak days etc.), not the
                // ones from when it was first scheduled.
                try? await schedule(candidate)
                continue
            }

            guard SmartNotificationHistory.shared.canSchedule(
                id: candidate.id,
                category: candidate.category,
                triggerAt: candidate.triggerDate
            ) else {
                continue
            }

            do {
                try await schedule(candidate)
                SmartNotificationHistory.shared.recordScheduled(
                    id: candidate.id,
                    category: candidate.category,
                    triggerAt: candidate.triggerDate
                )
                scheduledCount += 1
            } catch {
                Log.debug("SMART NOTIFICATION SCHEDULE ERROR:", error.localizedDescription)
            }

            if scheduledCount >= 2 {
                break
            }
        }

        Log.debug("SMART NOTIFICATIONS SCHEDULED:", scheduledCount, "reason:", reason)
    }

    func cancelAllSmartNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()

        let ids = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(smartPrefix) }

        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    private func schedule(_ candidate: SmartNotificationCandidate) async throws {
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: candidate.triggerDate
        )

        let relevance = min(1.0, Double(candidate.priority) / 100.0)

        let content = NotificationContentFactory.make(
            title: candidate.title,
            body: candidate.body,
            category: "SMART_NOTIFICATION",
            threadID: "smart.\(candidate.category.rawValue)",
            userInfo: [
                "type": "smart_notification",
                "smart_category": candidate.category.rawValue,
                "deep_link": candidate.deepLink
            ],
            relevance: relevance
        )

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: candidate.id,
            content: content,
            trigger: trigger
        )

        try await center.add(request)

        Log.debug("SMART NOTIFICATION ADDED:", candidate.id, candidate.title)
    }

    // MARK: - Fetch

    private func fetchTasks(
        context: ModelContext,
        currentUserID: String
    ) -> [DTTaskItem] {
        do {
            let descriptor = FetchDescriptor<DTTaskItem>(
                sortBy: [
                    SortDescriptor(\DTTaskItem.createdAt, order: .reverse)
                ]
            )

            return try context.fetch(descriptor).filter {
                $0.ownerUserID == currentUserID
            }
        } catch {
            Log.debug("SMART TASK FETCH ERROR:", error.localizedDescription)
            return []
        }
    }

    private func fetchExams(
        context: ModelContext,
        currentUserID: String
    ) -> [ExamItem] {
        do {
            let descriptor = FetchDescriptor<ExamItem>(
                sortBy: [
                    SortDescriptor(\ExamItem.examDate, order: .forward)
                ]
            )

            return try context.fetch(descriptor).filter {
                $0.ownerUserID == currentUserID
            }
        } catch {
            Log.debug("SMART EXAM FETCH ERROR:", error.localizedDescription)
            return []
        }
    }

    private func fetchEvents(
        context: ModelContext,
        currentUserID: String
    ) -> [EventItem] {
        do {
            let descriptor = FetchDescriptor<EventItem>()
            return try context.fetch(descriptor).filter {
                $0.ownerUserID == currentUserID
            }
        } catch {
            Log.debug("SMART EVENT FETCH ERROR:", error.localizedDescription)
            return []
        }
    }

    private func fetchFocusRecords(
        context: ModelContext,
        currentUserID: String
    ) -> [FocusSessionRecord] {
        do {
            let descriptor = FetchDescriptor<FocusSessionRecord>(
                sortBy: [
                    SortDescriptor(\FocusSessionRecord.endedAt, order: .reverse)
                ]
            )

            return try context.fetch(descriptor).filter {
                $0.ownerUserID == currentUserID
            }
        } catch {
            Log.debug("SMART FOCUS RECORD FETCH ERROR:", error.localizedDescription)
            return []
        }
    }
}
