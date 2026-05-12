//
//  DailyTodoApp.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import SwiftUI
import SwiftData
import WidgetKit
import UserNotifications
import UIKit

@main
struct DailyTodoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    private let container: ModelContainer
    private let appGroupID = "group.com.atakan.updo"

    @StateObject private var session = SessionStore()
    @StateObject private var crewStore = CrewStore()
    @StateObject private var friendStore = FriendStore()
    @StateObject private var todoStore: TodoStore
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var focusSession = FocusSessionManager.shared
    @StateObject private var studentStore: StudentStore

    @State private var openFocusFromNotification: Bool = false

    init() {
        do {
            guard let groupURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupID
            ) else {
                fatalError("App Group container bulunamadı")
            }

            let supportURL = groupURL.appendingPathComponent("Library/Application Support")

            try FileManager.default.createDirectory(
                at: supportURL,
                withIntermediateDirectories: true
            )

            let storeURL = supportURL.appendingPathComponent("default.store")

            let schema = Schema([
                DTTaskItem.self,
                WorkoutExerciseItem.self,
                WorkoutExerciseHistoryItem.self,
                EventItem.self,
                ExamItem.self,
                StudentProfile.self,
                Course.self,
                ExamStudyPlanItem.self,
                IdentityProgressState.self,
                FocusSessionRecord.self,
                Crew.self,
                CrewMember.self,
                CrewTask.self,
                CrewActivity.self,
                Friend.self,
                FriendMessage.self,
                SharedWeekItem.self,
                FriendFocusSession.self,
                CrewMessage.self,
                CrewFocusSession.self,
                CrewFocusRecord.self,
                FriendRequest.self
            ])

            let configuration = ModelConfiguration(
                schema: schema,
                url: storeURL
            )

            container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )

            FocusCompletionRecorder.shared.configure(container: container)

            let context = ModelContext(container)

            _todoStore = StateObject(
                wrappedValue: TodoStore(context: context)
            )

            _studentStore = StateObject(
                wrappedValue: StudentStore(context: context)
            )

        } catch {
            fatalError("SwiftData container oluşturulamadı: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            rootContent
        }
    }

    private var rootContent: some View {
        RootView(
            openFocusFromNotification: $openFocusFromNotification
        )
        .id(languageManager.selectedLanguage)
        .modelContainer(container)
        .environmentObject(todoStore)
        .environmentObject(session)
        .environmentObject(crewStore)
        .environmentObject(friendStore)
        .environmentObject(languageManager)
        .environmentObject(focusSession)
        .environment(\.locale, languageManager.activeLocale)
        .environmentObject(studentStore)
        .overlay {
            InAppBannerOverlay()
        }
        .onAppear {
            handleAppAppear()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didReceiveAPNSToken)) { _ in
            handleAPNSTokenNotification()
        }
        .onChange(of: session.currentUser?.id) { _, newID in
            handleCurrentUserChanged(newID)
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChanged(newPhase)
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openURLFromNotification)) { output in
            guard let url = output.object as? URL else { return }
            handleIncomingURL(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .presentActiveCrewFocusFromNotification)) { _ in
            openFocusFromNotification = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .presentCrewFocusInviteSheet)) { _ in
            openFocusFromNotification = true
        }
    }

    private func handleAppAppear() {
        observeAPNSTokenNotificationIfNeeded()

        Task {
            await session.restoreSupabaseSessionIfNeeded()

            await MainActor.run {
                PushTokenStore.shared.saveCurrentTokenWithRetry(
                    reason: "onAppear after session restore"
                )
            }
        }

        let context = ModelContext(container)

        WidgetAppSync.refreshFromSwiftData(context: context)

        LiveActivityScheduler.shared.registerBGTask()
        LiveActivityScheduler.shared.startForegroundLoop(container: container)

        let currentUserID = session.currentUser?.id.uuidString

        todoStore.setCurrentUserID(currentUserID)
        studentStore.setCurrentUserID(currentUserID)
        LiveActivityScheduler.shared.setCurrentUserID(currentUserID)

        syncCurrentUserIDToDefaults(session.currentUser?.id)

        if let userID = session.currentUser?.id {
            updateFriendPresence(isOnline: true)
            bootstrapFriendRealtime(for: userID)
        }

        rescheduleLocalNotificationsAndRegisterPush(reason: "onAppear")

        Task {
            await ChatBackendClient.shared.testMe()
        }
    }

    private func observeAPNSTokenNotificationIfNeeded() {
        NotificationCenter.default.removeObserver(
            self,
            name: .didReceiveAPNSToken,
            object: nil
        )

        NotificationCenter.default.addObserver(
            forName: .didReceiveAPNSToken,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                print("🔥 TOKEN RECEIVED -> SAVE WITH RETRY")
                PushTokenStore.shared.saveCurrentTokenWithRetry(
                    reason: "didReceiveAPNSToken observer"
                )
            }
        }
    }

    private func handleAPNSTokenNotification() {
        Task { @MainActor in
            print("🔥 TOKEN RECEIVED -> SAVE WITH RETRY FROM ONRECEIVE")
            PushTokenStore.shared.saveCurrentTokenWithRetry(
                reason: "didReceiveAPNSToken onReceive"
            )
        }
    }

    private func handleCurrentUserChanged(_ newID: UUID?) {
        let userIDString = newID.map { $0.uuidString }

        todoStore.setCurrentUserID(userIDString)
        studentStore.setCurrentUserID(userIDString)
        LiveActivityScheduler.shared.setCurrentUserID(userIDString)

        syncCurrentUserIDToDefaults(newID)

        friendStore.unsubscribePresenceRealtime()
        friendStore.unsubscribeFriendshipsRealtime()

        if let newID {
            updateFriendPresence(isOnline: true)
            bootstrapFriendRealtime(for: newID)
        }

        let context = ModelContext(container)
        WidgetAppSync.refreshFromSwiftData(context: context)

        Task { @MainActor in
            LiveActivityScheduler.shared.rescheduleBackgroundTask(container: container)
        }

        rescheduleLocalNotificationsAndRegisterPush(reason: "session user changed")

        guard newID != nil else { return }

        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            await MainActor.run {
                print("💾 TOKEN SAVE RETRY (user change)...")
                PushTokenStore.shared.forceResaveCurrentToken(
                    reason: "session user changed"
                )
            }
        }
    }

    private func handleScenePhaseChanged(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            LiveActivityScheduler.shared.startForegroundLoop(container: container)

            let context = ModelContext(container)
            WidgetAppSync.refreshFromSwiftData(context: context)

            friendStore.setAppActive(true)
            updateFriendPresence(isOnline: true)

            if let userID = session.currentUser?.id {
                bootstrapFriendRealtime(for: userID)
            }

            Task { @MainActor in
                print("🔥 PUSH TOKEN SAVE ON ACTIVE")
                PushTokenStore.shared.saveCurrentTokenWithRetry(
                    reason: "scene active"
                )
            }

        case .inactive:
            friendStore.setAppActive(false)

        case .background:
            friendStore.setAppActive(false)
            updateFriendPresence(isOnline: false)

            LiveActivityScheduler.shared.stopForegroundLoop()
            LiveActivityScheduler.shared.rescheduleBackgroundTask(container: container)

        @unknown default:
            break
        }
    }

    private func rescheduleLocalNotificationsAndRegisterPush(reason: String) {
        let context = ModelContext(container)
        let currentUserID = session.currentUser?.id.uuidString

        let descriptor = FetchDescriptor<EventItem>(
            sortBy: [SortDescriptor(\EventItem.startMinute, order: .forward)]
        )

        let allEvents = (try? context.fetch(descriptor)) ?? []
        let scopedEvents = allEvents.filter { $0.ownerUserID == currentUserID }

        Task {
            await NotificationManager.shared.requestPermissionIfNeeded()
            await NotificationManager.shared.rescheduleAll(events: scopedEvents)

            await MainActor.run {
                print("📡 REGISTERING FOR REMOTE NOTIFICATIONS:", reason)
                UIApplication.shared.registerForRemoteNotifications()

                PushTokenStore.shared.saveCurrentTokenWithRetry(
                    reason: "register remote notifications - \(reason)"
                )
            }
        }
    }

    private func updateFriendPresence(isOnline: Bool) {
        guard let userID = session.currentUser?.id else { return }

        Task {
            await friendStore.setPresence(
                currentUserID: userID,
                isOnline: isOnline
            )
        }
    }

    private func bootstrapFriendRealtime(for userID: UUID) {
        Task {
            await friendStore.loadAllFriendships(currentUserID: userID)

            let otherUserIDs = friendStore.friendships.compactMap { friendship -> UUID? in
                if friendship.requester_id == userID {
                    return friendship.addressee_id
                }

                if friendship.addressee_id == userID {
                    return friendship.requester_id
                }

                return nil
            }

            await friendStore.loadPresence(for: otherUserIDs)

            await MainActor.run {
                friendStore.subscribeToFriendshipsRealtime(currentUserID: userID)
                friendStore.subscribeToPresenceRealtime(for: otherUserIDs)
            }
        }
    }

    private func syncCurrentUserIDToDefaults(_ userID: UUID?) {
        if let userID {
            UserDefaults.standard.set(userID.uuidString, forKey: "current_user_id")
        } else {
            UserDefaults.standard.removeObject(forKey: "current_user_id")
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "dailytodo" else { return }

        if url.host == "live" {
            handleLiveActivityURL(url)
            return
        }

        if url.host == "week" {
            NotificationCenter.default.post(name: .openWeekFromWidget, object: nil)
            return
        }

        if url.host == "join-crew" {
            handleIncomingInviteURL(url)
            return
        }

        if url.host == "friend-chat" {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let friendshipID = components.queryItems?.first(where: { $0.name == "friendship_id" })?.value
            else {
                return
            }

            NotificationCenter.default.post(
                name: .openFriendChatFromNotification,
                object: friendshipID
            )
            return
        }

        if url.host == "crew-chat" {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let crewID = components.queryItems?.first(where: { $0.name == "crew_id" })?.value
            else {
                return
            }

            NotificationCenter.default.post(
                name: .openCrewChatFromNotification,
                object: crewID
            )
            return
        }
    }

    private func handleLiveActivityURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }

        let action = components.path.trimmingCharacters(
            in: CharacterSet(charactersIn: "/")
        )

        if action == "stop" {
            Task {
                await LiveActivityManager.shared.end()
            }
        }
    }

    private func handleIncomingInviteURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return
        }

        NotificationCenter.default.post(
            name: .openCrewInviteFromLink,
            object: code
        )
    }
}

extension Notification.Name {
    static let openWeekFromWidget = Notification.Name("openWeekFromWidget")
    static let openCrewInviteFromLink = Notification.Name("openCrewInviteFromLink")
}
