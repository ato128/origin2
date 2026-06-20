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
                return tr("hh_start_lc")
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
            return tr("hh_in_flow")

        case .crewFollowUp:
            return "Ekip seni bekliyor"

        case .insightsFollowUp:
            return tr("hh_doing_well")

        case .completionWrapUp:
            return currentHour >= 20 ? tr("hh_closing_well") : tr("hh_doing_well")

        case .defaultFlow:
            switch heroDayPhase {
            case .morning:
                return tr("hh_good_morning")
            case .afternoon:
                return tr("hh_going_well")
            case .evening, .night:
                return tr("hh_good_evening")
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
            return tr("hh_good_morning")
        case 12..<18:
            return tr("hh_good_day")
        default:
            return tr("hh_good_evening")
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
                            return tr("hh_in_focus", course)
                        }
                        return task.title
                    }
                    return tr("hd_focus_on")

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
                return tr("hh_crew_open")
            }

            return tr("hh_check_crew")

        case .insightsFollowUp:
            if completedTodayCount > 0 {
                return tr("hh_see_rhythm")
            }

            return tr("hh_check_today")

        case .completionWrapUp:
            if currentHour >= 20 {
                return tr("hh_close_calm")
            }

            return tr("hh_progress_today")

        case .defaultFlow:
            if let nextEvent {
                let now = currentMinuteOfDay()
                let start = nextEvent.startMinute
                let end = nextEvent.startMinute + nextEvent.durationMinute

                if now >= start && now < end {
                    return tr("hh_now_active", nextEvent.title)
                }

                let diff = start - now
                if diff > 0 && diff <= 45 {
                    return "\(nextEvent.title) \(diff) dk sonra"
                }
            }

            if let topTask = todayPendingTasks.first {
                if store.isOverdue(topTask) {
                    return tr("hh_clear_overdue")
                }

                return tr("hh_today_first", topTask.title)
            }

            return tr("hh_today_calm")
        }
    }
}
