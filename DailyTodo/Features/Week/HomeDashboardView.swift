//
//  HomeDashboardView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 7.03.2026.
//

import SwiftUI
import SwiftData
import Combine

struct HomeDashboardView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var store: TodoStore

    @Query(sort: \EventItem.startMinute, order: .forward)
    var allEvents: [EventItem]

    let onAddTask: () -> Void
    let onOpenWeek: () -> Void
    let onOpenInsights: () -> Void

    let dayTitles = ["Pzt","Sal","Çar","Per","Cum","Cmt","Paz"]

    @State var showingFocusSession: Bool = false
    @State var isFocusActive: Bool = false
    @State var activeFocusTaskTitle: String = ""
    @State var activeFocusRemainingSeconds: Int = 25 * 60
    @State var activeFocusStartedAt: Date? = nil
    @State var activeFocusTotalSeconds: Int = 25 * 60
    @State var pulseActiveFocus: Bool = false
    @State var liveDotPulse: Bool = false
    @State var nextClassPulse: Bool = false
    @State var nextClassSweep: Bool = false
    @State var selectedDay: Int = 0

    let focusRefreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var allTasks: [DTTaskItem] { store.items }

    var todayTasks: [DTTaskItem] {
        let cal = Calendar.current
        return allTasks
            .filter { task in
                guard !task.isDone else { return false }
                guard let due = task.dueDate else { return false }
                return cal.isDateInToday(due)
            }
            .sorted {
                ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }
    }

    var completedTodayCount: Int {
        let cal = Calendar.current
        return allTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return cal.isDateInToday(completedAt)
        }.count
    }

    var totalTodayTaskCount: Int {
        completedTodayCount + todayTasks.count
    }

    var streakCount: Int {
        StreakEngine.currentStreak(tasks: allTasks)
    }

    var focusTask: DTTaskItem? {
        let active = allTasks.filter { !$0.isDone }
        let now = Date()

        let upcoming = active.filter {
            guard let due = $0.dueDate else { return false }
            return due >= now
        }

        if let nearestUpcoming = upcoming.sorted(by: {
            ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
        }).first {
            return nearestUpcoming
        }

        return active.sorted { a, b in
            let aDate = a.dueDate ?? .distantFuture
            let bDate = b.dueDate ?? .distantFuture
            let aDiff = abs(aDate.timeIntervalSince(now))
            let bDiff = abs(bDate.timeIntervalSince(now))
            return aDiff < bDiff
        }.first
    }

    var focusTaskStatusText: String {
        guard let task = focusTask else { return "Bugün odak görevi yok" }

        if store.isOverdue(task) {
            return "⚠️ Gecikmiş görev"
        }

        if let due = task.dueDate,
           Calendar.current.isDateInToday(due) {
            return "🔥 Bugün tamamla"
        }

        return "🎯 Öncelikli görev"
    }

    var nextEvent: EventItem? {
        let today = weekdayIndexToday()
        let now = currentMinuteOfDay()

        let todaysEvents = allEvents
            .filter { $0.weekday == today }
            .sorted { $0.startMinute < $1.startMinute }

        if let live = todaysEvents.first(where: {
            now >= $0.startMinute && now < ($0.startMinute + $0.durationMinute)
        }) {
            return live
        }

        return todaysEvents.first(where: { $0.startMinute > now })
    }

    var nextEventStatusText: String {
        guard let nextEvent else { return "Bugün başka ders yok" }

        let now = currentMinuteOfDay()
        let start = nextEvent.startMinute
        let end = nextEvent.startMinute + nextEvent.durationMinute

        if now >= start && now < end {
            let left = max(0, end - now)
            return "Şu an aktif • \(left) dk kaldı"
        } else {
            let remain = max(0, start - now)
            return "\(remain) dk sonra"
        }
    }

    var nextEventTimeText: String {
        guard let nextEvent else { return "--:--" }
        return "\(hm(nextEvent.startMinute)) – \(hm(nextEvent.startMinute + nextEvent.durationMinute))"
    }

    var todayProgressValue: Double {
        guard totalTodayTaskCount > 0 else { return 0 }
        return Double(completedTodayCount) / Double(totalTodayTaskCount)
    }

    var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var todayDateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMMM, EEEE"
        return f.string(from: Date())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                homeMiniWeekCalendar
                todayProgressCard

                if isFocusActive {
                    activeFocusCard
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.98).combined(with: .opacity),
                            removal: .scale(scale: 0.96).combined(with: .opacity)
                        ))
                } else {
                    focusCard
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.98).combined(with: .opacity),
                            removal: .opacity
                        ))
                }

                nextClassCard
                todayTasksCard
                quickActionsCard
            }
            .padding(16)
            .padding(.bottom, 20)
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: isFocusActive)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingFocusSession) {
            FocusSessionView(
                taskTitle: focusTask?.title,
                onStartFocus: { title, totalSeconds in
                    activeFocusTaskTitle = title
                    activeFocusTotalSeconds = totalSeconds
                    activeFocusRemainingSeconds = totalSeconds
                    activeFocusStartedAt = Date()
                    isFocusActive = true
                    pulseActiveFocus = true
                },
                onTick: { remaining in
                    activeFocusRemainingSeconds = remaining
                },
                onFinishFocus: { _, _, _, _, _, _ in
                    isFocusActive = false
                    activeFocusTaskTitle = ""
                    activeFocusRemainingSeconds = 25 * 60
                    activeFocusTotalSeconds = 25 * 60
                    activeFocusStartedAt = nil
                    pulseActiveFocus = false
                }
            )
        }
        .onAppear {
            selectedDay = weekdayIndexToday()
        }
        .onChange(of: isFocusActive) { _, newValue in
            pulseActiveFocus = newValue
        }
        .onReceive(focusRefreshTimer) { _ in
            syncActiveFocusCountdown()
        }
    }
}
