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
    @Environment(\.locale) var locale

    @Query(sort: \EventItem.startMinute, order: .forward) var allEvents: [EventItem]
    @Query(sort: \ExamItem.examDate, order: .forward) var allExams: [ExamItem]
    @Query(sort: \Friend.createdAt, order: .reverse) var friends: [Friend]
    @Query(sort: \FriendMessage.createdAt, order: .reverse) var allFriendMessages: [FriendMessage]
    @Query var focusSessions: [CrewFocusSession]
    @Query var allWorkoutExercises: [WorkoutExerciseItem]

    let onAddTask: () -> Void
    let onOpenWeek: () -> Void
    let onOpenInsights: () -> Void

    @State var isFocusActive: Bool = false
    @State var activeFocusTaskTitle: String = ""
    @State var activeFocusRemainingSeconds: Int = 25 * 60
    @State var activeFocusStartedAt: Date? = nil
    @State var activeFocusTotalSeconds: Int = 25 * 60
    @State var pulseActiveFocus: Bool = false
    @State var liveDotPulse: Bool = false
    @State var selectedDay: Int = 0
    @State var showFriendsShortcut = false
    @State var showRecentFriendChat = false
    @State var showTasksShortcut = false
    @State var crewFocusGlowPulse: Bool = false
    @State var crewFocusNow = Date()

    @State var showHeaderCard = false
    @State var showHeroCard = false
    @State var showFocusCard = false
    @State var showTodayTasksCard = false
    @State var showMomentumCard = false
    @State var showWeekCard = false
    @State var showQuickActionsCard = false

    @State var inlineWorkoutExerciseIndex: Int = 0
    @State var inlineWorkoutCurrentSet: Int = 1
    @State var inlineWorkoutIsResting: Bool = false
    @State var inlineWorkoutRestSeconds: Int = 0
    @State var didLoadCrewFocusSessions = false

    @State var focusRoomSession: CrewFocusSessionDTO?

    enum HomeLayoutMode {
        case focusActive
        case crewFollowUp
        case insightsFollowUp
        case completionWrapUp
        case defaultFlow
    }

    let dashboardTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var dayTitles: [String] {
        ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
    }

    var dailyFlowSnapshot: DailyFlowSnapshot {
        DailyFlowEngine.makeSnapshot(
            tasks: userScopedTasks,
            events: userScopedEvents,
            now: Date()
        )
    }

    var shouldShowTodayTasksCard: Bool {
        !todayBoardTasks.isEmpty
    }

    var resolvedHeroTitleNormalized: String {
        resolveHeroState()
            .title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    var shouldShowSecondarySuggestedAction: Bool {
        guard let action = dailyFlowSnapshot.suggestedAction else { return false }
        if resolvedHeroKind == .noTaskPrompt { return false }
        if todayBoardTasks.isEmpty { return false }
        return action.normalizedTitle != resolvedHeroTitleNormalized
    }

    var homeLayoutMode: HomeLayoutMode {
        let heroKind = buildHeroCandidates()
            .max { $0.priority < $1.priority }?
            .kind

        if shouldShowFocusCard {
            return .focusActive
        }

        switch heroKind {
        case .crewFollowUp:
            return .crewFollowUp
        case .insightsFollowUp, .socialFollowUp:
            return .insightsFollowUp
        case .wrapUp:
            return .completionWrapUp
        default:
            return .defaultFlow
        }
    }

    var resolvedHeroKind: HomeHeroKind {
        buildHeroCandidates()
            .max { $0.priority < $1.priority }?
            .kind ?? .wrapUp
    }
    
    func startSuggestedExamFocus(for exam: ExamItem) {
        let minutes = suggestedStudyMinutes(for: exam)

        activeFocusTaskTitle = "\(exam.courseName.isEmpty ? exam.title : exam.courseName) \(exam.examType)"
        activeFocusTotalSeconds = minutes * 60
        activeFocusRemainingSeconds = minutes * 60
        activeFocusStartedAt = Date()
        isFocusActive = true
        pulseActiveFocus = true
    }
    
    func handleSuggestedSecondaryAction(_ action: SuggestedTaskAction) {
        switch action.style {
        case .planTomorrow:
            onOpenWeek()

        case .keepMomentum:
            showTasksShortcut = true

        case .lightenLoad:
            showTasksShortcut = true

        case .overdueRecovery, .quickWin, .startFocus, .beforeClass:
            showTasksShortcut = true
        }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 14) {
                    headerCard
                        .offset(y: showHeaderCard ? 0 : 18)
                        .opacity(showHeaderCard ? 1 : 0)
                        .scaleEffect(showHeaderCard ? 1 : 0.985)

                    todayHeroCard
                        .offset(y: showHeroCard ? 0 : 18)
                        .opacity(showHeroCard ? 1 : 0)
                        .scaleEffect(showHeroCard ? 1 : 0.985)
                        .animation(.spring(response: 0.44, dampingFraction: 0.84), value: resolvedHeroKind)

                    switch homeLayoutMode {
                    case .focusActive:
                        if shouldShowFocusCard {
                            currentFocusCard
                                .offset(y: showFocusCard ? 0 : 18)
                                .opacity(showFocusCard ? 1 : 0)
                                .scaleEffect(showFocusCard ? 1 : 0.985)
                                .transition(
                                    .asymmetric(
                                        insertion: .scale(scale: 0.98).combined(with: .opacity),
                                        removal: .scale(scale: 0.96).combined(with: .opacity)
                                    )
                                )
                        }

                        suggestedActionSection

                        if shouldShowTodayTasksCard {
                            todayTasksCard
                                .offset(y: showTodayTasksCard ? 0 : 18)
                                .opacity(showTodayTasksCard ? 1 : 0)
                                .scaleEffect(showTodayTasksCard ? 1 : 0.985)
                        }

                        momentumCard
                            .offset(y: showMomentumCard ? 0 : 18)
                            .opacity(showMomentumCard ? 1 : 0)
                            .scaleEffect(showMomentumCard ? 1 : 0.985)

                        homeMiniWeekCalendar
                            .offset(y: showWeekCard ? 0 : 18)
                            .opacity(showWeekCard ? 1 : 0)
                            .scaleEffect(showWeekCard ? 1 : 0.985)

                        quickActionsCard
                            .offset(y: showQuickActionsCard ? 0 : 18)
                            .opacity(showQuickActionsCard ? 1 : 0)
                            .scaleEffect(showQuickActionsCard ? 1 : 0.985)

                    case .crewFollowUp:
                        suggestedActionSection

                        if shouldShowTodayTasksCard {
                            todayTasksCard
                                .offset(y: showTodayTasksCard ? 0 : 18)
                                .opacity(showTodayTasksCard ? 1 : 0)
                                .scaleEffect(showTodayTasksCard ? 1 : 0.985)
                        }

                        homeMiniWeekCalendar
                            .offset(y: showWeekCard ? 0 : 18)
                            .opacity(showWeekCard ? 1 : 0)
                            .scaleEffect(showWeekCard ? 1 : 0.985)

                        momentumCard
                            .offset(y: showMomentumCard ? 0 : 18)
                            .opacity(showMomentumCard ? 1 : 0)
                            .scaleEffect(showMomentumCard ? 1 : 0.985)

                        quickActionsCard
                            .offset(y: showQuickActionsCard ? 0 : 18)
                            .opacity(showQuickActionsCard ? 1 : 0)
                            .scaleEffect(showQuickActionsCard ? 1 : 0.985)

                    case .insightsFollowUp:
                        momentumCard
                            .offset(y: showMomentumCard ? 0 : 18)
                            .opacity(showMomentumCard ? 1 : 0)
                            .scaleEffect(showMomentumCard ? 1 : 0.985)

                        suggestedActionSection

                        homeMiniWeekCalendar
                            .offset(y: showWeekCard ? 0 : 18)
                            .opacity(showWeekCard ? 1 : 0)
                            .scaleEffect(showWeekCard ? 1 : 0.985)

                        if shouldShowTodayTasksCard {
                            todayTasksCard
                                .offset(y: showTodayTasksCard ? 0 : 18)
                                .opacity(showTodayTasksCard ? 1 : 0)
                                .scaleEffect(showTodayTasksCard ? 1 : 0.985)
                        }

                        quickActionsCard
                            .offset(y: showQuickActionsCard ? 0 : 18)
                            .opacity(showQuickActionsCard ? 1 : 0)
                            .scaleEffect(showQuickActionsCard ? 1 : 0.985)

                    case .completionWrapUp:
                        momentumCard
                            .offset(y: showMomentumCard ? 0 : 18)
                            .opacity(showMomentumCard ? 1 : 0)
                            .scaleEffect(showMomentumCard ? 1 : 0.985)

                        suggestedActionSection

                        homeMiniWeekCalendar
                            .offset(y: showWeekCard ? 0 : 18)
                            .opacity(showWeekCard ? 1 : 0)
                            .scaleEffect(showWeekCard ? 1 : 0.985)

                        quickActionsCard
                            .offset(y: showQuickActionsCard ? 0 : 18)
                            .opacity(showQuickActionsCard ? 1 : 0)
                            .scaleEffect(showQuickActionsCard ? 1 : 0.985)

                        if shouldShowTodayTasksCard {
                            todayTasksCard
                                .offset(y: showTodayTasksCard ? 0 : 18)
                                .opacity(showTodayTasksCard ? 1 : 0)
                                .scaleEffect(showTodayTasksCard ? 1 : 0.985)
                        }

                    case .defaultFlow:
                        suggestedActionSection

                        if shouldShowTodayTasksCard {
                            todayTasksCard
                                .offset(y: showTodayTasksCard ? 0 : 18)
                                .opacity(showTodayTasksCard ? 1 : 0)
                                .scaleEffect(showTodayTasksCard ? 1 : 0.985)
                        }

                        momentumCard
                            .offset(y: showMomentumCard ? 0 : 18)
                            .opacity(showMomentumCard ? 1 : 0)
                            .scaleEffect(showMomentumCard ? 1 : 0.985)

                        homeMiniWeekCalendar
                            .offset(y: showWeekCard ? 0 : 18)
                            .opacity(showWeekCard ? 1 : 0)
                            .scaleEffect(showWeekCard ? 1 : 0.985)

                        quickActionsCard
                            .offset(y: showQuickActionsCard ? 0 : 18)
                            .opacity(showQuickActionsCard ? 1 : 0)
                            .scaleEffect(showQuickActionsCard ? 1 : 0.985)
                    }
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
                showHeroCard = false
                showFocusCard = false
                showTodayTasksCard = false
                showMomentumCard = false
                showWeekCard = false
                showQuickActionsCard = false

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) { showHeaderCard = true }
                    withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { crewFocusGlowPulse = true }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) { showHeroCard = true }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) { showFocusCard = true }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) { showTodayTasksCard = true }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) { showMomentumCard = true }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) { showWeekCard = true }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                    withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) { showQuickActionsCard = true }
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

    @ViewBuilder
    var suggestedActionSection: some View {
        if let suggestedAction = dailyFlowSnapshot.suggestedAction,
           shouldShowSecondarySuggestedAction {
            SuggestedNextActionCard(
                action: suggestedAction,
                palette: palette,
                onPrimaryTap: {
                    handleSuggestedPrimaryAction(suggestedAction)
                },
                onSecondaryTap: {
                    handleSuggestedSecondaryAction(suggestedAction)
                }
            )
        }
    }

    func handleSuggestedPrimaryAction(_ action: SuggestedTaskAction) {
        switch action.style {
        case .planTomorrow:
            onOpenWeek()

        case .keepMomentum:
            onAddTask()

        case .lightenLoad:
            showTasksShortcut = true

        case .overdueRecovery, .quickWin, .startFocus, .beforeClass:
            startInlineFocus()
        }
    }
}
