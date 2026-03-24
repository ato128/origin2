//
//  WeekView+Lifecycle.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 24.03.2026.
//

import SwiftUI
import SwiftData

extension WeekView {

    @MainActor
    func handleWeekMainTask() async {
        if let userID = session.currentUser?.id {
            crewStore.setCurrentUser(userID)
        }

        await crewStore.loadCrews()

        if selectedCrewID == nil {
            selectedCrewID = crewStore.crews.first?.id
        }

        if let crewID = selectedCrewID {
            await loadWeekCrewBackend(for: crewID)
        }
    }

    func handleWeekModeChange(_ newValue: WeekMode) {
        if newValue == .crew {
            showPersonalEntrance = false
            showCrewEntrance = false
            showCrewTaskHeader = false
            showCrewTaskCards = false
            showPersonalEventCards = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    showCrewEntrance = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                withAnimation(.easeOut(duration: 0.28)) {
                    showCrewTaskHeader = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
                    showCrewTaskCards = true
                }
            }
        } else {
            showCrewEntrance = false
            showCrewTaskHeader = false
            showCrewTaskCards = false
            showPersonalEntrance = false
            showPersonalEventCards = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                    showPersonalEntrance = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                withAnimation(.spring(response: 0.46, dampingFraction: 0.86)) {
                    showPersonalEventCards = true
                }
            }
        }
    }

    func onAppear(proxy: ScrollViewProxy) {
        if !didSetInitialDay {
            didSetInitialDay = true
            selectedDay = weekdayIndexToday()
        }

        if selectedCrewID == nil {
            selectedCrewID = allCrews.first?.id
        }

        if !didInitialAutoScroll {
            didInitialAutoScroll = true
            autoScrollIfNeeded(proxy: proxy)
        }

        animateSummary = true
        pulseTodayDot = true
        showCrewTaskHeader = weekMode == .crew
        showCrewTaskCards = weekMode == .crew
        showPersonalEntrance = weekMode == .personal
        showPersonalEventCards = weekMode == .personal

        if weekMode == .crew {
            showCrewEntrance = true
        }

        Task {
            await NotificationManager.shared.rescheduleAll(events: userScopedEvents)
        }
    }

    func onDayChanged(proxy: ScrollViewProxy) {
        lastAutoScrollTargetID = nil
        animateSummaryCard()
        autoScrollIfNeeded(proxy: proxy)
        showPersonalEventCards = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.86)) {
                showPersonalEventCards = true
            }
        }
    }

    func loadWeekCrewBackend(for crewID: UUID) async {
        await crewStore.loadMembers(for: crewID)
        await crewStore.loadMemberProfiles(for: crewStore.crewMembers)
        await crewStore.loadTasks(for: crewID)
        await crewStore.loadActivities(for: crewID)
        crewStore.subscribeToCrewRealtime(crewID: crewID)
    }

    func allCrewMembersForCrew(_ crewID: UUID) -> [CrewMemberDTO] {
        crewStore.crewMembers.filter { $0.crew_id == crewID }
    }
}
