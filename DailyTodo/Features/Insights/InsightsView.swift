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
    @State private var isStudyMode = false

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

    private var largeHeaderTitle: String {
        isStudyMode ? "Study Insights" : String(localized: "insights_title")
    }

    private var smallHeaderTitle: String {
        isStudyMode ? "Study Insights" : String(localized: "insights_title")
    }

    private var contentSpacing: CGFloat {
        isStudyMode ? 12 : 16
    }

    private var horizontalPadding: CGFloat {
        isStudyMode ? 14 : 16
    }

    private var largeTitleSize: CGFloat {
        isStudyMode ? 30 : 36
    }

    private var studyHeaderBottomPadding: CGFloat {
        isStudyMode ? 10 : 22
    }

    private var studyHeaderTopPadding: CGFloat {
        isStudyMode ? 4 : 8
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

                VStack(spacing: contentSpacing) {
                    headerSection

                    if isStudyMode {
                        studyContent
                    } else {
                        classicContent
                    }

                    Spacer(minLength: isStudyMode ? 74 : 90)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, isStudyMode ? 4 : 8)
            }
            .coordinateSpace(name: "insightsScroll")
            .onPreferenceChange(ScrollOffsetPreference.self) { value in
                scrollOffset = value
            }
            .scrollIndicators(.hidden)

            collapsedTopTitle
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

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: isStudyMode ? 6 : 8) {
                if isStudyMode {
                    HStack(alignment: .center, spacing: 10) {
                        Text("Study Insights")
                            .font(.system(size: largeTitleSize, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.primaryText)

                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                            .offset(y: 1)
                    }

                    Text("Akıllı öğrenci görünümü")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                } else {
                    Text(String(localized: "insights_title"))
                        .font(.system(size: largeTitleSize, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                }
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    isStudyMode.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(palette.secondaryCardFill)
                        .frame(width: isStudyMode ? 40 : 42, height: isStudyMode ? 40 : 42)
                        .overlay(
                            Circle()
                                .stroke(
                                    isStudyMode ? Color.accentColor.opacity(0.18) : palette.cardStroke,
                                    lineWidth: 1
                                )
                        )

                    Image(systemName: isStudyMode ? "chart.bar.fill" : "graduationcap.fill")
                        .font(.system(size: isStudyMode ? 16 : 18, weight: .bold))
                        .foregroundStyle(isStudyMode ? palette.primaryText : Color.accentColor)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isStudyMode ? "Normal Insights" : "Study Insights")
        }
        .padding(.horizontal, isStudyMode ? 4 : 20)
        .padding(.top, studyHeaderTopPadding)
        .padding(.bottom, studyHeaderBottomPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var classicContent: some View {
        Group {
            InsightsCardContainer(delay: 0.02) {
                OverviewCard(data: vm.overview)
            }

            InsightsCardContainer(delay: 0.05) {
                ProductivityScoreCard(data: vm.productivityScore)
            }

            InsightsCardContainer(delay: 0.08) {
                ConsistencyScoreCard(data: vm.consistencyScore)
            }

            InsightsCardContainer(delay: 0.11) {
                MostBusyDayCard(data: vm.mostBusyDay)
            }

            InsightsCardContainer(delay: 0.14) {
                DailyBoostCard(data: vm.dailyBoost)
            }

            InsightsCardContainer(delay: 0.17) {
                StudyHeatMapCard(data: vm.heatmap)
            }

            InsightsCardContainer(delay: 0.20) {
                FocusInsightsCard(data: vm.focusInsights)
            }

            if smartEngineEnabled {
                InsightsCardContainer(delay: 0.23) {
                    AICoachCard(data: vm.aiCoach) { action in
                        handleInsightAction(action)
                    }
                }
            }

            if smartEngineEnabled {
                InsightsCardContainer(delay: 0.26) {
                    SmartSuggestionCard(data: vm.smartSuggestion) { action in
                        handleInsightAction(action)
                    }
                }
            }
        }
    }

    private var studyContent: some View {
        Group {
            InsightsCardContainer(delay: 0.02) {
                StudyInsightsHeroCard(data: vm.studyHeroPremium) { action in
                    handleInsightAction(action)
                }
            }

            InsightsCardContainer(delay: 0.04) {
                StudyInsightsPagerCard(data: vm.studyDeck) { action in
                    handleInsightAction(action)
                }
            }

            InsightsCardContainer(delay: 0.06) {
                StudyInsightsQuickActionsRow(actions: vm.studyQuickActions) { action in
                    handleInsightAction(action)
                }
            }

            InsightsCardContainer(delay: 0.08) {
                StudyInsightsUnlockCard(data: vm.studyUnlockPrompt) { action in
                    handleInsightAction(action)
                }
            }
        }
    }

    private var collapsedTopTitle: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(smallHeaderTitle)
                    .font(.system(size: isStudyMode ? 16 : 17, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)
                    .opacity(smallTitleOpacity)

                if isStudyMode {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .opacity(smallTitleOpacity)
                }
            }
            .padding(.top, 10)

            Spacer()
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: collapseProgress)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: isStudyMode)
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
