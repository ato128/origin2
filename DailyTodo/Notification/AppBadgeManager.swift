//
//  AppBadgeManager.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 3.06.2026.
//

import UIKit
import UserNotifications

@MainActor
final class AppBadgeManager {
    static let shared = AppBadgeManager()

    private init() {}

    func clearBadge() {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0) { error in
                if let error {
                    Log.debug("❌ CLEAR BADGE ERROR:", error.localizedDescription)
                } else {
                    Log.debug("✅ APP BADGE CLEARED")
                }
            }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }

    func setBadge(_ count: Int) {
        let safeCount = max(0, count)

        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(safeCount) { error in
                if let error {
                    Log.debug("❌ SET BADGE ERROR:", error.localizedDescription)
                } else {
                    Log.debug("✅ APP BADGE SET:", safeCount)
                }
            }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = safeCount
        }
    }
}
