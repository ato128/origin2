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
    

    private let storageKey = "active_focus_session_state_v1"
    private let audioManager = FocusAudioManager.shared
    private let liveActivityManager = FocusLiveActivityManager.shared
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

    func startSession(
        mode: FocusMode,
        durationMinutes: Int,
        goal: FocusGoal,
        style: FocusStyle,
        participants: [FocusParticipant] = []
    ) {
        let start = Date()
        let end = start.addingTimeInterval(Double(durationMinutes * 60))

        let resolvedParticipants: [FocusParticipant]
        switch mode {
        case .personal:
            resolvedParticipants = []
        case .crew:
            resolvedParticipants = participants.isEmpty ? FocusParticipant.mockCrew : participants
        case .friend:
            resolvedParticipants = participants.isEmpty ? FocusParticipant.mockFriend : participants
        }

        let session = FocusSessionState(
            id: UUID(),
            mode: mode,
            durationMinutes: durationMinutes,
            startDate: start,
            endDate: end,
            isPaused: false,
            pausedRemainingSeconds: nil,
            participants: resolvedParticipants,
            goal: goal,
            style: style
        )

        currentSession = session
        isSessionActive = true
        isExpanded = true
        isMinimized = false
        save()
        startLifecycleTimer()
        audioManager.play(style: style)
        
        
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
        currentSession = nil
        isSessionActive = false
        isExpanded = false
        isMinimized = false
        completionSummary = nil
        save()
        stopLifecycleTimer()
        audioManager.stop()
        
        Task {
            await liveActivityManager.end()
        }
    }

    func pauseSession() {
        guard var session = currentSession, !session.isPaused else { return }
        let remaining = remainingSeconds
        session.isPaused = true
        session.pausedRemainingSeconds = remaining
        currentSession = session
        save()
        audioManager.pause()
        
        
    }

    func resumeSession() {
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
        
       
    }

    func togglePause() {
        guard let session = currentSession else { return }
        if session.isPaused {
            resumeSession()
        } else {
            pauseSession()
        }
    }

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
            return
        }

        if session.endDate <= Date() {
            currentSession = nil
            isSessionActive = false
            isExpanded = false
            isMinimized = false
            UserDefaults.standard.removeObject(forKey: storageKey)
            return
        }

        currentSession = session
        isSessionActive = true
        startLifecycleTimer()
        audioManager.play(style: session.style)
        
        
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
            closeSession()
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
        stopLifecycleTimer()
        audioManager.stop()

        let summary = FocusCompletionSummary(
            id: UUID(),
            mode: session.mode,
            durationMinutes: session.durationMinutes,
            completedAt: Date(),
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

        UserDefaults.standard.removeObject(forKey: storageKey)
        Task {
            await liveActivityManager.end()
        }
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
        currentSession?.participants.filter { $0.isReady }.count ?? 0
    }

    // MARK: - Monetizable summary data

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
    func dismissCompletionSummary() {
        completionSummary = nil
        isExpanded = false
    }

    func restartLastFinishedSession() {
        guard let session = lastFinishedSession else { return }

        startSession(
            mode: session.mode,
            durationMinutes: session.durationMinutes,
            goal: session.goal,
            style: session.style,
            participants: session.participants
        )

        completionSummary = nil
    }
    var selectedGoal: FocusGoal {
        currentSession?.goal ?? .study
    }

    var selectedStyle: FocusStyle {
        currentSession?.style ?? .silent
    }

}

enum FocusGoal: String, CaseIterable, Identifiable, Codable {
    case study
    case deepWork
    case reading
    case planning
    case workout

    var id: String { rawValue }

    var title: String {
        switch self {
        case .study: return "Study"
        case .deepWork: return "Deep Work"
        case .reading: return "Reading"
        case .planning: return "Planning"
        case .workout: return "Workout"
        }
    }

    var subtitle: String {
        switch self {
        case .study: return "Ders ve tekrar"
        case .deepWork: return "Kesintisiz çalışma"
        case .reading: return "Okuma akışı"
        case .planning: return "Planlama zamanı"
        case .workout: return "Aktif odak modu"
        }
    }

    var icon: String {
        switch self {
        case .study: return "book.closed.fill"
        case .deepWork: return "brain.head.profile"
        case .reading: return "text.book.closed.fill"
        case .planning: return "calendar"
        case .workout: return "figure.run"
        }
    }
}

enum FocusStyle: String, CaseIterable, Identifiable, Codable {
    case silent
    case ambient
    case rain
    case library

    var id: String { rawValue }

    var title: String {
        switch self {
        case .silent: return "Silent"
        case .ambient: return "Ambient"
        case .rain: return "Rain"
        case .library: return "Library"
        }
    }

    var subtitle: String {
        switch self {
        case .silent: return "Sessiz mod"
        case .ambient: return "Yumuşak arka plan"
        case .rain: return "Yağmur sesi hissi"
        case .library: return "Kütüphane atmosferi"
        }
    }

    var icon: String {
        switch self {
        case .silent: return "speaker.slash.fill"
        case .ambient: return "waveform"
        case .rain: return "cloud.rain.fill"
        case .library: return "building.columns.fill"
        }
    }

}

