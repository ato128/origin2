//
//  DailyTodoApp.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import SwiftUI
import SwiftData
import WidgetKit

@main
struct DailyTodoApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: DTTaskItem.self,
                EventItem.self,
                FocusSessionRecord.self
            )
        } catch {
            fatalError("SwiftData container oluşturulamadı: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .environmentObject(
                    TodoStore(context: ModelContext(container))
                )
                .onAppear {
                    let context = ModelContext(container)
                    WidgetAppSync.refreshFromSwiftData(context: context)

                    LiveActivityScheduler.shared.registerBGTask()
                    LiveActivityScheduler.shared.startForegroundLoop(container: container)
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
                    } else if url.absoluteString == "dailytodo://week" {
                        NotificationCenter.default.post(
                            name: .openWeekFromWidget,
                            object: nil
                        )
                    }
                }
        }
    }
}

extension Notification.Name {
    static let openWeekFromWidget = Notification.Name("openWeekFromWidget")
}
