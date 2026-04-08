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
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 8) {
                Text(todayDateText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)

                Circle()
                    .fill(headerAccentColor.opacity(0.85))
                    .frame(width: 4, height: 4)

                Text(homePriorityLine)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(headerAccentColor.opacity(0.95))
                    .lineLimit(1)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }

    var adaptiveGreetingText: String {
        switch homeLayoutMode {
        case .focusActive:
            return "Akıştasın"

        case .crewFollowUp:
            return "Ekip seni bekliyor"

        case .insightsFollowUp:
            return "İyi gidiyorsun"

        case .completionWrapUp:
            return currentHour >= 20 ? "Günü iyi kapatıyorsun" : "İyi gidiyorsun"

        case .defaultFlow:
            switch heroDayPhase {
            case .morning:
                return "Günaydın"
            case .afternoon:
                return "İyi gidiyor"
            case .evening, .night:
                return "İyi akşamlar"
            }
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
            return .blue
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
                        return "\(course) odağındasın"
                    }
                }
                return "Odak açık"
            }
            return "Ritmini koru"

        case .crewFollowUp:
            if let activeSession = activeBackendCrewFocusSession {
                return "\(activeSession.title) aktif"
            }
            if activeCrewTaskCount > 0 {
                return "Crew tarafında açık işler var"
            }
            return "Crew akışına göz at"

        case .insightsFollowUp:
            if completedTodayCount > 0 {
                return "Bugünkü ritmini görebilirsin"
            }
            return "Bugünün akışına göz at"

        case .completionWrapUp:
            if currentHour >= 20 {
                return "Günü sakin kapatabilirsin"
            }
            return "Bugün iyi ilerliyorsun"

        case .defaultFlow:
            if let nextEvent {
                let now = currentMinuteOfDay()
                let start = nextEvent.startMinute
                let end = nextEvent.startMinute + nextEvent.durationMinute

                if now >= start && now < end {
                    return "\(nextEvent.title) şu an aktif"
                }

                let diff = start - now
                if diff > 0 && diff <= 45 {
                    return "\(nextEvent.title) \(diff) dk sonra"
                }
            }

            if let topTask = todayPendingTasks.first {
                if store.isOverdue(topTask) {
                    return "Önce geciken görevi temizle"
                }
                return "Bugün önce \(topTask.title)"
            }

            return "Bugün sakin görünüyor"
        }
    }
}
