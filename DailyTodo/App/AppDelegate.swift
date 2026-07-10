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

        Log.debug("✅ APP DID FINISH LAUNCHING")

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
                    Log.debug("📡 REGISTERING FOR REMOTE NOTIFICATIONS...")
                    application.registerForRemoteNotifications()
                }

            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                    if let error {
                        Log.debug("🔴 NOTIFICATION PERMISSION ERROR:", error.localizedDescription)
                    }

                    Log.debug("🔔 NOTIFICATION PERMISSION GRANTED:", granted)

                    guard granted else { return }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        Log.debug("📡 REGISTERING FOR REMOTE NOTIFICATIONS...")
                        application.registerForRemoteNotifications()
                    }
                }

            case .denied:
                Log.debug("⛔️ NOTIFICATION PERMISSION DENIED")

            @unknown default:
                break
            }
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        application.applicationIconBadgeNumber = 0

        Task { @MainActor in
            PushTokenStore.shared.saveCurrentTokenWithRetry(reason: "applicationDidBecomeActive")

            FocusSessionManager.shared.reconcileExpiredSessionIfNeeded(
                reason: "applicationDidBecomeActive"
            )
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        #if DEBUG
        Log.debug("🟢 APNS TOKEN:", token)
        #endif

        Task { @MainActor in
            PushTokenStore.shared.storeToken(token)
            PushTokenStore.shared.saveCurrentTokenWithRetry(reason: "didRegisterForRemoteNotifications")
        }

        NotificationCenter.default.post(name: .didReceiveAPNSToken, object: nil)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Log.debug("🔴 APNS REGISTER FAILED:", error.localizedDescription)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo

        if let type = userInfo["type"] as? String, type == "crew_focus_invite" {
            NotificationCenter.default.post(
                name: .presentCrewFocusInviteSheet,
                object: userInfo
            )
            completionHandler([])
            return
        }

        if let type = userInfo["type"] as? String, type == "friend_focus_invite" {
            NotificationCenter.default.post(
                name: .presentFriendFocusInviteSheet,
                object: userInfo
            )
            completionHandler([])
            return
        }

        // Live duo updates — apply silently to the running session, banner only.
        if let type = userInfo["type"] as? String,
           ["friend_focus_joined", "friend_focus_left", "friend_focus_declined", "friend_focus_ended"].contains(type) {
            NotificationCenter.default.post(
                name: .friendFocusPeerEvent,
                object: userInfo
            )
        }

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

        case "crew_focus_invite", "friend_focus_invite":
            return true

        case "focus_room":
            return false

        case "crew_focus_ended", "crew_focus_left", "crew_focus_joined", "focus_ended_local":
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
                Task { @MainActor in
                    FocusSessionManager.shared.reconcileExpiredSessionIfNeeded(
                        reason: "notification_tap_focus_room"
                    )

                    NotificationCenter.default.post(
                        name: .presentActiveCrewFocusFromNotification,
                        object: crewID
                    )

                    NotificationCenter.default.post(
                        name: .openCrewFocusFromNotification,
                        object: crewID
                    )

                    NotificationCenter.default.post(
                        name: .focusNotificationOpened,
                        object: userInfo
                    )
                }
            }

        case "crew_focus_invite":
            NotificationCenter.default.post(
                name: .presentCrewFocusInviteSheet,
                object: userInfo
            )
            return

        case "friend_focus_invite":
            NotificationCenter.default.post(
                name: .presentFriendFocusInviteSheet,
                object: userInfo
            )
            return

        case "friend_focus_joined", "friend_focus_left", "friend_focus_declined", "friend_focus_ended":
            NotificationCenter.default.post(
                name: .friendFocusPeerEvent,
                object: userInfo
            )
            return

        case "focus_ended_local":
            Task { @MainActor in
                // A local (personal) session finalizes on-device with the real
                // summary — do NOT post presentFocusCompletionFromPush here, that
                // fallback builds a crew-flavored summary and used to hijack the
                // personal celebration.
                FocusSessionManager.shared.reconcileExpiredSessionIfNeeded(
                    reason: "notification_tap_focus_ended_local"
                )

                NotificationCenter.default.post(
                    name: .focusNotificationOpened,
                    object: userInfo
                )
            }

        case "crew_focus_ended":
            Task { @MainActor in
                FocusSessionManager.shared.reconcileExpiredSessionIfNeeded(
                    reason: "notification_tap_crew_focus_ended"
                )

                NotificationCenter.default.post(
                    name: .presentFocusCompletionFromPush,
                    object: userInfo
                )

                NotificationCenter.default.post(
                    name: .focusNotificationOpened,
                    object: userInfo
                )

                if let crewID = userInfo["crew_id"] as? String {
                    NotificationCenter.default.post(
                        name: .openCrewFocusFromNotification,
                        object: crewID
                    )
                }
            }

        case "crew_focus_left":
            Log.debug("📢 CREW FOCUS LEFT:", userInfo["leaver_name"] ?? "")

            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .focusNotificationOpened,
                    object: userInfo
                )
            }

        case "crew_focus_joined":
            Log.debug("📢 CREW FOCUS JOINED:", userInfo["joined_name"] ?? "")

            NotificationCenter.default.post(
                name: .crewFocusJoinedFromNotification,
                object: userInfo
            )

            Task { @MainActor in
                NotificationCenter.default.post(
                    name: .focusNotificationOpened,
                    object: userInfo
                )
            }

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
    static let presentFriendFocusInviteSheet = Notification.Name("presentFriendFocusInviteSheet")
    static let friendFocusPeerEvent = Notification.Name("friendFocusPeerEvent")
    static let presentActiveCrewFocusFromNotification = Notification.Name("presentActiveCrewFocusFromNotification")
    static let openCrewFocusInviteFromNotification = Notification.Name("openCrewFocusInviteFromNotification")
    static let openCrewFocusFromNotification = Notification.Name("openCrewFocusFromNotification")

    static let presentFocusCompletionFromPush = Notification.Name("presentFocusCompletionFromPush")
    static let crewFocusJoinedFromNotification = Notification.Name("crewFocusJoinedFromNotification")

    static let focusNotificationOpened = Notification.Name("focusNotificationOpened")
}
