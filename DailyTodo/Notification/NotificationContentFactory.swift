//
//  NotificationContentFactory.swift
//  DailyTodo
//
//  Single source of truth for locally-scheduled notification content. Every Updo
//  notification built here gets consistent, professional treatment:
//    • a thread identifier (so iOS groups related notifications)
//    • a relevance score (ordering in the stack / summary)
//    • an interruption level
//
//  NOTE: we intentionally do NOT attach a custom app-icon image. iOS already shows
//  the app icon on the leading edge; a second rendered icon as a trailing
//  attachment looked doubled-up and could lag the chosen icon. The standard system
//  icon is the clean, native look.
//

import UserNotifications

@MainActor
enum NotificationContentFactory {

    static func make(
        title: String,
        body: String,
        category: String,
        threadID: String,
        userInfo: [String: Any] = [:],
        relevance: Double = 0.5,
        interruption: UNNotificationInterruptionLevel = .active,
        attachIcon: Bool = false,
        sound: UNNotificationSound = .default
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        content.categoryIdentifier = category
        content.threadIdentifier = threadID
        content.userInfo = userInfo
        content.relevanceScore = relevance
        content.interruptionLevel = interruption
        // Custom icon attachment intentionally omitted — the system app icon is the
        // single, native notification icon. (`attachIcon` kept for source compat.)
        _ = attachIcon
        return content
    }
}
