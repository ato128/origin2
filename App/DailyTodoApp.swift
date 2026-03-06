//
//  DailyTodoApp.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import SwiftUI
import SwiftData

@main
struct DailyTodoApp: App {

    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: DTTaskItem.self,
                EventItem.self
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
                .onOpenURL { url in
                    if url.absoluteString == "dailytodo://live/stop" {
                        Task {
                            await LiveActivityManager.shared.end()
                        }
                    }
                }
        }
    }
}
