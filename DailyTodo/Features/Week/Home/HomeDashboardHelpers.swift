//
//  HomeDashboardHelpers.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI
import SwiftData
import Combine

struct HomeQuickAction: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let isHighlighted: Bool
    let action: () -> Void
}

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
    
    var smartSuggestions: [SmartTaskSuggestion] {
        guard smartEngineEnabled else { return [] }
        return SmartTaskEngine.suggestions(tasks: userScopedTasks, events: userScopedEvents)
    }
    
    var overdueTaskCount: Int {
        userScopedTasks.filter { task in !task.isDone && store.isOverdue(task) }.count
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
    
    var crewFollowUpHeroState: TodayHeroState {
        TodayHeroState(
            eyebrow: "Sıradaki alan",
            title: "Crew seni bekliyor",
            subtitle: "Kişisel tarafı bitirdin. Şimdi ekip tarafında devam edebilirsin.",
            icon: "person.3.fill",
            accent: .pink,
            badge1: HeroBadge(
                icon: "checklist",
                text: "\(activeCrewTaskCount) açık iş",
                tint: .pink
            ),
            badge2: HeroBadge(
                icon: "bolt.fill",
                text: "Crew",
                tint: .orange
            ),
            contextLine: "Bugünü tek başına değil, ekip akışını da kapatarak tamamlayabilirsin.",
            primaryCTA: "Crew’e Git",
            primaryIcon: "person.3.fill",
            primaryAction: {
                onOpenWeek()
            },
            secondaryCTA: HeroCTA(
                title: "Sohbet",
                icon: "bubble.left.and.bubble.right.fill",
                action: {
                    showFriendsShortcut = true
                }
            )
        )
    }

    var insightsFollowUpHeroState: TodayHeroState {
        TodayHeroState(
            eyebrow: "Bugün bitti",
            title: "Akışını kontrol et",
            subtitle: "Bugünkü ilerlemeni ve ritmini içgörülerden görebilirsin.",
            icon: "chart.bar.fill",
            accent: .blue,
            badge1: HeroBadge(
                icon: "flame.fill",
                text: "Seri \(streakCount)",
                tint: .orange
            ),
            badge2: HeroBadge(
                icon: "chart.bar.fill",
                text: "Insights",
                tint: .blue
            ),
            contextLine: "Hangi saatlerde daha iyi ilerlediğini görmek yarını daha iyi kurmana yardım eder.",
            primaryCTA: "İçgörülere Git",
            primaryIcon: "chart.bar.fill",
            primaryAction: {
                onOpenInsights()
            },
            secondaryCTA: HeroCTA(
                title: "Hafta",
                icon: "calendar",
                action: {
                    onOpenWeek()
                }
            )
        )
    }

    var wrapUpHeroState: TodayHeroState {
        TodayHeroState(
            eyebrow: "Gün tamamlandı",
            title: "Yarını hazırlayabilirsin",
            subtitle: "Bugün sakin kapandı. İstersen yarın için küçük bir plan yap.",
            icon: "calendar.badge.plus",
            accent: .green,
            badge1: HeroBadge(
                icon: "checkmark.circle.fill",
                text: "Tamam",
                tint: .green
            ),
            badge2: HeroBadge(
                icon: "calendar",
                text: "Yarın",
                tint: .blue
            ),
            contextLine: "Kısa bir plan, yarın başlarken sürtünmeyi azaltır.",
            primaryCTA: "Haftayı Aç",
            primaryIcon: "calendar",
            primaryAction: {
                onOpenWeek()
            },
            secondaryCTA: HeroCTA(
                title: "Görev Ekle",
                icon: "plus",
                action: {
                    onAddTask()
                }
            )
        )
    }
    
    

        func formatSeconds(_ seconds: Int) -> String {
            let safe = max(0, seconds)
            let minutes = safe / 60
            let secs = safe % 60
            return String(format: "%02d:%02d", minutes, secs)
        }
    
    var shouldShowFocusCard: Bool {
        activeBackendCrewFocusSession != nil || isFocusActive || hasAnyActiveFocusSession
    }

    @ViewBuilder
    var currentFocusCard: some View {
        if let activeSession = activeBackendCrewFocusSession {
            crewSharedFocusCard(session: activeSession)
        } else if isFocusActive || hasAnyActiveFocusSession {
            activeFocusCard
        }
    }

    var todayHeroState: TodayHeroState {
        if shouldShowFocusCard {
            return postFocusHeroState
        } else {
            return preFocusHeroState
        }
    }

    var preFocusHeroState: TodayHeroState {
        if let activeSession = activeBackendCrewFocusSession {
            return TodayHeroState(
                eyebrow: "Ortak odak aktif",
                title: activeSession.title,
                subtitle: "\(activeSession.host_name) ile oturum devam ediyor.",
                icon: activeSession.is_paused ? "pause.fill" : "person.2.fill",
                accent: activeSession.is_paused ? .orange : .blue,
                badge1: HeroBadge(
                    icon: "timer",
                    text: backendCrewFocusTimeText(for: activeSession, now: Date()),
                    tint: activeSession.is_paused ? .orange : .blue
                ),
                badge2: HeroBadge(
                    icon: "person.2.fill",
                    text: "Crew",
                    tint: .pink
                ),
                contextLine: activeSession.is_paused
                    ? "Ortak oturum duraklatılmış. Devam ettirip akışı geri kazan."
                    : "Şu an ekip odağı aktif. Odaya girip birlikte devam edebilirsin.",
                primaryCTA: "Odayı Aç",
                primaryIcon: "arrow.right.circle.fill",
                primaryAction: {
                    focusRoomSession = activeSession
                },
                secondaryCTA: HeroCTA(
                    title: "Crew",
                    icon: "person.3.fill",
                    action: {
                        onOpenWeek()
                    }
                )
            )
        }

        if let task = focusTask {
            let accent = focusAccentColor(for: task)
            let course = task.courseName.trimmingCharacters(in: .whitespacesAndNewlines)

            return TodayHeroState(
                eyebrow: "Bugünün önceliği",
                title: task.title,
                subtitle: focusCardStatusTextStudent,
                icon: focusSymbol(for: task),
                accent: accent,
                badge1: HeroBadge(
                    icon: "scope",
                    text: dueBadgeText(for: task),
                    tint: accent
                ),
                badge2: course.isEmpty ? nil : HeroBadge(
                    icon: "book.closed.fill",
                    text: course,
                    tint: accent
                ),
                contextLine: store.isOverdue(task)
                    ? "Bunu bitirmen günün geri kalanını rahatlatır."
                    : "Şimdi başlarsan gün dağılmadan momentum kazanırsın.",
                primaryCTA: "Başla",
                primaryIcon: "play.fill",
                primaryAction: {
                    startInlineFocus()
                },
                secondaryCTA: HeroCTA(
                    title: "Tüm Görevler",
                    icon: "list.bullet",
                    action: {
                        showTasksShortcut = true
                    }
                )
            )
        }

        if hasCompletedAllPersonalTodayTasks && hasCrewWorkToDo {
            return crewFollowUpHeroState
        }

        if hasCompletedAllPersonalTodayTasks && hasInsightsWorthShowing {
            return insightsFollowUpHeroState
        }

        return wrapUpHeroState
    }

    var postFocusHeroState: TodayHeroState {
        if let nextTask = nextSuggestedTaskAfterFocus {
            let accent = todayTaskAccent(for: nextTask)
            let course = nextTask.courseName.trimmingCharacters(in: .whitespacesAndNewlines)

            return TodayHeroState(
                eyebrow: "Sonraki adım",
                title: nextTask.title,
                subtitle: "Odaktan sonra sıradaki en mantıklı iş bu görünüyor.",
                icon: taskTypeBadgeIcon(for: nextTask),
                accent: accent,
                badge1: HeroBadge(
                    icon: "clock.fill",
                    text: dueBadgeText(for: nextTask),
                    tint: accent
                ),
                badge2: course.isEmpty ? nil : HeroBadge(
                    icon: "book.closed.fill",
                    text: course,
                    tint: accent
                ),
                contextLine: "Aktif odak bitince hazır şekilde seni beklesin.",
                primaryCTA: "Görevleri Gör",
                primaryIcon: "list.bullet",
                primaryAction: {
                    showTasksShortcut = true
                },
                secondaryCTA: HeroCTA(
                    title: "Hafta",
                    icon: "calendar",
                    action: {
                        onOpenWeek()
                    }
                )
            )
        }

        return TodayHeroState(
            eyebrow: "Akış sürüyor",
            title: "Odaktan sonra yolun hazır",
            subtitle: "Şimdilik sadece ritmi koru. Sonraki adımı sonra seçersin.",
            icon: "sparkles",
            accent: .blue,
            badge1: HeroBadge(
                icon: "scope",
                text: "Odak açık",
                tint: .blue
            ),
            badge2: HeroBadge(
                icon: "calendar",
                text: "Bugün",
                tint: .blue
            ),
            contextLine: "İstersen görevlerini ya da haftayı hızlıca gözden geçirebilirsin.",
            primaryCTA: "Görevleri Gör",
            primaryIcon: "list.bullet",
            primaryAction: {
                showTasksShortcut = true
            },
            secondaryCTA: HeroCTA(
                title: "Hafta",
                icon: "calendar",
                action: {
                    onOpenWeek()
                }
            )
        )
    }

    var nextSuggestedTaskAfterFocus: DTTaskItem? {
        let activeTitle = activeFocusTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        return todayBoardTasks.first { task in
            guard !task.isDone else { return false }

            if !activeTitle.isEmpty && task.title == activeTitle {
                return false
            }

            return true
        }
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

            activeFocusTaskTitle = focusTask?.title ?? "Odak"
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

            activeFocusTaskTitle = focusTask?.title ?? "Odak"
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

    func liveFocusRemaining(at now: Date) -> Int {
        guard let startedAt = activeFocusStartedAt else { return activeFocusRemainingSeconds }
        let elapsed = Int(now.timeIntervalSince(startedAt))
        return max(0, activeFocusTotalSeconds - elapsed)
    }

    func liveFocusTimeText(at now: Date) -> String {
        let remaining = liveFocusRemaining(at: now)
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func activeFocusUrgencyColor(for remaining: Int) -> Color {
        if remaining <= 60 { return .red }
        if remaining <= 300 { return .orange }
        return .blue
    }

    func smoothActiveFocusProgressBar(at now: Date) -> some View {
        let remaining = liveFocusRemaining(at: now)
        let progress = activeFocusTotalSeconds > 0
            ? 1 - (Double(remaining) / Double(activeFocusTotalSeconds))
            : 0

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
}
