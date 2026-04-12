//
//  HomeDashboardHelpers.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI
import SwiftData
import Combine

extension HomeDashboardView {
    var currentUserID: String? {
        session.currentUser?.id.uuidString
    }

    var allTasks: [DTTaskItem] {
        store.items
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

    var userScopedExams: [ExamItem] {
        guard let currentUserID else { return [] }
        return allExams.filter { $0.ownerUserID == currentUserID }
    }

    var smartSuggestions: [SmartTaskSuggestion] {
        guard smartEngineEnabled else { return [] }
        return SmartTaskEngine.suggestions(tasks: userScopedTasks, events: userScopedEvents)
    }

    var overdueTaskCount: Int {
        userScopedTasks.filter { task in
            !task.isDone && store.isOverdue(task)
        }.count
    }

    var todayTasks: [DTTaskItem] {
        let cal = Calendar.current
        return userScopedTasks
            .filter { task in
                guard !task.isDone else { return false }
                guard let due = task.dueDate else { return false }
                return cal.isDateInToday(due)
            }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
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
        StreakEngine.currentStreak(tasks: userScopedTasks)
    }

    var todayProgressValue: Double {
        guard totalTodayTaskCount > 0 else { return 0 }
        return Double(completedTodayCount) / Double(totalTodayTaskCount)
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
            .sorted { $0.startMinute < $1.startMinute }

        if let live = todaysEvents.first(where: { event in
            let start = event.startMinute
            let end = event.startMinute + event.durationMinute
            return now >= start && now < end
        }) {
            return live
        }

        return todaysEvents.first(where: { $0.startMinute > now })
    }

    var activeBackendCrewFocusSession: CrewFocusSessionDTO? {
        crewStore.activeFocusSessionByCrew.values.first(where: { $0.is_active })
    }

    var hasAnyActiveFocusSession: Bool {
        focusSession.isSessionActive
    }

    var isSharedFocusActive: Bool {
        focusSession.isSessionActive && focusSession.selectedMode != .personal
    }

    var activeSharedFriendName: String? {
        focusSession.selectedMode == .friend
            ? focusSession.currentSession?.participants.first(where: { !$0.isHost })?.name
            : nil
    }

    var latestRelevantCrewFocusSession: CrewFocusSession? {
        focusSessions
            .filter { session in
                if session.isActive { return true }
                return crewFocusNow.timeIntervalSince(session.endDate) <= 15
            }
            .sorted { $0.startedAt > $1.startedAt }
            .first
    }

    var hasCompletedAllPersonalTodayTasks: Bool {
        !todayBoardTasks.isEmpty && todayPendingBoardCount == 0
    }

    var activeCrewTaskCount: Int {
        crewStore.crewTasks.filter { !$0.is_done }.count
    }

    var hasCrewWorkToDo: Bool {
        activeCrewTaskCount > 0
    }

    var hasInsightsWorthShowing: Bool {
        completedTodayCount > 0 || streakCount > 0
    }

    var shouldShowFocusCard: Bool {
        activeBackendCrewFocusSession != nil || focusSession.isSessionActive
    }

    @ViewBuilder
    var currentFocusCard: some View {
        if let activeSession = activeBackendCrewFocusSession {
            crewSharedFocusCard(session: activeSession)
        } else if focusSession.isSessionActive {
            homeLiveFocusCard
        }
    }

    var nextSuggestedTaskAfterFocus: DTTaskItem? {
        todayBoardTasks.first { task in
            !task.isDone
        }
    }

    func formatSeconds(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        let minutes = safe / 60
        let secs = safe % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    func sessionStoreSafeEmailPrefix() -> String? {
        if let email = session.currentUser?.email, !email.isEmpty {
            return email.components(separatedBy: "@").first ?? email
        }
        return nil
    }

    func weekdayIndexToday() -> Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7
    }

    func currentMinuteOfDay() -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }

    func hm(_ minute: Int) -> String {
        let h = max(0, minute / 60)
        let m = max(0, minute % 60)
        return String(format: "%02d:%02d", h, m)
    }

