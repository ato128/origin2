//
//  WeekView+MainContent.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 24.03.2026.
//

import SwiftUI
import SwiftData
import UIKit
import Combine

extension WeekView {

    var weekMainContent: some View {
        ScrollViewReader { proxy in
            weekMainBase(proxy: proxy)
                .toolbar { toolbarContent }
                .overlay(toastView, alignment: .bottom)
                .sheet(isPresented: $showingAdd) {
                    addEventSheet
                }
                .sheet(isPresented: $showPlanAheadSheet) {
                    planAheadSheet
                }
                .sheet(isPresented: $showCrewPickerSheet) {
                    crewPickerSheet
                }
                .sheet(isPresented: $showingCreateCrewTask) {
                    createCrewTaskSheet
                }
                .sheet(item: $editingEvent) { ev in
                    editingEventSheet(ev)
                }
                .sheet(item: $selectedCrewTask) { task in
                    selectedCrewTaskSheet(task)
                }
                .sheet(item: $selectedTaskForEdit) { task in
                    selectedTaskForEditSheet(task)
                }
                .sheet(item: $selectedEventForDetail) { event in
                    selectedEventDetailSheet(event)
                }
        }
    }

    private func weekMainBase(proxy: ScrollViewProxy) -> some View {
        mainList(proxy: proxy)
            .modifier(
                WeekMainModifier(
                    weekMode: weekMode,

                    onAppearAction: {
                        onAppear(proxy: proxy)
                        crewPulse = true
                        commentPulse = true
                    },

                    onTask: {
                        await handleWeekMainTask()
                    },

                    onCrewChange: { newCrewID in
                        guard let id = newCrewID else { return }
                        Task {
                            await loadWeekCrewBackend(for: id)
                        }
                    },

                    onDayChange: {
                        onDayChanged(proxy: proxy)
                    },

                    onEventsChange: {
                        animateSummaryCard()
                        autoScrollIfNeeded(proxy: proxy)
                    },

                    onAllEventsChange: {
                        await NotificationManager.shared.rescheduleAll(events: allEvents)
                    },

                    liveTimer: liveTimer,

                    onLiveTick: {
                        await LiveActivityManager.shared.autoSyncIfNeeded(events: userScopedEvents)
                    },

                    onDisappearAction: {
                        crewStore.unsubscribe()
                    },

                    onCreateTaskChange: { isPresented in
                        if !isPresented, let crewID = selectedCrewID {
                            Task {
                                await loadWeekCrewBackend(for: crewID)
                            }
                        }
                    },

                    onWeekModeChange: { newValue in
                        handleWeekModeChange(newValue)
                    },

                    selectedCrewID: selectedCrewID,
                    selectedDay: selectedDay,
                    eventsForDayIDs: eventsForDayIDs,
                    allEventIDs: allEventIDs,
                    showingCreateCrewTask: showingCreateCrewTask
                )
            )
            .onReceive(NotificationCenter.default.publisher(for: .workoutCompleted)) { notification in
                if let taskID = notification.object as? PersistentIdentifier {
                    markWorkoutTaskDone(taskID: taskID)
                }
            }
    }

    @ViewBuilder
    func mainList(proxy: ScrollViewProxy) -> some View {
        if weekMode == .personal {
            personalWeekList(proxy: proxy)
                .id("personal")
                .transition(.opacity)
        } else {
            crewWeekList
                .id("crew")
                .transition(.opacity)
                .offset(y: showCrewEntrance ? 0 : 20)
                .opacity(showCrewEntrance ? 1 : 0)
                .scaleEffect(showCrewEntrance ? 1.0 : 0.99)
                .animation(.spring(response: 0.42, dampingFraction: 0.88), value: showCrewEntrance)
        }
    }

    var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                if weekMode == .crew {
                    Button {
                        Haptics.impact(.light)
                        shareCrewDay()
                    } label: {
                        Label("Bugünkü crew görevlerini paylaş", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        Haptics.impact(.light)
                        shareSelectedCrew()
                    } label: {
                        Label("Crew'ü paylaş", systemImage: "person.3.fill")
                    }

                    Button {
                        UIPasteboard.general.string = shareTextForCrewDay()
                        Haptics.notify(.success)
                        showCopiedToast()
                    } label: {
                        Label("Kopyala", systemImage: "doc.on.doc")
                    }
                } else {
                    Button {
                        Haptics.impact(.light)
                        shareDay()
                    } label: {
                        Label("Bu günü paylaş", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        Haptics.impact(.light)
                        shareWeek()
                    } label: {
                        Label("Tüm haftayı paylaş", systemImage: "calendar")
                    }

                    Button {
                        UIPasteboard.general.string = shareTextForSelectedDay()
                        Haptics.notify(.success)
                        showCopiedToast()
                    } label: {
                        Label("Kopyala", systemImage: "doc.on.doc")
                    }
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 30, height: 30)
            }

            Button {
                Haptics.impact(.light)
                planAheadDate = Date()
                planAheadMode = weekMode == .crew ? .crew : .personal
                showPlanAheadSheet = true
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 30, height: 30)
            }

            Button {
                Haptics.impact(.medium)

                if weekMode == .crew {
                    if selectedCrew != nil {
                        showingCreateCrewTask = true
                    } else {
                        showCrewPickerSheet = true
                    }
                } else {
                    planAheadDate = targetDateForSelectedDay()
                    showingAdd = true
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 30, height: 30)
            }
        }
    }

    var toastView: some View {
        Group {
            if showCopied {
                Text("Kopyalandı")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(radius: 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 30)
            }
        }
    }
}
