//
//  ActiveFocusView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 10.04.2026.
//

import SwiftUI

struct ActiveFocusView: View {
    @EnvironmentObject var focusSession: FocusSessionManager

    @State private var pulse = false
    @State private var showParticipantsExpanded = false

    private var mode: FocusMode {
        focusSession.currentSession?.mode ?? .personal
    }

    private var participants: [FocusParticipant] {
        focusSession.currentSession?.participants ?? []
    }

    private var hostParticipant: FocusParticipant? {
        participants.first(where: { $0.isHost })
    }

    private var visibleParticipants: [FocusParticipant] {
        Array(participants.prefix(mode == .crew ? 4 : 2))
    }

    private var readyCount: Int {
        participants.filter { $0.isReady || $0.isActive }.count
    }

    private var theme: ActiveFocusTheme {
        .forMode(mode)
    }

    private var titleText: String {
        switch mode {
        case .personal:
            return tr("af_personal_focus")
        case .crew:
            return "Crew Focus"
        case .friend:
            return tr("af_friend_focus")
        }
    }

    private var titleAccent: String {
        switch mode {
        case .personal:
            return "zone"
        case .crew:
            return "crew"
        case .friend:
            return "duo"
        }
    }

    private var durationText: String {
        "\(focusSession.durationMinutes) dk"
    }

    private var statusTitle: String {
        if focusSession.isPaused {
            return "DURAKLATILDI"
        }

        switch mode {
        case .personal:
            return "LIVE"
        case .crew:
            return "CREW LIVE"
        case .friend:
            return "DUO LIVE"
        }
    }

    private var subtitleText: String {
        if focusSession.isPaused {
            return tr("af_flow_waiting")
        }

        return tr("af_flow_going")
    }

    private var bottomHeadline: String {
        switch mode {
        case .personal:
            return "\(focusSession.selectedGoal.title) focus in progress"
        case .crew:
            return "Crew session in sync"
        case .friend:
            return "Shared focus in progress"
        }
    }

    private var bottomSubtitle: String {
        switch mode {
        case .personal:
            return focusSession.selectedGoal.subtitle
        case .crew:
            return tr("af_host_sub")
        case .friend:
            return tr("af_match_sub")
        }
    }

