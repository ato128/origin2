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
    @State private var localParticipants: [CrewFocusParticipantDTO] = []
    @State private var didInitialLoad = false
    @State private var isClosingView = false
    @State private var isStartingWaitingSession = false

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

    var isWaitingRoom: Bool {
        localSession.is_waiting == true
    }

    var requiredParticipantCount: Int {
        max(1, localSession.required_count ?? 1)
    }

    var hasEnoughParticipants: Bool {
        participants.count >= requiredParticipantCount
    }

    var waitingStatusText: String {
        if hasEnoughParticipants {
            return "Herkes hazır. Host başlatabilir."
        }
        return "Katılımcı bekleniyor"
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
                let finished = isSessionFinished(at: currentDate)

                ScrollView {
                    VStack(spacing: 20) {
                        headerCard

                        timerCard(
                            currentDate: currentDate,
                            remaining: remaining,
                            progressValue: progressValue,
                            timeText: timeText,
                            accent: accent,
                            finished: finished
                        )

                        if isWaitingRoom {
                            waitingInfoCard
                        }

                        participantsCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
                .onChange(of: remaining) { _, newRemaining in
                    guard !isClosingView else { return }
                    guard !isWaitingRoom else { return }

                    if !localSession.is_paused && newRemaining <= 0 {
                        handleSessionEndedFromUI()
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
               
                await refreshSessionStateOrDismiss()
            }
        }
        .onDisappear {
            glowPulse = false
        }
        .onChange(of: crewStore.activeFocusSessionByCrew[crew.id]) { _, newValue in
            guard !isClosingView else { return }

            if let newValue, isSessionValid(newValue, at: Date()) {
                localSession = newValue
                localParticipants = crewStore.focusParticipantsBySession[newValue.id] ?? localParticipants
            } else {
                handleSessionEndedFromStore()
            }
        }
        .onChange(of: crewStore.focusParticipantsBySession[localSession.id]) { _, newValue in
            localParticipants = newValue ?? []
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !isClosingView else { break }

                await crewStore.loadActiveFocusSession(for: crew.id)

                if let active = crewStore.activeFocusSessionByCrew[crew.id] {
                    localSession = active
                    await crewStore.loadFocusParticipants(sessionID: active.id)
                    localParticipants = crewStore.focusParticipantsBySession[active.id] ?? []
                } else {
                    await MainActor.run {
                        dismiss()
                    }
                    break
                }
            }
        }
    }
}

private extension CrewFocusRoomBackendView {
    func refreshSessionStateOrDismiss() async {
        await crewStore.loadActiveFocusSession(for: crew.id)

        guard let active = crewStore.activeFocusSessionByCrew[crew.id],
              isSessionValid(active, at: Date()) else {
            handleSessionEndedFromStore()
            return
        }

        localSession = active
        await crewStore.loadFocusParticipants(sessionID: active.id)
        localParticipants = crewStore.focusParticipantsBySession[active.id] ?? []
    }

    func isSessionValid(_ session: CrewFocusSessionDTO, at date: Date) -> Bool {
        guard session.is_active else { return false }
        if session.ended_at != nil { return false }

        if session.is_waiting == true {
            return true
        }

        if session.is_paused {
            return (session.paused_remaining_seconds ?? 0) > 0
        }

        guard let liveStart = CrewDateParser.parse(session.started_live_at ?? session.started_at) else {
            return false
        }

        let endDate = liveStart.addingTimeInterval(TimeInterval(session.duration_minutes * 60))
        return endDate > date
    }

    func isSessionFinished(at date: Date) -> Bool {
        !isSessionValid(localSession, at: date)
    }

    func handleSessionEndedFromUI() {
        guard !isClosingView else { return }
        isClosingView = true

        crewStore.activeFocusSessionByCrew.removeValue(forKey: crew.id)
        crewStore.focusParticipantsBySession.removeValue(forKey: localSession.id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            dismiss()
        }
    }

