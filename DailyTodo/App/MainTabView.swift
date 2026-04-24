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

extension Notification.Name {
    static let openFocusTabFromHome = Notification.Name("openFocusTabFromHome")
}

struct MainTabView: View {
    @Binding var openFocusFromNotification: Bool

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
                    .environmentObject(crewStore)
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
        .onChange(of: openFocusFromNotification) { _, newValue in
            guard newValue else { return }

            tab = .focus

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                openFocusFromNotification = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openWeekFromWidget)) { _ in
            tab = .week
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFocusTabFromHome)) { _ in
            tab = .focus
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCrewFocusFromNotification)) { output in
            tab = .focus

            if let payload = output.object as? [AnyHashable: Any] {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    NotificationCenter.default.post(
                        name: .presentCrewFocusInviteSheet,
                        object: payload
                    )
                }
            } else if let crewID = output.object as? String {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    NotificationCenter.default.post(
                        name: .presentActiveCrewFocusFromNotification,
                        object: crewID
                    )
                }
            }
        }
    }
}

