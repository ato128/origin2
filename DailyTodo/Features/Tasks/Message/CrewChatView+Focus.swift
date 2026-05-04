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
            HStack(spacing: 13) {
                ZStack {
                    Circle()
                        .fill(focusBannerAccent(session).opacity(0.16))
                        .frame(width: 42, height: 42)

                    Image(systemName: session.is_paused ? "pause.fill" : "timer")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(focusBannerAccent(session))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(focusBannerAccent(session))
                            .frame(width: 7, height: 7)

                        Text(session.is_paused ? "FOCUS PAUSED" : "LIVE FOCUS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.8)
                            .foregroundStyle(focusBannerAccent(session))
                    }

                    Text(
                        session.is_paused
                        ? String(localized: "crew_chat_focus_paused")
                        : String(localized: "crew_chat_focus_running")
                    )
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                    HStack(spacing: 5) {
                        Text(session.host_name)
                            .lineLimit(1)

                        Text("•")

                        Text(focusRemainingText(session))
                            .monospacedDigit()
                    }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.56))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(focusBannerAccent(session))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(focusBannerAccent(session).opacity(0.11))
                    )
            }
            .padding(.horizontal, 14)
            .frame(height: 78)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                focusBannerAccent(session).opacity(0.090),
                                Color(crewChatFocusHex: "#1593FF").opacity(0.050),
                                Color.white.opacity(0.042)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(focusBannerAccent(session).opacity(0.16), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.20), radius: 14, y: 7)
            )
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
            return Color(crewChatFocusHex: "#A3E635")
        }

        if session.is_paused {
            return Color(crewChatFocusHex: "#FBBF24")
        }

        let remainingText = focusRemainingText(session)
        let parts = remainingText.split(separator: ":")

        if let minString = parts.first, let minutes = Int(minString) {
            if minutes <= 3 {
                return Color(crewChatFocusHex: "#FF5A44")
            } else if minutes <= 10 {
                return Color(crewChatFocusHex: "#FBBF24")
            }
        }

        return Color(crewChatFocusHex: "#1593FF")
    }

    func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "low":
            return Color(crewChatFocusHex: "#A3E635")
        case "medium":
            return Color(crewChatFocusHex: "#FBBF24")
        case "high":
            return Color(crewChatFocusHex: "#FF5A44")
        case "urgent":
            return Color(crewChatFocusHex: "#C084FC")
        default:
            return Color(crewChatFocusHex: "#1593FF")
        }
    }

    func localizedMinutesText(_ minutes: Int) -> String {
        let isTurkish = Locale.current.language.languageCode?.identifier == "tr"
        return isTurkish ? "\(minutes) dk" : "\(minutes) min"
    }
}

// MARK: - Color Hex

private extension Color {
    init(crewChatFocusHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64

        switch cleaned.count {
        case 3:
            a = 255
            r = (int >> 8) * 17
            g = ((int >> 4) & 0xF) * 17
            b = (int & 0xF) * 17

        case 6:
            a = 255
            r = int >> 16
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        case 8:
            a = int >> 24
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        default:
            a = 255
            r = 255
            g = 255
            b = 255
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
