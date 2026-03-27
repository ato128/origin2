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
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(greetingText) 👋")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Text(todayDateText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.secondaryText)

                    Text(tr("home_header_stay_productive"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer(minLength: 12)

                if let recentFriend = recentChatFriend {
                    Button {
                        showRecentFriendChat = true
                    } label: {
                        HStack(spacing: 7) {
                            ZStack {
                                Circle()
                                    .fill(hexColor(recentFriend.colorHex).opacity(0.14))
                                    .frame(width: 22, height: 22)
                                    .shadow(
                                        color: isSharedFocusActive ? hexColor(recentFriend.colorHex).opacity(0.28) : .clear,
                                        radius: isSharedFocusActive ? 6 : 0
                                    )

                                Image(systemName: recentFriend.avatarSymbol)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(hexColor(recentFriend.colorHex))

                                Circle()
                                    .fill(isSharedFocusActive ? .green : palette.accent)
                                    .frame(width: 7, height: 7)
                                    .overlay(Circle().stroke(palette.cardFill, lineWidth: 1.4))
                                    .scaleEffect(isSharedFocusActive ? (pulseRecentFriendPill ? 1.18 : 0.92) : 1.0)
                                    .opacity(isSharedFocusActive ? (pulseRecentFriendPill ? 0.9 : 1.0) : 1.0)
                                    .offset(x: 7, y: -7)
                            }

                            Text(
                                isSharedFocusActive
                                ? "\((recentFriend.name.components(separatedBy: " ").first ?? recentFriend.name)) • \(tr("home_focus_short"))"
                                : (recentFriend.name.components(separatedBy: " ").first ?? recentFriend.name)
                            )
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(palette.primaryText)
                            .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(palette.secondaryCardFill))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                isSharedFocusActive ? Color.green.opacity(0.22) : palette.cardStroke,
                                lineWidth: 1
                            )
                        )
                        .shadow(
                            color: isSharedFocusActive ? Color.green.opacity(pulseRecentFriendPill ? 0.16 : 0.08) : .clear,
                            radius: isSharedFocusActive ? (pulseRecentFriendPill ? 10 : 4) : 0
                        )
                        .scaleEffect(pulseRecentFriendPill ? 1.015 : 1.0)
                        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulseRecentFriendPill)
                    }
                    .buttonStyle(.plain)
                    .onAppear { pulseRecentFriendPill = isSharedFocusActive }
                    .onChange(of: isSharedFocusActive) { _, newValue in pulseRecentFriendPill = newValue }
                } else {
                    Button {
                        showFriendsShortcut = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "message.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text(tr("home_friends"))
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(palette.primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(palette.secondaryCardFill))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(palette.cardStroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroCardBackground)
    }

    var homeMiniWeekCalendar: some View {
        VStack(spacing: 10) {
            HStack {
                Text(tr("home_this_week"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)

                Spacer()

                Button {
                    onOpenWeek()
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(palette.primaryText)
                        .padding(7)
                        .background(Circle().fill(palette.secondaryCardFill))
                        .overlay(Circle().stroke(palette.cardStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
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
                        VStack(spacing: 5) {
                            Text(dayTitles[day])
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(isSelected ? palette.primaryText : palette.secondaryText)

                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.system(size: 19, weight: .bold, design: .rounded))
                                .foregroundStyle(palette.primaryText)
                                .monospacedDigit()

                            ZStack {
                                if isToday && !hasItems {
                                    Circle()
                                        .stroke(Color.accentColor.opacity(0.7), lineWidth: 1.5)
                                        .frame(width: 7, height: 7)
                                } else {
                                    Circle()
                                        .fill(hasItems ? Color.accentColor : palette.cardStroke)
                                        .frame(width: hasItems ? 6 : 4, height: hasItems ? 6 : 4)
                                }
                            }
                            .frame(height: 8)
                            .padding(.top, 1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    isSelected
                                    ? Color.accentColor.opacity(appTheme == AppTheme.light.rawValue ? 0.14 : 0.18)
                                    : palette.secondaryCardFill
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(
                                    isSelected
                                    ? Color.accentColor.opacity(appTheme == AppTheme.light.rawValue ? 0.22 : 0.30)
                                    : palette.cardStroke,
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: isSelected ? Color.accentColor.opacity(0.08) : .clear, radius: isSelected ? 10 : 0)
                        .scaleEffect(isSelected ? 1.015 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(secondaryCardBackground)
        }
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
