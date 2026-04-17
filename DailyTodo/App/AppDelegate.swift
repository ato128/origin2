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

        print("✅ APP DID FINISH LAUNCHING")

        requestPushPermissionAndRegister(application)

        if let remotePayload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            handleNotificationPayload(remotePayload)
        }

        return true
    }

    private func requestPushPermissionAndRegister(_ application: UIApplication) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("📡 REGISTERING FOR REMOTE NOTIFICATIONS...")
                    application.registerForRemoteNotifications()
                }

            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                    if let error {
                        print("🔴 NOTIFICATION PERMISSION ERROR:", error.localizedDescription)
                    }

                    print("🔔 NOTIFICATION PERMISSION GRANTED:", granted)

                    guard granted else { return }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        print("📡 REGISTERING FOR REMOTE NOTIFICATIONS...")
                        application.registerForRemoteNotifications()
                    }
                }

            case .denied:
                print("⛔️ NOTIFICATION PERMISSION DENIED")

            @unknown default:
                break
            }
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        application.applicationIconBadgeNumber = 0
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("🟢 APNS TOKEN:", token)

        UserDefaults.standard.set(token, forKey: "apns_device_token")
        UserDefaults.standard.synchronize()

        NotificationCenter.default.post(name: .didReceiveAPNSToken, object: nil)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo

        if shouldShowCustomInAppBanner(for: userInfo) {
            let title = notification.request.content.title.isEmpty
                ? "Yeni bildirim"
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

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        handleNotificationPayload(userInfo)
        completionHandler()
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

        case "crew_focus_invite":
            return false

        case "focus_room":
            return false

        default:
            return false
        }
    }

    private func shouldShowCustomInAppBanner(for userInfo: [AnyHashable: Any]) -> Bool {
        guard UIApplication.shared.applicationState == .active else { return false }
        return !shouldSuppressSystemBanner(for: userInfo)
    }

    private func handleNotificationPayload(_ userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else {
            if let deepLink = userInfo["deep_link"] as? String,
               let url = URL(string: deepLink) {
                NotificationCenter.default.post(
                    name: .openURLFromNotification,
                    object: url
                )
            }
            return
        }

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
                    name: .presentActiveCrewFocusFromNotification,
                    object: crewID
                )

                NotificationCenter.default.post(
                    name: .openCrewFocusFromNotification,
                    object: crewID
                )
            }

        case "crew_focus_invite":
            NotificationCenter.default.post(
                name: .presentCrewFocusInviteSheet,
                object: userInfo
            )

           

        default:
            break
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
    static let openURLFromNotification = Notification.Name("openURLFromNotification")
    static let didReceiveAPNSToken = Notification.Name("didReceiveAPNSToken")

    static let presentCrewFocusInviteSheet = Notification.Name("presentCrewFocusInviteSheet")
    static let presentActiveCrewFocusFromNotification = Notification.Name("presentActiveCrewFocusFromNotification")
    static let openCrewFocusInviteFromNotification = Notification.Name("openCrewFocusInviteFromNotification")
    static let openCrewFocusFromNotification = Notification.Name("openCrewFocusFromNotification")
}
