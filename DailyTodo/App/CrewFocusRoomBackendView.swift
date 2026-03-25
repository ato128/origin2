//
//  CrewFocusRoomBackendView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 20.03.2026.
//

import SwiftUI

struct CrewFocusRoomBackendView: View {
    let crew: WeekCrewItem
    let sessionDTO: CrewFocusSessionDTO

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var session: SessionStore
    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue

    private let palette = ThemePalette()

    @State private var localSession: CrewFocusSessionDTO
    @State private var glowPulse = false
    @State private var isEnding = false
    @State private var isJoining = false
    @State private var isLeaving = false
    @State private var isTogglingPause = false
    @State private var localParticipants: [CrewFocusParticipantDTO] = []
    @State private var didInitialLoad = false

    init(crew: WeekCrewItem, sessionDTO: CrewFocusSessionDTO) {
        self.crew = crew
        self.sessionDTO = sessionDTO
        _localSession = State(initialValue: sessionDTO)
    }

    var participants: [CrewFocusParticipantDTO] {
        localParticipants
    }

    var currentUserID: UUID? {
        session.currentUser?.id
    }

    var currentUserName: String {
        if let email = session.currentUser?.email, !email.isEmpty {
            let prefix = email.split(separator: "@").first.map(String.init)
            return prefix?.isEmpty == false ? prefix! : email
        }
        return String(localized: "crew_focus_room_you")
    }

    var isJoined: Bool {
        if isHost { return true }

        return participants.contains {
            ($0.user_id != nil && $0.user_id == currentUserID) ||
            $0.member_name == currentUserName
        }
    }

    var isHost: Bool {
        if let hostUserID = localSession.host_user_id, let currentUserID {
            return hostUserID == currentUserID
        }
        return localSession.host_name == currentUserName
    }

