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

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    private init() {}

    // MARK: - Permission

    func requestPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        guard settings.authorizationStatus == .notDetermined else { return }

        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("🔴 Notification permission error:", error)
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

            let content = UNMutableNotificationContent()
            content.sound = .default
            content.title = event.title
            content.body = minutesBefore == 0
                ? "Ders başladı."
                : "\(minutesBefore) dk sonra başlıyor."

            let request = UNNotificationRequest(
                identifier: eventID(for: event, minutesBefore: minutesBefore),
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
                print("🟢 Scheduled one-shot:", request.identifier)
            } catch {
                print("🔴 Schedule one-shot error:", error)
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

        let content = UNMutableNotificationContent()
        content.sound = .default
        content.title = event.title
        content.body = minutesBefore == 0
            ? "Ders başladı."
            : "\(minutesBefore) dk sonra başlıyor."

        let request = UNNotificationRequest(
            identifier: eventID(for: event, minutesBefore: minutesBefore),
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            print("🟢 Scheduled repeating:", request.identifier)
        } catch {
            print("🔴 Schedule repeating error:", error)
        }
    }

    // MARK: - FOCUS NOTIFICATIONS

    func scheduleFocusFinishedNotification(title: String, after seconds: Int) async {
        guard seconds > 0 else { return }

        await requestPermissionIfNeeded()
        await cancelAllFocusFinishedNotifications()

        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.sound = .default
        content.title = "Focus tamamlandı"
        content.body = "\(title) oturumu bitti."
        content.categoryIdentifier = "FOCUS_FINISHED"

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
            print("🟢 Focus finish scheduled:", request.identifier)
        } catch {
            print("🔴 Focus finish schedule error:", error)
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

        print("📬 Pending notifications count:", pending.count)
        for req in pending {
            print("•", req.identifier)
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
