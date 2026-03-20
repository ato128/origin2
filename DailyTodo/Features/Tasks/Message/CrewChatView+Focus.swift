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
                Text("Start Shared Focus")
                    .font(.title3.bold())
                    .padding(.top, 8)

                Button {
                    selectedFocusMinutes = 25
                    showFocusDurationSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        showFocusTaskPicker = true
                    }
                } label: {
                    focusOptionRow(title: "25 min", subtitle: "Quick focus")
                }
                .buttonStyle(.plain)

                Button {
                    selectedFocusMinutes = 50
                    showFocusDurationSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        showFocusTaskPicker = true
                    }
                } label: {
                    focusOptionRow(title: "50 min", subtitle: "Deep work")
                }
                .buttonStyle(.plain)

                VStack(spacing: 10) {
                    Stepper("Custom: \(customFocusMinutes) min", value: $customFocusMinutes, in: 5...180, step: 5)

                    Button {
                        selectedFocusMinutes = customFocusMinutes
                        showFocusDurationSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            showFocusTaskPicker = true
                        }
                    } label: {
                        Text("Continue")
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
            .navigationTitle("Focus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
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
                    Text("Choose a task")
                        .font(.title3.bold())
                        .foregroundStyle(palette.primaryText)

                    Text("\(selectedFocusMinutes) min shared focus")
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
                            Text("Start without task")
                                .font(.headline)
                                .foregroundStyle(palette.primaryText)

                            Text("General focus session")
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

                if crewStore.crewTasks.filter({ !$0.is_done && $0.crew_id == crew.id }).isEmpty {
                    VStack(spacing: 8) {
                        Spacer()

                        Text("No active crew tasks")
                            .font(.headline)
                            .foregroundStyle(palette.primaryText)

                        Text("You can still start a general focus session.")
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryText)

                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(
                                crewStore.crewTasks.filter { !$0.is_done && $0.crew_id == crew.id },
                                id: \.id
                            ) { task in
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

                                            Text(task.status.capitalized)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(palette.secondaryText)
                                        }

                                        Spacer()

                                        Text(task.priority.capitalized)
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
            .navigationTitle("Focus Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") {
                        showFocusTaskPicker = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            showFocusDurationSheet = true
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
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
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: session.is_paused ? "pause.fill" : "timer")
                            .font(.caption.bold())
                            .foregroundStyle(focusBannerAccent(session))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.is_paused ? "Focus paused" : "Focus devam ediyor")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.primaryText)

                    HStack(spacing: 4) {
                        Text(session.host_name)
                        Text("•")
                        Text(focusRemainingText(session))
                    }
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(focusBannerAccent(session))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(palette.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(focusBannerAccent(session).opacity(0.22), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 8)
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
            resolvedTitle = "\(crew.name) Focus"
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
            return "\(session.duration_minutes) min"
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
}
