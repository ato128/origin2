//
//  ActiveFocusView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 10.04.2026.
//

import SwiftUI

struct ActiveFocusView: View {
    @EnvironmentObject var focusSession: FocusSessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var appeared = false
    @State private var pulse = false
    @State private var showParticipantsSheet = false

    private var mode: FocusMode { focusSession.selectedMode }

    private var theme: ActiveFocusTheme {
        ActiveFocusTheme.forMode(mode)
    }

    private var participants: [FocusParticipant] {
        focusSession.currentSession?.participants ?? []
    }

    private var hostParticipant: FocusParticipant? {
        participants.first(where: { $0.isHost })
    }

    private var readyCount: Int {
        participants.filter { $0.isReady || $0.isActive }.count
    }

    private var visibleParticipants: [FocusParticipant] {
        Array(participants.prefix(3))
    }

    private var hiddenParticipantCount: Int {
        max(participants.count - visibleParticipants.count, 0)
    }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                topBar

                Spacer(minLength: 8)

                centerStage

                Spacer(minLength: mode == .personal ? 18 : 10)

                if mode == .personal {
                    personalSupport
                        .padding(.horizontal, 28)
                        .padding(.bottom, 12)
                } else {
                    minimalSharedPanel
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                }

                footerCaption
                    .padding(.horizontal, 28)
                    .padding(.bottom, 14)

                bottomControls
                    .padding(.horizontal, 20)
                    .padding(.bottom, 22)
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showParticipantsSheet) {
            participantsSheet
        }
        .onAppear {
            appeared = true
            pulse = true
        }
    }
}

