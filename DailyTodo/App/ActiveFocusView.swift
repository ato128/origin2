//
//  ActiveFocusView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 10.04.2026.
//

import SwiftUI
import AudioToolbox
import Combine

struct ActiveFocusView: View {
    @EnvironmentObject var focusSession: FocusSessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var appeared = false
    @State private var pulse = false
    @State private var ringBreathing = false

    private var theme: FocusHeroTheme {
        FocusHeroTheme.forMode(focusSession.selectedMode)
    }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                topBar

                Spacer()

                centerRing

                Spacer()

                participantSection
                bottomInfo
                controls
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 34)

            if let summary = focusSession.completionSummary {
                completionOverlay(summary: summary)
            }
        }
        .onAppear {
            appeared = true
            pulse = true
            ringBreathing = true
            playSoftTapSound()
            hapticSoft()
        }
    }
}

private extension ActiveFocusView {
    var sessionLabel: String {
        switch focusSession.selectedMode {
        case .personal:
            return "Kişisel Focus"
        case .crew:
            return "Crew Focus"
        case .friend:
            return "Friend Focus"
        }
    }

    var durationTitle: String {
        "\(focusSession.durationMinutes) dk"
    }

    var bottomStatusText: String {
        if focusSession.isPaused {
            return "Oturum duraklatıldı"
        }
        return "Odak akışı devam ediyor"
    }

    var supportText: String {
        switch focusSession.selectedMode {
        case .personal:
            return "Derin odakta kalmaya devam et"
        case .crew:
            return "Host, hazır katılımcılar ve ortak süre aynı akışta"
        case .friend:
            return "Eşleşme aktif, ritmi birlikte sürdürün"
        }
    }

