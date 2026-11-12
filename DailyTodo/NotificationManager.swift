//
//  NotificationManager.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 4.03.2026.
//
import SwiftUI
import Foundation
import UserNotifications
import Combine
import UIKit

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    private init() {}

    // MARK: - Permission

    // The system prompt can be shown once, ever — so it is never raised cold.
    // New users are asked by the onboarding first ("want a heads-up before
    // class?") and only a "yes" leads to the prompt. Everything that runs on
    // its own (launch, rescheduling) goes through `requestPermissionIfNeeded`,
    // which stays silent until onboarding is over and while a "not now" is
    // still fresh.

    private static let primerDeclinedAtKey = "notifPrimerDeclinedAtV1"
    private static let onboardingDoneKey = "didFinishFullOnboardingV2"
    /// How long a "not now" in onboarding is respected before the app may ask.
    private static let declineSnooze: TimeInterval = 3 * 24 * 3600

    /// iOS has not been asked yet.
    func isUndetermined() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .notDetermined
    }

    private var mayPromptOnItsOwn: Bool {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: Self.onboardingDoneKey) else { return false }
        let declinedAt = defaults.double(forKey: Self.primerDeclinedAtKey)
        guard declinedAt > 0 else { return true }
        return Date().timeIntervalSince1970 - declinedAt > Self.declineSnooze
    }

    /// Automatic paths (launch, rescheduling). Prompts only when allowed to.
    func requestPermissionIfNeeded() async {
        guard mayPromptOnItsOwn, await isUndetermined() else { return }
        await prompt()
    }

    /// The user just said yes to our own question — show the system prompt now.
    @discardableResult
    func requestPermissionFromPrimer() async -> Bool {
        guard await isUndetermined() else {
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            return status == .authorized || status == .provisional
        }
        return await prompt()
    }

    /// The user said "not now" to our own question.
    func recordPrimerDeclined() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.primerDeclinedAtKey)
    }

    @discardableResult
    private func prompt() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            if granted { UIApplication.shared.registerForRemoteNotifications() }
            return granted
        } catch {
            Log.debug("🔴 Notification permission error:", error)
            return false
        }
    }

    // MARK: - EVENT NOTIFICATIONS

    /// Tüm event bildirimlerini yeniden kurar
    func rescheduleAll(events: [EventItem]) async {
        await requestPermissionIfNeeded()
        await cancelAllEventNotifications()

        for event in events where !event.isCompleted {
            await schedule(for: event, minutesBefore: 10)
            await schedule(for: event, minutesBefore: 0)
        }
    }

    /// Sadece ders/event bildirimlerini iptal et
    func cancelAllEventNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()

        let ids = pending
            .map(\.identifier)
            .filter { $0.hasPrefix("event.") }

        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }
    
    func cancelAllManagedNotifications() async {
        await cancelAllEventNotifications()
        await cancelAllFocusFinishedNotifications()
    }

    func cancel(for event: EventItem) async {
        let center = UNUserNotificationCenter.current()
        let ids = eventNotificationIDs(for: event)
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    /// Sync versiyon
    func remove(for event: EventItem) {
        let center = UNUserNotificationCenter.current()
        let ids = eventNotificationIDs(for: event)
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    func schedule(for event: EventItem, minutesBefore: Int) async {
        guard !event.isCompleted else { return }

        await requestPermissionIfNeeded()

        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current

        if let scheduledDate = event.scheduledDate {
            let targetDate = calendar.date(
                byAdding: .minute,
                value: -minutesBefore,
                to: scheduledDate
            ) ?? scheduledDate

            if targetDate <= Date() { return }

            let comps = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: targetDate
            )

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: comps,
                repeats: false
            )

            let content = NotificationContentFactory.make(
                title: event.title,
                body: minutesBefore == 0
                    ? tr("nm_class_started")
                    : tr("nm_starts_in", minutesBefore),
                category: "EVENT_REMINDER",
                threadID: "event.\(event.id.uuidString)",
                relevance: 0.7
            )

            let request = UNNotificationRequest(
                identifier: eventID(for: event, minutesBefore: minutesBefore),
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
                Log.debug("🟢 Scheduled one-shot:", request.identifier)
            } catch {
                Log.debug("🔴 Schedule one-shot error:", error)
            }

            return
        }

        let mappedWeekday = mapWeekdayToGregorian(event.weekday)

        let startHour = event.startMinute / 60
        let startMinute = event.startMinute % 60

        let baseDate = calendar.date(
            bySettingHour: startHour,
            minute: startMinute,
            second: 0,
            of: Date()
        ) ?? Date()

        let adjusted = calendar.date(
            byAdding: .minute,
            value: -minutesBefore,
            to: baseDate
        ) ?? baseDate

        let notifHour = calendar.component(.hour, from: adjusted)
        let notifMinute = calendar.component(.minute, from: adjusted)

        var comps = DateComponents()
        comps.weekday = mappedWeekday
        comps.hour = notifHour
        comps.minute = notifMinute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: comps,
            repeats: true
        )

        let content = NotificationContentFactory.make(
            title: event.title,
            body: minutesBefore == 0
                ? tr("nm_class_started")
                : tr("nm_starts_in", minutesBefore),
            category: "EVENT_REMINDER",
            threadID: "event.\(event.id.uuidString)",
            relevance: 0.7
        )

        let request = UNNotificationRequest(
            identifier: eventID(for: event, minutesBefore: minutesBefore),
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            Log.debug("🟢 Scheduled repeating:", request.identifier)
        } catch {
            Log.debug("🔴 Schedule repeating error:", error)
        }
    }

    // MARK: - FOCUS NOTIFICATIONS

    func scheduleFocusFinishedNotification(title: String, after seconds: Int) async {
        guard seconds > 0 else { return }

        await requestPermissionIfNeeded()
        await cancelAllFocusFinishedNotifications()

        let center = UNUserNotificationCenter.current()

        let content = NotificationContentFactory.make(
            title: tr("nm_focus_done"),
            body: "\(title) oturumu bitti.",
            category: "FOCUS_FINISHED",
            threadID: "focus.finished",
            relevance: 0.9
        )

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(seconds),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: focusFinishedID(),
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            Log.debug("🟢 Focus finish scheduled:", request.identifier)
        } catch {
            Log.debug("🔴 Focus finish schedule error:", error)
        }
    }

    func cancelAllFocusFinishedNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()

        let ids = pending
            .map(\.identifier)
            .filter { $0.hasPrefix("focus.finished.") }

        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    // MARK: - DEBUG

    func printPendingRequests() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()

        Log.debug("📬 Pending notifications count:", pending.count)
        for req in pending {
            Log.debug("•", req.identifier)
        }
    }

    // MARK: - Helpers

    private func eventID(for event: EventItem, minutesBefore: Int) -> String {
        "event.\(event.id.uuidString).before.\(minutesBefore)"
    }

    private func eventNotificationIDs(for event: EventItem) -> [String] {
        [
            eventID(for: event, minutesBefore: 10),
            eventID(for: event, minutesBefore: 0)
        ]
    }

    private func focusFinishedID() -> String {
        "focus.finished.main"
    }

    private func mapWeekdayToGregorian(_ weekday: Int) -> Int {
        switch weekday {
        case 0: return 2 // Pzt
        case 1: return 3 // Sal
        case 2: return 4 // Çar
        case 3: return 5 // Per
        case 4: return 6 // Cum
        case 5: return 7 // Cmt
        case 6: return 1 // Paz
        default: return 2
        }
    }
}
