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
        case .personal: return "Kişisel Focus"
        case .crew: return "Crew Focus"
        case .friend: return "Friend Focus"
        }
    }

    private var durationText: String {
        "\(focusSession.durationMinutes) dk"
    }

    private var statusTitle: String {
        if focusSession.isPaused { return "DURAKLATILDI" }

        switch mode {
        case .personal: return "HAZIR"
        case .crew: return "TAKIM HAZIR"
        case .friend: return "EŞLEŞTİ"
        }
    }

    private var subtitleText: String {
        if focusSession.isPaused { return "Focus akışı beklemede" }
        return "Odak akışı devam ediyor"
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
            return "Host, hazır katılımcılar ve ortak süre aynı akışta"
        case .friend:
            return "Eşleşme aktif, ritmi birlikte sürdürün"
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

                    Spacer(minLength: 16)

                    bottomSection(bottomInset: bottomInset)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .ignoresSafeArea()
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private extension ActiveFocusView {
    var ringSize: CGFloat { 292 }
    var ringLineWidth: CGFloat { 16 }

    func topBar(topInset: CGFloat) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.96))

                Text(durationText)
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            HStack(spacing: 12) {
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
            Circle()
                .fill(Color.white.opacity(0.05))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color.white.opacity(0.96))
                )
        }
        .buttonStyle(.plain)
    }

    var centerStage: some View {
        ZStack {
            Circle()
                .fill(theme.coreGlow.opacity(pulse ? 0.30 : 0.22))
                .frame(width: 360, height: 360)
                .blur(radius: 64)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            theme.innerGlow.opacity(pulse ? 0.24 : 0.15),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 12,
                        endRadius: 170
                    )
                )
                .frame(width: 308, height: 308)
                .blur(radius: 24)

            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: ringLineWidth)
                .frame(width: ringSize, height: ringSize)

            Circle()
                .trim(from: 0, to: max(focusSession.progress, 0.001))
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.98),
                            Color.white.opacity(0.90),
                            Color.white.opacity(0.82)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: ringSize, height: ringSize)
                .shadow(color: Color.white.opacity(0.10), radius: 8, x: 0, y: 0)
                .opacity(focusSession.isPaused ? 0.42 : 1)

            Circle()
                .stroke(Color.white.opacity(0.045), lineWidth: 1.1)
                .frame(width: ringSize - 36, height: ringSize - 36)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.04),
                            Color.white.opacity(0.015)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: ringSize - 56, height: ringSize - 56)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )

            

            VStack(spacing: 10) {
                Text(focusSession.timeString)
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.18), value: focusSession.timeString)

                Text(statusTitle)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(2.4)
                    .foregroundStyle(Color.white.opacity(0.72))

                Text(subtitleText)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.48))
            }
        }
        .frame(height: 360)
    }

   

    func bottomSection(bottomInset: CGFloat) -> some View {
        VStack(spacing: 14) {
            if mode != .personal {
                compactSharedPanel
                    .padding(.horizontal, 20)
            }

            VStack(spacing: 6) {
                Text(bottomHeadline)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .multilineTextAlignment(.center)

                Text(bottomSubtitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.46))
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
                    Color.black.opacity(0.34)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    var compactSharedPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sharedPanelTitle)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.95))

                    Text(sharedPanelSubtitle)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.56))
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        showParticipantsExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(showParticipantsExpanded ? "Daralt" : "Detay")
                            .font(.system(size: 11, weight: .bold, design: .rounded))

                        Image(systemName: showParticipantsExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(Color.white.opacity(0.80))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.06))
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
                    title: "Hazır",
                    value: "\(readyCount)/\(max(participants.count, 1))"
                )
            }

            participantPreviewRow

            if showParticipantsExpanded {
                expandedParticipantsGrid
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
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
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                        showParticipantsExpanded = true
                    }
                } label: {
                    Text("+\(participants.count - visibleParticipants.count)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .frame(width: 52, height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.04))
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
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.92))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 52)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
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
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.95))

                        Text(participantStatusText(participant))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.48))
                    }

                    Spacer()

                    tagCapsule(participantRoleText(participant))
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.035))
                )
            }
        }
    }

    func tagCapsule(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.70))
            .padding(.horizontal, 10)
            .frame(height: 22)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
    }

    func compactPill(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.82))

            VStack(alignment: .leading, spacing: 1) {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(Color.white.opacity(0.42))

                Text(value)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    var controls: some View {
        HStack(spacing: 14) {
            Button {
                focusSession.togglePause()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: focusSession.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 17, weight: .heavy))

                    Text(focusSession.isPaused ? "Devam Et" : "Duraklat")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(Color.white.opacity(0.96))
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
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
                                Color.red.opacity(0.92),
                                Color.red.opacity(0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 92, height: 64)
                    .overlay(
                        Image(systemName: "stop.fill")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(.white)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    func participantsStatusColor(_ participant: FocusParticipant) -> Color {
        if participant.isHost || participant.isActive { return .green }
        if participant.isReady { return .yellow }
        return .gray.opacity(0.8)
    }

    func participantStatusText(_ participant: FocusParticipant) -> String {
        if participant.isHost { return "Oturumu yönetiyor" }
        if participant.isActive { return "Şu an odakta" }
        if participant.isReady { return "Başlamaya hazır" }
        return "Henüz bağlanmadı"
    }

    func participantRoleText(_ participant: FocusParticipant) -> String {
        if participant.isHost { return "HOST" }
        if participant.isActive { return "AKTİF" }
        if participant.isReady { return "HAZIR" }
        return "BEKLİYOR"
    }

    var sharedPanelTitle: String {
        switch mode {
        case .crew: return "Crew ile ortak odak"
        case .friend: return "Birlikte odaklanıyorsunuz"
        case .personal: return ""
        }
    }

    var sharedPanelSubtitle: String {
        switch mode {
        case .crew:
            let host = hostParticipant?.name ?? "Atakan"
            return "\(host) host olarak oturumu yürütüyor"
        case .friend:
            return "Eşleşmiş focus aktif"
        case .personal:
            return ""
        }
    }

    var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    .black,
                    theme.backgroundMid,
                    .black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(theme.topGlow.opacity(pulse ? 0.30 : 0.22))
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .offset(x: 110, y: -170)

            Circle()
                .fill(theme.bottomGlow.opacity(pulse ? 0.20 : 0.14))
                .frame(width: 320, height: 320)
                .blur(radius: 110)
                .offset(x: -120, y: 330)
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

    static func forMode(_ mode: FocusMode) -> ActiveFocusTheme {
        switch mode {
        case .personal:
            return .init(
                backgroundMid: Color(red: 0.02, green: 0.04, blue: 0.12),
                topGlow: Color(red: 0.18, green: 0.42, blue: 1.00),
                bottomGlow: Color(red: 0.05, green: 0.18, blue: 0.52),
                coreGlow: Color(red: 0.20, green: 0.46, blue: 1.00),
                innerGlow: Color(red: 0.22, green: 0.52, blue: 1.00)
            )
        case .crew:
            return .init(
                backgroundMid: Color(red: 0.11, green: 0.02, blue: 0.04),
                topGlow: Color(red: 1.00, green: 0.20, blue: 0.24),
                bottomGlow: Color(red: 0.55, green: 0.04, blue: 0.10),
                coreGlow: Color(red: 1.00, green: 0.25, blue: 0.30),
                innerGlow: Color(red: 1.00, green: 0.35, blue: 0.38)
            )
        case .friend:
            return .init(
                backgroundMid: Color(red: 0.07, green: 0.03, blue: 0.12),
                topGlow: Color(red: 0.78, green: 0.34, blue: 1.00),
                bottomGlow: Color(red: 0.34, green: 0.08, blue: 0.55),
                coreGlow: Color(red: 0.82, green: 0.38, blue: 1.00),
                innerGlow: Color(red: 0.86, green: 0.50, blue: 1.00)
            )
        }
    }
}
