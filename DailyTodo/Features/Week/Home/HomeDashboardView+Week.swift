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

    // MARK: - Week Card

    var homeMiniWeekCalendar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(weekCardAccent)
                            .frame(width: 18, height: 1)

                        Text("WEEK FLOW")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.7)
                            .foregroundStyle(weekCardAccent)
                    }

                    Text(weekCardTitle)
                        .font(.system(size: 25, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(weekCardSubtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 10)

                Button {
                    onOpenWeek()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: weekCardButtonIcon)
                            .font(.system(size: 12, weight: .black))

                        Text(weekCTAButtonTitle.uppercased())
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(0.7)
                    }
                    .foregroundStyle(weekCardAccent)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(
                        Capsule()
                            .fill(weekCardAccent.opacity(0.13))
                            .overlay(
                                Capsule()
                                    .stroke(weekCardAccent.opacity(0.18), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 7) {
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
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(
                                    isSelected
                                    ? .white
                                    : .white.opacity(0.48)
                                )
                                .lineLimit(1)
                                .minimumScaleFactor(0.70)

                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(
                                    isSelected
                                    ? .white
                                    : .white.opacity(0.88)
                                )
                                .monospacedDigit()

                            HStack(spacing: 4) {
                                Circle()
                                    .fill(
                                        dayIndicatorColor(
                                            for: day,
                                            hasItems: hasItems,
                                            isToday: isToday,
                                            isSuggestedDay: isSuggestedDay
                                        )
                                    )
                                    .frame(
                                        width: hasItems || isToday || isSuggestedDay || hasExamDay ? 6 : 4,
                                        height: hasItems || isToday || isSuggestedDay || hasExamDay ? 6 : 4
                                    )

                                if hasExamDay {
                                    Capsule()
                                        .fill(Color(arenaHex: AppArenaPalette.gold))
                                        .frame(width: 10, height: 4)
                                }
                            }
                            .frame(height: 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    dayBackgroundColor(
                                        isSelected: isSelected,
                                        isSuggestedDay: isSuggestedDay,
                                        day: day
                                    )
                                )
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
                            color: isSelected ? weekCardAccent.opacity(0.16) : .clear,
                            radius: isSelected ? 10 : 0,
                            y: isSelected ? 5 : 0
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(weekDaysRailBackground)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(adaptiveWeekCardBackground())
    }

    // MARK: - Text

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

    // MARK: - State

    var weekCardAccent: Color {
        switch homeLayoutMode {
        case .crewFollowUp:
            return Color(arenaHex: AppArenaPalette.coral)
        case .completionWrapUp:
            return Color(arenaHex: AppArenaPalette.purple)
        case .insightsFollowUp:
            return Color(arenaHex: AppArenaPalette.blue)
        case .focusActive:
            return Color(arenaHex: AppArenaPalette.gold)
        case .defaultFlow:
            return Color(arenaHex: AppArenaPalette.blue)
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

    // MARK: - Backgrounds

    var weekDaysRailBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(arenaHex: AppArenaPalette.blue).opacity(0.045),
                        Color(arenaHex: AppArenaPalette.purple).opacity(0.032),
                        Color.white.opacity(0.030)
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
                                weekCardAccent.opacity(shouldEmphasizeWeekCard ? 0.10 : 0.060),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 6,
                            endRadius: 150
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 1)
            )
    }

    func adaptiveWeekCardBackground() -> some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        weekCardAccent.opacity(0.070),
                        Color(arenaHex: AppArenaPalette.purple).opacity(0.045),
                        Color(arenaHex: AppArenaPalette.surface).opacity(0.94)
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
                                weekCardAccent.opacity(0.14),
                                Color.clear
                            ],
                            center: .topTrailing,
                            startRadius: 8,
                            endRadius: 210
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(arenaHex: AppArenaPalette.blue).opacity(0.08),
                                Color.clear
                            ],
                            center: .bottomLeading,
                            startRadius: 10,
                            endRadius: 230
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(weekCardAccent.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 16, y: 9)
    }

    // MARK: - Day Styling

    func dayBackgroundColor(isSelected: Bool, isSuggestedDay: Bool, day: Int) -> Color {
        let count = tasksCount(on: day)

        if isSelected {
            return weekCardAccent.opacity(0.19)
        }

        if isSuggestedDay {
            return Color(arenaHex: AppArenaPalette.purple).opacity(0.10)
        }

        if count >= 4 {
            return Color(arenaHex: AppArenaPalette.coral).opacity(0.09)
        }

        if count >= 2 {
            return Color(arenaHex: AppArenaPalette.gold).opacity(0.08)
        }

        return Color.white.opacity(0.045)
    }

    func dayStrokeColor(isSelected: Bool, isSuggestedDay: Bool) -> Color {
        if isSelected {
            return weekCardAccent.opacity(0.25)
        }

        if isSuggestedDay {
            return Color(arenaHex: AppArenaPalette.purple).opacity(0.20)
        }

        return Color.white.opacity(0.075)
    }

    func dayIndicatorColor(
        for day: Int,
        hasItems: Bool,
        isToday: Bool,
        isSuggestedDay: Bool
    ) -> Color {
        let count = tasksCount(on: day)

        if isToday {
            return Color(arenaHex: AppArenaPalette.cyan)
        }

        if hasExam(on: day) {
            return Color(arenaHex: AppArenaPalette.gold)
        }

        if isSuggestedDay {
            return Color(arenaHex: AppArenaPalette.purple)
        }

        if count >= 4 {
            return Color(arenaHex: AppArenaPalette.coral)
        }

        if count >= 2 {
            return Color(arenaHex: AppArenaPalette.gold)
        }

        if hasItems {
            return Color(arenaHex: AppArenaPalette.blue)
        }

        return Color.white.opacity(0.18)
    }

    // MARK: - Data Helpers

    func hasExam(on day: Int) -> Bool {
        let calendar = Calendar.current
        let targetDate = targetDateFor(day: day)

        return userScopedExams.contains {
            calendar.isDate($0.examDate, inSameDayAs: targetDate)
        }
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
