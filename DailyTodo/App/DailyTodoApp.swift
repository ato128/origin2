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

            let context = ModelContext(container)
            _todoStore = StateObject(
                wrappedValue: TodoStore(context: context)
            )

        } catch {
            fatalError("SwiftData container oluşturulamadı: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .id(languageManager.selectedLanguage)
                .modelContainer(container)
                .environmentObject(todoStore)
                .environmentObject(session)
                .environmentObject(crewStore)
                .environmentObject(friendStore)
                .environmentObject(languageManager)
                .environment(\.locale, languageManager.activeLocale)
                .overlay {
                    InAppBannerOverlay()
                }
                .onAppear {
                    let context = ModelContext(container)

                    WidgetAppSync.refreshFromSwiftData(context: context)

                    LiveActivityScheduler.shared.registerBGTask()
                    LiveActivityScheduler.shared.startForegroundLoop(container: container)

                    let currentUserID = session.currentUser?.id.uuidString
                    todoStore.setCurrentUserID(currentUserID)
                    LiveActivityScheduler.shared.setCurrentUserID(currentUserID)

                    syncCurrentUserIDToDefaults(session.currentUser?.id)

                    let descriptor = FetchDescriptor<EventItem>(
                        sortBy: [SortDescriptor(\EventItem.startMinute, order: .forward)]
                    )
                    let allEvents = (try? context.fetch(descriptor)) ?? []
                    let scopedEvents = allEvents.filter { $0.ownerUserID == currentUserID }

                    Task {
                        await NotificationManager.shared.requestPermissionIfNeeded()
                        await NotificationManager.shared.rescheduleAll(events: scopedEvents)

                        await MainActor.run {
                            print("📡 REGISTERING FOR REMOTE NOTIFICATIONS FROM ONAPPEAR...")
                            UIApplication.shared.registerForRemoteNotifications()
                        }

                        // Token kaydetmeyi burada YAPMA — user hazır olmayabilir.
                        // onChange(session.currentUser?.id) ve didReceiveAPNSToken handle edecek.
                    }
                }
                .onChange(of: session.currentUser?.id) { _, newID in
                    let userIDString = newID.map { $0.uuidString }

                    todoStore.setCurrentUserID(userIDString)
                    LiveActivityScheduler.shared.setCurrentUserID(userIDString)

                    syncCurrentUserIDToDefaults(newID)

                    let context = ModelContext(container)
                    WidgetAppSync.refreshFromSwiftData(context: context)

                    Task { @MainActor in
                        LiveActivityScheduler.shared.rescheduleBackgroundTask(container: container)
                    }

                    let descriptor = FetchDescriptor<EventItem>(
                        sortBy: [SortDescriptor(\EventItem.startMinute, order: .forward)]
                    )
                    let allEvents = (try? context.fetch(descriptor)) ?? []
                    let scopedEvents = allEvents.filter { $0.ownerUserID == userIDString }

                    Task {
                        await NotificationManager.shared.requestPermissionIfNeeded()
                        await NotificationManager.shared.rescheduleAll(events: scopedEvents)

                        await MainActor.run {
                            print("📡 FORCE REGISTER FROM USER CHANGE...")
                            UIApplication.shared.registerForRemoteNotifications()
                        }

                        // APNS token register async — biraz bekle, sonra kaydet
                        try? await Task.sleep(nanoseconds: 3_000_000_000)

                        if let newID {
                            print("💾 TOKEN KAYIT DENEMESİ (onChange)...")
                            await PushTokenStore().saveCurrentToken(currentUserID: newID)
                        }
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        LiveActivityScheduler.shared.startForegroundLoop(container: container)
                        let context = ModelContext(container)
                        WidgetAppSync.refreshFromSwiftData(context: context)

                        // Uygulama açıldığında token yenile
                        if let userID = session.currentUser?.id {
                            Task {
                                await PushTokenStore().saveCurrentToken(currentUserID: userID)
                            }
                        }
                    } else if newPhase == .background {
                        LiveActivityScheduler.shared.stopForegroundLoop()
                        LiveActivityScheduler.shared.rescheduleBackgroundTask(container: container)
                    }
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: .openURLFromNotification)) { output in
                    guard let url = output.object as? URL else { return }
                    handleIncomingURL(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: .didReceiveAPNSToken)) { _ in
                    guard let userID = session.currentUser?.id else {
                        // User henüz hazır değil — onChange zaten handle edecek
                        print("⚠️ APNS TOKEN GELDİ AMA SESSION HAZIR DEĞİL")
                        return
                    }

                    print("💾 TOKEN KAYIT DENEMESİ (didReceiveAPNSToken)...")
                    Task {
                        await PushTokenStore().saveCurrentToken(currentUserID: userID)
                    }
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
            else { return }

            NotificationCenter.default.post(
                name: .openFriendChatFromNotification,
                object: friendshipID
            )
            return
        }

        if url.host == "crew-chat" {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let crewID = components.queryItems?.first(where: { $0.name == "crew_id" })?.value
            else { return }

            NotificationCenter.default.post(
                name: .openCrewChatFromNotification,
                object: crewID
            )
            return
        }
    }

    private func handleLiveActivityURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let action = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if action == "stop" {
            Task { await LiveActivityManager.shared.end() }
        }
    }

    private func handleIncomingInviteURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        NotificationCenter.default.post(name: .openCrewInviteFromLink, object: code)
    }
}

extension Notification.Name {
    static let openWeekFromWidget = Notification.Name("openWeekFromWidget")
    static let openCrewInviteFromLink = Notification.Name("openCrewInviteFromLink")
}
