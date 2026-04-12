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
            return "Başlamak İçin"
        }

        if hasUpcomingExamQuickActionPriority {
            return "Sınav İçin"
        }

        switch homeLayoutMode {
        case .focusActive:
            return "Hızlı Geçiş"
        case .crewFollowUp:
            return "Sıradaki Adımlar"
        case .insightsFollowUp:
            return "Devam Et"
        case .completionWrapUp:
            return "Kapanış Hamleleri"
        case .defaultFlow:
            return "Hızlı İşlemler"
        }
    }

    var quickActionsCardSubtitle: String {
        if shouldUseNoTaskQuickActions {
            return "Boş ekranı küçük bir adımla doldur"
        }

        if hasUpcomingExamQuickActionPriority {
            return "Yaklaşan sınav için en mantıklı kısa yollar"
        }

        switch homeLayoutMode {
        case .focusActive:
            return "Odak akışını bozmadan ilerle"
        case .crewFollowUp:
            return "Takım ve kişisel akış arasında geçiş yap"
        case .insightsFollowUp:
            return "Bugünkü ritme göre devam et"
        case .completionWrapUp:
            return "Günü kapatırken mantıklı hamleler"
        case .defaultFlow:
            return "Öğrenci akışın için kısa yollar"
        }
    }

    var contextualQuickActions: [HomeQuickAction] {
        if shouldUseNoTaskQuickActions {
            return [
                HomeQuickAction(
                    title: "Görev",
                    subtitle: "İlk adımı ekle",
                    systemImage: "plus",
                    tint: .green,
                    isHighlighted: true,
                    action: onAddTask
                ),
                HomeQuickAction(
                    title: "Yarın",
                    subtitle: "Önceden planla",
                    systemImage: "calendar.badge.plus",
                    tint: .purple,
                    isHighlighted: true,
                    action: onOpenWeek
                ),
                HomeQuickAction(
                    title: "Sınav",
                    subtitle: "Yeni sınav ekle",
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
                    subtitle: "\(courseTitle) çalış",
                    systemImage: "play.fill",
                    tint: .orange,
                    isHighlighted: true,
                    action: {
                        startSuggestedExamFocus(for: exam)
                    }
                ),
                HomeQuickAction(
                    title: "Planla",
                    subtitle: "Week’e yerleştir",
                    systemImage: "calendar.badge.plus",
                    tint: .purple,
                    isHighlighted: true,
                    action: onOpenWeek
                ),
                HomeQuickAction(
                    title: "Görevler",
                    subtitle: "Hazırlıkları gör",
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
                    title: "Görevler",
                    subtitle: "Kalanları gör",
                    systemImage: "list.bullet",
                    tint: .blue,
                    isHighlighted: true,
                    action: { showTasksShortcut = true }
                ),
                HomeQuickAction(
                    title: "Hafta",
                    subtitle: "Programı aç",
                    systemImage: "calendar",
                    tint: .purple,
                    isHighlighted: false,
                    action: onOpenWeek
                ),
                HomeQuickAction(
                    title: "İçgörü",
                    subtitle: "Ritmi gör",
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
                    subtitle: "Takıma dön",
                    systemImage: "person.3.fill",
                    tint: .pink,
                    isHighlighted: true,
                    action: onOpenWeek
                ),
                HomeQuickAction(
                    title: "Hafta",
                    subtitle: "Planı aç",
                    systemImage: "calendar.badge.plus",
                    tint: .purple,
                    isHighlighted: false,
                    action: onOpenWeek
                ),
                HomeQuickAction(
                    title: "Görev",
                    subtitle: "Kişisel ekle",
                    systemImage: "checklist",
                    tint: .green,
                    isHighlighted: false,
                    action: onAddTask
                )
            ]

        case .insightsFollowUp:
            return [
                HomeQuickAction(
                    title: "İçgörü",
                    subtitle: "Detaya bak",
                    systemImage: "chart.bar.fill",
                    tint: .orange,
                    isHighlighted: true,
                    action: onOpenInsights
                ),
                HomeQuickAction(
                    title: "Hafta",
                    subtitle: "Akışı aç",
                    systemImage: "calendar",
                    tint: .purple,
                    isHighlighted: false,
                    action: onOpenWeek
                ),
                HomeQuickAction(
                    title: "Görev",
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
                    title: "Yarın",
                    subtitle: "Planı kur",
                    systemImage: "calendar.badge.plus",
                    tint: .purple,
                    isHighlighted: true,
                    action: onOpenWeek
                ),
                HomeQuickAction(
                    title: "İçgörü",
                    subtitle: "Günü gör",
                    systemImage: "chart.bar.fill",
                    tint: .orange,
                    isHighlighted: false,
                    action: onOpenInsights
                ),
                HomeQuickAction(
                    title: "Görev",
                    subtitle: "Küçük ekle",
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
                        subtitle: "Günü düzenle",
                        systemImage: "calendar",
                        tint: .purple,
                        isHighlighted: true,
                        action: onOpenWeek
                    ),
                    HomeQuickAction(
                        title: "Odak",
                        subtitle: "25 dk başlat",
                        systemImage: "play.fill",
                        tint: .blue,
                        isHighlighted: true,
                        action: startInlineFocus
                    ),
                    HomeQuickAction(
                        title: "Görev",
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
                        subtitle: "Şimdi başla",
                        systemImage: "scope",
                        tint: .blue,
                        isHighlighted: true,
                        action: startInlineFocus
                    ),
                    HomeQuickAction(
                        title: "Görev",
                        subtitle: "Hızlı ekle",
                        systemImage: "plus",
                        tint: .green,
                        isHighlighted: false,
                        action: onAddTask
                    ),
                    HomeQuickAction(
                        title: "Hafta",
                        subtitle: "Programı aç",
                        systemImage: "calendar.badge.plus",
                        tint: .purple,
                        isHighlighted: false,
                        action: onOpenWeek
                    )
                ]
            }

            return [
                HomeQuickAction(
                    title: "Yarın",
                    subtitle: "Planla",
                    systemImage: "calendar",
                    tint: .purple,
                    isHighlighted: true,
                    action: onOpenWeek
                ),
                HomeQuickAction(
                    title: "Görev",
                    subtitle: "Eklemeyi unutma",
                    systemImage: "plus",
                    tint: .green,
                    isHighlighted: false,
                    action: onAddTask
                ),
                HomeQuickAction(
                    title: "İçgörü",
                    subtitle: "Günü gör",
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