    var participantSection: some View {
        Group {
            if focusSession.selectedMode != .personal,
               let session = focusSession.currentSession {
                VStack(alignment: .leading, spacing: 14) {
                    sessionContextHeader(session: session)

                    HStack(spacing: 10) {
                        sessionPill(
                            title: "Host",
                            value: focusSession.hostName ?? "Atakan",
                            icon: "person.crop.circle.fill"
                        )

                        sessionPill(
                            title: "Hazır",
                            value: "\(focusSession.readyCount)/\(max(focusSession.participantCount, 1))",
                            icon: "checkmark.circle.fill"
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(focusSession.selectedMode == .crew ? "Katılımcılar" : "Eşleşme")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.58))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(session.participants) { participant in
                                    participantChip(participant)
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                )
                .padding(.bottom, 18)
            }
        }
    }
    
    func sessionContextHeader(session: FocusSessionState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sessionContextTitle)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.96))

            Text(sessionContextSubtitle)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.68))
                .lineLimit(2)
        }
    }

    func sessionPill(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.88))

            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.48))
                    .tracking(1.0)

                Text(value)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.92))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    func participantChip(_ participant: FocusParticipant) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(participantStatusColor(participant))
                    .frame(width: 8, height: 8)

                if participant.isHost {
                    Text("HOST")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.52))
                        .tracking(1)
                } else {
                    Text(participant.isActive ? "AKTİF" : (participant.isReady ? "HAZIR" : "BEKLİYOR"))
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.52))
                        .tracking(1)
                }
            }

            Text(participant.name)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.96))
                .lineLimit(1)

            Text(participantStatusText(participant))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.64))
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 132)
        .frame(minHeight: 88, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    func participantStatusColor(_ participant: FocusParticipant) -> Color {
        if participant.isActive {
            return .green
        } else if participant.isReady {
            return .yellow
        } else {
            return .gray.opacity(0.8)
        }
    }

    func participantStatusText(_ participant: FocusParticipant) -> String {
        if participant.isHost {
            return "Oturumu yönetiyor"
        } else if participant.isActive {
            return "Şu an odakta"
        } else if participant.isReady {
            return "Başlamaya hazır"
        } else {
            return "Henüz hazır değil"
        }
    }
    
    var sessionContextTitle: String {
        switch focusSession.selectedMode {
        case .personal:
            return "Kişisel odak"
        case .crew:
            return "Crew ile ortak odak"
        case .friend:
            return "Birlikte odaklanıyorsunuz"
        }
    }

    var sessionContextSubtitle: String {
        switch focusSession.selectedMode {
        case .personal:
            return "Sessiz akış devam ediyor"
        case .crew:
            if let host = focusSession.hostName {
                return "\(host) host olarak oturumu yürütüyor. Ekip senkron halde devam ediyor."
            }
            return "Ekip odak akışı devam ediyor"
        case .friend:
            return "Eşleşmiş focus aktif. Birlikte ritmi koruyun."
        }
    }
    
    func completionOverlay(summary: FocusCompletionSummary) -> some View {
        ZStack {
            Color.black.opacity(0.50)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(completionAccent.opacity(0.18))
                        .frame(width: 120, height: 120)
                        .blur(radius: 24)

                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 86, height: 86)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )

                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundStyle(Color.white.opacity(0.96))
                }
                .padding(.top, 6)

                VStack(spacing: 8) {
                    Text(completionTitle(for: summary))
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.center)

                    Text(completionSubtitle(for: summary))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.74))
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 10) {
                    completionMetricCard(
                        title: "Bugün",
                        value: "\(summary.totalTodayMinutes) dk"
                    )

                    completionMetricCard(
                        title: "Seri",
                        value: "\(summary.streakDays) gün"
                    )

                    completionMetricCard(
                        title: "Oturum",
                        value: "\(summary.completedSessionsToday)"
                    )
                }

                VStack(spacing: 10) {
                    completionInfoRow(
                        title: "Goal",
                        value: summary.goal.title,
                        icon: summary.goal.icon
                    )

                    completionInfoRow(
                        title: "Sound",
                        value: summary.style.title,
                        icon: summary.style.icon
                    )

                    if summary.mode != .personal {
                        completionInfoRow(
                            title: "Katılımcı",
                            value: "\(max(summary.participantCount, 2)) kişi",
                            icon: "person.2.fill"
                        )
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        hapticMedium()
                        playSoftTapSound()
                        focusSession.restartLastFinishedSession()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .bold))

                            Text("Bir Session Daha")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            completionAccent.opacity(0.95),
                                            completionAccent.opacity(0.72)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        hapticSoft()
                        playSoftTapSound()
                        focusSession.dismissCompletionSummary()
                        dismiss()
                    } label: {
                        Text("Kapat")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.95))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(22)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color.black.opacity(0.72))

                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.22))

                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.05),
                                    Color.clear,
                                    Color.black.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            )
            .shadow(color: .black.opacity(0.24), radius: 22, x: 0, y: 14)
            .padding(.horizontal, 22)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    func completionMetricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.52))
                .tracking(1)

            Text(value)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.97))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    func completionInfoRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.08))

                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.9))
            }
            .frame(width: 28, height: 28)

            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.58))

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.94))
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    var completionAccent: Color {
        switch focusSession.selectedMode {
        case .personal:
            return Color.blue
        case .crew:
            return Color.red
        case .friend:
            return Color.purple
        }
    }

    func completionTitle(for summary: FocusCompletionSummary) -> String {
        switch summary.mode {
        case .personal:
            return "Harika iş çıkardın"
        case .crew:
            return "Crew session tamamlandı"
        case .friend:
            return "Ortak odak tamamlandı"
        }
    }

    func completionSubtitle(for summary: FocusCompletionSummary) -> String {
        switch summary.mode {
        case .personal:
            return "\(summary.durationMinutes) dakikalık \(summary.goal.title) oturumu başarıyla bitti."
        case .crew:
            return "\(summary.durationMinutes) dakikalık ekip focus oturumu tamamlandı. Katılımcılar ortak ritmi korudu."
        case .friend:
            return "\(summary.durationMinutes) dakikalık eşleşmiş focus tamamlandı. Birlikte odak akışı başarıyla sürdü."
        }
    }
    func infoPill(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))

            Text(value)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}

