//
//  FocusSessionManager.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 10.04.2026.
//

import SwiftUI
import Foundation
import Combine
import AVFoundation

@MainActor
final class FocusSessionManager: ObservableObject {
    static let shared = FocusSessionManager()

    @Published var isSessionActive: Bool = false
    @Published var isExpanded: Bool = false
    @Published var isMinimized: Bool = false
    @Published var currentSession: FocusSessionState?
    @Published var now: Date = Date()
    @Published var completionSummary: FocusCompletionSummary?
    @Published var lastFinishedSession: FocusSessionState?

    @Published var currentCrewID: UUID?
    @Published var currentCrewBackendSessionID: UUID?

    private let storageKey = "active_focus_session_state_v1"
    private let audioManager = FocusAudioManager.shared
    private let liveActivityManager = FocusLiveActivityManager.shared

    private weak var crewStore: CrewStore?
    private weak var sessionStore: SessionStore?

    private var timer: Timer?
    private var nowTimer: Timer?

    private init() {
        restoreSessionIfNeeded()
        startNowTimer()
    }

    deinit {
        timer?.invalidate()
        nowTimer?.invalidate()
    }

    // MARK: - Dependency Wiring

    func configure(sessionStore: SessionStore, crewStore: CrewStore) {
        self.sessionStore = sessionStore
        self.crewStore = crewStore
    }

    // MARK: - Public Launch API

    @discardableResult
    func startRequestedSession(
        mode: FocusMode,
        durationMinutes: Int,
        goal: FocusGoal,
        style: FocusStyle
    ) async -> Bool {
        guard !hasBlockingActiveSession else {
            print("FOCUS START BLOCKED: another session is already active")
            return false
        }

        switch mode {
        case .personal:
            startLocalSession(
                mode: .personal,
                durationMinutes: durationMinutes,
                goal: goal,
                style: style,
                participants: []
            )
            return true

        case .crew:
            return await startCrewSession(
                durationMinutes: durationMinutes,
                goal: goal,
                style: style
            )

        case .friend:
            startLocalSession(
                mode: .friend,
                durationMinutes: durationMinutes,
                goal: goal,
                style: style,
                participants: FocusParticipant.mockFriend
            )
            return true
        }
    }
    
   

    func expandSession() {
        guard isSessionActive else { return }
        isExpanded = true
        isMinimized = false
    }

    func minimizeSession() {
        guard isSessionActive else { return }
        isExpanded = false
        isMinimized = true
    }

    func closeSession() {
        guard let session = currentSession else {
            clearSessionLocally()
            return
        }

        FocusCompletionRecorder.shared.saveCompletedSession(
            ownerUserID: currentUserID?.uuidString,
            title: activeSessionDisplayTitle,
            startedAt: session.startDate,
            endedAt: Date(),
            totalSeconds: session.durationMinutes * 60,
            completedSeconds: elapsedSeconds,
            isCompleted: false
        )

        if session.mode == .crew,
           let crewID = currentCrewID,
           let backendSessionID = currentCrewBackendSessionID,
           let crewStore {

            let host = isCurrentUserHost

            Task {
                do {
                    if host {
                        try await crewStore.endCrewFocusSession(
                            sessionID: backendSessionID,
                            crewID: crewID,
                            hostUserID: currentUserID,
                            hostName: currentUserDisplayName,
                            completedMinutes: resolvedCompletedMinutes(for: session),
                            participantNames: session.participants.map(\.name),
                            taskID: nil
                        )
                    } else {
                        try await crewStore.leaveCrewFocusSession(
                            sessionID: backendSessionID,
                            crewID: crewID,
                            userID: currentUserID,
                            memberName: currentUserDisplayName
                        )
                    }
                } catch {
                    print(error.localizedDescription)
                }

                clearSessionLocally()
            }

            return
        }

        clearSessionLocally()
    }