    func handleSessionEndedFromStore() {
        guard !isClosingView else { return }
        isClosingView = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            dismiss()
        }
    }

    func startWaitingSession() {
        guard !isStartingWaitingSession else { return }
        isStartingWaitingSession = true

        Task {
            defer {
                Task { @MainActor in
                    isStartingWaitingSession = false
                }
            }

            do {
                try await crewStore.beginWaitingCrewFocusSession(
                    sessionID: localSession.id,
                    crewID: localSession.crew_id
                )

                await crewStore.loadActiveFocusSession(for: localSession.crew_id)

                if let updated = crewStore.activeFocusSessionByCrew[localSession.crew_id] {
                    await MainActor.run {
                        localSession = updated
                    }
                }
            } catch {
                print("BEGIN WAITING CREW SESSION ERROR:", error.localizedDescription)
            }
        }
    }

    func remainingSeconds(at date: Date) -> Int {
        if localSession.is_waiting == true {
            return localSession.duration_minutes * 60
        }

        if localSession.is_paused {
            return max(0, localSession.paused_remaining_seconds ?? 0)
        }

        guard let liveStart = CrewDateParser.parse(localSession.started_live_at ?? localSession.started_at) else {
            return localSession.duration_minutes * 60
        }

        let elapsed = Int(date.timeIntervalSince(liveStart))
        let total = localSession.duration_minutes * 60

        return max(0, total - elapsed)
    }

    func progress(forRemaining remaining: Int) -> Double {
        if localSession.is_waiting == true { return 0 }

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
        if !localSession.is_active || remaining <= 0 { return .green }
        if localSession.is_waiting == true { return .orange }
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

            Text("Odak Odası")
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
        accent: Color,
        finished: Bool
    ) -> some View {
        VStack(spacing: 18) {
            Text(localSession.title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)
                .multilineTextAlignment(.center)

            Text(statusTitle(finished: finished))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(statusColor(finished: finished))

            ZStack {
                Circle()
                    .stroke(palette.secondaryCardFill, lineWidth: 16)
                    .frame(width: 220, height: 220)

                Circle()
                    .trim(from: 0, to: finished ? 1 : progressValue)
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
                    Image(systemName: centerIconName(finished: finished))
                        .font(.title2)
                        .foregroundStyle(accent)

                    if finished {
                        Text("Bitti")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                    } else if localSession.is_waiting == true {
                        Text("Bekliyor")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
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

                Text("Host: \(localSession.host_name)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
            }

            if localSession.is_waiting == true && isHost {
                Button {
                    startWaitingSession()
                } label: {
                    HStack(spacing: 8) {
                        if isStartingWaitingSession {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .bold))
                        }

                        Text(isStartingWaitingSession ? "Başlatılıyor..." : "Focusu Başlat")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(hasEnoughParticipants ? Color.green : Color.gray.opacity(0.45))
                    )
                }
                .buttonStyle(.plain)
                .disabled(!hasEnoughParticipants || isStartingWaitingSession)
                .opacity((!hasEnoughParticipants || isStartingWaitingSession) ? 0.7 : 1)
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

    var waitingInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: hasEnoughParticipants ? "checkmark.circle.fill" : "hourglass")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(hasEnoughParticipants ? .green : .orange)

                VStack(alignment: .leading, spacing: 3) {
                    Text(hasEnoughParticipants ? "Katılımcılar hazır" : "Katılımcı bekleniyor")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Text(waitingStatusText)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                waitingMiniPill(title: "Gerekli", value: "\(requiredParticipantCount)")
                waitingMiniPill(title: "Katılan", value: "\(participants.count)")
                waitingMiniPill(title: "Durum", value: hasEnoughParticipants ? "Hazır" : "Bekliyor")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(cardBackground)
    }

    func waitingMiniPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.45))
                .tracking(1.2)

            Text(value)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(palette.primaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    var participantsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Katılımcılar")
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            if participants.isEmpty {
                Text("Henüz aktif katılımcı yok")
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
                            Text("Host")
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

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }

    func statusTitle(finished: Bool) -> String {
        if finished {
            return "Oturum tamamlandı"
        }

        if localSession.is_waiting == true {
            return "Katılımcı bekleniyor"
        }

        if localSession.is_paused {
            return "Duraklatıldı"
        }

        return "Odakta kal"
    }

    func statusColor(finished: Bool) -> Color {
        if finished { return .green }
        if localSession.is_waiting == true { return .orange }
        if localSession.is_paused { return .orange }
        return palette.secondaryText
    }

    func centerIconName(finished: Bool) -> String {
        if finished { return "checkmark.circle.fill" }
        if localSession.is_waiting == true { return "hourglass" }
        if localSession.is_paused { return "pause.fill" }
        return "timer"
    }

    func localizedMinutesText(_ minutes: Int) -> String {
        let isTurkish = Locale.current.language.languageCode?.identifier == "tr"
        return isTurkish ? "\(minutes) dk" : "\(minutes) min"
    }
}
