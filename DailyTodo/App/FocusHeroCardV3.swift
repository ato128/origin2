//
//  FocusHeroCardV3.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 9.04.2026.
//

import SwiftUI

struct FocusHeroCardV3: View {
    let mode: FocusMode
    let selectedPreset: FocusDurationPreset
    let customMinutes: Int
    let progress: Double
    let statusText: String
    let supportText: String
    let selectedGoal: FocusGoal
    let selectedStyle: FocusStyle
    let preSessionTitle: String
    let preSessionSubtitle: String
    let preSessionParticipants: [FocusParticipant]
    let preSessionCanStart: Bool
    let onSelectPreset: (FocusDurationPreset) -> Void
    let onTapGoal: () -> Void
    let onTapStyle: () -> Void
    let onTapCTA: () -> Void

    @EnvironmentObject var focusSession: FocusSessionManager

    @State private var appeared = false
    @State private var ambientPulse = false
    @State private var ctaPressed = false

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var durationText: String {
        if focusSession.isSessionActive && focusSession.selectedMode == mode {
            return "\(focusSession.durationMinutes) dk"
        }

        switch selectedPreset {
        case .short: return "15 dk"
        case .medium: return "25 dk"
        case .long: return "45 dk"
        case .custom: return "Özel"
        }
    }

    private var theme: FocusHeroTheme {
        FocusHeroTheme.forMode(mode)
    }

    private var metricItems: [(String, String)] {
        focusSession.heroMetricItems(for: mode)
    }
    
    private var ritualItems: [(String, String)] {
        [
            ("Goal", selectedGoal.title),
            ("Sound", selectedStyle.title)
        ]
    }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(alignment: .leading, spacing: 15) {
                topHeader
                heroStage
                metricRow
                ritualRow
                lobbySection
                presetRow
                ctaArea
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(cardStroke)
        .shadow(color: .black.opacity(0.34), radius: 28, x: 0, y: 18)
        .shadow(color: theme.shadowColor.opacity(0.12), radius: 16, x: 0, y: 8)
        .scaleEffect(appeared ? 1 : 0.99)
        .offset(y: appeared ? 0 : 8)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.76, dampingFraction: 0.86), value: appeared)
        .onAppear {
            appeared = true
            ambientPulse = true
        }
    }
}

