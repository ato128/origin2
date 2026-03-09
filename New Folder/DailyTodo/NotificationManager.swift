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

    // İstersen Settings'ten kapatmak için AppStorage da ekleriz.
    // Şimdilik basit.

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

    /// Tüm ders bildirimlerini yeniden kurar (en sağlıklısı bu)
    func rescheduleAll(events: [EventItem]) async {
        await requestPermissionIfNeeded()
        await cancelAllEventNotifications()

        for e in events {
            await schedule(for: e, minutesBefore: 10)  // 10 dk önce
            await schedule(for: e, minutesBefore: 0)   // ders başlarken
        }
    }

    /// Sadece derslerle ilgili bildirimleri iptal et
    func cancelAllEventNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()

        let ids = pending
            .map(\.identifier)
            .filter { $0.hasPrefix("event.") }

        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    func cancel(for event: EventItem) async {
        let center = UNUserNotificationCenter.current()
        let ids = notificationIDs(for: event)
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    // ✅ EKLENDİ: EditEventView’de çağırdığın sync versiyon
    // (Senin EditEventView’de async bekletmeden çağırman için)
    func remove(for event: EventItem) {
        let center = UNUserNotificationCenter.current()
        let ids = notificationIDs(for: event)
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    func schedule(for event: EventItem, minutesBefore: Int) async {
        let center = UNUserNotificationCenter.current()

        // Haftalık tekrar eden trigger:
        // weekday: 0=Pzt...6=Paz  →  Calendar weekday: 2=Pzt...1=Paz
        // (Gregorian: 1=Sun, 2=Mon, ...7=Sat)
        let cal = Calendar.current
        let mappedWeekday = mapWeekdayToGregorian(event.weekday)

        let startHour = event.startMinute / 60
        let startMin  = event.startMinute % 60

        // Bildirim saati = ders saati - offset
        let notifDate = cal.date(bySettingHour: startHour, minute: startMin, second: 0, of: Date()) ?? Date()
        let adjusted = cal.date(byAdding: .minute, value: -minutesBefore, to: notifDate) ?? notifDate

        let notifHour = cal.component(.hour, from: adjusted)
        let notifMin  = cal.component(.minute, from: adjusted)

        var comps = DateComponents()
        comps.weekday = mappedWeekday
        comps.hour = notifHour
        comps.minute = notifMin

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let content = UNMutableNotificationContent()
        content.sound = .default
        content.title = event.title

        if minutesBefore == 0 {
            content.body = "Ders başladı."
        } else {
            content.body = "\(minutesBefore) dk sonra başlıyor."
        }

        let request = UNNotificationRequest(
            identifier: id(for: event, minutesBefore: minutesBefore),
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            print("🟢 Scheduled:", request.identifier)
        } catch {
            print("🔴 Schedule error:", error)
        }
    }

    // MARK: - Helpers

    // Senin mevcut identifier formatın:
    // "event.<uuid>.before.<minutes>"
    private func id(for event: EventItem, minutesBefore: Int) -> String {
        "event.\(event.id.uuidString).before.\(minutesBefore)"
    }

    // ✅ remove/cancel için aynı formatta 0 ve 10 dk id’leri
    private func notificationIDs(for event: EventItem) -> [String] {
        [
            id(for: event, minutesBefore: 10),
            id(for: event, minutesBefore: 0)
        ]
    }

    private func mapWeekdayToGregorian(_ weekday: Int) -> Int {
        // event: 0=Pzt..6=Paz
        // greg: 1=Paz,2=Pzt,3=Sal,4=Çar,5=Per,6=Cum,7=Cmt
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