    func pauseSession() {
        guard let session = currentSession else { return }

        if session.mode == .crew,
           let crewID = currentCrewID,
           let backendSessionID = currentCrewBackendSessionID,
           let crewStore,
           isCurrentUserHost {
            let remaining = remainingSeconds

            Task {
                do {
                    try await crewStore.pauseCrewFocusSession(
                        sessionID: backendSessionID,
                        crewID: crewID,
                        hostUserID: currentUserID,
                        hostName: currentUserDisplayName,
                        pausedRemainingSeconds: remaining
                    )

                    if let updated = crewStore.activeFocusSessionByCrew[crewID] {
                        hydrateFromCrewSessionDTO(
                            updated,
                            crewID: crewID,
                            participantsDTO: crewStore.focusParticipantsBySession[updated.id] ?? [],
                            preferredGoal: selectedGoal,
                            preferredStyle: selectedStyle
                        )
                    } else {
                        applyLocalPause()
                    }
                } catch {
                    print("FOCUS PAUSE SESSION ERROR:", error.localizedDescription)
                }
            }

            return
        }

        applyLocalPause()
    }

    func resumeSession() {
        guard let session = currentSession else { return }

        if session.mode == .crew,
           let crewID = currentCrewID,
           let backendSessionID = currentCrewBackendSessionID,
           let crewStore,
           isCurrentUserHost {
            let remaining = session.pausedRemainingSeconds ?? remainingSeconds

            Task {
                do {
                    try await crewStore.resumeCrewFocusSession(
                        sessionID: backendSessionID,
                        crewID: crewID,
                        hostUserID: currentUserID,
                        hostName: currentUserDisplayName,
                        durationMinutes: session.durationMinutes,
                        pausedRemainingSeconds: remaining
                    )

                    if let updated = crewStore.activeFocusSessionByCrew[crewID] {
                        hydrateFromCrewSessionDTO(
                            updated,
                            crewID: crewID,
                            participantsDTO: crewStore.focusParticipantsBySession[updated.id] ?? [],
                            preferredGoal: selectedGoal,
                            preferredStyle: selectedStyle
                        )
                    } else {
                        applyLocalResume()
                    }
                } catch {
                    print("FOCUS RESUME SESSION ERROR:", error.localizedDescription)
                }
            }

            return
        }

        applyLocalResume()
    }

    func togglePause() {
        guard let session = currentSession else { return }
        if session.isPaused {
            resumeSession()
        } else {
            pauseSession()
        }
    }

    func dismissCompletionSummary() {
        completionSummary = nil
        isExpanded = false
    }

    func restartLastFinishedSession() {
        guard let session = lastFinishedSession else { return }

        startLocalSession(
            mode: session.mode,
            durationMinutes: session.durationMinutes,
            goal: session.goal,
            style: session.style,
            participants: session.participants
        )

        completionSummary = nil
    }

    // MARK: - Crew Hydration

    func hydrateFromCrewSessionDTO(
        _ dto: CrewFocusSessionDTO,
        crewID: UUID,
        participantsDTO: [CrewFocusParticipantDTO],
        preferredGoal: FocusGoal? = nil,
        preferredStyle: FocusStyle? = nil
    ) {
        let existingGoal = currentSession?.goal
        let existingStyle = currentSession?.style

        let goal = preferredGoal ?? existingGoal ?? .study
        let style = preferredStyle ?? existingStyle ?? .silent

        let startDate = CrewDateParser.parse(dto.started_at) ?? Date()

        let resolvedEndDate: Date
        if dto.is_paused {
            let remaining = max(0, dto.paused_remaining_seconds ?? 0)
            resolvedEndDate = Date().addingTimeInterval(TimeInterval(remaining))
        } else {
            resolvedEndDate = startDate.addingTimeInterval(TimeInterval(dto.duration_minutes * 60))
        }

        let mappedParticipants = mapCrewParticipants(
            participantsDTO,
            hostUserID: dto.host_user_id
        )

        let session = FocusSessionState(
            id: dto.id,
            mode: .crew,
            durationMinutes: dto.duration_minutes,
            startDate: startDate,
            endDate: resolvedEndDate,
            isPaused: dto.is_paused,
            pausedRemainingSeconds: dto.is_paused ? dto.paused_remaining_seconds : nil,
            participants: mappedParticipants,
            goal: goal,
            style: style
        )

        currentSession = session
        currentCrewID = crewID
        currentCrewBackendSessionID = dto.id
        isSessionActive = dto.is_active
        isExpanded = dto.is_active
        isMinimized = false

        save()
        startLifecycleTimer()
        syncAudioForCurrentState()

        Task {
            await syncLiveActivityIfNeeded()
        }
    }