private extension FocusHeroCardV3 {
    var cardStroke: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.12),
                        Color.white.opacity(0.04),
                        Color.black.opacity(0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
    
    var lobbySection: some View {
        Group {
            if mode != .personal {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(preSessionTitle)
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.96))

                            Text(preSessionSubtitle)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.70))
                                .lineLimit(2)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            Circle()
                                .fill(preSessionCanStart ? Color.green : Color.yellow)
                                .frame(width: 8, height: 8)

                            Text(preSessionCanStart ? "Hazır" : "Bekliyor")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.88))
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(preSessionParticipants) { participant in
                                lobbyParticipantChip(participant)
                            }
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.black.opacity(0.16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    func lobbyParticipantChip(_ participant: FocusParticipant) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Circle()
                    .fill(lobbyStatusColor(participant))
                    .frame(width: 8, height: 8)

                Text(participant.isHost ? "HOST" : (participant.isReady ? "READY" : "WAITING"))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.52))
                    .tracking(1)
            }

            Text(participant.name)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.96))
                .lineLimit(1)

            Text(lobbyStatusText(participant))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.64))
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 126)
        .frame(minHeight: 82, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
    
    func lobbyStatusColor(_ participant: FocusParticipant) -> Color {
        participant.isReady ? .green : .gray.opacity(0.75)
    }

    func lobbyStatusText(_ participant: FocusParticipant) -> String {
        if participant.isHost {
            return "Oturumu başlatabilir"
        } else if participant.isReady {
            return "Başlamaya hazır"
        } else {
            return "Hazır olmayı bekliyor"
        }
    }

    var backgroundLayer: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            theme.topColor,
                            theme.midColor,
                            theme.bottomColor
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RadialGradient(
                colors: [
                    Color.black.opacity(0.00),
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.42),
                    Color.black.opacity(0.72)
                ],
                center: .center,
                startRadius: 16,
                endRadius: 250
            )
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.07),
                            Color.clear,
                            Color.black.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(theme.highlightColor.opacity(ambientPulse ? 0.16 : 0.11))
                .frame(width: 170, height: 170)
                .blur(radius: 42)
                .offset(x: 108, y: -112)
                .animation(.easeInOut(duration: 5.4).repeatForever(autoreverses: true), value: ambientPulse)

            Circle()
                .fill(theme.secondaryGlow.opacity(ambientPulse ? 0.14 : 0.09))
                .frame(width: 150, height: 150)
                .blur(radius: 44)
                .offset(x: -72, y: 112)
                .animation(.easeInOut(duration: 6.0).repeatForever(autoreverses: true), value: ambientPulse)

            Ellipse()
                .fill(Color.black.opacity(0.18))
                .frame(width: 260, height: 140)
                .blur(radius: 26)
                .offset(y: 88)

            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.035),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
        }
    }

    var topHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(mode.heroEyebrow)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.70))
                    .textCase(.uppercase)
                    .tracking(1.5)

                Text(mode.heroTitle)
                    .font(.system(size: 27, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.985))

                Text(mode.heroSubtitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.78))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )

                Image(systemName: "timer")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.88))
            }
            .frame(width: 64, height: 64)
        }
    }

    var heroStage: some View {
        HStack(alignment: .center, spacing: 14) {
            leftInfoColumn
            Spacer(minLength: 0)
            ringSection
        }
    }

    var leftInfoColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusPill

            VStack(alignment: .leading, spacing: 4) {
                Text(durationText)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.985))
                    .contentTransition(.numericText())

                Text(modeDurationSubtitle)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.80))
                    .lineLimit(2)
            }

            VStack(alignment: .leading, spacing: 6) {
                compactInfoRow(title: "Durum", value: statusText)
                compactInfoRow(title: "Açıklama", value: supportText)
                compactInfoRow(title: "Not", value: supportingLine)
            }
        }
        .frame(width: 126, alignment: .leading)
    }

    func compactInfoRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.48))
                .tracking(1.1)

            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.76))
                .lineLimit(2)
        }
    }

    var statusPill: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(theme.badgeDotColor)
                .frame(width: 8, height: 8)

            Text(focusSession.isSessionActive && focusSession.selectedMode == mode ? "Aktif" : "Hazır")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.92))
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.20))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }

    var ringSection: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 13)

            Circle()
                .trim(from: 0, to: appeared ? clampedProgress : 0)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.93),
                            theme.ringTint.opacity(0.88)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 13, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: theme.ringTint.opacity(0.08), radius: 6, x: 0, y: 0)
                .animation(.easeOut(duration: 0.9), value: appeared)

            Circle()
                .stroke(Color.white.opacity(0.02), lineWidth: 1)
                .padding(9)

            VStack(spacing: 2) {
                Text("\(Int(clampedProgress * 100))%")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.985))

                Text(statusText.lowercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.66))

                Text(durationText)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.42))
                    .padding(.top, 2)
            }
        }
        .frame(width: 176, height: 176)
    }

    var metricRow: some View {
        HStack(spacing: 9) {
            ForEach(Array(metricItems.enumerated()), id: \.offset) { _, item in
                metricCard(title: item.0, value: item.1)
            }
        }
    }
    
    var ritualRow: some View {
        HStack(spacing: 9) {
            interactiveRitualCard(
                title: "Goal",
                value: selectedGoal.title,
                subtitle: selectedGoal.subtitle,
                icon: selectedGoal.icon,
                isAccent: true,
                action: onTapGoal
            )

            interactiveRitualCard(
                title: "Sound",
                value: selectedStyle.title,
                subtitle: selectedStyle.subtitle,
                icon: selectedStyle.icon,
                isAccent: true,
                action: onTapStyle
            )
        }
    }

    func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.52))
                .tracking(1.0)

            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.95))
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }
    
    func interactiveRitualCard(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        isAccent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isAccent ? Color.white.opacity(0.14) : Color.white.opacity(0.08))

                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.92))
                    }
                    .frame(width: 28, height: 28)

                    Text(title.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.52))
                        .tracking(1.0)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.40))
                }

                Text(value)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.97))
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .lineLimit(2)

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(isAccent ? 0.08 : 0.05), lineWidth: 1)
                    )
            )
            .shadow(
                color: isAccent ? theme.highlightColor.opacity(0.10) : .clear,
                radius: 10,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
    }

    var presetRow: some View {
        HStack(spacing: 9) {
            ForEach(FocusDurationPreset.allCases) { preset in
                Button {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                        onSelectPreset(preset)
                    }
                } label: {
                    Text(preset == .custom ? "Özel" : preset.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(selectedPreset == preset ? 0.98 : 0.76))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    selectedPreset == preset
                                    ? LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.10),
                                            Color.white.opacity(0.055)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    : LinearGradient(
                                        colors: [
                                            Color.black.opacity(0.10),
                                            Color.black.opacity(0.18)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(
                                            Color.white.opacity(selectedPreset == preset ? 0.09 : 0.035),
                                            lineWidth: 1
                                        )
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    var ctaArea: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.84))

                Text(mode.startLine)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.86))
                    .lineLimit(1)
            }

            Button {
                onTapCTA()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "timer")
                        .font(.system(size: 15, weight: .bold))

                    Text(mode.ctaTitle)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .opacity(0.76)
                }
                .foregroundStyle(Color.white.opacity(0.97))
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.09),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 19, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                .scaleEffect(ctaPressed ? 0.988 : 1)
                .animation(.spring(response: 0.22, dampingFraction: 0.8), value: ctaPressed)
            }
            .buttonStyle(PressStateButtonStyle(isPressed: $ctaPressed))
        }
    }

    var modeDurationSubtitle: String {
        switch selectedPreset {
        case .short:
            return "Hızlı çalışma"
        case .medium:
            return "Derin odak"
        case .long:
            return "Yoğun akış"
        case .custom:
            return "Özel süre"
        }
    }

    var supportingLine: String {
        switch mode {
        case .personal:
            return "\(selectedGoal.title) • \(selectedStyle.title)"
        case .crew:
            return "\(focusSession.readyCount)/\(max(focusSession.participantCount, 3)) kişi hazır"
        case .friend:
            return "\(selectedGoal.title) • \(selectedStyle.title)"
        }
    }
}

