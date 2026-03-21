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

@main
struct DailyTodoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    private let container: ModelContainer

    @StateObject private var session = SessionStore()
    @StateObject private var crewStore = CrewStore()
    @StateObject private var friendStore = FriendStore()
    @StateObject private var todoStore: TodoStore

    init() {
        do {
            container = try ModelContainer(
                for: DTTaskItem.self,
                WorkoutExerciseItem.self,
                WorkoutExerciseHistoryItem.self,
                EventItem.self,
                FocusSessionRecord.self,
                Crew.self,
                CrewMember.self,
                CrewTask.self,
                CrewActivity.self,
                CrewTaskComment.self,
                CrewTaskPoll.self,
                CrewTaskReaction.self,
                Friend.self,
                FriendMessage.self,
                SharedWeekItem.self,
                FriendFocusSession.self,
                CrewMessage.self,
                CrewFocusSession.self,
                CrewFocusRecord.self,
                FriendRequest.self
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
                .modelContainer(container)
                .environmentObject(todoStore)
                .environmentObject(session)
                .environmentObject(crewStore)
                .environmentObject(friendStore)
                .onAppear {
                    let context = ModelContext(container)
                    WidgetAppSync.refreshFromSwiftData(context: context)

                    LiveActivityScheduler.shared.registerBGTask()
                    LiveActivityScheduler.shared.startForegroundLoop(container: container)

                    PushNotificationManager.requestPermission()

                    todoStore.setCurrentUserID(session.currentUser?.id.uuidString)
                }
                .onChange(of: session.currentUser?.id) { _, newID in
                    todoStore.setCurrentUserID(newID?.uuidString)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        LiveActivityScheduler.shared
                            .startForegroundLoop(container: container)

                    } else if newPhase == .background {
                        LiveActivityScheduler.shared
                            .stopForegroundLoop()

                        LiveActivityScheduler.shared
                            .rescheduleBackgroundTask(container: container)
                    }
                }
                .onOpenURL { url in
                    if url.absoluteString == "dailytodo://live/stop" {
                        Task {
                            await LiveActivityManager.shared.end()
                        }
                        return
                    }

                    if url.absoluteString == "dailytodo://week" {
                        NotificationCenter.default.post(
                            name: .openWeekFromWidget,
                            object: nil
                        )
                        return
                    }

                    handleIncomingInviteURL(url)
                }
        }
    }

    private func handleIncomingInviteURL(_ url: URL) {
        guard url.scheme == "dailytodo" else { return }
        guard url.host == "join-crew" else { return }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
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