    var body: some View {
        GeometryReader { geo in
            let topInset = geo.safeAreaInsets.top
            let bottomInset = geo.safeAreaInsets.bottom

            ZStack {
                backgroundLayer

                VStack(spacing: 0) {
                    topBar(topInset: topInset)

                    Spacer(minLength: 8)

                    centerStage
                        .frame(maxWidth: .infinity)

                    Spacer(minLength: 14)

                    bottomSection(bottomInset: bottomInset)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard PerformanceSettings.enableSlowAmbientAnimations else {
                pulse = false
                return
            }

            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .onDisappear {
            pulse = false
        }
    }
}

private extension ActiveFocusView {

    var ringSize: CGFloat { 292 }
    var ringLineWidth: CGFloat { 16 }

    var stablePulseCoreOpacity: Double {
        PerformanceSettings.enableSlowAmbientAnimations
        ? (pulse ? 0.24 : 0.17)
        : 0.20
    }

    var stablePulseInnerOpacity: Double {
        PerformanceSettings.enableSlowAmbientAnimations
        ? (pulse ? 0.18 : 0.11)
        : 0.14
    }

    var stableTopGlowOpacity: Double {
        PerformanceSettings.enableSlowAmbientAnimations
        ? (pulse ? 0.26 : 0.18)
        : 0.21
    }

    var stableBottomGlowOpacity: Double {
        PerformanceSettings.enableSlowAmbientAnimations
        ? (pulse ? 0.18 : 0.12)
        : 0.14
    }

    // MARK: - Top Bar

    func topBar(topInset: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(theme.accent)
                        .frame(width: 20, height: 1)

                    Text(statusTitle)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(2.0)
                        .foregroundStyle(theme.accent)
                }

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(titleText)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(titleAccent)
                        .font(.system(size: 23, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(theme.accent)
                }

                Text(durationText)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.46))
            }

            Spacer()

            HStack(spacing: 10) {
                topCircleButton(icon: "minus") {
                    focusSession.minimizeSession()
                }

                topCircleButton(icon: "xmark") {
                    focusSession.closeSession()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, max(topInset, 16) + 8)
    }

    func topCircleButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(.white.opacity(0.94))
                .frame(width: 52, height: 52)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.095),
                                    Color.black.opacity(0.24),
                                    Color.white.opacity(0.045)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.11), lineWidth: 1)
                        )
                        .shadow(
                            color: Color.black.opacity(0.24),
                            radius: PerformanceSettings.cardShadowRadius,
                            y: 6
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Center Stage

    var centerStage: some View {
        ZStack {
            Circle()
                .fill(theme.coreGlow.opacity(stablePulseCoreOpacity * PerformanceSettings.radialOpacityMultiplier))
                .frame(width: 360, height: 360)
                .blur(radius: PerformanceSettings.enableHeavyBlurEffects ? 70 : 34)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            theme.innerGlow.opacity(stablePulseInnerOpacity * PerformanceSettings.radialOpacityMultiplier),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 12,
                        endRadius: 170
                    )
                )
                .frame(width: 308, height: 308)
                .blur(radius: PerformanceSettings.enableHeavyBlurEffects ? 26 : 14)

            Circle()
                .stroke(Color.white.opacity(0.065), lineWidth: ringLineWidth)
                .frame(width: ringSize, height: ringSize)

            Circle()
                .trim(from: 0, to: max(focusSession.progress, 0.001))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            theme.accent.opacity(0.98),
                            theme.secondaryAccent.opacity(0.95),
                            theme.accent.opacity(0.98)
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: ringSize, height: ringSize)
                .shadow(
                    color: theme.accent.opacity(0.18),
                    radius: PerformanceSettings.glowShadowRadius
                )
                .opacity(focusSession.isPaused ? 0.42 : 1)

            Circle()
                .stroke(Color.white.opacity(0.040), lineWidth: 1.1)
                .frame(width: ringSize - 36, height: ringSize - 36)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            theme.accent.opacity(0.085 * PerformanceSettings.radialOpacityMultiplier),
                            Color.white.opacity(0.018)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: ringSize - 56, height: ringSize - 56)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.045), lineWidth: 1)
                )

            VStack(spacing: 10) {
                Text(focusSession.timeString)
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.16), value: focusSession.timeString)

                Text(statusTitle)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(theme.accent)

                Text(subtitleText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.46))
            }
        }
        .frame(height: 360)
    }

    // MARK: - Bottom Section

    func bottomSection(bottomInset: CGFloat) -> some View {
        VStack(spacing: 14) {
            if mode != .personal {
                compactSharedPanel
                    .padding(.horizontal, 20)
            }

            VStack(spacing: 7) {
                Text(bottomHeadline)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white.opacity(0.96))
                    .multilineTextAlignment(.center)

                Text(bottomSubtitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.46))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            controls
                .padding(.horizontal, 20)
        }
        .padding(.top, 10)
        .padding(.bottom, max(bottomInset, 12) + 8)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.00),
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.38)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Shared Panel

    var compactSharedPanel: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(theme.accent)
                            .frame(width: 16, height: 1)

                        Text(mode == .crew ? "CREW SYNC" : "DUO SYNC")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.6)
                            .foregroundStyle(theme.accent)
                    }

                    Text(sharedPanelTitle)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.white.opacity(0.95))

                    Text(sharedPanelSubtitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.50))
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        showParticipantsExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(showParticipantsExpanded ? "DARALT" : "DETAY")
                            .font(.system(size: 9, weight: .black, design: .monospaced))

                        Image(systemName: showParticipantsExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .black))
                    }
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(
                        Capsule(style: .continuous)
                            .fill(theme.accent.opacity(0.12))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(theme.accent.opacity(0.18), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                compactPill(
                    icon: "person.crop.circle",
                    title: "Host",
                    value: hostParticipant?.name ?? "Atakan"
                )

                compactPill(
                    icon: "checkmark.circle.fill",
                    title: tr("hf_ready"),
                    value: "\(readyCount)/\(max(participants.count, 1))"
                )
            }

            participantPreviewRow

            if showParticipantsExpanded {
                expandedParticipantsGrid
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            theme.accent.opacity(0.070),
                            theme.secondaryAccent.opacity(0.040),
                            Color.white.opacity(0.035)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(theme.accent.opacity(0.14), lineWidth: 1)
                )
                .shadow(
                    color: Color.black.opacity(0.20),
                    radius: PerformanceSettings.cardShadowRadius,
                    y: 6
                )
        )
    }

    var participantPreviewRow: some View {
        HStack(spacing: 8) {
            ForEach(visibleParticipants) { participant in
                compactParticipantChip(participant)
            }

            if participants.count > visibleParticipants.count {
                Button {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
                        showParticipantsExpanded = true
                    }
                } label: {
                    Text("+\(participants.count - visibleParticipants.count)")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.92))
                        .frame(width: 52, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.045))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.075), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    func compactParticipantChip(_ participant: FocusParticipant) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(participantsStatusColor(participant))
                .frame(width: 10, height: 10)

            Text(participant.name)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 52)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.065), lineWidth: 1)
                )
        )
    }

    var expandedParticipantsGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(participants) { participant in
                HStack(spacing: 10) {
                    Circle()
                        .fill(participantsStatusColor(participant))
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(participant.name)
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(.white.opacity(0.95))

                        Text(participantStatusText(participant))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.48))
                    }

                    Spacer()

                    tagCapsule(participantRoleText(participant))
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.038))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.060), lineWidth: 1)
                        )
                )
            }
        }
    }

    func tagCapsule(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .tracking(0.7)
            .foregroundStyle(theme.accent)
            .padding(.horizontal, 10)
            .frame(height: 22)
            .background(
                Capsule(style: .continuous)
                    .fill(theme.accent.opacity(0.12))
            )
    }

    func compactPill(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(theme.accent)

            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.38))

                Text(value)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.accent.opacity(0.070))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(theme.accent.opacity(0.12), lineWidth: 1)
                )
        )
    }

    // MARK: - Controls

    var controls: some View {
        HStack(spacing: 14) {
            Button {
                focusSession.togglePause()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: focusSession.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 17, weight: .black))

                    Text(focusSession.isPaused ? "Devam Et" : "Duraklat")
                        .font(.system(size: 17, weight: .black))
                }
                .foregroundStyle(.white.opacity(0.96))
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.070),
                                    Color.white.opacity(0.040)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.085), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            Button {
                focusSession.closeSession()
            } label: {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(arenaHex: AppArenaPalette.coral),
                                Color.red.opacity(0.78)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 92, height: 64)
                    .overlay(
                        Image(systemName: "stop.fill")
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(.white)
                    )
                    .shadow(
                        color: Color(arenaHex: AppArenaPalette.coral).opacity(0.18),
                        radius: PerformanceSettings.glowShadowRadius,
                        y: 6
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Participant Logic

    func participantsStatusColor(_ participant: FocusParticipant) -> Color {
        if participant.isHost || participant.isActive {
            return Color(arenaHex: AppArenaPalette.green)
        }

        if participant.isReady {
            return Color(arenaHex: AppArenaPalette.gold)
        }

        return .gray.opacity(0.8)
    }

    func participantStatusText(_ participant: FocusParticipant) -> String {
        if participant.isHost { return tr("af_managing") }
        if participant.isActive { return tr("af_focusing_now") }
        if participant.isReady { return tr("af_ready_start") }
        return tr("af_not_connected")
    }

    func participantRoleText(_ participant: FocusParticipant) -> String {
        if participant.isHost { return "HOST" }
        if participant.isActive { return tr("af_active_caps") }
        if participant.isReady { return "HAZIR" }
        return tr("ch_pending_caps")
    }

    var sharedPanelTitle: String {
        switch mode {
        case .crew:
            return "Crew ile ortak odak"
        case .friend:
            return tr("af_focusing_together")
        case .personal:
            return ""
        }
    }

    var sharedPanelSubtitle: String {
        switch mode {
        case .crew:
            let host = hostParticipant?.name ?? "Atakan"
            return tr("af_host_running", host)
        case .friend:
            return tr("af_matched_active")
        case .personal:
            return ""
        }
    }

    // MARK: - Background

    var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    theme.backgroundMid,
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(theme.topGlow.opacity(stableTopGlowOpacity * PerformanceSettings.radialOpacityMultiplier))
                .frame(width: 360, height: 360)
                .blur(radius: PerformanceSettings.enableHeavyBlurEffects ? 95 : 42)
                .offset(x: 110, y: -170)

            Circle()
                .fill(theme.bottomGlow.opacity(stableBottomGlowOpacity * PerformanceSettings.radialOpacityMultiplier))
                .frame(width: 320, height: 320)
                .blur(radius: PerformanceSettings.enableHeavyBlurEffects ? 112 : 48)
                .offset(x: -120, y: 330)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.14),
                    Color.clear,
                    Color.black.opacity(0.32)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

