//
//  AppDelegate.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 21.03.2026.
//

import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        if let notificationResponse = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            handleNotificationPayload(notificationResponse)
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("APNS TOKEN:", token)
        UserDefaults.standard.set(token, forKey: "apns_device_token")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNS REGISTER ERROR:", error.localizedDescription)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        handleNotificationPayload(userInfo)
        completionHandler()
    }

    private func handleNotificationPayload(_ userInfo: [AnyHashable: Any]) {
        if let type = userInfo["type"] as? String {
            switch type {
            case "crew_chat":
                if let crewID = userInfo["crew_id"] as? String {
                    NotificationCenter.default.post(
                        name: .openCrewChatFromNotification,
                        object: crewID
                    )
                }

            case "friend_chat":
                if let friendID = userInfo["friend_id"] as? String {
                    NotificationCenter.default.post(
                        name: .openFriendChatFromNotification,
                        object: friendID
                    )
                }

            case "focus_room":
                if let crewID = userInfo["crew_id"] as? String {
                    NotificationCenter.default.post(
                        name: .openCrewFocusFromNotification,
                        object: crewID
                    )
                }

            default:
                break
            }
        }

        if let deepLink = userInfo["deep_link"] as? String,
           let url = URL(string: deepLink) {
            NotificationCenter.default.post(
                name: .openURLFromNotification,
                object: url
            )
        }
    }
}

extension Notification.Name {
    static let openCrewChatFromNotification = Notification.Name("openCrewChatFromNotification")
    static let openFriendChatFromNotification = Notification.Name("openFriendChatFromNotification")
    static let openCrewFocusFromNotification = Notification.Name("openCrewFocusFromNotification")
    static let openURLFromNotification = Notification.Name("openURLFromNotification")
}
