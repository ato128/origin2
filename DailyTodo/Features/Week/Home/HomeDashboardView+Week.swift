//
//  HomeDashboardView+Week.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 30.03.2026.
//

import SwiftUI
import SwiftData
import Combine

extension HomeDashboardView {
    var homeMiniWeekCalendar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(weekCardTitle)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                        .shadow(color: .white.opacity(0.04), radius: 2, y: 1)

                    Text(weekCardSubtitle)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 10)

                Button {
                    onOpenWeek()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: weekCardButtonIcon)
                            .font(.system(size: 11.5, weight: .bold))

                        Text(weekCTAButtonTitle)
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(
                        shouldEmphasizeWeekCard ? weekCardAccent : palette.primaryText
                    )
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(
                                shouldEmphasizeWeekCard
                                ? weekCardAccent.opacity(0.10)
                                : palette.secondaryCardFill.opacity(0.96)
                            )
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                shouldEmphasizeWeekCard
                                ? weekCardAccent.opacity(0.14)
                                : palette.cardStroke.opacity(0.88),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { day in
                    let isSelected = day == selectedDay
                    let isToday = day == weekdayIndexToday()
                    let date = targetDateFor(day: day)
                    let taskCount = tasksCount(on: day)
                    let hasItems = hasEvents(on: day) || taskCount > 0
                    let isSuggestedDay = suggestedWeekDay == day
                    let hasExamDay = hasExam(on: day)

                    Button {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                            selectedDay = day
                        }
                    } label: {
                        VStack(spacing: 7) {
                            Text(dayTitles[day])
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    isSelected ? palette.primaryText : palette.secondaryText
                                )

                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(palette.primaryText)
                                .monospacedDigit()

                            HStack(spacing: 4) {
                                Circle()
                                    .fill(dayIndicatorColor(
                                        for: day,
                                        hasItems: hasItems,
                                        isToday: isToday,
                                        isSuggestedDay: isSuggestedDay
                                    ))
                                    .frame(
                                        width: hasItems || isToday || isSuggestedDay || hasExamDay ? 6 : 4,
                                        height: hasItems || isToday || isSuggestedDay || hasExamDay ? 6 : 4
                                    )

                                if hasExamDay {
                                    Capsule()
                                        .fill(Color.orange.opacity(0.92))
                                        .frame(width: 10, height: 4)
                                }
                            }
                            .frame(height: 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(dayBackgroundColor(
                                    isSelected: isSelected,
                                    isSuggestedDay: isSuggestedDay,
                                    day: day
                                ))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(
                                    dayStrokeColor(
                                        isSelected: isSelected,
                                        isSuggestedDay: isSuggestedDay
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: isSelected ? weekCardAccent.opacity(0.12) : .clear,
                            radius: isSelected ? 8 : 0,
                            y: isSelected ? 4 : 0
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.030),
                                Color.white.opacity(0.018)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        weekCardAccent.opacity(shouldEmphasizeWeekCard ? 0.08 : 0.04),
                                        Color.clear
                                    ],
                                    center: .topLeading,
                                    startRadius: 6,
                                    endRadius: 140
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(
                                shouldEmphasizeWeekCard
                                ? weekCardAccent.opacity(0.08)
                                : palette.cardStroke.opacity(0.76),
                                lineWidth: 1
                            )
                    )
            )
        }
        .padding(20)
        .background(adaptiveWeekCardBackground())
    }

    var weekCardTitle: String {
        switch homeLayoutMode {
        case .focusActive:
            return "Bu Hafta"
        case .crewFollowUp:
            return "Hafta ve Crew"
        case .insightsFollowUp:
            return "Haftanın Akışı"
        case .completionWrapUp:
            return "Yarın ve Hafta"
        case .defaultFlow:
            return "Bu Hafta"
        }
    }

    var weekCardSubtitle: String {
        let busyDays = (0..<7).filter { tasksCount(on: $0) >= 3 }.count
        let emptyDays = (0..<7).filter { tasksCount(on: $0) == 0 }.count

        if shouldUseWrapUpMomentumTone {
            return "Yarın için uygun günü hızlıca seç."
        }

        if hasVisibleUpcomingExamMomentum {
            return "Sınav yaklaşırken haftanı dengede tut."
        }

        if busyDays >= 3 {
            return "\(busyDays) gün yoğun görünüyor."
        }

        if emptyDays >= 3 {
            return "Haftada boş alanların var."
        }

        return "Haftanın akışını tek bakışta gör."
    }

    var weekCTAButtonTitle: String {
        switch homeLayoutMode {
        case .completionWrapUp:
            return "Planla"
        default:
            return "Aç"
        }
    }

    var weekCardButtonIcon: String {
        switch homeLayoutMode {
        case .completionWrapUp:
            return "calendar.badge.plus"
        default:
            return "calendar"
        }
    }

    var weekCardAccent: Color {
        switch homeLayoutMode {
        case .crewFollowUp:
            return .pink
        case .completionWrapUp:
            return .purple
        case .insightsFollowUp:
            return .blue
        case .focusActive:
            return .orange
        case .defaultFlow:
            return .accentColor
        }
    }

    var shouldEmphasizeWeekCard: Bool {
        switch homeLayoutMode {
        case .crewFollowUp, .completionWrapUp:
            return true
        default:
            return false
        }
    }

    var suggestedWeekDay: Int? {
        switch homeLayoutMode {
        case .completionWrapUp:
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            let weekday = Calendar.current.component(.weekday, from: tomorrow)
            return (weekday + 5) % 7
        case .crewFollowUp:
            return nil
        default:
            return nil
        }
    }

    func hasExam(on day: Int) -> Bool {
        let calendar = Calendar.current
        let targetDate = targetDateFor(day: day)

        return userScopedExams.contains {
            calendar.isDate($0.examDate, inSameDayAs: targetDate)
        }
    }

    func adaptiveWeekCardBackground() -> some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        palette.cardFill,
                        palette.cardFill.opacity(0.97)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                shouldEmphasizeWeekCard ? weekCardAccent.opacity(0.10) : weekCardAccent.opacity(0.04),
                                Color.clear
                            ],
                            center: .topTrailing,
                            startRadius: 8,
                            endRadius: 180
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                weekCardAccent.opacity(0.06),
                                Color.clear
                            ],
                            center: .bottomLeading,
                            startRadius: 10,
                            endRadius: 220
                        )
                    )
                    .blur(radius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(
                        shouldEmphasizeWeekCard
                        ? weekCardAccent.opacity(0.14)
                        : palette.cardStroke.opacity(0.86),
                        lineWidth: 1
                    )
            )
    }

    func dayBackgroundColor(isSelected: Bool, isSuggestedDay: Bool, day: Int) -> Color {
        let count = tasksCount(on: day)

        if isSelected {
            return weekCardAccent.opacity(appTheme == AppTheme.light.rawValue ? 0.15 : 0.20)
        }

        if isSuggestedDay {
            return weekCardAccent.opacity(0.08)
        }

        if count >= 4 {
            return Color.red.opacity(0.09)
        }

        if count >= 2 {
            return Color.orange.opacity(0.07)
        }

        return palette.secondaryCardFill.opacity(0.94)
    }

    func dayStrokeColor(isSelected: Bool, isSuggestedDay: Bool) -> Color {
        if isSelected {
            return weekCardAccent.opacity(0.22)
        }

        if isSuggestedDay {
            return weekCardAccent.opacity(0.18)
        }

        return palette.cardStroke.opacity(0.82)
    }

    func dayIndicatorColor(for day: Int, hasItems: Bool, isToday: Bool, isSuggestedDay: Bool) -> Color {
        let count = tasksCount(on: day)

        if isToday {
            return weekCardAccent
        }

        if hasExam(on: day) {
            return .orange
        }

        if isSuggestedDay {
            return weekCardAccent
        }

        if count >= 4 {
            return .red
        }

        if count >= 2 {
            return .orange
        }

        if hasItems {
            return .blue
        }

        return palette.cardStroke
    }

    func hasEvents(on day: Int) -> Bool {
        let calendar = Calendar.current
        let targetDate = targetDateFor(day: day)

        return userScopedEvents.contains { ev in
            if let scheduledDate = ev.scheduledDate {
                return calendar.isDate(scheduledDate, inSameDayAs: targetDate)
            } else {
                return ev.weekday == day
            }
        }
    }

    func tasksCount(on day: Int) -> Int {
        let calendar = Calendar.current
        let targetDate = targetDateFor(day: day)

        return userScopedTasks.filter { task in
            if let due = task.dueDate {
                return calendar.isDate(due, inSameDayAs: targetDate)
            }
            if let week = task.scheduledWeekDate {
                return calendar.isDate(week, inSameDayAs: targetDate)
            }
            return false
        }.count
    }
}