    func targetDateFor(day: Int) -> Date {
        let calendar = Calendar.current
        let today = Date()
        let current = weekdayIndexToday()
        let delta = day - current
        return calendar.date(byAdding: .day, value: delta, to: today) ?? today
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

    func workoutExercisesForFocusTask() -> [WorkoutExerciseItem]? {
        guard let focusTask else { return nil }
        guard focusTask.taskType == "workout" else { return nil }

        let items = allWorkoutExercises
            .filter { $0.taskUUID == focusTask.taskUUID }
            .sorted {
                if $0.orderIndex != $1.orderIndex {
                    return $0.orderIndex < $1.orderIndex
                }
                return $0.createdAt < $1.createdAt
            }

        return items.isEmpty ? nil : items
    }

    func startInlineFocus() {
        Task {
            let minutes: Int

            if let task = focusTask, let due = task.dueDate {
                let diffSeconds = Int(due.timeIntervalSinceNow)
                let suggestedSeconds = max(15 * 60, min(diffSeconds, 60 * 60))
                minutes = max(15, suggestedSeconds / 60)
            } else {
                minutes = 25
            }

            let goal: FocusGoal
            if let task = focusTask {
                switch task.taskType.lowercased() {
                case "workout":
                    goal = .workout
                case "project":
                    goal = .deepWork
                case "study", "exam", "homework":
                    goal = .study
                default:
                    goal = .study
                }
            } else {
                goal = .study
            }

            _ = await focusSession.startRequestedSession(
                mode: .personal,
                durationMinutes: minutes,
                goal: goal,
                style: .silent
            )
        }
    }

    func stopActiveFocus() {
        focusSession.closeSession()
    }

    func advanceInlineWorkout() {
        // Eski çağrılar bozulmasın diye tutuldu.
    }

    func finishInlineWorkout() {
        focusSession.closeSession()
    }

    func completeLinkedWeekEvent(for task: DTTaskItem) {
        if let matchedEvent = userScopedEvents.first(where: { $0.sourceTaskUUID == task.taskUUID }) {
            matchedEvent.isCompleted = true

            do {
                try modelContext.save()
            } catch {
                print("❌ Linked week event complete error:", error)
            }
        }
    }

    func syncActiveFocusCountdown() {
        // Countdown artık FocusSessionManager tarafından yönetiliyor.
    }

    func liveFocusRemaining(at now: Date) -> Int {
        focusSession.remainingSeconds
    }

    func liveFocusTimeText(at now: Date) -> String {
        focusSession.timeString
    }

    func activeFocusUrgencyColor(for remaining: Int) -> Color {
        if focusSession.isPaused { return .orange }
        if remaining <= 60 { return .red }
        if remaining <= 300 { return .orange }

        switch focusSession.selectedMode {
        case .personal:
            return .blue
        case .crew:
            return .pink
        case .friend:
            return .purple
        }
    }

    func smoothActiveFocusProgressBar(at now: Date) -> some View {
        let progress = max(0.02, focusSession.progress)

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(palette.secondaryCardFill)

                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(8, geo.size.width * progress))
            }
        }
    }

    func backendCrewFocusAccentColor(for session: CrewFocusSessionDTO, now: Date) -> Color {
        if !session.is_active { return .green }
        if session.is_paused { return .orange }

        let remaining = backendCrewFocusRemainingSeconds(for: session, now: now)
        if remaining <= 180 { return .red }
        if remaining <= 600 { return .orange }
        return .blue
    }

    func backendCrewFocusRemainingSeconds(for session: CrewFocusSessionDTO, now: Date) -> Int {
        if session.is_paused {
            return max(0, session.paused_remaining_seconds ?? 0)
        }

        guard let startedAt = CrewDateParser.parse(session.started_at) else {
            return session.duration_minutes * 60
        }

        let endDate = startedAt.addingTimeInterval(TimeInterval(session.duration_minutes * 60))
        return max(0, Int(endDate.timeIntervalSince(now)))
    }

    func backendCrewFocusTimeText(for session: CrewFocusSessionDTO, now: Date) -> String {
        let remaining = backendCrewFocusRemainingSeconds(for: session, now: now)
        return String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }
}
