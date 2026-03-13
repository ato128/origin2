//
//  InsightsView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import SwiftUI
import SwiftData

struct InsightsView: View {
    @State private var scrollOffset: CGFloat = 0

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
            InsightsAmbientHeader()
                .frame(height: 300)
                .ignoresSafeArea()

            if showTopBlur {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(height: 96)
                    .ignoresSafeArea(edges: .top)
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.04))
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
                            .foregroundStyle(.white)
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
                    }

                    InsightsCardContainer(delay: 0.26) {
                        SmartSuggestionCard(data: vm.smartSuggestion)
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
                    .foregroundStyle(.white)
                    .opacity(smallTitleOpacity)
                    .padding(.top, 10)

                Spacer()
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.86), value: collapseProgress)
        }
        .background(Color(.systemGroupedBackground))
        .toolbar(.hidden, for: .navigationBar)
    }
}