private struct ActiveFocusTheme {
    let backgroundMid: Color
    let topGlow: Color
    let bottomGlow: Color
    let coreGlow: Color
    let innerGlow: Color
    let accent: Color
    let secondaryAccent: Color

    static func forMode(_ mode: FocusMode) -> ActiveFocusTheme {
        switch mode {
        case .personal:
            return .init(
                backgroundMid: Color(arenaHex: "#050814"),
                topGlow: Color(arenaHex: AppArenaPalette.cyan),
                bottomGlow: Color(arenaHex: AppArenaPalette.purple),
                coreGlow: Color(arenaHex: AppArenaPalette.cyan),
                innerGlow: Color(arenaHex: AppArenaPalette.blue),
                accent: Color(arenaHex: AppArenaPalette.cyan),
                secondaryAccent: Color(arenaHex: AppArenaPalette.purple)
            )

        case .crew:
            return .init(
                backgroundMid: Color(arenaHex: "#11060A"),
                topGlow: Color(arenaHex: AppArenaPalette.coral),
                bottomGlow: Color(arenaHex: AppArenaPalette.gold),
                coreGlow: Color(arenaHex: AppArenaPalette.coral),
                innerGlow: Color(arenaHex: AppArenaPalette.coral),
                accent: Color(arenaHex: AppArenaPalette.coral),
                secondaryAccent: Color(arenaHex: AppArenaPalette.gold)
            )

        case .friend:
            return .init(
                backgroundMid: Color(arenaHex: "#090614"),
                topGlow: Color(arenaHex: AppArenaPalette.purple),
                bottomGlow: Color(arenaHex: AppArenaPalette.blue),
                coreGlow: Color(arenaHex: AppArenaPalette.purple),
                innerGlow: Color(arenaHex: AppArenaPalette.purple),
                accent: Color(arenaHex: AppArenaPalette.purple),
                secondaryAccent: Color(arenaHex: AppArenaPalette.blue)
            )
        }
    }
}
