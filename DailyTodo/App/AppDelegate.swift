//
//  AppDelegate.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 21.03.2026.
//

import UIKit
import UserNotifications
import FirebaseCore

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        let center = UNUserNotificationCenter.current()
        center.delegate = self

        application.registerForRemoteNotifications()

        if let remotePayload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            handleNotificationPayload(remotePayload)
        }

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        application.applicationIconBadgeNumber = 0
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
        let userInfo = notification.request.content.userInfo

        if shouldShowCustomInAppBanner(for: userInfo) {
            let title = notification.request.content.title.isEmpty
                ? "Yeni mesaj"
                : notification.request.content.title

            let body = notification.request.content.body

            Task { @MainActor in
                InAppBannerCenter.shared.show(
                    title: title,
                    message: body,
                    payload: userInfo
                )
            }

            completionHandler([])
            return
        }

        if shouldSuppressSystemBanner(for: userInfo) {
            completionHandler([])
            return
        }

        completionHandler([.banner, .sound, .badge])
    }

    private func shouldSuppressSystemBanner(for userInfo: [AnyHashable: Any]) -> Bool {
        guard let type = userInfo["type"] as? String else { return false }

        switch type {
        case "friend_chat":
            guard let incomingFriendshipID = userInfo["friendship_id"] as? String else { return false }
            let activeFriendshipID = UserDefaults.standard.string(forKey: "active_friendship_id")
            return activeFriendshipID == incomingFriendshipID

        case "crew_chat":
            guard let incomingCrewID = userInfo["crew_id"] as? String else { return false }
            let activeCrewID = UserDefaults.standard.string(forKey: "active_crew_id")
            return activeCrewID == incomingCrewID

        default:
            return false
        }
    }

    private func shouldShowCustomInAppBanner(for userInfo: [AnyHashable: Any]) -> Bool {
        guard UIApplication.shared.applicationState == .active else { return false }
        return !shouldSuppressSystemBanner(for: userInfo)
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
                if let friendshipID = userInfo["friendship_id"] as? String {
                    NotificationCenter.default.post(
                        name: .openFriendChatFromNotification,
                        object: friendshipID
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
