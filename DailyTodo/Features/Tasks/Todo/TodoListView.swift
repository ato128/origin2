//
//  TodoListView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 5.03.2026.
//

import SwiftUI
import SwiftData
import UIKit
import Combine

struct TodoListView: View {
    @Binding var selectedTab: AppTab
    @EnvironmentObject var store: TodoStore
    @EnvironmentObject var session: SessionStore

    @AppStorage("appTheme") var appTheme = AppTheme.gradient.rawValue

    var palette: ThemePalette {
        ThemePalette()
    }

    @Query(sort: \EventItem.startMinute, order: .forward)
    var allEvents: [EventItem]

    @Query(sort: \Crew.createdAt, order: .reverse)
    var crews: [Crew]

    @Query var members: [CrewMember]
    @Query var crewTasks: [CrewTask]

    @Query(sort: \CrewActivity.createdAt, order: .reverse)
    var activities: [CrewActivity]

    @Query var friendMessages: [FriendMessage]
    @Query var crewMessages: [CrewMessage]

    enum NextClassStatus {
        case live
        case next
    }

    @State var showLeaderboardPodium = false
    @State var previousTopCrewID: UUID?
    @State var showingAdd: Bool = false
    @State var showMessages = false
    @State var now = Date()
    @State var showTasksShortcut = false

    let chipTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var unreadCount: Int {
        let friendUnread = friendMessages.filter { !$0.isRead }.count
        let crewUnread = crewMessages.filter { !$0.isRead }.count
        return friendUnread + crewUnread
    }

    var items: [DTTaskItem] {
        store.items
    }

    var currentUserID: UUID? {
        session.currentUser?.id
    }

    var userScopedEvents: [EventItem] {
        guard let currentUserID else { return [] }
        return allEvents.filter { $0.ownerUserID == currentUserID.uuidString }
    }

    var userScopedCrews: [Crew] {
        guard let currentUserID else { return [] }
        return crews.filter { $0.ownerUserID == currentUserID }
    }

    var nextClassInfo: (title: String, timeText: String, status: NextClassStatus)? {
        let calendar = Calendar.current
        let todayDate = Date()
        let todayWeekday = weekdayIndexToday()
        let nowMinute = currentMinuteOfDay()

        let todayEvents = userScopedEvents
            .filter { event in
                guard !event.isCompleted else { return false }

                if let scheduledDate = event.scheduledDate {
                    return calendar.isDate(scheduledDate, inSameDayAs: todayDate)
                } else {
                    return event.weekday == todayWeekday
                }
            }
            .sorted { $0.startMinute < $1.startMinute }

        if let live = todayEvents.first(where: { event in
            let start = event.startMinute
            let end = event.startMinute + event.durationMinute
            return nowMinute >= start && nowMinute < end
        }) {
            let endMinute = live.startMinute + live.durationMinute
            let remain = max(0, endMinute - nowMinute)
            return (live.title, localizedMinuteText(remain), .live)
        }

        if let next = todayEvents.first(where: { $0.startMinute > nowMinute }) {
            let remain = max(0, next.startMinute - nowMinute)
            return (next.title, localizedMinuteText(remain), .next)
        }

        return nil
    }

    var todayTasks: [DTTaskItem] {
        let calendar = Calendar.current

        return items
            .filter { !$0.isDone }
            .filter { item in
                guard let dueDate = item.dueDate else { return false }
                return calendar.isDate(dueDate, inSameDayAs: Date())
            }
            .sorted {
                ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }
    }

    var body: some View {
        ZStack {
            tasksAmbientBackground

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Color.clear.frame(height: 76)

                    tasksHeader

                    HomeDashboardView(
                        onAddTask: {
                            showingAdd = true
                            haptic(.medium)
                        },
                        onOpenWeek: {
                            selectedTab = .week
                        },
                        onOpenInsights: {
                            selectedTab = .insights
                        }
                    )
                    .environmentObject(store)

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingAdd) {
            AddTaskView()
                .environmentObject(store)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showMessages) {
            MessagesView()
        }
        .onReceive(chipTimer) { value in
            now = value
        }
        .onAppear {
            previousTopCrewID = userScopedCrews
                .sorted { $0.totalFocusMinutes > $1.totalFocusMinutes }
                .first?.id

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    showLeaderboardPodium = true
                }
            }
        }
        .sheet(isPresented: $showTasksShortcut) {
            NavigationStack {
                TasksView()
                    .environmentObject(store)
            }
        }
        .onChange(of: userScopedCrews.map { "\($0.id.uuidString)-\($0.totalFocusMinutes)" }) { _, _ in
            let newTopCrewID = userScopedCrews
                .sorted { $0.totalFocusMinutes > $1.totalFocusMinutes }
                .first?.id

            if let previousTopCrewID, let newTopCrewID, previousTopCrewID != newTopCrewID {
                let gen = UIImpactFeedbackGenerator(style: .medium)
                gen.prepare()
                gen.impactOccurred()
            }

            self.previousTopCrewID = newTopCrewID
        }
    }

    private func localizedMinuteText(_ minutes: Int) -> String {
        let format = String(localized: "todo_minutes_format")
        return String(format: format, minutes)
    }
}