private struct FocusHeroTheme {
    let topColor: Color
    let midColor: Color
    let bottomColor: Color
    let highlightColor: Color
    let secondaryGlow: Color
    let ringTint: Color
    let shadowColor: Color
    let badgeDotColor: Color

    static func forMode(_ mode: FocusMode) -> FocusHeroTheme {
        switch mode {
        case .personal:
            return FocusHeroTheme(
                topColor: Color(red: 0.20, green: 0.28, blue: 0.62),
                midColor: Color(red: 0.07, green: 0.15, blue: 0.40),
                bottomColor: Color(red: 0.02, green: 0.05, blue: 0.14),
                highlightColor: Color(red: 0.25, green: 0.48, blue: 0.92),
                secondaryGlow: Color(red: 0.15, green: 0.28, blue: 0.72),
                ringTint: Color(red: 0.86, green: 0.91, blue: 1.00),
                shadowColor: Color(red: 0.08, green: 0.18, blue: 0.55),
                badgeDotColor: Color(red: 0.74, green: 0.86, blue: 1.00)
            )
        case .crew:
            return FocusHeroTheme(
                topColor: Color(red: 0.56, green: 0.18, blue: 0.22),
                midColor: Color(red: 0.36, green: 0.06, blue: 0.10),
                bottomColor: Color(red: 0.12, green: 0.02, blue: 0.04),
                highlightColor: Color(red: 0.88, green: 0.28, blue: 0.34),
                secondaryGlow: Color(red: 0.58, green: 0.10, blue: 0.14),
                ringTint: Color(red: 1.00, green: 0.90, blue: 0.92),
                shadowColor: Color(red: 0.45, green: 0.06, blue: 0.10),
                badgeDotColor: Color(red: 1.00, green: 0.80, blue: 0.82)
            )
        case .friend:
            return FocusHeroTheme(
                topColor: Color(red: 0.42, green: 0.24, blue: 0.62),
                midColor: Color(red: 0.24, green: 0.10, blue: 0.38),
                bottomColor: Color(red: 0.08, green: 0.04, blue: 0.14),
                highlightColor: Color(red: 0.66, green: 0.36, blue: 0.88),
                secondaryGlow: Color(red: 0.38, green: 0.16, blue: 0.62),
                ringTint: Color(red: 0.95, green: 0.88, blue: 1.00),
                shadowColor: Color(red: 0.24, green: 0.10, blue: 0.42),
                badgeDotColor: Color(red: 0.92, green: 0.84, blue: 1.00)
            )
        }
    }
}
