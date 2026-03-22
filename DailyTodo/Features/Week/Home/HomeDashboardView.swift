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
    @AppStorage("smartEngineEnabled") var smartEngineEnabled: Bool = true
    @AppStorage("appTheme") var appTheme = AppTheme.gradient.rawValue
    @AppStorage("focus_workout_mode") var focusWorkoutMode: Bool = false
    @AppStorage("focus_workout_exercise_name") var focusWorkoutExerciseName: String = ""
    @AppStorage("focus_workout_current_set") var focusWorkoutCurrentSet: Int = 0
    @AppStorage("focus_workout_total_sets") var focusWorkoutTotalSets: Int = 0
    @AppStorage("focus_workout_is_resting") var focusWorkoutIsResting: Bool = false

    let palette = ThemePalette()

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var store: TodoStore
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var session: SessionStore

    @Query(sort: \EventItem.startMinute, order: .forward)
    var allEvents: [EventItem]

    @Query(sort: \Friend.createdAt, order: .reverse)
    var friends: [Friend]

    @Query(sort: \FriendMessage.createdAt, order: .reverse)
    var allFriendMessages: [FriendMessage]

    @Query var focusSessions: [CrewFocusSession]
    @Query private var allWorkoutExercises: [WorkoutExerciseItem]

    let onAddTask: () -> Void
    let onOpenWeek: () -> Void
    let onOpenInsights: () -> Void

    let dayTitles = ["Pzt","Sal","Çar","Per","Cum","Cmt","Paz"]

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
    @State var showFriendsShortcut = false
    @State var showRecentFriendChat = false
    @State var pulseRecentFriendPill = false
    @State var crewFocusGlowPulse: Bool = false
    @State var crewFocusNow = Date()

    @State var showHeaderCard = false
    @State var showWeekCard = false
    @State var showProgressCard = false
    @State var showFocusCard = false
    @State var showNextClassCard = false
    @State var showTodayTasksCard = false
    @State var showQuickActionsCard = false
    @State var showTasksShortcut = false

    @State private var inlineWorkoutExerciseIndex: Int = 0
    @State private var inlineWorkoutCurrentSet: Int = 1
    @State private var inlineWorkoutIsResting: Bool = false
    @State private var inlineWorkoutRestSeconds: Int = 0
    @State private var didLoadCrewFocusSessions = false

    @State  var focusRoomSession: CrewFocusSessionDTO?

    let dashboardTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var smartSuggestions: [SmartTaskSuggestion] {
        guard smartEngineEnabled else { return [] }
        return SmartTaskEngine.suggestions(
            tasks: userScopedTasks,
            events: userScopedEvents
        )
    }

    var overdueTaskCount: Int {
        userScopedTasks.filter { task in
            !task.isDone && store.isOverdue(task)
        }.count
    }

    var allTasks: [DTTaskItem] {
        store.items
    }
    
    var currentUserID: String? {
        session.currentUser?.id.uuidString
    }

    var userScopedEvents: [EventItem] {
        guard let currentUserID else { return [] }
        return allEvents.filter { $0.ownerUserID == currentUserID }
    }

    var userScopedFriends: [Friend] {
        guard let currentUserID else { return [] }
        return friends.filter { $0.ownerUserID == currentUserID }
    }

    var userScopedTasks: [DTTaskItem] {
        guard let currentUserID else { return [] }
        return allTasks.filter { $0.ownerUserID == currentUserID }
    }

    var todayTasks: [DTTaskItem] {
        let cal = Calendar.current
        return userScopedTasks
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
        return userScopedTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return cal.isDateInToday(completedAt)
        }.count
    }

    var totalTodayTaskCount: Int {
        completedTodayCount + todayTasks.count
    }

    var streakCount: Int {
        return StreakEngine.currentStreak(tasks: userScopedTasks)
    }

    var focusTask: DTTaskItem? {
        let now = Date()
        let active = userScopedTasks.filter { !$0.isDone }

        var nearestUpcoming: DTTaskItem?
        var nearestUpcomingDate: Date?

        var nearestOverall: DTTaskItem?
        var nearestOverallDistance: TimeInterval?

        for task in active {
            let due = task.dueDate ?? .distantFuture

            if due >= now {
                if nearestUpcomingDate == nil || due < nearestUpcomingDate! {
                    nearestUpcoming = task
                    nearestUpcomingDate = due
                }
            }

            let distance = abs(due.timeIntervalSince(now))
            if nearestOverallDistance == nil || distance < nearestOverallDistance! {
                nearestOverall = task
                nearestOverallDistance = distance
            }
        }

        return nearestUpcoming ?? nearestOverall
    }

    func workoutExercisesForFocusTask() -> [WorkoutExerciseItem]? {
        guard let focusTask else { return nil }
        guard focusTask.taskType == "workout" else { return nil }

        let items = allWorkoutExercises
            .filter { $0.taskUUID == focusTask.taskUUID }
            .sorted { lhs, rhs in
                if lhs.orderIndex != rhs.orderIndex {
                    return lhs.orderIndex < rhs.orderIndex
                }
                return lhs.createdAt < rhs.createdAt
            }

        return items.isEmpty ? nil : items
    }

    var currentInlineWorkoutExercise: WorkoutExerciseItem? {
        guard let exercises = workoutExercisesForFocusTask(),
              inlineWorkoutExerciseIndex >= 0,
              inlineWorkoutExerciseIndex < exercises.count else { return nil }
        return exercises[inlineWorkoutExerciseIndex]
    }

    var activeBackendCrewFocusSession: CrewFocusSessionDTO? {
        crewStore.activeFocusSessionByCrew.values.first(where: { $0.is_active })
    }

    func weekCrewItem(for crewID: UUID) -> WeekCrewItem? {
        guard let crew = crewStore.crews.first(where: { $0.id == crewID }) else { return nil }

        return WeekCrewItem(
            id: crew.id,
            name: crew.name,
            icon: crew.icon,
            colorHex: crew.color_hex
        )
    }

    func startInlineFocus() {
        if let exercises = workoutExercisesForFocusTask(), !exercises.isEmpty {
            inlineWorkoutExerciseIndex = 0
            inlineWorkoutCurrentSet = 1
            inlineWorkoutIsResting = false
            inlineWorkoutRestSeconds = 0

            let firstExercise = exercises[inlineWorkoutExerciseIndex]

            focusWorkoutMode = true
            focusWorkoutExerciseName = firstExercise.name
            focusWorkoutCurrentSet = inlineWorkoutCurrentSet
            focusWorkoutTotalSets = firstExercise.sets
            focusWorkoutIsResting = false

            let duration = max(60, firstExercise.restSeconds > 0 ? firstExercise.restSeconds : 60)

            activeFocusTaskTitle = focusTask?.title ?? "Workout"
            activeFocusTotalSeconds = duration
            activeFocusRemainingSeconds = duration
            activeFocusStartedAt = Date()
            isFocusActive = true
            pulseActiveFocus = true
        } else {
            let duration: Int

            if let task = focusTask, let due = task.dueDate {
                let diff = Int(due.timeIntervalSinceNow)
                duration = max(15 * 60, min(diff, 60 * 60))
            } else {
                duration = 25 * 60
            }

            activeFocusTaskTitle = focusTask?.title ?? "Focus"
            activeFocusTotalSeconds = duration
            activeFocusRemainingSeconds = duration
            activeFocusStartedAt = Date()
            isFocusActive = true
            pulseActiveFocus = true
        }
    }

    func stopActiveFocus() {
        isFocusActive = false
        pulseActiveFocus = false
        activeFocusTaskTitle = ""
        activeFocusRemainingSeconds = 25 * 60
        activeFocusTotalSeconds = 25 * 60
        activeFocusStartedAt = nil

        inlineWorkoutExerciseIndex = 0
        inlineWorkoutCurrentSet = 1
        inlineWorkoutIsResting = false
        inlineWorkoutRestSeconds = 0

        focusWorkoutMode = false
        focusWorkoutExerciseName = ""
        focusWorkoutCurrentSet = 0
        focusWorkoutTotalSets = 0
        focusWorkoutIsResting = false
    }

    func completeLinkedWeekEvent(for task: DTTaskItem) {
        if let matchedEvent = userScopedEvents.first(where: { $0.sourceTaskUUID == task.taskUUID }) {
            matchedEvent.isCompleted = true

            do {
                try modelContext.save()
                print("✅ Event completed:", matchedEvent.title)
            } catch {
                print("❌ Linked week event complete error:", error)
            }
        } else {
            print("❌ No matched week event found for taskUUID:", task.taskUUID)
        }
    }

    func advanceInlineWorkout() {
        guard let exercises = workoutExercisesForFocusTask(),
              inlineWorkoutExerciseIndex < exercises.count else { return }

        let exercise = exercises[inlineWorkoutExerciseIndex]

        if inlineWorkoutIsResting {
            inlineWorkoutIsResting = false
            focusWorkoutIsResting = false
            activeFocusStartedAt = Date()
            return
        }

        if inlineWorkoutCurrentSet < exercise.sets {
            inlineWorkoutCurrentSet += 1
            focusWorkoutCurrentSet = inlineWorkoutCurrentSet

            if exercise.restSeconds > 0 {
                inlineWorkoutIsResting = true
                inlineWorkoutRestSeconds = exercise.restSeconds
                focusWorkoutIsResting = true
                activeFocusTotalSeconds = exercise.restSeconds
                activeFocusRemainingSeconds = exercise.restSeconds
                activeFocusStartedAt = Date()
            }
        } else {
            if inlineWorkoutExerciseIndex < exercises.count - 1 {
                inlineWorkoutExerciseIndex += 1
                inlineWorkoutCurrentSet = 1

                let nextExercise = exercises[inlineWorkoutExerciseIndex]
                focusWorkoutExerciseName = nextExercise.name
                focusWorkoutCurrentSet = 1
                focusWorkoutTotalSets = nextExercise.sets

                if exercise.restSeconds > 0 {
                    inlineWorkoutIsResting = true
                    inlineWorkoutRestSeconds = exercise.restSeconds
                    focusWorkoutIsResting = true
                    activeFocusTotalSeconds = exercise.restSeconds
                    activeFocusRemainingSeconds = exercise.restSeconds
                    activeFocusStartedAt = Date()
                }
            } else {
                finishInlineWorkout()
            }
        }
    }

    func finishInlineWorkout() {
        if let task = focusTask {
            task.isDone = true
            task.completedAt = Date()

            completeLinkedWeekEvent(for: task)

            do {
                try modelContext.save()
            } catch {
                print("❌ Task save error:", error)
            }
        }

        isFocusActive = false
        pulseActiveFocus = false

        focusWorkoutMode = false
        focusWorkoutExerciseName = ""
        focusWorkoutCurrentSet = 0
        focusWorkoutTotalSets = 0
        focusWorkoutIsResting = false

        inlineWorkoutExerciseIndex = 0
        inlineWorkoutCurrentSet = 1
        inlineWorkoutIsResting = false
        inlineWorkoutRestSeconds = 0

        activeFocusTaskTitle = ""
        activeFocusRemainingSeconds = 25 * 60
        activeFocusTotalSeconds = 25 * 60
        activeFocusStartedAt = nil
    }

    func syncActiveFocusCountdown() {
        guard isFocusActive else { return }
        guard let startedAt = activeFocusStartedAt else { return }

        let elapsed = Int(Date().timeIntervalSince(startedAt))
        let remaining = max(0, activeFocusTotalSeconds - elapsed)

        activeFocusRemainingSeconds = remaining

        if remaining == 0 {
            if focusWorkoutMode {
                if inlineWorkoutIsResting {
                    inlineWorkoutIsResting = false
                    focusWorkoutIsResting = false
                    activeFocusStartedAt = Date()
                } else {
                    advanceInlineWorkout()
                }
            } else {
                isFocusActive = false
                pulseActiveFocus = false
            }
        }
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

    var recentChatFriend: Friend? {
        guard let latestMessage = allFriendMessages.max(by: { $0.createdAt < $1.createdAt }) else {
            return nil
        }
        return userScopedFriends.first(where: { $0.id == latestMessage.friendID })
    }

    var nextEvent: EventItem? {
        let calendar = Calendar.current
        let today = Date()
        let todayWeekday = weekdayIndexToday()
        let now = currentMinuteOfDay()

        let todaysEvents = userScopedEvents
            .filter { event in
                guard !event.isCompleted else { return false }

                if let scheduledDate = event.scheduledDate {
                    return calendar.isDate(scheduledDate, inSameDayAs: today)
                } else {
                    return event.weekday == todayWeekday
                }
            }
            .sorted { lhs, rhs in
                lhs.startMinute < rhs.startMinute
            }

        if let live = todaysEvents.first(where: { event in
            let start = event.startMinute
            let end = event.startMinute + event.durationMinute
            return now >= start && now < end
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

    var latestRelevantCrewFocusSession: CrewFocusSession? {
        focusSessions
            .filter { session in
                if session.isActive {
                    return true
                }

                return crewFocusNow.timeIntervalSince(session.endDate) <= 15
            }
            .sorted { $0.startedAt > $1.startedAt }
            .first
    }

    var hasAnyActiveFocusSession: Bool {
        guard let timestamp = UserDefaults.standard.object(forKey: "focus_end_date") as? Double else {
            return false
        }

        let endDate = Date(timeIntervalSince1970: timestamp)
        return endDate.timeIntervalSinceNow > 0
    }

    var isSharedFocusActive: Bool {
        UserDefaults.standard.string(forKey: "focus_mode") == "shared" && hasAnyActiveFocusSession
    }

    var activeSharedFriendName: String? {
        UserDefaults.standard.string(forKey: "focus_friend_name")
    }

    var focusCardTitle: String {
        if isSharedFocusActive {
            return "Shared Focus"
        }
        return "Focus Now"
    }

    var focusCardMainText: String {
        if isSharedFocusActive, let friendName = activeSharedFriendName {
            return "\(friendName) ile focus"
        }
        return focusTask?.title ?? "Bugün odak görevi yok"
    }

    var focusCardStatusText: String {
        if isSharedFocusActive {
            return "🟢 Shared session active"
        }
        return focusTaskStatusText
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
        ZStack {
            ScrollView {
                VStack(spacing: 14) {
                    headerCard
                        .offset(y: showHeaderCard ? 0 : 18)
                        .opacity(showHeaderCard ? 1 : 0)
                        .scaleEffect(showHeaderCard ? 1 : 0.985)

                    homeMiniWeekCalendar
                        .offset(y: showWeekCard ? 0 : 18)
                        .opacity(showWeekCard ? 1 : 0)
                        .scaleEffect(showWeekCard ? 1 : 0.985)

                    todayProgressCard
                        .offset(y: showProgressCard ? 0 : 18)
                        .opacity(showProgressCard ? 1 : 0)
                        .scaleEffect(showProgressCard ? 1 : 0.985)

                    if let activeSession = activeBackendCrewFocusSession {
                        crewSharedFocusCard(session: activeSession)
                            .offset(y: showFocusCard ? 0 : 18)
                            .opacity(showFocusCard ? 1 : 0)
                            .scaleEffect(showFocusCard ? 1 : 0.985)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.98).combined(with: .opacity),
                                removal: .scale(scale: 0.96).combined(with: .opacity)
                            ))
                    } else if isFocusActive || hasAnyActiveFocusSession {
                        activeFocusCard
                            .offset(y: showFocusCard ? 0 : 18)
                            .opacity(showFocusCard ? 1 : 0)
                            .scaleEffect(showFocusCard ? 1 : 0.985)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.98).combined(with: .opacity),
                                removal: .scale(scale: 0.96).combined(with: .opacity)
                            ))
                    } else {
                        focusCard
                            .offset(y: showFocusCard ? 0 : 18)
                            .opacity(showFocusCard ? 1 : 0)
                            .scaleEffect(showFocusCard ? 1 : 0.985)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.98).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    nextClassCard
                        .offset(y: showNextClassCard ? 0 : 18)
                        .opacity(showNextClassCard ? 1 : 0)
                        .scaleEffect(showNextClassCard ? 1 : 0.985)

                    todayTasksCard
                        .offset(y: showTodayTasksCard ? 0 : 18)
                        .opacity(showTodayTasksCard ? 1 : 0)
                        .scaleEffect(showTodayTasksCard ? 1 : 0.985)

                    if smartEngineEnabled, let firstSuggestion = smartSuggestions.first {
                        SmartTaskSuggestionCard(suggestion: firstSuggestion)
                    }

                    quickActionsCard
                        .offset(y: showQuickActionsCard ? 0 : 18)
                        .opacity(showQuickActionsCard ? 1 : 0)
                        .scaleEffect(showQuickActionsCard ? 1 : 0.985)
                }
                .padding(.horizontal, 16)
                .padding(.top, 0)
                .padding(.bottom, 36)
                .animation(.spring(response: 0.38, dampingFraction: 0.86), value: isFocusActive)
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 90)
            }
            .sheet(isPresented: $showRecentFriendChat) {
                if let recentFriend = recentChatFriend {
                    NavigationStack {
                        FriendChatView(friend: recentFriend)
                    }
                }
            }
            .sheet(isPresented: $showFriendsShortcut) {
                NavigationStack {
                    CrewView(initialTab: .friends)
                }
            }
            .sheet(isPresented: $showTasksShortcut) {
                NavigationStack {
                    TasksView()
                        .environmentObject(store)
                }
            }
            .sheet(item: $focusRoomSession) { openedSession in
                if let crewItem = weekCrewItem(for: openedSession.crew_id) {
                    NavigationStack {
                        CrewFocusRoomBackendView(
                            crew: crewItem,
                            sessionDTO: openedSession
                        )
                        .environmentObject(crewStore)
                        .environmentObject(session)
                    }
                }
            }
            .onAppear {
                selectedDay = weekdayIndexToday()
                syncActiveFocusCountdown()

                if !didLoadCrewFocusSessions {
                    didLoadCrewFocusSessions = true

                    Task {
                        await crewStore.loadCrews()

                        for crew in crewStore.crews {
                            await crewStore.loadActiveFocusSession(for: crew.id)
                        }
                    }
                }

                showHeaderCard = false
                showWeekCard = false
                showProgressCard = false
                showFocusCard = false
                showNextClassCard = false
                showTodayTasksCard = false
                showQuickActionsCard = false

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                        showHeaderCard = true
                    }
                    withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                        crewFocusGlowPulse = true
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                        showWeekCard = true
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                        showProgressCard = true
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                        showFocusCard = true
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                        showNextClassCard = true
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                        showTodayTasksCard = true
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                        showQuickActionsCard = true
                    }
                }
            }
            .onChange(of: isFocusActive) { _, newValue in
                pulseActiveFocus = newValue
            }
            .onReceive(dashboardTimer) { value in
                crewFocusNow = value
                syncActiveFocusCountdown()
                selectedDay = weekdayIndexToday()
            }
        }
    }
}
