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
                .toolbar(.hidden, for: .navigationBar)
                .overlay(weekFloatingTopActions, alignment: .topTrailing)
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
                .sheet(isPresented: $showCourseSetupSheet) {
                    CourseSetupSheet()
                        .environmentObject(studentStore)
                }
        }
    }
    
    var weekFloatingTopActions: some View {
        HStack(spacing: 9) {
            Menu {
                if weekMode == .crew {
                    Button {
                        Haptics.impact(.light)
                        shareCrewDay()
                    } label: {
                        Label("week_share_today_crew_tasks", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        Haptics.impact(.light)
                        shareSelectedCrew()
                    } label: {
                        Label("week_share_crew", systemImage: "person.3.fill")
                    }

                    Button {
                        UIPasteboard.general.string = shareTextForCrewDay()
                        Haptics.notify(.success)
                        showCopiedToast()
                    } label: {
                        Label("week_copy", systemImage: "doc.on.doc")
                    }
                } else {
                    Button {
                        Haptics.impact(.light)
                        shareDay()
                    } label: {
                        Label("week_share_this_day", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        Haptics.impact(.light)
                        shareWeek()
                    } label: {
                        Label("week_share_full_week", systemImage: "calendar")
                    }

                    Button {
                        UIPasteboard.general.string = shareTextForSelectedDay()
                        Haptics.notify(.success)
                        showCopiedToast()
                    } label: {
                        Label("week_copy", systemImage: "doc.on.doc")
                    }
                }
            } label: {
                weekFloatingIconButton(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.plain)

            Button {
                Haptics.impact(.light)
                planAheadDate = Date()
                planAheadMode = weekMode == .crew ? .crew : .personal
                showPlanAheadSheet = true
            } label: {
                weekFloatingIconButton(systemName: "calendar")
            }
            .buttonStyle(.plain)

            Button {
                Haptics.impact(.medium)

                if weekMode == .crew {
                    if selectedCrew != nil {
                        showingCreateCrewTask = true
                    } else {
                        showCrewPickerSheet = true
                    }
                } else {
                    studentStore.reload()
                    planAheadDate = targetDateForSelectedDay()
                    showingAdd = true
                }
            } label: {
                weekFloatingIconButton(systemName: "plus")
            }
            .buttonStyle(.plain)
        }
        .padding(.trailing, 16)
        .padding(.top, 10)
    }
    
    func weekFloatingIconButton(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: systemName == "plus" ? 17 : 15, weight: .black))
            .foregroundStyle(weekMode == .crew ? Color(arenaHex: AppArenaPalette.coral) : Color(arenaHex: AppArenaPalette.cyan))
            .frame(width: 42, height: 42)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.095),
                                Color.white.opacity(0.045)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.11), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.24), radius: 12, y: 6)
            )
    }

    private func weekMainBase(proxy: ScrollViewProxy) -> some View {
        mainList(proxy: proxy)
            .modifier(
                WeekMainModifier(
                    weekMode: weekMode,

                    onAppearAction: {
                        isWeekScreenVisible = true
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
                        guard isWeekScreenVisible else { return }
                        await LiveActivityManager.shared.autoSyncIfNeeded(events: userScopedEvents)
                    },

                    onDisappearAction: {
                        isWeekScreenVisible = false
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
                        Label("week_share_today_crew_tasks", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        Haptics.impact(.light)
                        shareSelectedCrew()
                    } label: {
                        Label("week_share_crew", systemImage: "person.3.fill")
                    }

                    Button {
                        UIPasteboard.general.string = shareTextForCrewDay()
                        Haptics.notify(.success)
                        showCopiedToast()
                    } label: {
                        Label("week_copy", systemImage: "doc.on.doc")
                    }
                } else {
                    Button {
                        Haptics.impact(.light)
                        shareDay()
                    } label: {
                        Label("week_share_this_day", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        Haptics.impact(.light)
                        shareWeek()
                    } label: {
                        Label("week_share_full_week", systemImage: "calendar")
                    }

                    Button {
                        UIPasteboard.general.string = shareTextForSelectedDay()
                        Haptics.notify(.success)
                        showCopiedToast()
                    } label: {
                        Label("week_copy", systemImage: "doc.on.doc")
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
                    studentStore.reload()
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
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color(arenaHex: AppArenaPalette.green))

                    Text("week_copied")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .tracking(0.7)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .frame(height: 42)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(arenaHex: AppArenaPalette.green).opacity(0.13),
                                    Color.white.opacity(0.060)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color(arenaHex: AppArenaPalette.green).opacity(0.18), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.24), radius: 14, y: 7)
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 30)
            }
        }
    }
}
