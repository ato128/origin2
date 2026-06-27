//
//  NotificationContentFactory.swift
//  DailyTodo
//
//  Single source of truth for locally-scheduled notification content. Every Updo
//  notification built here gets consistent, professional treatment:
//    • the live app-icon attachment (rich media)
//    • a thread identifier (so iOS groups related notifications)
//    • a relevance score (ordering in the stack / summary)
//    • an interruption level
//
//  Centralizing this keeps the schedulers focused on *when* and *why*, while the
//  factory owns *how a notification looks*.
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
        attachIcon: Bool = true,
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

        if attachIcon, let icon = NotificationIconRenderer.makeIconAttachment() {
            content.attachments = [icon]
        }

        return content
    }
}