    func applyCrewRealtimeStateIfNeeded(
        activeSession: CrewFocusSessionDTO?,
        crewID: UUID,
        participants: [CrewFocusParticipantDTO],
        preferredGoal: FocusGoal? = nil,
        preferredStyle: FocusStyle? = nil
    ) {
        guard currentCrewID == crewID || selectedMode == .crew || currentSession?.mode == .crew else { return }

        if let activeSession {
            hydrateFromCrewSessionDTO(
                activeSession,
                crewID: crewID,
                participantsDTO: participants,
                preferredGoal: preferredGoal,
                preferredStyle: preferredStyle
            )
        } else if currentSession?.mode == .crew {
            clearSessionLocally()
        }
    }

    // MARK: - Internal Start Methods

    private func startLocalSession(
        mode: FocusMode,
        durationMinutes: Int,
        goal: FocusGoal,
        style: FocusStyle,
        participants: [FocusParticipant]
    ) {
        let start = Date()
        let end = start.addingTimeInterval(Double(durationMinutes * 60))

        let session = FocusSessionState(
            id: UUID(),
            mode: mode,
            durationMinutes: durationMinutes,
            startDate: start,
            endDate: end,
            isPaused: false,
            pausedRemainingSeconds: nil,
            participants: participants,
            goal: goal,
            style: style
        )

        currentCrewID = nil
        currentCrewBackendSessionID = nil

        currentSession = session
        isSessionActive = true
        isExpanded = true
        isMinimized = false

        save()
        startLifecycleTimer()
        audioManager.play(style: style)

        Task {
            await syncLiveActivityIfNeeded()
        }
    }

    private func startCrewSession(
        durationMinutes: Int,
        goal: FocusGoal,
        style: FocusStyle
    ) async -> Bool {
        guard let crewStore else {
            print("START CREW SESSION ERROR: CrewStore not configured")
            return false
        }

        guard let crew = crewStore.crews.first else {
            print("START CREW SESSION ERROR: No crew found")
            return false
        }

        let hostName = currentUserDisplayName
        let title = "\(goal.title) Focus"

        do {
            let dto = try await
            crewStore.startCrewFocusSession(
                crewID: crew.id,
                hostUserID: currentUserID,
                hostName: hostName,
                title: title,
                taskID: nil,
                taskTitle: nil,
                durationMinutes: durationMinutes,
                participantCount: 1
            )

            
            await crewStore.loadActiveFocusSession(for: crew.id)
            await crewStore.loadFocusParticipants(sessionID: dto.id)

            let participants = crewStore.focusParticipantsBySession[dto.id] ?? []

            hydrateFromCrewSessionDTO(
                dto,
                crewID: crew.id,
                participantsDTO: participants,
                preferredGoal: goal,
                preferredStyle: style
            )

            await syncLiveActivityIfNeeded()
            return true
        } catch {
            print("START CREW SESSION ERROR:", error.localizedDescription)
            return false
        }
    }

    // MARK: - Persistence / Timers

    func restoreSessionIfNeeded() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let session = try? JSONDecoder().decode(FocusSessionState.self, from: data)
        else {
            currentSession = nil
            isSessionActive = false
            isExpanded = false
            isMinimized = false
            return
        }

        if session.isPaused {
            currentSession = session
            isSessionActive = true
            syncAudioForCurrentState()

            Task {
                await syncLiveActivityIfNeeded()
            }
            return
        }

        if session.endDate <= Date() {
            clearSessionLocally()
            UserDefaults.standard.removeObject(forKey: storageKey)
            return
        }

        currentSession = session
        isSessionActive = true
        startLifecycleTimer()
        syncAudioForCurrentState()

