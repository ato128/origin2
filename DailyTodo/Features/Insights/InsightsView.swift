//
//  InsightsView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import SwiftUI
import SwiftData

struct InsightsView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.locale) private var locale

    @AppStorage("smartEngineEnabled") private var smartEngineEnabled: Bool = true
    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    @State private var scrollOffset: CGFloat = 0
    @State private var insightSelectedTab: AppTab = .tasks

    @State private var goTasks = false
    @State private var goWeek = false
    @State private var goFocus = false

    @Query(sort: \DTTaskItem.createdAt, order: .reverse)
    private var tasks: [DTTaskItem]

    @Query(sort: \FocusSessionRecord.startedAt, order: .reverse)
    private var focusSessions: [FocusSessionRecord]

    @Query(sort: \EventItem.startMinute, order: .forward)
    private var events: [EventItem]

    @Query(sort: \ExamItem.examDate, order: .forward)
    private var exams: [ExamItem]

    private var currentUserIDString: String? {
        session.currentUser?.id.uuidString
    }

    private var filteredTasks: [DTTaskItem] {
        guard let currentUserIDString else { return [] }
        return tasks.filter { $0.ownerUserID == currentUserIDString }
    }

    private var filteredFocusSessions: [FocusSessionRecord] {
        guard let currentUserIDString else { return [] }
        return focusSessions.filter { $0.ownerUserID == currentUserIDString }
    }

    private var filteredEvents: [EventItem] {
        guard let currentUserIDString else { return [] }
        return events.filter { $0.ownerUserID == currentUserIDString }
    }

    private var filteredExams: [ExamItem] {
        guard let currentUserIDString else { return [] }
        return exams.filter { $0.ownerUserID == currentUserIDString }
    }

    private var vm: InsightsViewModel {
        InsightsViewModel(
            tasks: filteredTasks,
            focusSessions: filteredFocusSessions,
            events: filteredEvents,
            exams: filteredExams,
            userID: currentUserIDString,
            localeIdentifier: locale.identifier
        )
    }

    private var collapseProgress: CGFloat {
        let progress = (-scrollOffset - 20) / 70
        return min(max(progress, 0), 1)
    }

    private var smallTitleOpacity: CGFloat {
        min(max((collapseProgress - 0.15) / 0.55, 0), 1)
    }

    private var showTopBlur: Bool {
        collapseProgress > 0.12
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground()

            if appTheme == AppTheme.gradient.rawValue {
                InsightsAmbientHeader()
                    .frame(height: 300)
                    .ignoresSafeArea()
            }

            if showTopBlur {
                Rectangle()
                    .fill(palette.cardFill)
                    .frame(height: 96)
                    .ignoresSafeArea(edges: .top)
                    .overlay(
                        Rectangle()
                            .fill(palette.cardStroke)
                            .frame(height: 0.5),
                        alignment: .bottom
                    )
                    .transition(.opacity)
            }

            ScrollView {
                ScrollOffsetReader(coordinateSpaceName: "insightsScroll")

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("insights_title")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.primaryText)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 22)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    InsightsCardContainer(delay: 0.02) {
                        StudentInsightHeroCard(data: vm.studentHero) { action in
                            handleInsightAction(action)
                        }
                    }

                    InsightsCardContainer(delay: 0.05) {
                        ExamReadinessCard(data: vm.examReadiness) { action in
                            handleInsightAction(action)
                        }
                    }

                    InsightsCardContainer(delay: 0.08) {
                        CourseBalanceCard(data: vm.courseBalance)
                    }

                    InsightsCardContainer(delay: 0.11) {
                        WeeklyMomentumCard(data: vm.weeklyMomentum)
                    }

                    InsightsCardContainer(delay: 0.14) {
                        StudyPatternCard(data: vm.studyPattern)
                    }

                    InsightsCardContainer(delay: 0.17) {
                        FocusInsightsCard(data: vm.focusInsights)
                    }

                    if smartEngineEnabled {
                        InsightsCardContainer(delay: 0.20) {
                            AICoachCard(data: vm.aiCoach) { action in
                                handleInsightAction(action)
                            }
                        }
                    }

                    if smartEngineEnabled {
                        InsightsCardContainer(delay: 0.23) {
                            SmartSuggestionCard(data: vm.smartSuggestion) { action in
                                handleInsightAction(action)
                            }
                        }
                    }

                    Spacer(minLength: 90)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .coordinateSpace(name: "insightsScroll")
            .onPreferenceChange(ScrollOffsetPreference.self) { value in
                scrollOffset = value
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 0) {
                Text("insights_title")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)
                    .opacity(smallTitleOpacity)
                    .padding(.top, 10)

                Spacer()
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.86), value: collapseProgress)
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(
            Group {
                NavigationLink("", isActive: $goTasks) {
                    TodoListView(selectedTab: $insightSelectedTab)
                }

                NavigationLink("", isActive: $goWeek) {
                    WeekView()
                }

                NavigationLink("", isActive: $goFocus) {
                    FocusSessionView(
                        taskID: nil,
                        taskTitle: String(localized: "insights_quick_focus_title"),
                        onStartFocus: { _, _ in },
                        onTick: { _ in },
                        onFinishFocus: { _, _, _, _, _, _ in },
                        workoutExercises: nil
                    )
                }
            }
            .hidden()
        )
    }

    private func handleInsightAction(_ action: SmartSuggestionAction) {
        switch action {
        case .openTasks:
            goTasks = true
        case .openWeek:
            goWeek = true
        case .openFocus:
            goFocus = true
        case .none:
            break
        }
    }
}