private extension ActiveFocusView {
    var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(sessionLabel)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.82))

                Text(durationTitle)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.98))
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    hapticSoft()
                    playSoftTapSound()
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        focusSession.minimizeSession()
                    }
                    dismiss()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)

                Button {
                    hapticMedium()
                    playSoftTapSound()
                    focusSession.closeSession()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    var centerRing: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.18))
                .frame(width: 288, height: 288)
                .blur(radius: 26)

            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 18)

            Circle()
                .trim(from: 0, to: focusSession.progress)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.98),
                            theme.ringTint.opacity(0.90)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: theme.ringTint.opacity(0.18), radius: 12, x: 0, y: 0)
                .animation(.easeInOut(duration: 0.5), value: focusSession.progress)

            Circle()
                .stroke(Color.white.opacity(0.025), lineWidth: 1)
                .padding(11)

            VStack(spacing: 6) {
                Text(focusSession.timeString)
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.99))
                    .contentTransition(.numericText())

                Text(focusSession.selectedMode.statusText.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.60))
                    .tracking(1.3)

                Text(bottomStatusText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.42))
                    .padding(.top, 2)
            }
        }
        .frame(width: 270, height: 270)
        .scaleEffect(ringBreathing && !focusSession.isPaused ? 1.018 : 1.0)
        .animation(
            !focusSession.isPaused
            ? .easeInOut(duration: 3.2).repeatForever(autoreverses: true)
            : .easeOut(duration: 0.25),
            value: ringBreathing
        )
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.94)
        .animation(.spring(response: 0.8, dampingFraction: 0.86), value: appeared)
    }

    var bottomInfo: some View {
        VStack(spacing: 8) {
            Text(primaryBottomTitle)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.92))

            Text(supportText)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.56))
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 22)
    }
    
    var primaryBottomTitle: String {
        if focusSession.isPaused {
            return "Session paused"
        }

        switch focusSession.selectedMode {
        case .personal:
            return "Deep focus in progress"
        case .crew:
            return "Crew session in sync"
        case .friend:
            return "Shared focus in progress"
        }
    }
    var controls: some View {
        HStack(spacing: 20) {
            Button {
                focusSession.togglePause()
                hapticMedium()
                playSoftTapSound()

                if !focusSession.isPaused {
                    ringBreathing = true
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: focusSession.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 16, weight: .bold))

                    Text(focusSession.isPaused ? "Devam Et" : "Duraklat")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(Color.white.opacity(0.96))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            Button {
                hapticWarning()
                playEndTapSound()
                focusSession.closeSession()
                dismiss()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .frame(width: 54, height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.red.opacity(0.18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }

    var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    theme.bottomColor,
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(theme.highlightColor.opacity(pulse ? 0.18 : 0.10))
                .frame(width: 320, height: 320)
                .blur(radius: 84)
                .offset(x: 70, y: -120)
                .animation(.easeInOut(duration: 4.4).repeatForever(autoreverses: true), value: pulse)

            Circle()
                .fill(theme.secondaryGlow.opacity(pulse ? 0.14 : 0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: -110, y: 220)
                .animation(.easeInOut(duration: 5.6).repeatForever(autoreverses: true), value: pulse)

            Ellipse()
                .fill(Color.black.opacity(0.24))
                .frame(width: 320, height: 180)
                .blur(radius: 34)
                .offset(y: 120)
        }
    }

    func hapticSoft() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()
    }

    func hapticMedium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    func hapticWarning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    func playSoftTapSound() {
        AudioServicesPlaySystemSound(1104)
    }

    func playEndTapSound() {
        AudioServicesPlaySystemSound(1155)
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
