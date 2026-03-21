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
    case crew
    case insights
    case settings
}

struct MainTabView: View {
    
    @EnvironmentObject var store: TodoStore
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var crewStore: CrewStore
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
                CrewView(initialTab: .crews)
            }
            .tabItem { Label("Crew", systemImage: "person.3.fill") }
            .tag(AppTab.crew)

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
        .onAppear {
            print("MAIN TAB CURRENT USER:", session.currentUser?.id.uuidString ?? "nil")

            store.setCurrentUserID(session.currentUser?.id.uuidString)
            crewStore.setCurrentUser(session.currentUser?.id)
            crewStore.resetForUserChange()
        }
        .onChange(of: session.currentUser?.id) { _, newUserID in
            print("MAIN TAB USER CHANGED:", newUserID?.uuidString ?? "nil")

            store.setCurrentUserID(newUserID?.uuidString)
            crewStore.setCurrentUser(newUserID)
            crewStore.resetForUserChange()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openWeekFromWidget)) { _ in
            tab = .week
        }
    }
}