    var body: some View {
        ZStack {
            AppBackground()

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let currentDate = context.date
                let remaining = remainingSeconds(at: currentDate)
                let progressValue = progress(forRemaining: remaining)
                let timeText = mmss(forRemaining: remaining)
                let accent = focusAccentColor(forRemaining: remaining)

                ScrollView {
                    VStack(spacing: 20) {
                        headerCard
                        timerCard(
                            currentDate: currentDate,
                            remaining: remaining,
                            progressValue: progressValue,
                            timeText: timeText,
                            accent: accent
                        )
                        participantsCard
                        controlsCard(currentDate: currentDate)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
                .onChange(of: remaining) { _, newValue in
                    guard !isEnding else { return }
                    guard localSession.is_active, !localSession.is_paused else { return }

                    if newValue <= 0, isHost {
                        isEnding = true

                        Task {
                            await finishSessionIfNeeded()
                        }
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                glowPulse = true
            }

            guard !didInitialLoad else { return }
            didInitialLoad = true

            Task {
                await crewStore.loadActiveFocusSession(for: crew.id)

                if let active = crewStore.activeFocusSessionByCrew[crew.id] {
                    localSession = active
                    await crewStore.loadFocusParticipants(sessionID: active.id)
                    localParticipants = crewStore.focusParticipantsBySession[active.id] ?? []
                    await syncCrewLiveActivity()
                } else {
                    await endCrewLiveActivityIfNeeded()
                }
            }
        }
        .onChange(of: crewStore.activeFocusSessionByCrew[crew.id]) { _, newValue in
            if let newValue {
                localSession = newValue
                localParticipants = crewStore.focusParticipantsBySession[newValue.id] ?? localParticipants

                Task {
                    await syncCrewLiveActivity()
                }
            } else {
                Task {
                    await endCrewLiveActivityIfNeeded()
                }
                dismiss()
            }
        }
        .onChange(of: crewStore.focusParticipantsBySession[localSession.id]) { _, newValue in
            localParticipants = newValue ?? []

            Task {
                await syncCrewLiveActivity()
            }
        }
    }
}

private extension CrewFocusRoomBackendView {
    func remainingSeconds(at date: Date) -> Int {
        if localSession.is_paused {
            return max(0, localSession.paused_remaining_seconds ?? 0)
        }

        guard let startedAt = CrewDateParser.parse(localSession.started_at) else {
            return localSession.duration_minutes * 60
        }

        let elapsed = Int(date.timeIntervalSince(startedAt))
        let total = localSession.duration_minutes * 60

        return max(0, total - elapsed)
    }

    func progress(forRemaining remaining: Int) -> Double {
        let total = Double(localSession.duration_minutes * 60)
        guard total > 0 else { return 0 }

        let elapsed = total - Double(remaining)
        return min(1, max(0, elapsed / total))
    }

    func mmss(forRemaining remaining: Int) -> String {
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func focusAccentColor(forRemaining remaining: Int) -> Color {
        if !localSession.is_active { return .green }
        if localSession.is_paused { return .orange }
        if remaining <= 180 { return .red }
        if remaining <= 600 { return .orange }
        return .blue
    }

    var headerCard: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(palette.primaryText)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(palette.cardFill)
                            .overlay(
                                Circle()
                                    .stroke(palette.cardStroke, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Text("crew_focus_room_title")
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
    }

    func timerCard(
        currentDate: Date,
        remaining: Int,
        progressValue: Double,
        timeText: String,
        accent: Color
    ) -> some View {

        return VStack(spacing: 18) {
            Text(localSession.title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)
                .multilineTextAlignment(.center)

            Text(
                !localSession.is_active ? String(localized: "crew_focus_room_session_completed") :
                localSession.is_paused ? String(localized: "crew_focus_room_paused") :
                String(localized: "crew_focus_room_stay_locked_in")
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(
                !localSession.is_active ? .green :
                localSession.is_paused ? .orange :
                palette.secondaryText
            )

            ZStack {
                Circle()
                    .stroke(palette.secondaryCardFill, lineWidth: 16)
                    .frame(width: 220, height: 220)

                Circle()
                    .trim(from: 0, to: progressValue)
                    .stroke(
                        accent,
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 220, height: 220)
                    .shadow(color: accent.opacity(glowPulse ? 0.22 : 0.10), radius: 6)
                    .animation(.linear(duration: 1), value: progressValue)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(glowPulse ? 0.22 : 0.10),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 105
                        )
                    )
                    .frame(width: 175, height: 175)
                    .blur(radius: 5)

                VStack(spacing: 8) {
                    Image(systemName: !localSession.is_active ? "checkmark.circle.fill" : localSession.is_paused ? "pause.fill" : "timer")
                        .font(.title2)
                        .foregroundStyle(accent)

                    if !localSession.is_active || remaining <= 0 {
                        Text("crew_focus_room_done")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                    } else {
                        Text(timeText)
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.primaryText)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.18), value: timeText)
                    }

                    Text(localizedMinutesText(localSession.duration_minutes))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.secondaryText)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .foregroundStyle(accent)

                Text(String(format: String(localized: "crew_focus_room_host"), localSession.host_name))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(palette.cardFill)

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(accent.opacity(0.28), lineWidth: 1)

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(
                                    glowPulse
                                    ? (remaining <= 180 ? 0.16 : remaining <= 600 ? 0.13 : 0.10)
                                    : (remaining <= 180 ? 0.08 : remaining <= 600 ? 0.07 : 0.04)
                                ),
                                Color.clear
                            ],
                            center: .top,
                            startRadius: 20,
                            endRadius: 260
                        )
                    )
                    .blur(radius: 9)
            }
        )
        .shadow(
            color: accent.opacity(
                glowPulse
                ? (remaining <= 180 ? 0.18 : remaining <= 600 ? 0.14 : 0.10)
                : (remaining <= 180 ? 0.10 : remaining <= 600 ? 0.08 : 0.05)
            ),
            radius: 10,
            y: 4
        )
        .compositingGroup()
    }

    var participantsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("crew_focus_room_participants")
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            if participants.isEmpty {
                Text("crew_focus_room_no_participants")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            } else {
                ForEach(participants, id: \.id) { participant in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.accentColor.opacity(0.16))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(String(participant.member_name.prefix(1)).uppercased())
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.accentColor)
                            )

                        Text(participant.member_name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.primaryText)

                        Spacer()

                        if participant.member_name == localSession.host_name {
                            Text("crew_focus_room_host_badge")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.green.opacity(0.12))
                                )
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(cardBackground)
    }

    func controlsCard(currentDate: Date) -> some View {
        VStack(spacing: 12) {
            if !isJoined && localSession.is_active {
                Button {
                    Task {
                        await joinSession()
                    }
                } label: {
                    Text(isJoining ? String(localized: "crew_focus_room_joining") : String(localized: "crew_focus_room_join_session"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.accentColor)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isJoining)
            } else {
                Button {
                    Task {
                        await leaveSession()
                    }
                } label: {
                    Text(isLeaving ? String(localized: "crew_focus_room_leaving") : String(localized: "crew_focus_room_leave_session"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(palette.secondaryCardFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(palette.cardStroke, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(isLeaving)
            }

            if localSession.is_active && isHost {
                Button {
                    Task {
                        await togglePauseResume(currentDate: currentDate)
                    }
                } label: {
                    Text(localSession.is_paused ? String(localized: "crew_focus_room_resume_session") : String(localized: "crew_focus_room_pause_session"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(localSession.is_paused ? .green : .orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(palette.secondaryCardFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(
                                            (localSession.is_paused ? Color.green : Color.orange).opacity(0.22),
                                            lineWidth: 1
                                        )
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(isTogglingPause)
            }

            if localSession.is_active && isHost {
                Button {
                    Task {
                        await endSession()
                    }
                } label: {
                    Text("crew_focus_room_end_session")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(palette.secondaryCardFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.red.opacity(0.22), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }

    func joinSession() async {
        guard !isJoining else { return }
        guard localSession.is_active else { return }
        guard !isJoined else { return }

        isJoining = true
        defer { isJoining = false }

        do {
            try await crewStore.joinCrewFocusSession(
                sessionID: localSession.id,
                crewID: crew.id,
                userID: currentUserID,
                memberName: currentUserName
            )

            await crewStore.loadFocusParticipants(sessionID: localSession.id)
            await crewStore.loadFocusParticipants(sessionID: localSession.id)
            localParticipants = crewStore.focusParticipantsBySession[localSession.id] ?? localParticipants
            await syncCrewLiveActivity()
        } catch {
            print("JOIN FOCUS SESSION ERROR:", error.localizedDescription)
        }
    }

    func leaveSession() async {
        guard !isLeaving else { return }
        guard isJoined else {
            dismiss()
            return
        }

        isLeaving = true
        defer { isLeaving = false }

        do {
            try await crewStore.leaveCrewFocusSession(
                sessionID: localSession.id,
                crewID: crew.id,
                userID: currentUserID,
                memberName: currentUserName
            )

            await endCrewLiveActivityIfNeeded()
            dismiss()
        } catch {
            print("LEAVE FOCUS SESSION ERROR:", error.localizedDescription)
        }
    }

    func togglePauseResume(currentDate: Date) async {
        guard !isTogglingPause else { return }
        guard localSession.is_active else { return }
        guard isHost else { return }

        isTogglingPause = true
        defer { isTogglingPause = false }

        do {
            if localSession.is_paused {
                try await crewStore.resumeCrewFocusSession(
                    sessionID: localSession.id,
                    crewID: crew.id,
                    hostUserID: currentUserID,
                    hostName: currentUserName,
                    durationMinutes: localSession.duration_minutes,
                    pausedRemainingSeconds: localSession.paused_remaining_seconds ?? 0
                )
            } else {
                try await crewStore.pauseCrewFocusSession(
                    sessionID: localSession.id,
                    crewID: crew.id,
                    hostUserID: currentUserID,
                    hostName: currentUserName,
                    pausedRemainingSeconds: remainingSeconds(at: currentDate)
                )
            }

            await crewStore.loadActiveFocusSession(for: crew.id)

            if let updated = crewStore.activeFocusSessionByCrew[crew.id] {
                localSession = updated
                await syncCrewLiveActivity()
            } else {
                await endCrewLiveActivityIfNeeded()
            }
        } catch {
            print("TOGGLE PAUSE RESUME ERROR:", error.localizedDescription)
        }
    }

    func endSession() async {
        guard localSession.is_active else { return }
        guard isHost else { return }

        let completedMinutes: Int
        if localSession.is_paused {
            let remaining = localSession.paused_remaining_seconds ?? 0
            let elapsedSeconds = max(0, localSession.duration_minutes * 60 - remaining)
            completedMinutes = max(1, elapsedSeconds / 60)
        } else {
            completedMinutes = max(1, localSession.duration_minutes - (remainingSeconds(at: Date()) / 60))
        }

        do {
            try await crewStore.endCrewFocusSession(
                sessionID: localSession.id,
                crewID: crew.id,
                hostUserID: currentUserID,
                hostName: currentUserName,
                completedMinutes: completedMinutes,
                participantNames: participants.map(\.member_name),
                taskID: localSession.task_id
            )

            await endCrewLiveActivityIfNeeded()
            dismiss()
        } catch {
            print("END FOCUS SESSION ERROR:", error.localizedDescription)
        }
    }

    func finishSessionIfNeeded() async {
        guard localSession.is_active else { return }
        guard isHost else { return }

        do {
            try await crewStore.endCrewFocusSession(
                sessionID: localSession.id,
                crewID: crew.id,
                hostUserID: currentUserID,
                hostName: currentUserName,
                completedMinutes: localSession.duration_minutes,
                participantNames: participants.map(\.member_name),
                taskID: localSession.task_id
            )

            await endCrewLiveActivityIfNeeded()
            dismiss()
        } catch {
            print("AUTO END FOCUS SESSION ERROR:", error.localizedDescription)
        }
    }

    func liveSubtitleText() -> String {
        let isTurkish = Locale.current.language.languageCode?.identifier == "tr"
        return isTurkish ? "\(localSession.host_name) ile focus" : "Focus with \(localSession.host_name)"
    }

    func liveStartDate() -> Date {
        CrewDateParser.parse(localSession.started_at) ?? Date()
    }

    func liveEndDate() -> Date {
        if localSession.is_paused {
            let remaining = max(0, localSession.paused_remaining_seconds ?? 0)
            return Date().addingTimeInterval(TimeInterval(remaining))
        }

        let startedAt = liveStartDate()
        return startedAt.addingTimeInterval(TimeInterval(localSession.duration_minutes * 60))
    }

    func syncCrewLiveActivity() async {
        guard isJoined || isHost else {
            await FocusLiveActivityManager.shared.end()
            return
        }

        guard localSession.is_active else {
            await FocusLiveActivityManager.shared.end()
            return
        }

        await FocusLiveActivityManager.shared.startOrUpdate(
            title: localSession.title,
            subtitle: liveSubtitleText(),
            modeRaw: "crew",
            startDate: liveStartDate(),
            endDate: liveEndDate(),
            isPaused: localSession.is_paused,
            isResting: false,
            pausedRemainingSeconds: localSession.is_paused
                ? remainingSeconds(at: Date())
                : nil,
            pausedProgress: localSession.is_paused
                ? progress(forRemaining: remainingSeconds(at: Date()))
                : nil
        )
    }

    func endCrewLiveActivityIfNeeded() async {
        await FocusLiveActivityManager.shared.end()
    }

    func localizedMinutesText(_ minutes: Int) -> String {
        let isTurkish = Locale.current.language.languageCode?.identifier == "tr"
        return isTurkish ? "\(minutes) dk" : "\(minutes) min"
    }
}
