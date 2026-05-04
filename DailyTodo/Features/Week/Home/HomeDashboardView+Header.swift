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
        HStack(alignment: .top, spacing: 12) {
            ArenaLargeTitle(
                eyebrow: todayDateText.uppercased(),
                title: adaptiveGreetingText,
                accent: headerArenaAccentWord,
                accentColor: headerArenaTint
            )

            Spacer(minLength: 10)

            HStack(spacing: 9) {
                ArenaIconButton(
                    systemName: "plus",
                    tint: headerArenaTint,
                    emphasized: true,
                    action: onAddTask
                )

                ArenaIconButton(
                    systemName: smartEngineEnabled ? "sparkles" : "sparkles.slash",
                    tint: .white.opacity(0.82),
                    emphasized: false,
                    action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            smartEngineEnabled.toggle()
                        }
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
    }
    var headerArenaTint: Color {
        switch homeLayoutMode {
        case .focusActive:
            switch focusSession.selectedMode {
            case .personal:
                return Color(arenaHex: AppArenaPalette.blue)
            case .crew:
                return Color(arenaHex: AppArenaPalette.coral)
            case .friend:
                return Color(arenaHex: AppArenaPalette.purple)
            }

        case .crewFollowUp:
            return Color(arenaHex: AppArenaPalette.coral)

        case .insightsFollowUp:
            return Color(arenaHex: AppArenaPalette.gold)

        case .completionWrapUp:
            return Color(arenaHex: AppArenaPalette.green)

        case .defaultFlow:
            return Color(arenaHex: AppArenaPalette.cyan)
        }
    }

    var headerArenaAccentWord: String {
        switch homeLayoutMode {
        case .focusActive:
            return "focus"

        case .crewFollowUp:
            return "crew"

        case .insightsFollowUp:
            return "ritim"

        case .completionWrapUp:
            return "tamam"

        case .defaultFlow:
            switch heroDayPhase {
            case .morning:
                return "başla"
            case .afternoon:
                return "devam"
            case .evening, .night:
                return "plan"
            }
        }
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
            switch focusSession.selectedMode {
            case .personal:
                return .blue
            case .crew:
                return .pink
            case .friend:
                return .purple
            }

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
            if focusSession.isSessionActive {
                switch focusSession.selectedMode {
                case .personal:
                    if let task = focusTask {
                        let course = task.courseName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !course.isEmpty {
                            return "\(course) odağındasın"
                        }
                        return task.title
                    }
                    return "Odak açık"

                case .crew:
                    if let host = focusSession.hostName, !host.isEmpty {
                        return "\(host) ile ortak focus"
                    }
                    return "Crew focus aktif"

                case .friend:
                    return "Birlikte focus aktif"
                }
            }

            if let activeSession = activeBackendCrewFocusSession {
                return "\(activeSession.title) aktif"
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
