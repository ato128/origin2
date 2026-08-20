//
//  CrewChatView+Focus.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI

extension CrewChatView {

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
            return Color(arenaHex: "#A3E635")
        }

        if session.is_paused {
            return Color(arenaHex: "#FBBF24")
        }

        let remainingText = focusRemainingText(session)
        let parts = remainingText.split(separator: ":")

        if let minString = parts.first, let minutes = Int(minString) {
            if minutes <= 3 {
                return Color(arenaHex: "#FF5A44")
            } else if minutes <= 10 {
                return Color(arenaHex: "#FBBF24")
            }
        }

        return Color(arenaHex: "#1593FF")
    }

    func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "low":
            return Color(arenaHex: "#A3E635")
        case "medium":
            return Color(arenaHex: "#FBBF24")
        case "high":
            return Color(arenaHex: "#FF5A44")
        case "urgent":
            return Color(arenaHex: "#C084FC")
        default:
            return Color(arenaHex: "#1593FF")
        }
    }

    func localizedMinutesText(_ minutes: Int) -> String {
        let isTurkish = !appLanguageIsEnglish()
        return isTurkish ? "\(minutes) dk" : "\(minutes) min"
    }

    /// Focus pill → YENİ focus sistemi. Aktif crew session'ından bir invite
    /// payload'ı kurup app kökündeki CrewFocusInviteSheet'i açar (kaç kişi odakta
    /// + Katıl). "Katıl" → handleCrewFocusInviteJoin → joinCrewFocusSession +
    /// FocusSessionManager.hydrateFromCrewSessionDTO devralır. Eski
    /// CrewFocusRoomBackendView'a artık gerek yok.
    func presentCrewFocusJoin(session: CrewFocusSessionDTO) {
        let activeParticipants = (crewStore.focusParticipantsBySession[session.id] ?? [])
            .filter { $0.is_active }
        let names = activeParticipants.map { $0.member_name }

        var userInfo: [AnyHashable: Any] = [
            "crew_id": session.crew_id.uuidString,
            "session_id": session.id.uuidString,
            "host_name": session.host_name,
            "crew_name": crew.name,
            "duration_minutes": session.duration_minutes,
            "started_at": session.started_at,
            "total_participants": max(names.count, 1)
        ]
        if let taskTitle = session.task_title { userInfo["task_title"] = taskTitle }
        if let hostID = session.host_user_id { userInfo["host_user_id"] = hostID.uuidString }
        if !names.isEmpty { userInfo["participant_names"] = names }

        NotificationCenter.default.post(
            name: .presentCrewFocusInviteSheet,
            object: userInfo
        )
    }
}

// MARK: - Color Hex
