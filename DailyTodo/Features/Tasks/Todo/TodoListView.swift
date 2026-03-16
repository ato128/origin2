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

    @AppStorage("appTheme") var appTheme = AppTheme.gradient.rawValue
    let palette = ThemePalette()

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

    enum HomeSection: String, CaseIterable, Identifiable {
        case personal = "Personal"
        case crew = "Crew"

        var id: String { rawValue }
    }

    enum NextClassStatus {
        case live
        case next
    }

    @State var showLeaderboardPodium = false
    @State var previousTopCrewID: UUID?
    @State var showingAdd: Bool = false
    @State var homeSection: HomeSection = .personal
    @State var showMessages = false
    @State var now = Date()

    let chipTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var unreadCount: Int {
        let friendUnread = friendMessages.filter { !$0.isRead }.count
        let crewUnread = crewMessages.filter { !$0.isRead }.count
        return friendUnread + crewUnread
    }

    var items: [DTTaskItem] {
        store.items
    }

    var nextClassInfo: (title: String, timeText: String, status: NextClassStatus)? {
        let today = weekdayIndexToday()
        let nowMinute = currentMinuteOfDay()

        let todayEvents = allEvents
            .filter { $0.weekday == today }
            .sorted { $0.startMinute < $1.startMinute }

        if let live = todayEvents.first(where: {
            nowMinute >= $0.startMinute &&
            nowMinute < ($0.startMinute + $0.durationMinute)
        }) {
            let endMinute = live.startMinute + live.durationMinute
            let remain = max(0, endMinute - nowMinute)
            return (live.title, "\(remain) dk", .live)
        }

        if let next = todayEvents.first(where: { $0.startMinute > nowMinute }) {
            let remain = max(0, next.startMinute - nowMinute)
            return (next.title, "\(remain) dk", .next)
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
                    topSegment

                    if homeSection == .personal {
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
                    } else {
                        crewOverviewCard
                        crewListCard
                        crewActivityCard
                        socialQuickActionsCard
                    }

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
            previousTopCrewID = crews
                .sorted { $0.totalFocusMinutes > $1.totalFocusMinutes }
                .first?.id

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    showLeaderboardPodium = true
                }
            }
        }
        .onChange(of: crews.map { "\($0.id.uuidString)-\($0.totalFocusMinutes)" }) { _, _ in
            let newTopCrewID = crews
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
}
