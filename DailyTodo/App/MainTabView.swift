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
    case focus
    case insights
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
                FocusView()
                    .environmentObject(session)
            }
            .tabItem { Label("Focus", systemImage: "timer") }
            .tag(AppTab.focus)

            NavigationStack {
                InsightsView()
                    .environmentObject(store)
            }
            .tabItem { Label("Insights", systemImage: "chart.bar") }
            .tag(AppTab.insights)
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

struct FocusPlaceholderView: View {
    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 14) {
                Spacer()

                Image(systemName: "timer")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.blue)

                Text("Focus")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Buraya odak ekranını yerleştireceğiz.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()
            }
            .padding()
        }
    }
}
