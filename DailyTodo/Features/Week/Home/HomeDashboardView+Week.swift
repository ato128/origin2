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
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(weekCardTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.secondaryText)

                    if !weekCardSubtitle.isEmpty {
                        Text(weekCardSubtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(palette.secondaryText.opacity(0.9))
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button {
                    onOpenWeek()
                } label: {
                    Image(systemName: weekCardButtonIcon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(palette.primaryText)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(palette.secondaryCardFill)
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    shouldEmphasizeWeekCard
                                    ? weekCardAccent.opacity(0.22)
                                    : palette.cardStroke,
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
                    let hasItems = hasEvents(on: day)
                    let isSuggestedDay = suggestedWeekDay == day

                    Button {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                            selectedDay = day
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(dayTitles[day])
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(isSelected ? palette.primaryText : palette.secondaryText)

                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(palette.primaryText)
                                .monospacedDigit()

                            Circle()
                                .fill(dayIndicatorColor(for: day, hasItems: hasItems, isToday: isToday, isSuggestedDay: isSuggestedDay))
                                .frame(
                                    width: (hasItems || isSuggestedDay || isToday) ? 6 : 4,
                                    height: (hasItems || isSuggestedDay || isToday) ? 6 : 4
                                )
                                .opacity(isToday || hasItems || isSuggestedDay ? 1 : 0.7)
                                .padding(.top, 1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(dayBackgroundColor(
                                    isSelected: isSelected,
                                    isSuggestedDay: isSuggestedDay
                                ))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    dayStrokeColor(
                                        isSelected: isSelected,
                                        isSuggestedDay: isSuggestedDay
                                    ),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background {
                adaptiveWeekCardBackground()
            }
        }
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
        switch homeLayoutMode {
        case .focusActive:
            return "Odaktan sonra sıradaki günü gör"
        case .crewFollowUp:
            return "Kişisel ve ekip akışını birlikte gör"
        case .insightsFollowUp:
            return "Bugünden sonra haftanın ritmi nasıl ilerliyor"
        case .completionWrapUp:
            return "Yarın için en doğru günü hızlıca seç"
        case .defaultFlow:
            return ""
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
    func adaptiveWeekCardBackground() -> some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                shouldEmphasizeWeekCard ? weekCardAccent.opacity(0.08) : Color.clear,
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
                        shouldEmphasizeWeekCard
                        ? weekCardAccent.opacity(0.18)
                        : palette.cardStroke,
                        lineWidth: 1
                    )
            )
    }

    func dayBackgroundColor(isSelected: Bool, isSuggestedDay: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(appTheme == AppTheme.light.rawValue ? 0.14 : 0.18)
        }

        if isSuggestedDay {
            return weekCardAccent.opacity(0.08)
        }

        return palette.secondaryCardFill
    }

    func dayStrokeColor(isSelected: Bool, isSuggestedDay: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(0.28)
        }

        if isSuggestedDay {
            return weekCardAccent.opacity(0.22)
        }

        return palette.cardStroke
    }

    func dayIndicatorColor(for day: Int, hasItems: Bool, isToday: Bool, isSuggestedDay: Bool) -> Color {
        if isToday {
            return .accentColor
        }

        if isSuggestedDay {
            return weekCardAccent
        }

        if hasItems {
            return .accentColor
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
}
