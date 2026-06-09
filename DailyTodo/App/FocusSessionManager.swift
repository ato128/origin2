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
import UserNotifications

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
    @Published var currentCrewHostUserID: UUID?
    
    private struct StoredFocusSessionSnapshot: Codable {
        let session: FocusSessionState
        let crewID: UUID?
        let crewBackendSessionID: UUID?
        let crewHostUserID: UUID?
        let savedAt: Date
    }

    private let storageKey = "active_focus_session_state_v1"
    private let lastFocusMinutesKey = "last_focus_minutes_v1"
    private let audioManager = FocusAudioManager.shared
    private let liveActivityManager = FocusLiveActivityManager.shared

    private weak var crewStore: CrewStore?
    private weak var sessionStore: SessionStore?

    private var timer: Timer?
    private var nowTimer: Timer?
    private var isCompletingSession: Bool = false

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

        retryExpiredFinalizeAfterDependenciesReady(reason: "configure")
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

    // MARK: - Close (User Stopped Manually)

    /// Kullanıcı stop'a bastığında çağrılır.
    /// Personal/Friend → tebrikler + lokal bildirim
    /// Crew host → herkese end push + tebrikler
    /// Crew üye → kendisi ayrılır, diğerlerine "X ayrıldı" push
    func closeSession() {
        guard let session = currentSession else {
            clearSessionLocally()
            return
        }

        // Failed completion recorder (totalSeconds dolmadı)
        FocusCompletionRecorder.shared.saveCompletedSession(
            ownerUserID: currentUserID?.uuidString,
            title: activeSessionDisplayTitle,
            startedAt: session.startDate,
            endedAt: Date(),
            totalSeconds: session.durationMinutes * 60,
            completedSeconds: elapsedSeconds,
            isCompleted: false
        )

        // Crew akışı
        if session.mode == .crew,
           let crewID = currentCrewID,
           let backendSessionID = currentCrewBackendSessionID,
           let crewStore {

            let host = isCurrentUserHost
            let completedMins = resolvedCompletedMinutes(for: session)
            let participantSnapshot = session.participants
            let leaverName = currentUserDisplayName
            let leaverID = currentUserID
            let backendParticipants = crewStore.focusParticipantsBySession[backendSessionID] ?? []
            let otherParticipantIDsSnapshot = backendParticipants
                .compactMap { $0.user_id }
                .filter { $0 != currentUserID }

            // Crew session backend güncelle (async)
            Task { [weak self] in
                guard let self else { return }

                do {
                    if host {
                        // Host kapatıyor → focus tamamen sonlandırılıyor
                        try await crewStore.endCrewFocusSession(
                            sessionID: backendSessionID,
                            crewID: crewID,
                            hostUserID: self.currentUserID,
                            hostName: leaverName,
                            completedMinutes: completedMins,
                            participantNames: participantSnapshot.map(\.name),
                            taskID: nil
                        )
                    } else {
                        // Üye ayrılıyor → focus diğerleri için devam ediyor
                        try await crewStore.leaveCrewFocusSession(
                            sessionID: backendSessionID,
                            crewID: crewID,
                            userID: self.currentUserID,
                            memberName: leaverName
                        )

                        // Diğerlerine "X ayrıldı" push
                        await self.sendLeftPushToOthers(
                            crewID: crewID,
                            leaverName: leaverName,
                            otherParticipantIDs: otherParticipantIDsSnapshot
                        )
                    }
                } catch {
                    print("CLOSE SESSION BACKEND ERROR:", error.localizedDescription)
                }
            }

            // Crew için tebrikler + bildirim:
            // - Host → tebrikler + end push diğerlerine (completeAndPersist içinde)
            // - Üye → kendi tebrikler ekranı (kendisi ayrıldı, "X dk yaptın" göstermek mantıklı)
            completeAndPersist(session, shouldPersistCrewBackend: false)
            return
        }

        // Personal/Friend: tebrikler + lokal bildirim
        completeAndPersist(session, shouldPersistCrewBackend: false)
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

        let startDate = CrewDateParser.parse(dto.started_live_at ?? dto.started_at) ?? Date()

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
        currentCrewHostUserID = dto.host_user_id
        isSessionActive = dto.is_active
        isExpanded = false
        isMinimized = dto.is_active

        save()
        startLifecycleTimer()
        syncAudioForCurrentState()

        if dto.is_active && !dto.is_paused {
            scheduleFocusEndBackupNotification(for: session)
        }

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

        scheduleFocusEndBackupNotification(for: session)

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
            let dto = try await crewStore.startCrewFocusSession(
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
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            currentSession = nil
            isSessionActive = false
            isExpanded = false
            isMinimized = false
            return
        }

        let restoredSession: FocusSessionState
        let restoredCrewID: UUID?
        let restoredCrewBackendSessionID: UUID?
        let restoredCrewHostUserID: UUID?

        if let snapshot = try? JSONDecoder().decode(StoredFocusSessionSnapshot.self, from: data) {
            restoredSession = snapshot.session
            restoredCrewID = snapshot.crewID
            restoredCrewBackendSessionID = snapshot.crewBackendSessionID
            restoredCrewHostUserID = snapshot.crewHostUserID
        } else if let legacySession = try? JSONDecoder().decode(FocusSessionState.self, from: data) {
            restoredSession = legacySession
            restoredCrewID = nil
            restoredCrewBackendSessionID = nil
            restoredCrewHostUserID = nil
        } else {
            currentSession = nil
            isSessionActive = false
            isExpanded = false
            isMinimized = false
            UserDefaults.standard.removeObject(forKey: storageKey)
            return
        }

        currentSession = restoredSession
        currentCrewID = restoredCrewID
        currentCrewBackendSessionID = restoredCrewBackendSessionID
        currentCrewHostUserID = restoredCrewHostUserID

        if restoredSession.isPaused {
            isSessionActive = true
            isExpanded = false
            isMinimized = true
            syncAudioForCurrentState()

            Task {
                await syncLiveActivityIfNeeded()
            }

            return
        }

        if restoredSession.endDate <= Date() {
            isSessionActive = true
            isExpanded = false
            isMinimized = true
            now = Date()
            stopLifecycleTimer()
            audioManager.stop()

            reconcileExpiredSessionIfNeeded(reason: "restore_expired")
            return
        }

        isSessionActive = true
        isExpanded = false
        isMinimized = true
        startLifecycleTimer()
        syncAudioForCurrentState()

        Task {
            await syncLiveActivityIfNeeded()
        }
    }
    
    func reconcileExpiredSessionIfNeeded(reason: String) {
        guard let session = currentSession else { return }
        guard !session.isPaused else { return }
        guard session.endDate <= Date() else { return }

        now = Date()

        guard canFinalizeSession(session) else {
            print("⏳ EXPIRED FOCUS WAITING FOR DEPENDENCIES:", reason)
            print("⏳ mode:", session.mode.rawValue)
            print("⏳ currentUserID:", currentUserID?.uuidString ?? "nil")
            print("⏳ crewStore:", crewStore == nil ? "nil" : "ready")
            print("⏳ currentCrewID:", currentCrewID?.uuidString ?? "nil")
            print("⏳ backendSessionID:", currentCrewBackendSessionID?.uuidString ?? "nil")

            retryExpiredFinalizeAfterDependenciesReady(reason: reason)
            return
        }

        print("✅ RECONCILE EXPIRED FOCUS:", reason)
        finishSession(session)
    }
    
    private func canFinalizeSession(_ session: FocusSessionState) -> Bool {
        guard currentUserID != nil else {
            return false
        }

        switch session.mode {
        case .personal, .friend:
            return true

        case .crew:
            guard crewStore != nil else { return false }
            guard currentCrewID != nil else { return false }

            return true
        }
    }

    private func save() {
        guard let currentSession else {
            UserDefaults.standard.removeObject(forKey: storageKey)
            return
        }

        let snapshot = StoredFocusSessionSnapshot(
            session: currentSession,
            crewID: currentCrewID,
            crewBackendSessionID: currentCrewBackendSessionID,
            crewHostUserID: currentCrewHostUserID,
            savedAt: Date()
        )

        if let encoded = try? JSONEncoder().encode(snapshot) {
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
        completeAndPersist(
            session,
            shouldPersistCrewBackend: true
        )
    }

    // MARK: - Completion (Tebrikler + Bildirimler + Live Activity end)

    private func completeAndPersist(
        _ session: FocusSessionState,
        shouldPersistCrewBackend: Bool = true
    ) {
        guard !isCompletingSession else {
            print("⚪️ COMPLETE SKIPPED: already completing")
            return
        }

        isCompletingSession = true

        stopLifecycleTimer()
        audioManager.stop()
        cancelFocusEndBackupNotification(for: session)

    

        let ended = Date()
        let totalSeconds = session.durationMinutes * 60

        let completedMinutes = max(1, resolvedCompletedMinutes(for: session))
        let completedSeconds = max(1, elapsedSeconds)

        FocusCompletionRecorder.shared.saveCompletedSession(
            ownerUserID: currentUserID?.uuidString,
            title: activeSessionDisplayTitle,
            startedAt: session.startDate,
            endedAt: ended,
            totalSeconds: totalSeconds,
            completedSeconds: completedSeconds,
            isCompleted: completedSeconds >= totalSeconds - 5
        )

        let previousMinutes: Int? = {
            let value = UserDefaults.standard.integer(forKey: lastFocusMinutesKey)
            return value > 0 ? value : nil
        }()

        let summary = FocusCompletionSummary(
            id: UUID(),
            mode: session.mode,
            durationMinutes: completedMinutes,
            completedAt: ended,
            totalTodayMinutes: todayFocusMinutes + completedMinutes,
            streakDays: streakDays + 1,
            completedSessionsToday: max(1, weekFocusSessions - 2),
            goal: session.goal,
            style: session.style,
            participantCount: session.participants.count,
            previousMinutes: previousMinutes
        )

        UserDefaults.standard.set(completedMinutes, forKey: lastFocusMinutesKey)

        lastFinishedSession = session
        completionSummary = summary

        let completedLiveTitle: String = {
            switch session.mode {
            case .personal:
                return "\(session.goal.title) Focus"
            case .crew:
                return "Crew Focus"
            case .friend:
                return "Friend Focus"
            }
        }()

        let completedLiveSubtitle: String = {
            switch session.mode {
            case .personal:
                return "Kişisel focus tamamlandı"
            case .crew:
                return "Crew focus tamamlandı"
            case .friend:
                return "Shared focus tamamlandı"
            }
        }()

        Task {
            await liveActivityManager.finishThenEnd(
                title: completedLiveTitle,
                subtitle: completedLiveSubtitle,
                modeRaw: session.mode.rawValue,
                startDate: session.startDate,
                completedAt: ended
            )
        }

        if session.mode == .personal || session.mode == .friend {
            if shouldScheduleImmediateCompletionNotification(endedAt: ended) {
                scheduleLocalFocusEndedNotification(
                    durationMinutes: completedMinutes,
                    previousMinutes: previousMinutes
                )
            } else {
                print("⚪️ LOCAL COMPLETION NOTIF SKIPPED: backup notification already handled")
            }
        }

        if shouldPersistCrewBackend,
           session.mode == .crew,
           let crewID = currentCrewID {
            let crewName = crewStore?.crews.first(where: { $0.id == crewID })?.name ?? "Crew"

            let participantIDs = collectParticipantUserIDs(
                from: session.participants,
                crewID: crewID
            )

            let backendSessionID = currentCrewBackendSessionID
            let hostUserID = currentUserID
            let hostName = currentUserDisplayName
            let shouldPersistAsHost = isCurrentUserHost

            Task { [weak self] in
                guard let self else { return }

                if shouldPersistAsHost {
                    await self.persistCrewFocusCompletionToBackend(
                        session: session,
                        crewID: crewID,
                        backendSessionID: backendSessionID,
                        hostUserID: hostUserID,
                        hostName: hostName,
                        completedMinutes: completedMinutes
                    )

                    await self.sendCrewFocusEndedPush(
                        crewID: crewID,
                        crewName: crewName,
                        participantIDs: participantIDs,
                        durationMinutes: completedMinutes,
                        previousMinutes: previousMinutes
                    )
                } else {
                    print("⚪️ CREW FOCUS BACKEND PERSIST SKIPPED: current user is not host")
                }
            }
        }

        currentSession = nil
        isSessionActive = false
        isMinimized = false
        isExpanded = false
        currentCrewID = nil
        currentCrewBackendSessionID = nil
        currentCrewHostUserID = nil

        UserDefaults.standard.removeObject(forKey: storageKey)

        NotificationCenter.default.post(
            name: Notification.Name("focus_completed"),
            object: nil
        )
        isCompletingSession = false
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
        currentCrewHostUserID = nil
        isCompletingSession = false

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
        cancelFocusEndBackupNotification(for: session)
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
        scheduleFocusEndBackupNotification(for: session)
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

        let elapsed = max(0, session.durationMinutes * 60 - remainingSeconds)
        return max(1, elapsed / 60)
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

    // MARK: - Bildirim Helper'ları

    private func smartFocusCompletionBody(
        durationMinutes: Int,
        previousMinutes: Int?
    ) -> String {
        guard let previousMinutes, previousMinutes > 0 else {
            return "\(durationMinutes) dakika focus tamamladın. Güzel başlangıç 🎯"
        }

        let delta = durationMinutes - previousMinutes

        if delta >= 5 {
            return "\(durationMinutes) dakika tamamladın · geçen seferden \(delta) dk daha fazla. İyileşiyorsun 🚀"
        }

        if delta > 0 {
            return "\(durationMinutes) dakika tamamladın · geçen seferden \(delta) dk daha iyi 👏"
        }

        if delta == 0 {
            return "\(durationMinutes) dakika tamamladın · ritmini korudun 🔥"
        }

        return "\(durationMinutes) dakika tamamladın · bugün kısa tuttun ama akışı bozmadın ✅"
    }

    private func lastSavedFocusMinutes() -> Int? {
        let value = UserDefaults.standard.integer(forKey: lastFocusMinutesKey)
        return value > 0 ? value : nil
    }

    private func shouldScheduleImmediateCompletionNotification(
        endedAt: Date
    ) -> Bool {
        Date().timeIntervalSince(endedAt) < 12
    }

    private func focusEndBackupNotificationID(for session: FocusSessionState) -> String {
        "focus_end_backup_\(session.id.uuidString)"
    }

    private func scheduleFocusEndBackupNotification(for session: FocusSessionState) {
        let center = UNUserNotificationCenter.current()
        let previousMinutes = lastSavedFocusMinutes()
        let identifier = focusEndBackupNotificationID(for: session)

        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized ||
                  settings.authorizationStatus == .provisional ||
                  settings.authorizationStatus == .ephemeral else {
                print("⚠️ FOCUS END BACKUP NOTIF SKIPPED: permission not granted")
                return
            }

            let triggerDate = session.endDate

            guard triggerDate > Date().addingTimeInterval(3) else {
                print("⚠️ FOCUS END BACKUP NOTIF SKIPPED: endDate too close")
                return
            }

            let content = UNMutableNotificationContent()

            switch session.mode {
            case .personal:
                content.title = "Focus tamamlandı 🎉"
            case .crew:
                content.title = "Crew focus tamamlandı 🎉"
            case .friend:
                content.title = "Friend focus tamamlandı 🎉"
            }

            content.body = self.smartFocusCompletionBody(
                durationMinutes: session.durationMinutes,
                previousMinutes: previousMinutes
            )

            content.sound = .default
            content.userInfo = [
                "type": "focus_ended_local",
                "session_id": session.id.uuidString,
                "mode": session.mode.rawValue,
                "duration_minutes": session.durationMinutes,
                "previous_minutes": previousMinutes ?? 0
            ]

            if #available(iOS 15.0, *) {
                content.interruptionLevel = .timeSensitive
            }

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: triggerDate
            )

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: false
            )

            center.removePendingNotificationRequests(withIdentifiers: [identifier])

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                if let error {
                    print("❌ FOCUS END BACKUP NOTIF ERROR:", error.localizedDescription)
                } else {
                    print("✅ FOCUS END BACKUP NOTIF SCHEDULED:", triggerDate)
                }
            }
        }
    }

    private func cancelFocusEndBackupNotification(for session: FocusSessionState) {
        let identifier = focusEndBackupNotificationID(for: session)

        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [identifier]
        )

        print("🧹 FOCUS END BACKUP NOTIF CANCELLED:", identifier)
    }
    
    private func collectParticipantUserIDs(
        from participants: [FocusParticipant],
        crewID: UUID
    ) -> [UUID] {
        guard let backendSessionID = currentCrewBackendSessionID,
              let crewStore else {
            return []
        }

        let dtos = crewStore.focusParticipantsBySession[backendSessionID] ?? []
        return dtos.compactMap { $0.user_id }
    }

    /// Kişisel veya Friend focus bitince LOCAL notification göster.
    private func scheduleLocalFocusEndedNotification(
        durationMinutes: Int,
        previousMinutes: Int?
    ) {
        let center = UNUserNotificationCenter.current()

        // Önce permission kontrol et — log için
        center.getNotificationSettings { settings in
            print("🔔 NOTIF AUTHORIZATION STATUS:", settings.authorizationStatus.rawValue)
            print("🔔 NOTIF ALERT SETTING:", settings.alertSetting.rawValue)
            print("🔔 NOTIF SOUND SETTING:", settings.soundSetting.rawValue)
            print("🔔 NOTIF LOCK SCREEN:", settings.lockScreenSetting.rawValue)
        }

        let content = UNMutableNotificationContent()
        content.title = "Focus tamamlandı 🎉"

        content.body = smartFocusCompletionBody(
            durationMinutes: durationMinutes,
            previousMinutes: previousMinutes
        )

        content.sound = .default
        content.interruptionLevel = .timeSensitive   // Lock Screen'de daha güçlü görünür
        content.userInfo = [
            "type": "focus_ended_local",
            "duration_minutes": durationMinutes
        ]

        // 2 saniye sonra tetiklensin (live activity end'ine zaman tanı)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)

        let request = UNNotificationRequest(
            identifier: "focus_ended_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                print("❌ LOCAL FOCUS NOTIF ERROR:", error.localizedDescription)
            } else {
                print("✅ LOCAL FOCUS NOTIF SCHEDULED for \(durationMinutes) dk")
            }
        }
    }

    private func sendCrewFocusEndedPush(
        crewID: UUID,
        crewName: String,
        participantIDs: [UUID],
        durationMinutes: Int,
        previousMinutes: Int?
    ) async {
        await FocusInviteService.shared.sendEndNotifications(
            crewID: crewID,
            crewName: crewName,
            participantIDs: participantIDs,
            durationMinutes: durationMinutes,
            previousMinutes: previousMinutes
        )
    }
    
    private func persistCrewFocusCompletionToBackend(
        session: FocusSessionState,
        crewID: UUID,
        backendSessionID: UUID?,
        hostUserID: UUID?,
        hostName: String,
        completedMinutes: Int,
        taskID: UUID? = nil
    ) async {
        guard let crewStore else {
            print("❌ CREW FOCUS BACKEND PERSIST SKIPPED: crewStore nil")
            return
        }

        let participantNames = session.participants
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let backendSessionID {
            do {
                try await crewStore.endCrewFocusSession(
                    sessionID: backendSessionID,
                    crewID: crewID,
                    hostUserID: hostUserID,
                    hostName: hostName,
                    completedMinutes: completedMinutes,
                    participantNames: participantNames,
                    taskID: taskID
                )

                print("✅ CREW FOCUS BACKEND PERSISTED:", crewID.uuidString)
                return
            } catch {
                print("❌ CREW FOCUS END BACKEND ERROR:", error.localizedDescription)
            }
        }

        await crewStore.createFocusRecord(
            crewID: crewID,
            userID: hostUserID,
            memberName: hostName,
            minutes: completedMinutes
        )

        print("✅ CREW FOCUS BACKEND FALLBACK RECORD CREATED:", crewID.uuidString)
    }

    private func sendLeftPushToOthers(
        crewID: UUID,
        leaverName: String,
        otherParticipantIDs: [UUID]
    ) async {
        let crewName = crewStore?.crews.first(where: { $0.id == crewID })?.name ?? "Crew"

        let uniqueIDs = Array(Set(otherParticipantIDs))

        guard !uniqueIDs.isEmpty else {
            print("FOCUS LEFT PUSH SKIPPED: no other participants")
            return
        }

        await FocusInviteService.shared.sendLeftNotifications(
            crewID: crewID,
            crewName: crewName,
            leaverID: currentUserID ?? UUID(),
            leaverName: leaverName,
            otherParticipantIDs: uniqueIDs
        )
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
    
    private func retryExpiredFinalizeAfterDependenciesReady(reason: String) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            let delays: [UInt64] = [
                0,
                700_000_000,
                1_500_000_000,
                3_000_000_000
            ]

            for delay in delays {
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: delay)
                }

                guard let session = self.currentSession else { return }
                guard !session.isPaused else { return }
                guard session.endDate <= Date() else { return }

                self.reconcileExpiredSessionIfNeeded(reason: "\(reason)_retry")
            }
        }
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
        if let currentCrewHostUserID,
           let currentUserID {
            return currentCrewHostUserID == currentUserID
        }

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
    
    var requestedMinutes: Int {
        durationMinutes
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
