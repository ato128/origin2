//
//  HomeDashboardView+Focus.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI
import SwiftData

extension HomeDashboardView {
    var focusCard: some View {
        Group {
            if let task = focusTask {
                let accent = focusAccentColor(for: task)
                let isLinkedToCurrentFocus = isCurrentFocusTask(task)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Çalışma Seansı")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(palette.secondaryText)

                            HStack(spacing: 6) {
                                Text(task.title)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(palette.primaryText)
                                    .lineLimit(1)

                                if isLinkedToCurrentFocus {
                                    focusStateTag(title: "Odakta", tint: accent)
                                }
                            }
                        }

                        Spacer()

                        ZStack {
                            Circle()
                                .fill(accent.opacity(0.14))
                                .frame(width: 46, height: 46)

                            Image(systemName: focusSymbol(for: task))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(accent)
                        }
                    }

                    HStack(spacing: 8) {
                        if let due = task.dueDate {
                            miniBadge(
                                icon: "clock.fill",
                                text: due.formatted(date: .omitted, time: .shortened),
                                tint: palette.secondaryText
                            )
                        }

                        miniBadge(
                            icon: "scope",
                            text: focusCardStatusTextStudent,
                            tint: accent
                        )

                        if !task.courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            miniBadge(
                                icon: "book.closed.fill",
                                text: task.courseName,
                                tint: accent.opacity(0.95)
                            )
                        }

                        Spacer()
                    }