        Task {
            await syncLiveActivityIfNeeded()
        }
    }

    private func save() {
        guard let currentSession else {
            UserDefaults.standard.removeObject(forKey: storageKey)
            return
        }

        if let encoded = try? JSONEncoder().encode(currentSession) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func startLifecycleTimer() {
        stopLifecycleTimer()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func stopLifecycleTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func startNowTimer() {
        nowTimer?.invalidate()
        nowTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.now = Date()
        }
    }

    private func tick() {
        guard let session = currentSession else {
            clearSessionLocally()
            return
        }

        if session.isPaused {
            return
        }

        if remainingSeconds <= 0 {
            finishSession(session)
        }
    }

   

    private func finishSession(_ session: FocusSessionState) {
        if session.mode == .crew,
           let crewID = currentCrewID,
           let backendSessionID = currentCrewBackendSessionID,
           let crewStore,
           isCurrentUserHost {

            Task {
                do {
                    try await crewStore.endCrewFocusSession(
                        sessionID: backendSessionID,
                        crewID: crewID,
                        hostUserID: currentUserID,
                        hostName: currentUserDisplayName,
                        completedMinutes: session.durationMinutes,
                        participantNames: session.participants.map(\.name),
                        taskID: nil
                    )
                } catch {
                    print("AUTO END CREW SESSION ERROR:", error.localizedDescription)
                }

                IdentityXPManager.shared.add(
                    .crewFocus(minutes: session.durationMinutes)
                )

                completeAndPersist(session)
            }

            return
        }

        IdentityXPManager.shared.add(
            .focusCompleted(minutes: session.durationMinutes)
        )

        completeAndPersist(session)
    }
    
    // FocusSessionManager.swift içine EKLE

    private func completeAndPersist(_ session: FocusSessionState) {
        stopLifecycleTimer()
        audioManager.stop()

        let ended = Date()
        let totalSeconds = session.durationMinutes * 60
        let completed = max(1, elapsedSeconds)

        FocusCompletionRecorder.shared.saveCompletedSession(
            ownerUserID: currentUserID?.uuidString,
            title: activeSessionDisplayTitle,
            startedAt: session.startDate,
            endedAt: ended,
            totalSeconds: totalSeconds,
            completedSeconds: completed,
            isCompleted: true
        )

        let summary = FocusCompletionSummary(
            id: UUID(),
            mode: session.mode,
            durationMinutes: session.durationMinutes,
            completedAt: ended,
            totalTodayMinutes: todayFocusMinutes + session.durationMinutes,
            streakDays: streakDays + 1,
            completedSessionsToday: max(1, weekFocusSessions - 2),
            goal: session.goal,
            style: session.style,
            participantCount: session.participants.count
        )

        lastFinishedSession = session
        completionSummary = summary

        currentSession = nil
        isSessionActive = false
        isMinimized = false
        isExpanded = true
        currentCrewID = nil
        currentCrewBackendSessionID = nil

        UserDefaults.standard.removeObject(forKey: storageKey)

        NotificationCenter.default.post(
            name: Notification.Name("focus_completed"),
            object: nil
        )

        Task {
            await liveActivityManager.end()
        }
    }

    private func clearSessionLocally() {
        stopLifecycleTimer()
        audioManager.stop()

        currentSession = nil
        isSessionActive = false
        isExpanded = false
        isMinimized = false
        completionSummary = nil
        currentCrewID = nil
        currentCrewBackendSessionID = nil

        UserDefaults.standard.removeObject(forKey: storageKey)

        Task {
            await liveActivityManager.end()
        }
    }

    private func applyLocalPause() {
        guard var session = currentSession, !session.isPaused else { return }

        let remaining = remainingSeconds
        session.isPaused = true
        session.pausedRemainingSeconds = remaining
        currentSession = session

        save()
        audioManager.pause()

        Task {
            await syncLiveActivityIfNeeded()
        }
    }

    private func applyLocalResume() {
        guard var session = currentSession, session.isPaused else { return }

        let remaining = session.pausedRemainingSeconds ?? 0
        let newStart = Date()
        let newEnd = newStart.addingTimeInterval(Double(remaining))

        session.startDate = newStart
        session.endDate = newEnd
        session.isPaused = false
        session.pausedRemainingSeconds = nil
        currentSession = session

        save()
        audioManager.resume()

        Task {
            await syncLiveActivityIfNeeded()
        }
    }

    private func syncAudioForCurrentState() {
        guard let session = currentSession else { return }

        if session.isPaused {
            audioManager.pause()
        } else {
            audioManager.play(style: session.style)
        }
    }

    private func resolvedCompletedMinutes(for session: FocusSessionState) -> Int {
        if session.isPaused {
            let remaining = session.pausedRemainingSeconds ?? 0
            let elapsedSeconds = max(0, session.durationMinutes * 60 - remaining)
            return max(1, elapsedSeconds / 60)
        }

        return max(1, session.durationMinutes - (remainingSeconds / 60))
    }

    private func mapCrewParticipants(
        _ participantsDTO: [CrewFocusParticipantDTO],
        hostUserID: UUID?
    ) -> [FocusParticipant] {
        participantsDTO.map { dto in
            FocusParticipant(
                id: dto.id,
                name: dto.member_name,
                isHost: dto.user_id == hostUserID,
                isReady: dto.is_active,
                isActive: dto.is_active
            )
        }
    }
    private func syncLiveActivityIfNeeded() async {
        guard let session = currentSession else {
            await liveActivityManager.end()
            return
        }

        let title: String
        let subtitle: String
        let modeRaw = session.mode.rawValue

        switch session.mode {
        case .personal:
            title = "\(session.goal.title) Focus"
            subtitle = "Kişisel focus aktif"
        case .crew:
            title = "Crew Focus"
            subtitle = liveSubtitleText
        case .friend:
            title = "Friend Focus"
            subtitle = "Shared focus aktif"
        }

        let effectiveEndDate: Date
        if session.isPaused {
            effectiveEndDate = Date().addingTimeInterval(
                TimeInterval(session.pausedRemainingSeconds ?? remainingSeconds)
            )
        } else {
            effectiveEndDate = session.endDate
        }

        await liveActivityManager.startOrUpdate(
            title: title,
            subtitle: subtitle,
            modeRaw: modeRaw,
            startDate: session.startDate,
            endDate: effectiveEndDate,
            isPaused: session.isPaused,
            isResting: false,
            pausedRemainingSeconds: session.isPaused
                ? (session.pausedRemainingSeconds ?? remainingSeconds)
                : nil,
            pausedProgress: session.isPaused ? progress : nil
        )
    }

    private var liveSubtitleText: String {
        if let hostName {
            return "\(hostName) ile focus"
        }
        return "Crew focus aktif"
    }

    // MARK: - Derived

    var currentUserID: UUID? {
        sessionStore?.currentUser?.id
    }

    var currentUserDisplayName: String {
        if let email = sessionStore?.currentUser?.email, !email.isEmpty {
            let prefix = email.split(separator: "@").first.map(String.init)
            if let prefix, !prefix.isEmpty {
                return prefix
            }
            return email
        }
        return "You"
    }

    var isCurrentUserHost: Bool {
        guard let currentSession else { return false }
        return currentSession.participants.first(where: { $0.isHost })?.name == currentUserDisplayName
    }

    var remainingSeconds: Int {
        guard let session = currentSession else { return 0 }

        if session.isPaused {
            return max(0, session.pausedRemainingSeconds ?? 0)
        }

        return max(0, Int(session.endDate.timeIntervalSince(now)))
    }

    var elapsedSeconds: Int {
        guard let session = currentSession else { return 0 }
        return max(0, session.durationMinutes * 60 - remainingSeconds)
    }

    var progress: Double {
        guard let session = currentSession else { return 0 }
        let total = Double(max(session.durationMinutes * 60, 1))
        return min(max(Double(elapsedSeconds) / total, 0), 1)
    }

    var timeString: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var compactTimeString: String {
        "\(remainingSeconds / 60) dk"
    }

    var bubbleTitle: String {
        guard let session = currentSession else { return "Focus" }
        switch session.mode {
        case .personal: return "Focus"
        case .crew: return "Crew"
        case .friend: return "Friend"
        }
    }

    var bubbleSubtitle: String {
        timeString
    }

    var statusLine: String {
        guard let session = currentSession else { return "Hazır" }
        if session.isPaused { return "Focus duraklatıldı" }

        switch session.mode {
        case .personal:
            return "Şu an focustasın"
        case .crew:
            return "Crew session aktif"
        case .friend:
            return "Friend session aktif"
        }
    }

    var selectedMode: FocusMode {
        currentSession?.mode ?? .personal
    }

    var durationMinutes: Int {
        currentSession?.durationMinutes ?? 25
    }

    var isPaused: Bool {
        currentSession?.isPaused ?? false
    }

    var hostName: String? {
        currentSession?.participants.first(where: { $0.isHost })?.name
    }

    var participantCount: Int {
        currentSession?.participants.count ?? 0
    }

    var readyCount: Int {
        currentSession?.participants.filter { $0.isReady || $0.isActive }.count ?? 0
    }
    
    var hasBlockingActiveSession: Bool {
        isSessionActive && currentSession != nil
    }

    var activeSessionMode: FocusMode? {
        currentSession?.mode
    }

    var activeSessionDisplayTitle: String {
        guard let session = currentSession else { return "Focus" }

        switch session.mode {
        case .personal:
            return "\(session.goal.title) Focus"
        case .crew:
            return "Crew Focus"
        case .friend:
            return "Friend Focus"
        }
    }

    func canStartNewSession() -> Bool {
        !hasBlockingActiveSession
    }

    // MARK: - Summary Values

    var todayFocusMinutes: Int {
        if isSessionActive && selectedMode == .personal {
            return 72 + (elapsedSeconds / 60)
        }
        return 72
    }

    var weekFocusSessions: Int {
        if isSessionActive && selectedMode == .personal {
            return 5
        }
        return 4
    }

    var streakDays: Int {
        switch selectedMode {
        case .personal: return 6
        case .crew: return 5
        case .friend: return 3
        }
    }

    var lastSessionText: String {
        switch selectedMode {
        case .personal: return "Son oturum 2 saat önce"
        case .crew: return "Son crew oturumu dün"
        case .friend: return "Son ortak oturum bugün"
        }
    }

    var personalMetricOneTitle: String { "Bugün" }
    var personalMetricOneValue: String { "\(todayFocusMinutes) dk" }

    var personalMetricTwoTitle: String { "Seri" }
    var personalMetricTwoValue: String { "\(streakDays) gün" }

    var personalMetricThreeTitle: String { "Hafta" }
    var personalMetricThreeValue: String { "\(weekFocusSessions) session" }

    var crewMetricOneTitle: String { "Host" }
    var crewMetricOneValue: String { hostName ?? "Atakan" }

    var crewMetricTwoTitle: String { "Katılımcı" }
    var crewMetricTwoValue: String { "\(max(participantCount, 3)) kişi" }

    var crewMetricThreeTitle: String { "Hazır" }
    var crewMetricThreeValue: String { "\(max(readyCount, 2))/\(max(participantCount, 3))" }

    var friendMetricOneTitle: String { "Eşleşme" }
    var friendMetricOneValue: String {
        currentSession?.participants.first(where: { !$0.isHost })?.name ?? "Ece"
    }

    var friendMetricTwoTitle: String { "Hazır" }
    var friendMetricTwoValue: String { "\(max(readyCount, 2))/\(max(participantCount, 2))" }

    var friendMetricThreeTitle: String { "Seri" }
    var friendMetricThreeValue: String { "\(streakDays) gün" }

    func heroMetricItems(for mode: FocusMode) -> [(String, String)] {
        switch mode {
        case .personal:
            return [
                (personalMetricOneTitle, personalMetricOneValue),
                (personalMetricTwoTitle, personalMetricTwoValue),
                (personalMetricThreeTitle, personalMetricThreeValue)
            ]
        case .crew:
            return [
                (crewMetricOneTitle, crewMetricOneValue),
                (crewMetricTwoTitle, crewMetricTwoValue),
                (crewMetricThreeTitle, crewMetricThreeValue)
            ]
        case .friend:
            return [
                (friendMetricOneTitle, friendMetricOneValue),
                (friendMetricTwoTitle, friendMetricTwoValue),
                (friendMetricThreeTitle, friendMetricThreeValue)
            ]
        }
    }

    var selectedGoal: FocusGoal {
        currentSession?.goal ?? .study
    }

    var selectedStyle: FocusStyle {
        currentSession?.style ?? .silent
    }
}