// MARK: - Main Sections
private extension ActiveFocusView {
    var backgroundLayer: some View {
        ZStack {
            Color.black

            RadialGradient(
                colors: [
                    theme.primaryGlow.opacity(0.55),
                    Color.clear
                ],
                center: .center,
                startRadius: 80,
                endRadius: 420
            )
            .blur(radius: 60)

            RadialGradient(
                colors: [
                    theme.secondaryGlow.opacity(0.42),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 360
            )
            .blur(radius: 80)

            RadialGradient(
                colors: [
                    theme.coreGlow.opacity(0.32),
                    Color.clear
                ],
                center: .center,
                startRadius: 30,
                endRadius: 260
            )
            .blur(radius: 50)
        }
        .ignoresSafeArea()
    }

    var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(headerTitle)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.94))

                Text(durationHeaderText)
                    .font(.system(size: 29, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            HStack(spacing: 12) {
                circleIconButton(systemName: "minus") {
                    focusSession.minimizeSession()
                }

                circleIconButton(systemName: "xmark") {
                    focusSession.closeSession()
                    dismiss()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 58)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -8)
        .animation(.spring(response: 0.58, dampingFraction: 0.84), value: appeared)
    }

    var centerStage: some View {
        ZStack {
            Circle()
                .fill(theme.ringGlow.opacity(0.20))
                .frame(width: 304, height: 304)
                .blur(radius: 40)

            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 16)
                .frame(width: 304, height: 304)

            Circle()
                .trim(from: 0, to: ringTrimValue)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.98),
                            theme.ringTint.opacity(0.96),
                            Color.white.opacity(0.98)
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 304, height: 304)
                .shadow(color: theme.ringTint.opacity(0.18), radius: 14, x: 0, y: 0)
                .animation(.linear(duration: 1), value: focusSession.progress)

            Circle()
                .stroke(Color.white.opacity(0.03), lineWidth: 1)
                .frame(width: 258, height: 258)

            movingOrb

            VStack(spacing: 8) {
                Text(focusSession.timeString)
                    .font(.system(size: 45, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text(statusHeadline)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(Color.white.opacity(0.72))

                Text("Odak akışı devam ediyor")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.48))
            }
        }
        .scaleEffect(appeared ? 1 : 0.965)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.72, dampingFraction: 0.84), value: appeared)
    }

    var personalSupport: some View {
        VStack(spacing: 6) {
            Text(personalMainTitle)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.97))
                .multilineTextAlignment(.center)

            Text(personalMainSubtitle)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.58))
                .multilineTextAlignment(.center)
        }
    }

    var minimalSharedPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(sharedPanelTitle)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.97))

            sharedTopPills

            Button {
                showParticipantsSheet = true
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    participantPreviewHeader
                    participantPreviewRow
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    var footerCaption: some View {
        VStack(spacing: 6) {
            Text(footerTitle)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.94))
                .multilineTextAlignment(.center)

            Text(footerSubtitle)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.52))
                .multilineTextAlignment(.center)
        }
    }

    var bottomControls: some View {
        HStack(spacing: 14) {
            Button {
                focusSession.togglePause()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: focusSession.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 19, weight: .bold))

                    Text(focusSession.isPaused ? "Devam Et" : "Duraklat")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 66)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            Button {
                focusSession.closeSession()
                dismiss()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.76, green: 0.08, blue: 0.12),
                                    Color(red: 0.50, green: 0.03, blue: 0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )

                    Image(systemName: "stop.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 84, height: 66)
            }
            .buttonStyle(.plain)
        }
    }

    var participantsSheet: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Katılımcılar")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)

                        ForEach(participants) { participant in
                            participantSheetRow(participant)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Derived Values
private extension ActiveFocusView {
    var durationHeaderText: String {
        "\(focusSession.durationMinutes) dk"
    }

    var ringTrimValue: Double {
        max(focusSession.progress, 0.01)
    }

    var hostNameText: String {
        hostParticipant?.name ?? "Atakan"
    }

    var readyCountText: String {
        "\(readyCount)/\(max(participants.count, 1))"
    }

    var headerTitle: String {
        switch mode {
        case .personal: return "Kişisel Focus"
        case .crew: return "Crew Focus"
        case .friend: return "Friend Focus"
        }
    }

    var statusHeadline: String {
        if focusSession.isPaused { return "DURAKLATILDI" }

        switch mode {
        case .personal:
            return "HAZIR"
        case .crew:
            return "TAKIM HAZIR"
        case .friend:
            return "EŞLEŞTİ"
        }
    }

    var personalMainTitle: String {
        switch focusSession.selectedGoal {
        case .study: return "Study focus in progress"
        case .deepWork: return "Deep focus in progress"
        case .reading: return "Reading flow in progress"
        case .planning: return "Planning session in progress"
        case .workout: return "Workout flow in progress"
        }
    }

    var personalMainSubtitle: String {
        switch focusSession.selectedGoal {
        case .study: return "Ders odağını koru ve ritmini sürdür"
        case .deepWork: return "Derin odakta kalmaya devam et"
        case .reading: return "Okuma ritmini bölmeden devam et"
        case .planning: return "Planını sakin biçimde ilerlet"
        case .workout: return "Akışı bozmadan devam et"
        }
    }

    var sharedPanelTitle: String {
        switch mode {
        case .crew: return "Crew ile ortak odak"
        case .friend: return "Birlikte odaklanıyorsunuz"
        case .personal: return ""
        }
    }

    var sharedMembersTitle: String {
        switch mode {
        case .crew: return "Katılımcılar"
        case .friend: return "Eşleşme"
        case .personal: return ""
        }
    }

    var footerTitle: String {
        switch mode {
        case .personal:
            switch focusSession.selectedGoal {
            case .study: return "Study session in progress"
            case .deepWork: return "Deep focus in progress"
            case .reading: return "Reading flow in progress"
            case .planning: return "Planning session in progress"
            case .workout: return "Workout flow in progress"
            }
        case .crew:
            return "Crew session in sync"
        case .friend:
            return "Shared focus in progress"
        }
    }

    var footerSubtitle: String {
        switch mode {
        case .personal:
            return "Odağı koru ve akışı bozmadan devam et"
        case .crew:
            return "Host, hazır katılımcılar ve ortak süre aynı akışta"
        case .friend:
            return "Eşleşme aktif, ritmi birlikte sürdürün"
        }
    }
}

// MARK: - Small Components
private extension ActiveFocusView {
    func circleIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )

                Image(systemName: systemName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.96))
            }
            .frame(width: 58, height: 58)
        }
        .buttonStyle(.plain)
    }

    var movingOrb: some View {
        let orbitRadius: CGFloat = 152
        let angle = Angle.degrees(-90 + ringTrimValue * 360)

        return Circle()
            .fill(theme.ringTint)
            .frame(width: 28, height: 28)
            .shadow(color: Color.white.opacity(0.18), radius: 12, x: 0, y: 0)
            .overlay(
                Circle()
                    .fill(Color.white.opacity(0.16))
                    .blur(radius: 10)
            )
            .offset(
                x: CGFloat(cos(angle.radians)) * orbitRadius,
                y: CGFloat(sin(angle.radians)) * orbitRadius
            )
            .animation(.linear(duration: 1), value: focusSession.progress)
    }

    var sharedTopPills: some View {
        HStack(spacing: 8) {
            infoPill(
                icon: "person.crop.circle",
                title: "Host",
                value: hostNameText
            )

            infoPill(
                icon: "checkmark.circle.fill",
                title: "Hazır",
                value: readyCountText
            )
        }
    }

    var participantPreviewHeader: some View {
        HStack {
            Text(sharedMembersTitle)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.88))

            Spacer()

            HStack(spacing: 6) {
                if hiddenParticipantCount > 0 {
                    Text("+\(hiddenParticipantCount)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.82))
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.40))
            }
        }
    }

    var participantPreviewRow: some View {
        HStack(spacing: 8) {
            ForEach(visibleParticipants) { participant in
                compactParticipantPill(participant)
            }
        }
    }

    func infoPill(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.9))

            VStack(alignment: .leading, spacing: 0) {
                Text(title.uppercased())
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(Color.white.opacity(0.48))

                Text(value)
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 42)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    func compactParticipantPill(_ participant: FocusParticipant) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(participantColor(participant).opacity(0.20))
                        .frame(width: 28, height: 28)

                    Circle()
                        .fill(participantColor(participant))
                        .frame(width: 10, height: 10)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(participant.name)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.96))
                        .lineLimit(1)

                    Text(participantRole(participant))
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(1.6)
                        .foregroundStyle(Color.white.opacity(0.45))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            Text(participantSubtitle(participant))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.58))
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    func participantSheetRow(_ participant: FocusParticipant) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(participantColor(participant).opacity(0.20))
                    .frame(width: 40, height: 40)

                Circle()
                    .fill(participantColor(participant))
                    .frame(width: 12, height: 12)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(participant.name)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text(participantSubtitle(participant))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.62))
            }

            Spacer()

            Text(participantRole(participant))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(Color.white.opacity(0.55))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Participant Helpers