                    Button {
                        startInlineFocus()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .bold))

                            Text("Çalışmayı Başlat")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            accent,
                                            accent.opacity(0.88)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .shadow(color: accent.opacity(0.20), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(palette.cardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            accent.opacity(0.10),
                                            Color.clear
                                        ],
                                        center: .topTrailing,
                                        startRadius: 10,
                                        endRadius: 220
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(accent.opacity(0.16), lineWidth: 1)
                        )
                )
                .shadow(
                    color: accent.opacity(0.08),
                    radius: 12,
                    x: 0,
                    y: 5
                )
            }
        }
    }

    var activeFocusCard: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date
            let liveRemaining = liveFocusRemaining(at: now)
            let urgencyColor = activeFocusUrgencyColor(for: liveRemaining)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aktif Çalışma")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.secondaryText)

                        HStack(spacing: 6) {
                            Text(activeFocusTaskTitle.isEmpty ? "Odak Oturumu" : activeFocusTaskTitle)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(palette.primaryText)
                                .lineLimit(1)

                            focusStateTag(title: "Odakta", tint: urgencyColor)
                        }
                    }

                    Spacer()

                    Text(liveFocusTimeText(at: now))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(urgencyColor)
                }

                smoothActiveFocusProgressBar(at: now)
                    .frame(height: 8)

                HStack(spacing: 8) {
                    miniBadge(
                        icon: "timer",
                        text: liveRemaining <= 60 ? "Son dakika" : "Devam ediyor",
                        tint: urgencyColor
                    )

                    if let task = focusTask,
                       !task.courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        miniBadge(
                            icon: "book.closed.fill",
                            text: task.courseName,
                            tint: urgencyColor.opacity(0.95)
                        )
                    }

                    Spacer()
                }

                HStack(spacing: 10) {
                    Button {
                        if focusWorkoutMode {
                            advanceInlineWorkout()
                        }
                    } label: {
                        Text(focusWorkoutMode ? "Sonraki Set" : "Odayı Aç")
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor)
                            )
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        stopActiveFocus()
                    } label: {
                        Text("Duraklat")
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                Capsule()
                                    .fill(Color.orange.opacity(0.16))
                            )
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(palette.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        urgencyColor.opacity(0.10),
                                        Color.clear
                                    ],
                                    center: .topLeading,
                                    startRadius: 20,
                                    endRadius: 220
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(urgencyColor.opacity(0.16), lineWidth: 1)
                    )
            )
            .shadow(
                color: urgencyColor.opacity(0.08),
                radius: 12,
                x: 0,
                y: 5
            )
        }
        .onAppear {
            liveDotPulse = true
        }
    }

    func focusChip(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(color.opacity(0.14))
        )
    }

    func focusStateTag(title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tint.opacity(0.14))
            )
    }

    func backendCrewFocusAccentColor(for session: CrewFocusSessionDTO, now: Date) -> Color {
        if !session.is_active { return .green }
        if session.is_paused { return .orange }

        let remaining = backendCrewFocusRemainingSeconds(for: session, now: now)
        if remaining <= 180 { return .red }
        if remaining <= 600 { return .orange }
        return .blue
    }

    func backendCrewFocusRemainingSeconds(for session: CrewFocusSessionDTO, now: Date) -> Int {
        if session.is_paused {
            return max(0, session.paused_remaining_seconds ?? 0)
        }

        guard let startedAt = CrewDateParser.parse(session.started_at) else {
            return session.duration_minutes * 60
        }

        let endDate = startedAt.addingTimeInterval(TimeInterval(session.duration_minutes * 60))
        return max(0, Int(endDate.timeIntervalSince(now)))
    }

    func backendCrewFocusTimeText(for session: CrewFocusSessionDTO, now: Date) -> String {
        let remaining = backendCrewFocusRemainingSeconds(for: session, now: now)
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func sessionStoreSafeEmailPrefix() -> String? {
        if let email = session.currentUser?.email, !email.isEmpty {
            return email.components(separatedBy: "@").first ?? email
        }
        return nil
    }

    func crewSharedFocusCard(session: CrewFocusSessionDTO) -> some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date
            let remaining = backendCrewFocusRemainingSeconds(for: session, now: now)
            let liveTimeText = backendCrewFocusTimeText(for: session, now: now)
            let total = Double(session.duration_minutes * 60)
            let progress = total > 0
                ? min(1, max(0, 1 - Double(remaining) / total))
                : 0

            let accent = backendCrewFocusAccentColor(for: session, now: now)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Ortak Odak")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.secondaryText)

                        Text(session.title)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.primaryText)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(!session.is_active ? "Bitti" : liveTimeText)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(!session.is_active ? .green : palette.primaryText)
                        .monospacedDigit()
                }

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(palette.secondaryCardFill)
                        .frame(height: 8)

                    GeometryReader { geo in
                        Capsule()
                            .fill(accent)
                            .frame(
                                width: max(10, geo.size.width * (!session.is_active ? 1 : progress)),
                                height: 8
                            )
                    }
                }
                .frame(height: 8)

                HStack(spacing: 10) {
                    Button {
                        focusRoomSession = session
                    } label: {
                        Text("Odayı Aç")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.accentColor)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task {
                            let hostName = sessionStoreSafeEmailPrefix() ?? "You"

                            do {
                                if session.is_paused {
                                    try await crewStore.resumeCrewFocusSession(
                                        sessionID: session.id,
                                        crewID: session.crew_id,
                                        hostUserID: self.session.currentUser?.id,
                                        hostName: hostName,
                                        durationMinutes: session.duration_minutes,
                                        pausedRemainingSeconds: session.paused_remaining_seconds ?? 0
                                    )
                                } else {
                                    try await crewStore.pauseCrewFocusSession(
                                        sessionID: session.id,
                                        crewID: session.crew_id,
                                        hostUserID: self.session.currentUser?.id,
                                        hostName: hostName,
                                        pausedRemainingSeconds: remaining
                                    )
                                }

                                await crewStore.loadActiveFocusSession(for: session.crew_id)
                            } catch {
                                print("HOME FOCUS PAUSE/RESUME ERROR:", error.localizedDescription)
                            }
                        }
                    } label: {
                        Text(session.is_paused ? "Devam Et" : "Duraklat")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(session.is_paused ? .green : .orange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill((session.is_paused ? Color.green : Color.orange).opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(palette.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        accent.opacity(0.10),
                                        Color.clear
                                    ],
                                    center: .topLeading,
                                    startRadius: 20,
                                    endRadius: 220
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(accent.opacity(0.18), lineWidth: 1)
                    )
            )
        }
    }

    var focusCardStatusTextStudent: String {
        guard let task = focusTask else { return "Bugün için öneri yok" }

        if store.isOverdue(task) {
            return "Öncelikli"
        }

        if let due = task.dueDate,
           Calendar.current.isDateInToday(due) {
            return "Sıradaki odak"
        }

        return "Hazır"
    }

    func focusAccentColor(for task: DTTaskItem) -> Color {
        if store.isOverdue(task) {
            return .red
        }

        switch task.taskType.lowercased() {
        case "exam":
            return .orange
        case "project":
            return .purple
        case "workout":
            return .green
        case "study":
            return .blue
        case "homework":
            return .pink
        default:
            return .accentColor
        }
    }

    func focusSymbol(for task: DTTaskItem) -> String {
        switch task.taskType.lowercased() {
        case "exam":
            return "doc.text.fill"
        case "project":
            return "folder.fill"
        case "workout":
            return "dumbbell.fill"
        case "study":
            return "brain.head.profile"
        case "homework":
            return "book.closed.fill"
        default:
            return "scope"
        }
    }

    func isCurrentFocusTask(_ task: DTTaskItem) -> Bool {
        guard isFocusActive else { return false }
        return activeFocusTaskTitle == task.title
    }
}
