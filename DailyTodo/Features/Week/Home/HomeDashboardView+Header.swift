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
                    Text("\(adaptiveGreetingText) \(headerEmoji)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Text(todayDateText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.secondaryText)

                    Text(homePriorityLine)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(headerAccentColor.opacity(0.95))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
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
                        Image(systemName: headerPeopleButtonIcon)
                            .font(.system(size: 12, weight: .bold))

                        Text(headerPeopleButtonTitle)
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(palette.primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(headerPeopleButtonFill)
                    )
                    .overlay(
                        Capsule()
                            .stroke(headerPeopleButtonStroke, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var adaptiveGreetingText: String {
        switch homeLayoutMode {
        case .focusActive:
            return "Akıştasın"
        case .crewFollowUp:
            return greetingText
        case .insightsFollowUp:
            return "İyi gidiyorsun"
        case .completionWrapUp:
            return currentHour >= 20 ? "Günü kapat" : greetingText
        case .defaultFlow:
            return greetingText
        }
    }

    var headerEmoji: String {
        switch homeLayoutMode {
        case .focusActive:
            return "🎯"
        case .crewFollowUp:
            return "👥"
        case .insightsFollowUp:
            return "✨"
        case .completionWrapUp:
            return currentHour >= 20 ? "🌙" : "✅"
        case .defaultFlow:
            if currentHour < 12 { return "☀️" }
            if currentHour < 18 { return "👋" }
            return "🌆"
        }
    }

    var headerAccentColor: Color {
        switch homeLayoutMode {
        case .focusActive:
            return .blue
        case .crewFollowUp:
            return .pink
        case .insightsFollowUp:
            return .orange
        case .completionWrapUp:
            return .green
        case .defaultFlow:
            return palette.secondaryText
        }
    }

    var headerPeopleButtonTitle: String {
        switch homeLayoutMode {
        case .crewFollowUp:
            return "Crew"
        case .focusActive:
            return recentChatFriend != nil ? "Sohbet" : "Arkadaşlar"
        default:
            return "Arkadaşlar"
        }
    }

    var headerPeopleButtonIcon: String {
        switch homeLayoutMode {
        case .crewFollowUp:
            return "person.3.fill"
        default:
            return "person.2.fill"
        }
    }

    var headerPeopleButtonFill: Color {
        switch homeLayoutMode {
        case .crewFollowUp:
            return Color.pink.opacity(0.10)
        case .insightsFollowUp:
            return Color.orange.opacity(0.08)
        default:
            return palette.secondaryCardFill
        }
    }

    var headerPeopleButtonStroke: Color {
        switch homeLayoutMode {
        case .crewFollowUp:
            return Color.pink.opacity(0.20)
        case .insightsFollowUp:
            return Color.orange.opacity(0.18)
        default:
            return palette.cardStroke
        }
    }

    var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Günaydın"
        case 12..<18:
            return "İyi günler"
        default:
            return "İyi akşamlar"
        }
    }

    var todayDateText: String {
        Date.now.formatted(
            Date.FormatStyle()
                .locale(locale)
                .day()
                .month(.wide)
                .weekday(.wide)
        )
    }

    var homePriorityLine: String {
        switch homeLayoutMode {
        case .focusActive:
            if isFocusActive || hasAnyActiveFocusSession {
                if let task = focusTask {
                    let course = task.courseName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !course.isEmpty {
                        return "\(course) odağındasın. Ritmi bozma."
                    }
                }
                return "Odak açık. Küçük ama net devam et."
            }
            return "Akışı koru."

        case .crewFollowUp:
            if let activeSession = activeBackendCrewFocusSession {
                return "\(activeSession.title) için crew akışı aktif."
            }
            if activeCrewTaskCount > 0 {
                return "Kişisel taraf tamamlanınca crew tarafına geç."
            }
            return "Ekip tarafında kontrol edilecek şeyler olabilir."

        case .insightsFollowUp:
            if completedTodayCount > 0 {
                return "Bugünkü ritmini içgörülerden daha net görebilirsin."
            }
            return "Bugünün akışını hızlıca gözden geçirebilirsin."

        case .completionWrapUp:
            if currentHour >= 20 {
                return "Bugün sakin görünüyor. İstersen yarını planla."
            }
            return "Bugünün yükü büyük ölçüde tamam."

        case .defaultFlow:
            if let nextEvent {
                let now = currentMinuteOfDay()
                let start = nextEvent.startMinute
                let end = nextEvent.startMinute + nextEvent.durationMinute

                if now >= start && now < end {
                    return "\(nextEvent.title) aktif. Odağını koru."
                }

                let diff = start - now
                if diff > 0 && diff <= 45 {
                    return "\(nextEvent.title) \(diff) dk sonra başlıyor."
                }
            }

            if let topTask = todayPendingTasks.first {
                if store.isOverdue(topTask) {
                    return "Önce geciken görevi temizlemek iyi olur."
                }
                return "Bugün önce \(topTask.title) ile başla."
            }

            return "Bugün sakin görünüyor. İstersen yarını planla."
        }
    }
}
