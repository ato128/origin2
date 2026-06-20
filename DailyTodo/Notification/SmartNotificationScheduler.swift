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
        let focusRecords = fetchFocusRecords(context: context, currentUserID: currentUserID)

        let candidates = SmartNotificationBrain.makeCandidates(
            tasks: tasks,
            exams: exams,
            focusRecords: focusRecords
        )

        guard !candidates.isEmpty else {
            Log.debug("SMART NOTIFICATIONS: no candidates - \(reason)")
            return
        }

        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let pendingIDs = Set(pending.map(\.identifier))

        var scheduledCount = 0

        for candidate in candidates {
            if pendingIDs.contains(candidate.id) {
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

        let content = UNMutableNotificationContent()
        content.title = candidate.title
        content.body = candidate.body
        content.sound = .default
        content.categoryIdentifier = "SMART_NOTIFICATION"
        content.userInfo = [
            "type": "smart_notification",
            "smart_category": candidate.category.rawValue,
            "deep_link": candidate.deepLink
        ]

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
