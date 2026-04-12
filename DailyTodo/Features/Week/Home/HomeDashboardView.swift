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

    @AppStorage("homeDashboardAnimatedAppearCount") private var homeDashboardAnimatedAppearCount: Int = 0

    let palette = ThemePalette()

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var store: TodoStore
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var focusSession: FocusSessionManager
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

    @State var selectedDay: Int = 0
    @State var showFriendsShortcut = false
    @State var showRecentFriendChat = false
    @State var showTasksShortcut = false
    @State var crewFocusGlowPulse: Bool = false
    @State var crewFocusNow = Date()

    @State var showHeaderCard = false
    @State var showOverviewCards = false
    @State var showFocusCard = false
    @State var showTodayTasksCard = false
    @State var showMomentumCard = false
    @State var showWeekCard = false

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

    var shouldPrioritizeMomentumBeforeTasks: Bool {
        switch resolvedHeroKind {
        case .upcomingExam, .wrapUp, .insightsFollowUp, .crewFollowUp, .socialFollowUp:
            return true
        default:
            return false
        }
    }

    var shouldShowTodayTasksCard: Bool {
        if !todayBoardTasks.isEmpty { return true }
        if resolvedHeroKind == .overdueTask { return false }
        if resolvedHeroKind == .nextClass { return false }
        if resolvedHeroKind == .upcomingExam { return false }
        if resolvedHeroKind == .noTaskPrompt { return false }
        return false
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

    @ViewBuilder
    func smartSuggestedActionStrip(action: SuggestedTaskAction) -> some View {
        let tint = suggestedActionTint(for: action)

        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                tint.opacity(0.24),
                                tint.opacity(0.08),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: 24
                        )
                    )
                    .frame(width: 38, height: 38)

                Circle()
                    .fill(Color.white.opacity(0.045))
                    .frame(width: 32, height: 32)

                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    .frame(width: 32, height: 32)

                Image(systemName: suggestedActionIcon(for: action))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint.opacity(0.98))
                    .shadow(color: tint.opacity(0.20), radius: 4)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(1)

                Text(action.subtitle)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.secondaryText.opacity(0.92))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button {
                handleSuggestedPrimaryAction(action)
            } label: {
                HStack(spacing: 5) {
                    Text(suggestedPrimaryCTA(for: action))
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 9.5, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint.opacity(0.94),
                                    tint.opacity(0.76)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: tint.opacity(0.20), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            palette.cardFill,
                            palette.cardFill.opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    tint.opacity(0.12),
                                    Color.clear
                                ],
                                center: .topLeading,
                                startRadius: 4,
                                endRadius: 140
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    tint.opacity(0.08),
                                    Color.clear
                                ],
                                center: .bottomTrailing,
                                startRadius: 8,
                                endRadius: 160
                            )
                        )
                        .blur(radius: 10)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(tint.opacity(0.14), lineWidth: 1)
                )
        )
    }

    private func runEntranceSequence(animated: Bool) {
        if animated {
            showHeaderCard = false
            showOverviewCards = false
            showFocusCard = false
            showTodayTasksCard = false
            showMomentumCard = false
            showWeekCard = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                    showHeaderCard = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                    showOverviewCards = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                    showFocusCard = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                    showTodayTasksCard = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                    showWeekCard = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                    showMomentumCard = true
                }
            }
        } else {
            showHeaderCard = true
            showOverviewCards = true
            showFocusCard = true
            showTodayTasksCard = true
            showMomentumCard = true
            showWeekCard = true
        }
    }

    func suggestedActionTint(for action: SuggestedTaskAction) -> Color {
        switch action.style {
        case .planTomorrow: return .purple
        case .keepMomentum: return .green
        case .lightenLoad: return .orange
        case .overdueRecovery: return .red
        case .quickWin: return .blue
        case .startFocus: return .blue
        case .beforeClass: return .indigo
        }
    }

    func suggestedActionIcon(for action: SuggestedTaskAction) -> String {
        switch action.style {
        case .planTomorrow: return "calendar.badge.plus"
        case .keepMomentum: return "flame.fill"
        case .lightenLoad: return "sparkles"
        case .overdueRecovery: return "exclamationmark.triangle.fill"
        case .quickWin: return "bolt.fill"
        case .startFocus: return "play.fill"
        case .beforeClass: return "clock.fill"
        }
    }

    func suggestedPrimaryCTA(for action: SuggestedTaskAction) -> String {
        switch action.style {
        case .planTomorrow: return "Planla"
        case .keepMomentum: return "Ekle"
        case .lightenLoad: return "Aç"
        case .overdueRecovery: return "Başla"
        case .quickWin: return "Yap"
        case .startFocus: return "Odaklan"
        case .beforeClass: return "Geç"
        }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                        .offset(y: showHeaderCard ? 0 : 18)
                        .opacity(showHeaderCard ? 1 : 0)
                        .scaleEffect(showHeaderCard ? 1 : 0.985)

                    todayOverviewTopCards
                        .offset(y: showOverviewCards ? 0 : 18)
                        .opacity(showOverviewCards ? 1 : 0)
                        .scaleEffect(showOverviewCards ? 1 : 0.985)

                    if shouldShowFocusCard {
                        currentFocusCard
                            .offset(y: showFocusCard ? 0 : 18)
                            .opacity(showFocusCard ? 1 : 0)
                            .scaleEffect(showFocusCard ? 1 : 0.985)
                    }

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
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 36)
                .animation(.spring(response: 0.38, dampingFraction: 0.86), value: focusSession.isSessionActive)
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

                if !didLoadCrewFocusSessions {
                    didLoadCrewFocusSessions = true
                    Task {
                        await crewStore.loadCrews()
                        for crew in crewStore.crews {
                            await crewStore.loadActiveFocusSession(for: crew.id)
                        }
                    }
                }

                let shouldAnimateEntrance = homeDashboardAnimatedAppearCount < 2

                if shouldAnimateEntrance {
                    homeDashboardAnimatedAppearCount += 1
                }

                crewFocusGlowPulse = false
                runEntranceSequence(animated: shouldAnimateEntrance)
            }
            .onReceive(dashboardTimer) { value in
                crewFocusNow = value
                selectedDay = weekdayIndexToday()
            }
        }
    }

    @ViewBuilder
    var suggestedActionSection: some View {
        if let suggestedAction = dailyFlowSnapshot.suggestedAction,
           shouldShowSecondarySuggestedAction {
            smartSuggestedActionStrip(action: suggestedAction)
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
