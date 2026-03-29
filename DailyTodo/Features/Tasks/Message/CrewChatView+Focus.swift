//
//  CrewChatView+Focus.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI

extension CrewChatView {

    var focusDurationSheet: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("crew_chat_focus_start_title")
                    .font(.title3.bold())
                    .padding(.top, 8)

                Button {
                    selectedFocusMinutes = 25
                    showFocusDurationSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        showFocusTaskPicker = true
                    }
                } label: {
                    focusOptionRow(
                        title: localizedMinutesText(25),
                        subtitle: String(localized: "crew_chat_focus_quick")
                    )
                }
                .buttonStyle(.plain)

                Button {
                    selectedFocusMinutes = 50
                    showFocusDurationSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        showFocusTaskPicker = true
                    }
                } label: {
                    focusOptionRow(
                        title: localizedMinutesText(50),
                        subtitle: String(localized: "crew_chat_focus_deep_work")
                    )
                }
                .buttonStyle(.plain)

                VStack(spacing: 10) {
                    Stepper(
                        String(
                            format: String(localized: "crew_chat_focus_custom_stepper"),
                            customFocusMinutes
                        ),
                        value: $customFocusMinutes,
                        in: 5...180,
                        step: 5
                    )

                    Button {
                        selectedFocusMinutes = customFocusMinutes
                        showFocusDurationSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            showFocusTaskPicker = true
                        }
                    } label: {
                        Text("crew_chat_continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.green.opacity(0.16))
                            .foregroundStyle(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(palette.cardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(palette.cardStroke, lineWidth: 1)
                        )
                )

                Spacer()
            }
            .padding(20)
            .navigationTitle("crew_chat_focus_nav_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("event_close") {
                        showFocusDurationSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    var focusTaskPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Text("crew_chat_focus_choose_task")
                        .font(.title3.bold())
                        .foregroundStyle(palette.primaryText)

                    Text(
                        String(
                            format: String(localized: "crew_chat_focus_shared_minutes"),
                            selectedFocusMinutes
                        )
                    )
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                }
                .padding(.top, 8)

                Button {
                    selectedFocusTask = nil
                    Task {
                        await startBackendFocusSession()
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("crew_chat_focus_without_task")
                                .font(.headline)
                                .foregroundStyle(palette.primaryText)

                            Text("crew_chat_focus_general_session")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                        }

                        Spacer()

                        Image(systemName: "timer")
                            .foregroundStyle(.green)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(palette.cardFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(palette.cardStroke, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                let activeTasks = crewStore.crewTasks.filter {
                    !$0.is_done && $0.crew_id == crew.id
                }

                if activeTasks.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()

                        Text("crew_chat_focus_no_active_tasks")
                            .font(.headline)
                            .foregroundStyle(palette.primaryText)

                        Text("crew_chat_focus_still_general")
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryText)

                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(activeTasks, id: \.id) { task in
                                Button {
                                    selectedFocusTask = task
                                    Task {
                                        await startBackendFocusSession()
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(priorityColor(task.priority).opacity(0.18))
                                            .frame(width: 38, height: 38)
                                            .overlay(
                                                Image(systemName: "checklist")
                                                    .font(.subheadline.bold())
                                                    .foregroundStyle(priorityColor(task.priority))
                                            )

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(task.title)
                                                .font(.headline)
                                                .foregroundStyle(palette.primaryText)
                                                .multilineTextAlignment(.leading)

                                            Text(localizedTaskStatus(task.status))
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(palette.secondaryText)
                                        }

                                        Spacer()

                                        Text(localizedPriority(task.priority))
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(priorityColor(task.priority))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 5)
                                            .background(
                                                Capsule()
                                                    .fill(priorityColor(task.priority).opacity(0.12))
                                            )
                                    }
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(palette.cardFill)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                    .stroke(palette.cardStroke, lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding(20)
            .navigationTitle("crew_chat_focus_task_nav_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("week_back") {
                        showFocusTaskPicker = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            showFocusDurationSheet = true
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("event_close") {
                        showFocusTaskPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    func focusOptionRow(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }

            Spacer()

            Image(systemName: "timer")
                .foregroundStyle(.green)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(palette.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    func focusLiveBanner(session: CrewFocusSessionDTO) -> some View {
        Button {
            focusRoomSession = session
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(focusBannerAccent(session).opacity(0.18))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: session.is_paused ? "pause.fill" : "timer")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(focusBannerAccent(session))
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(
                        session.is_paused
                        ? String(localized: "crew_chat_focus_paused")
                        : String(localized: "crew_chat_focus_running")
                    )
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                    HStack(spacing: 4) {
                        Text(session.host_name)
                        Text("•")
                        Text(focusRemainingText(session))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.68))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(focusBannerAccent(session))
            }
            .padding(.horizontal, 16)
            .frame(height: 76)
            .background(glassRoundedBackground(cornerRadius: 26))
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    func startBackendFocusSession() async {
        showFocusTaskPicker = false

        let hostName = currentDisplayName()
        let hostUserID = session.currentUser?.id

        let resolvedTitle: String
        if let selectedFocusTask {
            resolvedTitle = selectedFocusTask.title
        } else {
            resolvedTitle = "\(crew.name) \(String(localized: "crew_chat_focus_default_title_suffix"))"
        }

        do {
            let createdSession = try await crewStore.startCrewFocusSession(
                crewID: crew.id,
                hostUserID: hostUserID,
                hostName: hostName,
                title: resolvedTitle,
                taskID: selectedFocusTask?.id,
                taskTitle: selectedFocusTask?.title,
                durationMinutes: selectedFocusMinutes
            )

            await crewStore.loadActiveFocusSession(for: crew.id)
            await crewStore.loadFocusParticipants(sessionID: createdSession.id)

            try? await Task.sleep(nanoseconds: 250_000_000)

            await crewStore.loadFocusParticipants(sessionID: createdSession.id)

            await MainActor.run {
                focusRoomSession = createdSession
            }
        } catch {
            print("START BACKEND FOCUS SESSION ERROR:", error.localizedDescription)
        }
    }

    func focusRemainingText(_ session: CrewFocusSessionDTO) -> String {
        if session.is_paused, let paused = session.paused_remaining_seconds {
            let minutes = paused / 60
            let seconds = paused % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }

        guard let startedAt = CrewDateParser.parse(session.started_at) else {
            return localizedMinutesText(session.duration_minutes)
        }

        let endDate = startedAt.addingTimeInterval(TimeInterval(session.duration_minutes * 60))
        let remaining = max(0, Int(endDate.timeIntervalSinceNow.rounded(.down)))
        let minutes = remaining / 60
        let seconds = remaining % 60

        return String(format: "%02d:%02d", minutes, seconds)
    }

    func focusBannerAccent(_ session: CrewFocusSessionDTO) -> Color {
        if !session.is_active {
            return .green
        }

        if session.is_paused {
            return .orange
        }

        let remainingText = focusRemainingText(session)
        let parts = remainingText.split(separator: ":")

        if let minString = parts.first, let minutes = Int(minString) {
            if minutes <= 3 {
                return .red
            } else if minutes <= 10 {
                return .orange
            }
        }

        return .blue
    }

    func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "low":
            return .green
        case "medium":
            return .orange
        case "high":
            return .red
        case "urgent":
            return .pink
        default:
            return .blue
        }
    }

    func localizedMinutesText(_ minutes: Int) -> String {
        let isTurkish = Locale.current.language.languageCode?.identifier == "tr"
        return isTurkish ? "\(minutes) dk" : "\(minutes) min"
    }

    func localizedTaskStatus(_ status: String) -> String {
        let isTurkish = Locale.current.language.languageCode?.identifier == "tr"

        switch status.lowercased() {
        case "todo":
            return isTurkish ? "Yapılacak" : "Todo"
        case "inprogress":
            return isTurkish ? "Devam Ediyor" : "In Progress"
        case "review":
            return isTurkish ? "İncelemede" : "Review"
        case "done":
            return isTurkish ? "Tamamlandı" : "Done"
        default:
            return status.capitalized
        }
    }

    func localizedPriority(_ priority: String) -> String {
        let isTurkish = Locale.current.language.languageCode?.identifier == "tr"

        switch priority.lowercased() {
        case "low":
            return isTurkish ? "Düşük" : "Low"
        case "medium":
            return isTurkish ? "Orta" : "Medium"
        case "high":
            return isTurkish ? "Yüksek" : "High"
        case "urgent":
            return isTurkish ? "Acil" : "Urgent"
        default:
            return priority.capitalized
        }
    }
}