private extension ActiveFocusView {
    func participantColor(_ participant: FocusParticipant) -> Color {
        if participant.isActive {
            return .green
        } else if participant.isReady {
            return .yellow
        } else {
            return .gray.opacity(0.85)
        }
    }

    func participantRole(_ participant: FocusParticipant) -> String {
        if participant.isHost { return "HOST" }
        if participant.isActive { return "AKTİF" }
        if participant.isReady { return "HAZIR" }
        return "BEKLİYOR"
    }

    func participantSubtitle(_ participant: FocusParticipant) -> String {
        if participant.isHost { return "Oturumu yönetiyor" }
        if participant.isActive { return "Şu an odakta" }
        if participant.isReady { return "Başlamaya hazır" }
        return "Henüz bağlanmadı"
    }
}

// MARK: - Theme
private struct ActiveFocusTheme {
    let backgroundMid: Color
    let primaryGlow: Color
    let secondaryGlow: Color
    let coreGlow: Color
    let ringGlow: Color
    let ringTint: Color

    static func forMode(_ mode: FocusMode) -> ActiveFocusTheme {
        switch mode {
        case .personal:
            return ActiveFocusTheme(
                backgroundMid: Color(red: 0.01, green: 0.03, blue: 0.10),
                primaryGlow: Color(red: 0.22, green: 0.42, blue: 1.00),
                secondaryGlow: Color(red: 0.16, green: 0.26, blue: 0.84),
                coreGlow: Color(red: 0.14, green: 0.30, blue: 0.92),
                ringGlow: Color(red: 0.44, green: 0.62, blue: 1.00),
                ringTint: Color(red: 0.92, green: 0.96, blue: 1.00)
            )
        case .crew:
            return ActiveFocusTheme(
                backgroundMid: Color(red: 0.08, green: 0.01, blue: 0.03),
                primaryGlow: Color(red: 0.84, green: 0.16, blue: 0.24),
                secondaryGlow: Color(red: 1.00, green: 0.40, blue: 0.44),
                coreGlow: Color(red: 0.78, green: 0.12, blue: 0.18),
                ringGlow: Color(red: 1.00, green: 0.46, blue: 0.50),
                ringTint: Color(red: 1.00, green: 0.92, blue: 0.94)
            )
        case .friend:
            return ActiveFocusTheme(
                backgroundMid: Color(red: 0.05, green: 0.02, blue: 0.10),
                primaryGlow: Color(red: 0.54, green: 0.22, blue: 0.92),
                secondaryGlow: Color(red: 0.84, green: 0.52, blue: 1.00),
                coreGlow: Color(red: 0.48, green: 0.18, blue: 0.84),
                ringGlow: Color(red: 0.88, green: 0.56, blue: 1.00),
                ringTint: Color(red: 0.97, green: 0.91, blue: 1.00)
            )
        }
    }
}
