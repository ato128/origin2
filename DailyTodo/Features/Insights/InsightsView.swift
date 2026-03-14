//
//  InsightsView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import SwiftUI
import SwiftData

struct InsightsView: View {
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

    private var vm: InsightsViewModel {
        InsightsViewModel(
            tasks: tasks,
            focusSessions: focusSessions,
            events: events
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
                        Text("Insights")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.primaryText)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 22)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    InsightsCardContainer(delay: 0.02) {
                        DailyBoostCard(data: vm.dailyBoost)
                    }

                    InsightsCardContainer(delay: 0.05) {
                        OverviewCard(data: vm.overview)
                    }

                    InsightsCardContainer(delay: 0.08) {
                        WeeklyProgressCard(data: vm.weeklyProgress)
                    }

                    InsightsCardContainer(delay: 0.11) {
                        StudyHeatMapCard(data: vm.heatmap)
                    }

                    InsightsCardContainer(delay: 0.14) {
                        FocusInsightsCard(data: vm.focusInsights)
                    }

                    InsightsCardContainer(delay: 0.17) {
                        ProductivityScoreCard(data: vm.productivityScore)
                    }

                    InsightsCardContainer(delay: 0.20) {
                        ConsistencyScoreCard(data: vm.consistencyScore)
                    }

                    InsightsCardContainer(delay: 0.23) {
                        MostBusyDayCard(data: vm.mostBusyDay)
                            .frame(maxWidth: .infinity)
                    }

                    if smartEngineEnabled {
                        InsightsCardContainer(delay: 0.245) {
                            AICoachCard(data: vm.aiCoach) { action in
                                handleInsightAction(action)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    if smartEngineEnabled {
                        InsightsCardContainer(delay: 0.26) {
                            SmartSuggestionCard(data: vm.smartSuggestion) { action in
                                handleInsightAction(action)
                            }
                            .frame(maxWidth: .infinity)
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
                Text("Insights")
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
                        taskTitle: "Quick Focus",
                        onStartFocus: { _, _ in },
                        onTick: { _ in },
                        onFinishFocus: { _, _, _, _, _, _ in }
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
