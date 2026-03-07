//
//  MainTabView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//


import SwiftUI
import SwiftData
import Foundation

enum AppTab: Hashable {
    case tasks
    case week
    case insights
    case settings
}

struct MainTabView: View {
    @EnvironmentObject var store: TodoStore
    @State private var tab: AppTab = .tasks

    var body: some View {
        TabView(selection: $tab) {

            NavigationStack {
                TodoListView(selectedTab: $tab)
            }
            .tabItem { Label("Tasks", systemImage: "checklist") }
            .tag(AppTab.tasks)

            NavigationStack {
                WeekView()
            }
            .tabItem { Label("Week", systemImage: "calendar") }
            .tag(AppTab.week)

            NavigationStack {
                InsightsView()
                    .environmentObject(store)
            }
            .tabItem { Label("Insights", systemImage: "chart.bar") }
            .tag(AppTab.insights)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(AppTab.settings)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openWeekFromWidget)) { _ in
            tab = .week
        }
    }
}
