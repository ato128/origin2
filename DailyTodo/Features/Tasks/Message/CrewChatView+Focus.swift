//
//  CrewChatView+Focus.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI

extension CrewChatView {

    

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

    
}
