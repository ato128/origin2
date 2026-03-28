//
//  HomeDashboardView+Header.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI
import SwiftData
import Combine

extension HomeDashboardView {
    var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(greetingText) 👋")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Text(todayDateText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.secondaryText)

                    Text(studentHeaderSubtitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 12)

                Button {
                    if recentChatFriend != nil {
                        showRecentFriendChat = true
                    } else {
                        showFriendsShortcut = true
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 12, weight: .bold))

                        Text("Arkadaşlar")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(palette.primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(palette.secondaryCardFill)
                    )
                    .overlay(
                        Capsule()
                            .stroke(palette.cardStroke, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var homeMiniWeekCalendar: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Bu Hafta")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)

                Spacer()

                Button {
                    onOpenWeek()
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(palette.primaryText)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(palette.secondaryCardFill)
                        )
                        .overlay(
                            Circle()
                                .stroke(palette.cardStroke, lineWidth: 1)
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
                                .fill(hasItems ? Color.accentColor : palette.cardStroke)
                                .frame(width: hasItems ? 6 : 4, height: hasItems ? 6 : 4)
                                .opacity(isToday || hasItems ? 1 : 0.7)
                                .padding(.top, 1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    isSelected
                                    ? Color.accentColor.opacity(appTheme == AppTheme.light.rawValue ? 0.14 : 0.18)
                                    : palette.secondaryCardFill
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    isSelected
                                    ? Color.accentColor.opacity(0.28)
                                    : palette.cardStroke,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(secondaryCardBackground)
        }
    }

    var studentHeaderSubtitle: String {
        if let nextEvent {
            let now = currentMinuteOfDay()
            let start = nextEvent.startMinute
            let end = nextEvent.startMinute + nextEvent.durationMinute

            if now >= start && now < end {
                return "\(nextEvent.title) dersindesin, odağını koru."
            }

            if todayBoardTasks.count > 0 {
                return "Bugün \(todayBoardTasks.count) görevin ve sıradaki dersin var."
            }

            return "Bugünün programı hazır."
        }

        if todayBoardTasks.count > 0 {
            return "Bugünkü görevlerini tamamlamaya odaklan."
        }

        return "Bugün sakin bir gün görünüyor."
    }

    func hasEvents(on day: Int) -> Bool {
        let calendar = Calendar.current
        let targetDate = targetDateFor(day: day)
        return allEvents.contains { ev in
            if let scheduledDate = ev.scheduledDate {
                return calendar.isDate(scheduledDate, inSameDayAs: targetDate)
            } else {
                return ev.weekday == day
            }
        }
    }
}
