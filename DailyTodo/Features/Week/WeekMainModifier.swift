//
//  WeekMainModifier.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 24.03.2026.
//

import SwiftUI
import SwiftData
import Combine

struct WeekMainModifier: ViewModifier {
    let weekMode: WeekMode

    let onAppearAction: () -> Void
    let onTask: () async -> Void

    let onCrewChange: (UUID?) -> Void
    let onDayChange: () -> Void
    let onEventsChange: () -> Void
    let onAllEventsChange: () async -> Void

    let liveTimer: Publishers.Autoconnect<Timer.TimerPublisher>
    let onLiveTick: () async -> Void

    let onDisappearAction: () -> Void
    let onCreateTaskChange: (Bool) -> Void
    let onWeekModeChange: (WeekMode) -> Void

    let selectedCrewID: UUID?
    let selectedDay: Int
    let eventsForDayIDs: [UUID]
    let allEventIDs: [UUID]
    let showingCreateCrewTask: Bool

    func body(content: Content) -> some View {
        content
            .animation(.easeInOut(duration: 0.25), value: weekMode)
            .onAppear {
                onAppearAction()
            }
            .task {
                await onTask()
            }
            .onChange(of: selectedCrewID) { _, newValue in
                onCrewChange(newValue)
            }
            .onChange(of: selectedDay) { _, _ in
                onDayChange()
            }
            .onChange(of: eventsForDayIDs) { _, _ in
                onEventsChange()
            }
            .onChange(of: allEventIDs) { _, _ in
                Task {
                    await onAllEventsChange()
                }
            }
            .onReceive(liveTimer) { _ in
                Task {
                    await onLiveTick()
                }
            }
            .onDisappear {
                onDisappearAction()
            }
            .onChange(of: showingCreateCrewTask) { _, isPresented in
                onCreateTaskChange(isPresented)
            }
            .onChange(of: weekMode) { _, newValue in
                onWeekModeChange(newValue)
            }
    }
}
