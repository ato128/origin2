//
//  HomeDashboardView+Actions.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
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
    var quickActionsCard: some View {
        let actions = contextualQuickActions

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(quickActionsCardTitle)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                Text(quickActionsCardSubtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
            }

            HStack(spacing: 10) {
                ForEach(actions) { item in
                    quickActionButton(
                        title: item.title,
                        subtitle: item.subtitle,
                        systemImage: item.systemImage,
                        tint: item.tint,
                        isHighlighted: item.isHighlighted,
                        action: item.action
                    )
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(adaptiveQuickActionsBackground)
        .shadow(
            color: shouldEmphasizeQuickActionsCard ? Color.accentColor.opacity(0.08) : .clear,
            radius: shouldEmphasizeQuickActionsCard ? 10 : 0,
            y: shouldEmphasizeQuickActionsCard ? 4 : 0
        )
    }

    func quickActionButton(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        isHighlighted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint.opacity(isHighlighted ? 0.18 : 0.14))
                        .frame(width: 40, height: 40)

                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isHighlighted ? tint.opacity(0.08) : palette.secondaryCardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isHighlighted ? tint.opacity(0.26) : palette.cardStroke,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isHighlighted ? tint.opacity(0.08) : .clear,
                radius: isHighlighted ? 8 : 0,
                y: isHighlighted ? 3 : 0
            )
        }
        .buttonStyle(.plain)
    }

    var hasUpcomingExamQuickActionPriority: Bool {
        nearestRelevantExam != nil && resolvedHeroKind == .upcomingExam
    }

    var shouldUseNoTaskQuickActions: Bool {
        todayBoardTasks.isEmpty && resolvedHeroKind == .noTaskPrompt
    }

    var shouldUseNightPlanningQuickActions: Bool {
        resolvedHeroKind == .wrapUp || resolvedHeroKind == .noTaskPrompt
    }

    var quickActionFocusMinutesText: String {
        if let exam = nearestRelevantExam {
            return "\(suggestedStudyMinutes(for: exam)) dk"
        }
        return "25 dk"
    }

    var quickActionsCardTitle: String {
        if shouldUseNoTaskQuickActions {
            return tr("ha_to_start")
        }

        if hasUpcomingExamQuickActionPriority {
            return tr("ha_for_exam")
        }

        switch homeLayoutMode {
        case .focusActive:
            return tr("ha_quick_switch")
        case .crewFollowUp:
            return tr("ha_next_steps")
        case .insightsFollowUp:
            return "Devam Et"
        case .completionWrapUp:
            return tr("ha_closing_moves")
        case .defaultFlow:
            return tr("ha_quick_actions")
        }
    }

    var quickActionsCardSubtitle: String {
        if shouldUseNoTaskQuickActions {
            return tr("ha_fill_empty")
        }

        if hasUpcomingExamQuickActionPriority {
            return tr("ha_exam_shortcuts")
        }

        switch homeLayoutMode {
        case .focusActive:
            return tr("ha_keep_focus")
        case .crewFollowUp:
            return tr("ha_switch_flows")
        case .insightsFollowUp:
            return tr("ha_by_rhythm")
        case .completionWrapUp:
            return tr("ha_closing_logical")
        case .defaultFlow:
            return tr("ha_student_shortcuts")
        }
    }

    var contextualQuickActions: [HomeQuickAction] {
        if shouldUseNoTaskQuickActions {
            return [
                HomeQuickAction(
                    title: tr("at_kind_task"),
                    subtitle: tr("ha_add_first_step"),
                    systemImage: "plus",
                    tint: .green,
                    isHighlighted: true,
                    action: onAddTask
                ),
                HomeQuickAction(
                    title: tr("common_tomorrow"),
                    subtitle: tr("ha_plan_ahead"),
                    systemImage: "calendar.badge.plus",
                    tint: .purple,
                    isHighlighted: true,
                    action: onOpenWeek
                ),
                HomeQuickAction(
                    title: tr("at_kind_exam"),
                    subtitle: tr("ha_add_new_exam"),
                    systemImage: "graduationcap.fill",
                    tint: .orange,
                    isHighlighted: false,
                    action: {
                        showTasksShortcut = true
                    }
                )
            ]
        }

        if hasUpcomingExamQuickActionPriority, let exam = nearestRelevantExam {
            let courseTitle = exam.courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? exam.title
                : exam.courseName

            return [
                HomeQuickAction(
                    title: quickActionFocusMinutesText,
                    subtitle: tr("ha_study_course", courseTitle),
                    systemImage: "play.fill",
                    tint: .orange,
                    isHighlighted: true,
                    action: {
                        startSuggestedExamFocus(for: exam)
                    }
                ),
                HomeQuickAction(
                    title: "Planla",
                    subtitle: tr("ha_place_in_week"),
                    systemImage: "calendar.badge.plus",
                    tint: .purple,
                    isHighlighted: true,
                    action: onOpenWeek
                ),
                HomeQuickAction(
                    title: tr("ph_tasks_word"),
                    subtitle: tr("ha_see_prep"),
                    systemImage: "list.bullet",
                    tint: .blue,
                    isHighlighted: false,
                    action: {
                        showTasksShortcut = true
                    }
                )
            ]
        }

        switch homeLayoutMode {
        case .focusActive:
            return [
                HomeQuickAction(
                    title: tr("ph_tasks_word"),
                    subtitle: tr("ha_see_remaining"),
                    systemImage: "list.bullet",
                    tint: .blue,
                    isHighlighted: true,
                    action: { showTasksShortcut = true }
                ),
                HomeQuickAction(
                    title: "Hafta",
                    subtitle: tr("ha_open_schedule"),
                    systemImage: "calendar",
                    tint: .purple,
                    isHighlighted: false,
                    action: onOpenWeek
                ),
                HomeQuickAction(
                    title: tr("hd_insights"),
                    subtitle: tr("ha_see_rhythm"),
                    systemImage: "chart.bar.fill",
                    tint: .orange,
                    isHighlighted: false,
                    action: onOpenInsights
                )
            ]

        case .crewFollowUp:
            return [
                HomeQuickAction(
                    title: "Crew",
                    subtitle: tr("ha_back_to_crew"),
                    systemImage: "person.3.fill",
                    tint: .pink,
                    isHighlighted: true,
                    action: onOpenWeek
                ),
                HomeQuickAction(
                    title: "Hafta",
                    subtitle: tr("ha_open_plan"),
                    systemImage: "calendar.badge.plus",
                    tint: .purple,
                    isHighlighted: false,
                    action: onOpenWeek
                ),
                HomeQuickAction(
                    title: tr("at_kind_task"),
                    subtitle: tr("ha_add_personal"),
                    systemImage: "checklist",
                    tint: .green,
                    isHighlighted: false,
                    action: onAddTask
                )
            ]

        case .insightsFollowUp:
            return [
                HomeQuickAction(
                    title: tr("hd_insights"),
                    subtitle: "Detaya bak",
                    systemImage: "chart.bar.fill",
                    tint: .orange,
                    isHighlighted: true,
                    action: onOpenInsights
                ),
                HomeQuickAction(
                    title: "Hafta",
                    subtitle: tr("ha_open_flow"),
                    systemImage: "calendar",
                    tint: .purple,
                    isHighlighted: false,
                    action: onOpenWeek
                ),
                HomeQuickAction(
                    title: tr("at_kind_task"),
                    subtitle: "Yeni ekle",
                    systemImage: "checklist",
                    tint: .green,
                    isHighlighted: false,
                    action: onAddTask
                )
            ]

        case .completionWrapUp:
            return [
                HomeQuickAction(
                    title: tr("common_tomorrow"),
                    subtitle: tr("ha_build_plan"),
                    systemImage: "calendar.badge.plus",
                    tint: .purple,
                    isHighlighted: true,
                    action: onOpenWeek
                ),
                HomeQuickAction(
                    title: tr("hd_insights"),
                    subtitle: tr("ha_see_day"),
                    systemImage: "chart.bar.fill",
                    tint: .orange,
                    isHighlighted: false,
                    action: onOpenInsights
                ),
                HomeQuickAction(
                    title: tr("at_kind_task"),
                    subtitle: tr("ha_add_small"),
                    systemImage: "plus",
                    tint: .green,
                    isHighlighted: false,
                    action: onAddTask
                )
            ]

        case .defaultFlow:
            let hour = Calendar.current.component(.hour, from: Date())

            if hour < 12 {
                return [
                    HomeQuickAction(
                        title: "Planla",
                        subtitle: tr("ha_arrange_day"),
                        systemImage: "calendar",
                        tint: .purple,
                        isHighlighted: true,
                        action: onOpenWeek
                    ),
                    HomeQuickAction(
                        title: "Odak",
                        subtitle: tr("ha_start_25"),
                        systemImage: "play.fill",
                        tint: .blue,
                        isHighlighted: true,
                        action: startInlineFocus
                    ),
                    HomeQuickAction(
                        title: tr("at_kind_task"),
                        subtitle: "Yeni ekle",
                        systemImage: "plus",
                        tint: .green,
                        isHighlighted: false,
                        action: onAddTask
                    )
                ]
            }

            if hour < 18 {
                return [
                    HomeQuickAction(
                        title: "Odak",
                        subtitle: tr("ha_start_now"),
                        systemImage: "scope",
                        tint: .blue,
                        isHighlighted: true,
                        action: startInlineFocus
                    ),
                    HomeQuickAction(
                        title: tr("at_kind_task"),
                        subtitle: tr("ha_quick_add"),
                        systemImage: "plus",
                        tint: .green,
                        isHighlighted: false,
                        action: onAddTask
                    ),
                    HomeQuickAction(
                        title: "Hafta",
                        subtitle: tr("ha_open_schedule"),
                        systemImage: "calendar.badge.plus",
                        tint: .purple,
                        isHighlighted: false,
                        action: onOpenWeek
                    )
                ]
            }

            return [
                HomeQuickAction(
                    title: tr("common_tomorrow"),
                    subtitle: "Planla",
                    systemImage: "calendar",
                    tint: .purple,
                    isHighlighted: true,
                    action: onOpenWeek
                ),
                HomeQuickAction(
                    title: tr("at_kind_task"),
                    subtitle: "Eklemeyi unutma",
                    systemImage: "plus",
                    tint: .green,
                    isHighlighted: false,
                    action: onAddTask
                ),
                HomeQuickAction(
                    title: tr("hd_insights"),
                    subtitle: tr("ha_see_day"),
                    systemImage: "chart.bar.fill",
                    tint: .orange,
                    isHighlighted: false,
                    action: onOpenInsights
                )
            ]
        }
    }
    
    func startSuggestedExamFocus(for exam: ExamItem) {
        let minutes = suggestedStudyMinutes(for: exam)

        Task {
            _ = await focusSession.startRequestedSession(
                mode: .personal,
                durationMinutes: minutes,
                goal: .study,
                style: .silent
            )
        }
    }

    var adaptiveQuickActionsBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                shouldEmphasizeQuickActionsCard ? Color.accentColor.opacity(0.08) : Color.clear,
                                Color.clear
                            ],
                            center: .topTrailing,
                            startRadius: 12,
                            endRadius: 220
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        shouldEmphasizeQuickActionsCard
                        ? Color.accentColor.opacity(0.22)
                        : palette.cardStroke,
                        lineWidth: 1
                    )
            )
    }
}
