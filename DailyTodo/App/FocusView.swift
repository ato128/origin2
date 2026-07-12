//
//  FocusView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 8.04.2026.
//
import SwiftUI
import SwiftData

struct FocusView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var focusSession: FocusSessionManager
    @EnvironmentObject var crewStore: CrewStore
    
    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()
    
    @State private var selectedMode: FocusMode = .personal
    @State private var selectedPreset: FocusDurationPreset = .medium
    @State private var customMinutes: Int = 60
    
    @State private var selectedGoal: FocusGoal = .study
    @State private var selectedStyle: FocusStyle = .silent
    
    @State private var showCustomDurationSheet = false
    @State private var showGoalPicker = false
    @State private var showStylePicker = false
    @State private var showCrewStartSheet = false
    
    @State private var pageAppeared = false
    @State private var isLaunchingFocus = false
    
    @State private var selectedCrewID: UUID?
    @State private var selectedCrewTaskID: UUID?
    @State private var selectedParticipantIDs: Set<UUID> = []

    // Friend (duo) focus
    @State private var showFriendPickerSheet = false

    @Query(sort: \Friend.createdAt, order: .reverse)
    private var localFriends: [Friend]
    
    var body: some View {
        ZStack {
            ArenaBackground(
                primaryGlow: selectedModeAccent,
                secondaryGlow: selectedModeSecondaryAccent,
                warmGlow: Color(arenaHex: AppArenaPalette.coral),
                intensity: 0.94
            )
            
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        pageHeader

                        Spacer(minLength: 18)

                        FocusModeSwitcherV3(selectedMode: $selectedMode)

                        Spacer(minLength: 18)

                        focusHeroNumber

                        Spacer(minLength: 16)

                        compactControlsSection

                        if selectedMode == .crew {
                            Spacer(minLength: 14)
                            crewSummaryHint
                        }

                        Spacer(minLength: 16)

                        bigStartButton

                        Color.clear.frame(height: 96)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: geo.size.height, alignment: .top)
                    .blur(radius: isLaunchingFocus ? 1.5 : 0)
                    .scaleEffect(isLaunchingFocus ? 0.992 : 1)
                    .animation(.easeInOut(duration: 0.28), value: isLaunchingFocus)
                }
                .disabled(isLaunchingFocus)
            }
            
            if isLaunchingFocus {
                launchOverlay
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showCustomDurationSheet) {
            customDurationSheet
        }
        .sheet(isPresented: $showGoalPicker) {
            goalPickerSheet
        }
        .sheet(isPresented: $showStylePicker) {
            stylePickerSheet
        }
        .sheet(isPresented: $showCrewStartSheet) {
            crewStartSheet
        }
        .sheet(isPresented: $showFriendPickerSheet) {
            friendPickerSheet
        }
        .fullScreenCover(isPresented: $focusSession.isExpanded) {
            ActiveFocusView()
                .environmentObject(focusSession)
        }
        .onAppear {
            pageAppeared = true
            focusSession.configure(sessionStore: session, crewStore: crewStore)
            consumeWidgetAutostartIfNeeded()

            Task {
                await crewStore.loadCrews()
                
                if selectedCrewID == nil {
                    selectedCrewID = crewStore.crews.first?.id
                }
                
                await loadCrewStartDependenciesIfNeeded()
                
                if selectedParticipantIDs.isEmpty {
                    selectedParticipantIDs = Set(
                        activeCrewMembers
                            .filter { isLockedParticipant($0) }
                            .map(\.user_id)
                    )
                }
            }
        }
        .onChange(of: selectedCrewID) { _, _ in
            selectedCrewTaskID = nil
            selectedParticipantIDs.removeAll()
            
            Task {
                await loadCrewStartDependenciesIfNeeded()
                selectedParticipantIDs = Set(
                    activeCrewMembers
                        .filter { isLockedParticipant($0) }
                        .map(\.user_id)
                )
            }
        }
        .onChange(of: selectedMode) { _, newValue in
            if newValue == .crew, selectedCrewID == nil {
                selectedCrewID = crewStore.crews.first?.id
            }
        }
        .onReceive(crewStore.$activeFocusSessionByCrew) { sessionsByCrew in
            guard let crewID = focusSession.currentCrewID else { return }
            
            let dto = sessionsByCrew[crewID]
            let participants = dto.flatMap { crewStore.focusParticipantsBySession[$0.id] } ?? []
            
            focusSession.applyCrewRealtimeStateIfNeeded(
                activeSession: dto,
                crewID: crewID,
                participants: participants,
                preferredGoal: selectedGoal,
                preferredStyle: selectedStyle
            )
        }
        .onReceive(crewStore.$focusParticipantsBySession) { participantsBySession in
            guard
                let crewID = focusSession.currentCrewID,
                let backendSessionID = focusSession.currentCrewBackendSessionID,
                let dto = crewStore.activeFocusSessionByCrew[crewID]
            else { return }
            
            let participants = participantsBySession[backendSessionID] ?? []
            
            focusSession.applyCrewRealtimeStateIfNeeded(
                activeSession: dto,
                crewID: crewID,
                participants: participants,
                preferredGoal: selectedGoal,
                preferredStyle: selectedStyle
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .startFocusFromWidget)) { _ in
            consumeWidgetAutostartIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .presentActiveCrewFocusFromNotification)) { output in
            guard let crewIDString = output.object as? String,
                  let crewID = UUID(uuidString: crewIDString) else { return }

            Task {
                await crewStore.loadActiveFocusSession(for: crewID)

                guard let dto = crewStore.activeFocusSessionByCrew[crewID] else {
                    Log.debug("⚪️ ACTIVE CREW FOCUS NOT FOUND:", crewID.uuidString)
                    return
                }

                await crewStore.loadFocusParticipants(sessionID: dto.id)
                let participants = crewStore.focusParticipantsBySession[dto.id] ?? []

                await MainActor.run {
                    selectedMode = .crew

                    focusSession.hydrateFromCrewSessionDTO(
                        dto,
                        crewID: crewID,
                        participantsDTO: participants,
                        preferredGoal: selectedGoal,
                        preferredStyle: selectedStyle
                    )

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        focusSession.expandSession()
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private extension FocusView {
    /// Bold-number hero: the duration as a large, typography-driven centerpiece
    /// (matches the Updo widget identity). When a session is live it switches to
    /// the running MM:SS. No decorative ring — the real progress ring appears in
    /// the active focus screen.
    /// Editorial minimal hero — left-aligned giant number, a thin accent rule,
    /// the unit label and the estimated finish time. Calm, luxurious, restrained
    /// (no card, no glow chrome). The number is the page.
    var focusHeroNumber: some View {
        let isActive = focusSession.isSessionActive

        return VStack(alignment: .leading, spacing: 8) {
            // Live status
            HStack(spacing: 7) {
                Circle()
                    .fill(selectedModeAccent)
                    .frame(width: 6, height: 6)
                    .shadow(color: selectedModeAccent.opacity(0.6), radius: 5)

                Text(effectiveStageStatusText.uppercased())
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            // Giant number — home active-focus serif italic identity
            FocusHeroDigits(
                text: isActive ? focusSession.timeString : "\(resolvedMinutes)",
                accent: selectedModeAccent,
                size: isActive ? 86 : 104
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .leading) {
                Ellipse()
                    .fill(selectedModeAccent.opacity(0.12))
                    .frame(width: 300, height: 190)
                    .blur(radius: 95)
                    .offset(x: -40, y: 8)
                    .allowsHitTesting(false)
            }
            .animation(.spring(response: 0.40, dampingFraction: 0.86), value: isActive)

            // Accent rule + unit + finish
            HStack(spacing: 10) {
                Rectangle()
                    .fill(selectedModeAccent)
                    .frame(width: 38, height: 2)

                Text(isActive ? tr("focus_countdown_caps") : tr("focus_minutes_caps"))
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(2.5)
                    .foregroundStyle(.white.opacity(0.55))

                Spacer(minLength: 8)

                Text(isActive ? effectiveStageMetaText : tr("focus_finish_prefix", focusFinishText))
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.40))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(pageAppeared ? 1 : 0)
        .scaleEffect(isLaunchingFocus ? 1.02 : 1, anchor: .leading)
        .blur(radius: isLaunchingFocus ? 0.6 : 0)
        .animation(.spring(response: 0.6, dampingFraction: 0.88), value: pageAppeared)
        .animation(.easeInOut(duration: 0.28), value: isLaunchingFocus)
    }

    /// Estimated clock time the session would end if started now.
    var focusFinishText: String {
        let end = Date().addingTimeInterval(TimeInterval(resolvedMinutes * 60))
        return end.formatted(.dateTime.hour().minute())
    }

    var editorialDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
    }

    var pageHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(selectedModeAccent)
                        .frame(width: 20, height: 1)

                    Text(focusEyebrow)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(2.5)
                        .foregroundStyle(selectedModeAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("Focus")
                        .font(.system(size: 39, weight: .black))
                        .foregroundStyle(.white)

                    Text(focusHeaderAccent)
                        .font(.system(size: 36, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    selectedModeAccent,
                                    selectedModeSecondaryAccent
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 8)

            HStack(spacing: 9) {
                focusHeaderIconButton(
                    systemName: "timer",
                    badge: focusSession.isSessionActive ? "LIVE" : nil
                ) {
                    if focusSession.isSessionActive {
                        focusSession.expandSession()
                    }
                }

                focusHeaderIconButton(systemName: "ellipsis") { }
            }
        }
        .padding(.top, 10)
        .opacity(pageAppeared ? 1 : 0)
        .offset(y: pageAppeared ? 0 : 8)
        .animation(.spring(response: 0.65, dampingFraction: 0.86), value: pageAppeared)
    }
    
    var focusEyebrow: String {
        switch selectedMode {
        case .personal:
            return tr("fv_eyebrow_personal")
        case .crew:
            return tr("fv_eyebrow_crew")
        case .friend:
            return tr("fv_eyebrow_friend")
        }
    }

    var focusHeaderAccent: String {
        switch selectedMode {
        case .personal:
            return tr("fv_accent_zone")
        case .crew:
            return "crew"
        case .friend:
            return "duo"
        }
    }

    var focusHeaderSubtitle: String {
        if focusSession.isSessionActive {
            return activeFocusInfoText
        }

        switch selectedMode {
        case .personal:
            return tr("fv_personal_sub")
        case .crew:
            return tr("fv_crew_sub")
        case .friend:
            return tr("fv_friend_sub")
        }
    }

    func focusHeaderIconButton(
        systemName: String,
        badge: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white.opacity(0.86))
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.090),
                                        Color.white.opacity(0.050)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .stroke(Color.white.opacity(0.11), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.22), radius: 12, y: 6)
                    )

                if let badge {
                    Text(badge)
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 5)
                        .frame(height: 17)
                        .background(
                            Capsule()
                                .fill(Color(arenaHex: AppArenaPalette.green))
                        )
                        .offset(x: 5, y: -5)
                }
            }
        }
        .buttonStyle(.plain)
    }

    var compactControlsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            durationRow

            VStack(spacing: 0) {
                editorialDivider

                editorialSettingRow(
                    title: tr("fv_goal_caps"),
                    value: selectedGoal.title,
                    subtitle: selectedGoal.subtitle,
                    icon: selectedGoal.icon,
                    action: { showGoalPicker = true }
                )

                editorialDivider

                editorialSettingRow(
                    title: tr("fv_sound_caps"),
                    value: selectedStyle.title,
                    subtitle: selectedStyle.subtitle,
                    icon: selectedStyle.icon,
                    action: { showStylePicker = true }
                )

                editorialDivider
            }
        }
        .opacity(isLaunchingFocus ? 0.0 : 1)
        .offset(y: isLaunchingFocus ? 10 : 0)
        .animation(.easeInOut(duration: 0.22), value: isLaunchingFocus)
    }

    func editorialSettingRow(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(selectedModeAccent)
                    .frame(width: 22)

                Text(title)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.40))
                    .frame(width: 50, alignment: .leading)

                VStack(alignment: .leading, spacing: 1) {
                    Text(value)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.white.opacity(0.24))
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    var crewSummaryHint: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Color(arenaHex: AppArenaPalette.green))
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color(arenaHex: AppArenaPalette.green).opacity(0.13))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(tr("fv_crew_start"))
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)

                Text(tr("fv_crew_start_sub"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.50))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(arenaHex: AppArenaPalette.green).opacity(0.060),
                            Color.white.opacity(0.035)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color(arenaHex: AppArenaPalette.green).opacity(0.13), lineWidth: 1)
                )
        )
    }

    var durationRow: some View {
        HStack(spacing: 10) {
            durationChip(.short, text: "15 dk")
            durationChip(.medium, text: "25 dk")
            durationChip(.long, text: "45 dk")
            customDurationChip
        }
    }

    func durationChip(_ preset: FocusDurationPreset, text: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                selectedPreset = preset
            }
        } label: {
            Text(text)
                .editorialDurationChip(selected: selectedPreset == preset, accent: selectedModeAccent)
        }
        .buttonStyle(.plain)
    }

    var customDurationChip: some View {
        Button {
            showCustomDurationSheet = true
        } label: {
            Text(selectedPreset == .custom ? "\(customMinutes) dk" : tr("wv_custom"))
                .editorialDurationChip(selected: selectedPreset == .custom, accent: selectedModeAccent)
        }
        .buttonStyle(.plain)
    }

    func compactInfoCard(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(selectedModeAccent.opacity(0.13))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(selectedModeAccent.opacity(0.16), lineWidth: 1)
                        )

                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(selectedModeAccent)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title.uppercased())
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1.3)
                        .foregroundStyle(.white.opacity(0.36))

                    Text(value)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.white.opacity(0.96))
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(1)
                        .minimumScaleFactor(0.80)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.white.opacity(0.25))
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .frame(height: 88)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                selectedModeAccent.opacity(0.060),
                                Color(arenaHex: AppArenaPalette.purple).opacity(0.040),
                                Color.white.opacity(0.035)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(selectedModeAccent.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 10, y: 5)
            )
        }
        .buttonStyle(.plain)
    }
    
    var hasAnyBlockingFocus: Bool {
        focusSession.isSessionActive
    }

    var activeFocusInfoText: String {
        guard let mode = focusSession.activeSessionMode else { return "" }

        switch mode {
        case .personal:
            return tr("fv_personal_active")
        case .crew:
            return tr("fv_crew_active")
        case .friend:
            return tr("fv_friend_active")
        }
    }

    var activeCrewSessionsForHome: [CrewFocusSessionDTO] {
        let now = Date()

        return crewStore.activeFocusSessionByCrew.values
            .filter { session in
                guard session.is_active else { return false }
                guard session.ended_at == nil else { return false }

                if session.is_paused {
                    return (session.paused_remaining_seconds ?? 0) > 0
                }

                guard let startedAt = CrewDateParser.parse(session.started_at) else { return false }

                let endDate = startedAt.addingTimeInterval(
                    TimeInterval(session.duration_minutes * 60)
                )

                return endDate > now
            }
            .sorted {
                let lhs = CrewDateParser.parse($0.started_at) ?? .distantPast
                let rhs = CrewDateParser.parse($1.started_at) ?? .distantPast
                return lhs > rhs
            }
    }

    var selectedCrewHasActiveSession: Bool {
        guard let selectedCrewID else { return false }
        return crewStore.activeFocusSessionByCrew[selectedCrewID]?.is_active == true
    }

    var bigStartButton: some View {
        VStack(spacing: 12) {
            Button {
                triggerFocusLaunch()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: focusSession.isSessionActive ? "lock.fill" : "play.fill")
                        .font(.system(size: 15, weight: .black))

                    Text(focusSession.isSessionActive ? tr("fv_open_active") : modeCTA)
                        .font(.system(size: 17, weight: .black))
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)

                    Spacer()

                    Image(systemName: focusSession.isSessionActive ? "arrow.up.forward.app" : "arrow.right")
                        .font(.system(size: 14, weight: .black))
                        .opacity(0.86)
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 22)
                .frame(height: 60)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: focusSession.isSessionActive
                                ? [
                                    Color(arenaHex: AppArenaPalette.gold),
                                    Color(arenaHex: AppArenaPalette.coral)
                                ]
                                : [
                                    selectedModeAccent,
                                    selectedModeSecondaryAccent
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.white.opacity(0.13), lineWidth: 1)
                        )
                )
                .shadow(
                    color: (focusSession.isSessionActive ? Color(arenaHex: AppArenaPalette.gold) : selectedModeAccent).opacity(0.24),
                    radius: 22,
                    y: 12
                )
            }
            .buttonStyle(PressScaleButtonStyle())
            .padding(.top, 2)
            .opacity(isLaunchingFocus ? 0.0 : 1)
            .offset(y: isLaunchingFocus ? 8 : 0)
            .animation(.easeInOut(duration: 0.18), value: isLaunchingFocus)

            if !focusSession.isSessionActive && !activeCrewSessionsForHome.isEmpty {
                activeCrewSessionsSection
            }
        }
    }

    var activeCrewSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(activeCrewSessionsForHome.count > 1 ? "Aktif Crew Focuslar" : "Aktif Crew Focus")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(palette.primaryText.opacity(0.94))

            ForEach(activeCrewSessionsForHome, id: \.id) { activeSession in
                Button {
                    Task {
                        await crewStore.loadActiveFocusSession(for: activeSession.crew_id)

                        guard let latestSession = crewStore.activeFocusSessionByCrew[activeSession.crew_id],
                              latestSession.id == activeSession.id,
                              latestSession.is_active,
                              latestSession.ended_at == nil
                        else {
                            return
                        }

                        await crewStore.loadFocusParticipants(sessionID: latestSession.id)
                        let participants = crewStore.focusParticipantsBySession[latestSession.id] ?? []

                        await MainActor.run {
                            selectedMode = .crew
                            focusSession.hydrateFromCrewSessionDTO(
                                latestSession,
                                crewID: latestSession.crew_id,
                                participantsDTO: participants,
                                preferredGoal: selectedGoal,
                                preferredStyle: selectedStyle
                            )
                            focusSession.expandSession()
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(activeSession.title)
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(1)

                            Text("\(tr("hf_started_by", activeSession.host_name)) • \(tr("rel_min_short_n", activeSession.duration_minutes))")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(tr("hf_join"))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.blue.opacity(0.9))
                            )
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    /// Widget "start" button. The URL handler sets a one-shot flag (the widget
    /// may cold-launch the app before this view exists); reading it clears it,
    /// so onAppear + notification can't double-start.
    func consumeWidgetAutostartIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "focus.pendingWidgetAutostart") else { return }
        defaults.removeObject(forKey: "focus.pendingWidgetAutostart")

        guard !focusSession.isSessionActive else {
            focusSession.expandSession()
            return
        }

        // Small beat so the tab switch settles before the launch animation.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard !focusSession.isSessionActive else { return }
            triggerFocusLaunch()
        }
    }

    func triggerFocusLaunch() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if focusSession.isSessionActive {
            focusSession.expandSession()
            return
        }

        if !activeCrewSessionsForHome.isEmpty && selectedMode != .crew {
            selectedMode = .crew
            return
        }

        if selectedMode == .crew {
            showCrewStartSheet = true
            return
        }

        if selectedMode == .friend {
            // Duo needs a real friend — pick who to invite, then start.
            showFriendPickerSheet = true
            return
        }

        withAnimation(.easeInOut(duration: 0.24)) {
            isLaunchingFocus = true
        }

        Task {
            try? await Task.sleep(nanoseconds: 320_000_000)

            let started = await focusSession.startRequestedSession(
                mode: selectedMode,
                durationMinutes: resolvedMinutes,
                goal: selectedGoal,
                style: selectedStyle,
                preferredCrewID: selectedCrewID
            )

            if !started {
                Log.debug("FOCUS START FAILED")
            }

            try? await Task.sleep(nanoseconds: 280_000_000)

            await MainActor.run {
                isLaunchingFocus = false
            }
        }
    }
    
    var effectiveStageMode: FocusMode {
        if focusSession.isSessionActive {
            return focusSession.selectedMode
        }
        return selectedMode
    }

    var effectiveStageDurationText: String {
        if focusSession.isSessionActive {
            return focusSession.timeString
        }
        return durationText
    }

    var effectiveStageStatusText: String {
        if focusSession.isSessionActive {
            if focusSession.isPaused {
                return tr("hv_paused")
            }

            switch focusSession.selectedMode {
            case .personal:
                return "Aktif session"
            case .crew:
                return tr("hf_ready_count", focusSession.readyCount, max(focusSession.participantCount, 1))
            case .friend:
                return "Birlikte aktif"
            }
        }

        return heroStatusText
    }

    var effectiveStageMetaText: String {
        if focusSession.isSessionActive {
            return "\(focusSession.selectedGoal.title) • \(focusSession.selectedStyle.title)"
        }
        return "\(selectedGoal.title) • \(selectedStyle.title)"
    }

    var effectiveStageProgress: Double {
        if focusSession.isSessionActive {
            return max(0.02, focusSession.progress)
        }
        return heroProgress
    }

    var crewStartSheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text(tr("fv_start_crew"))
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(tr("fv_crew_pick_sub"))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    crewPickerSection
                    crewTaskSection
                    crewParticipantSection
                    crewLaunchSummaryCard

                    Button {
                        Task {
                            await startCrewSessionFromSheet()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill")
                            Text(tr("fv_start_crew"))
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            selectedModeAccent.opacity(0.95),
                                            selectedModeSecondaryAccent.opacity(0.88)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
        }
        .presentationDetents([.large])
    }
    
    var crewLaunchSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("fv_summary"))
                .font(.system(size: 15, weight: .heavy, design: .rounded))

            HStack(spacing: 10) {
                summaryMiniPill(
                    title: tr("duration_label"),
                    value: durationText
                )

                summaryMiniPill(
                    title: tr("at_kind_task"),
                    value: selectedCrewTaskID == nil ? "Yok" : tr("fv_selected")
                )

                summaryMiniPill(
                    title: tr("fv_person"),
                    value: "\(selectedParticipantIDs.count)"
                )
            }
        }
    }

    func summaryMiniPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.45))
                .tracking(1.4)

            Text(value)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }

    var crewPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Crew")
                .font(.system(size: 15, weight: .heavy, design: .rounded))

            ForEach(crewStore.crews, id: \.id) { crew in
                Button {
                    selectedCrewID = crew.id
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            selectedCrewID == crew.id
                                            ? selectedModeAccent.opacity(0.30)
                                            : Color.white.opacity(0.08),
                                            Color.white.opacity(0.04)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Image(systemName: crew.icon)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(
                                    selectedCrewID == crew.id
                                    ? Color.white.opacity(0.96)
                                    : Color.white.opacity(0.76)
                                )
                        }
                        .frame(width: 46, height: 46)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(crew.name)
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                                .foregroundStyle(.primary)

                            Text(tr("fv_crew_space"))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if selectedCrewID == crew.id {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(selectedModeAccent)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(selectedCrewID == crew.id ? 0.09 : 0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(
                                        selectedCrewID == crew.id
                                        ? selectedModeAccent.opacity(0.35)
                                        : Color.white.opacity(0.05),
                                        lineWidth: 1
                                    )
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    var crewTaskSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("at_kind_task"))
                .font(.system(size: 15, weight: .heavy, design: .rounded))

            Button {
                selectedCrewTaskID = nil
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        selectedCrewTaskID == nil
                                        ? Color.green.opacity(0.24)
                                        : Color.white.opacity(0.08),
                                        Color.white.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Image(systemName: "sparkles")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(selectedCrewTaskID == nil ? .white : Color.white.opacity(0.72))
                    }
                    .frame(width: 46, height: 46)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr("fv_start_no_task"))
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(.primary)

                        Text("Genel bir crew focus oturumu")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if selectedCrewTaskID == nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(selectedCrewTaskID == nil ? 0.09 : 0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(
                                    selectedCrewTaskID == nil
                                    ? Color.green.opacity(0.28)
                                    : Color.white.opacity(0.05),
                                    lineWidth: 1
                                )
                        )
                )
            }
            .buttonStyle(.plain)

            ForEach(activeCrewTasks, id: \.id) { task in
                let isSelected = selectedCrewTaskID == task.id

                Button {
                    selectedCrewTaskID = task.id
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            isSelected
                                            ? selectedModeAccent.opacity(0.28)
                                            : Color.white.opacity(0.08),
                                            Color.white.opacity(0.04)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Image(systemName: "checklist")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(isSelected ? .white : Color.white.opacity(0.74))
                        }
                        .frame(width: 46, height: 46)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)

                            Text(task.status.capitalized)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(selectedModeAccent)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(isSelected ? 0.09 : 0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(
                                        isSelected
                                        ? selectedModeAccent.opacity(0.32)
                                        : Color.white.opacity(0.05),
                                        lineWidth: 1
                                    )
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    var crewParticipantSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tr("cfr_participants"))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))

                Spacer()

                Button("Herkes") {
                    selectedParticipantIDs = Set(
                        activeCrewMembers.map(\.user_id)
                    )
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.blue)
            }

            ForEach(activeCrewMembers, id: \.id) { member in
                let userID = member.user_id
                let isSelected = selectedParticipantIDs.contains(userID)
                let name = displayName(for: member)
                let isLocked = isLockedParticipant(member)

                Button {
                    guard !isLocked else { return }

                    if isSelected {
                        selectedParticipantIDs.remove(userID)
                    } else {
                        selectedParticipantIDs.insert(userID)
                    }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            isSelected
                                            ? selectedModeAccent.opacity(0.95)
                                            : Color.white.opacity(0.14),
                                            Color.white.opacity(0.06)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Text(String(name.prefix(1)).uppercased())
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 42, height: 42)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(name)
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundStyle(.primary)

                            Text(isLocked ? tr("fv_required_participant") : member.role.capitalized)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if isLocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.7))
                        } else if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 21, weight: .bold))
                                .foregroundStyle(selectedModeAccent)
                        } else {
                            Circle()
                                .stroke(Color.white.opacity(0.18), lineWidth: 1.2)
                                .frame(width: 20, height: 20)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(isSelected || isLocked ? 0.09 : 0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(
                                        isSelected || isLocked
                                        ? selectedModeAccent.opacity(0.30)
                                        : Color.white.opacity(0.05),
                                        lineWidth: 1
                                    )
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    func startCrewSessionFromSheet() async {
        guard let crewID = selectedCrewID else { return }

        guard !focusSession.isSessionActive else {
            await MainActor.run {
                focusSession.expandSession()
            }
            return
        }

        await crewStore.loadActiveFocusSession(for: crewID)

        if let existing = crewStore.activeFocusSessionByCrew[crewID], existing.is_active {
            await crewStore.loadFocusParticipants(sessionID: existing.id)
            let participants = crewStore.focusParticipantsBySession[existing.id] ?? []

            await MainActor.run {
                focusSession.hydrateFromCrewSessionDTO(
                    existing,
                    crewID: crewID,
                    participantsDTO: participants,
                    preferredGoal: selectedGoal,
                    preferredStyle: selectedStyle
                )
                showCrewStartSheet = false
                focusSession.expandSession()
            }
            return
        }

        let invitedParticipantIDs = selectedParticipantIDs.filter { $0 != focusSession.currentUserID }

        guard !invitedParticipantIDs.isEmpty else {
            Log.debug("CREW START BLOCKED: en az 1 davetli katılımcı seçilmeli")
            return
        }

        await MainActor.run {
            showCrewStartSheet = false
            withAnimation(.easeInOut(duration: 0.24)) {
                isLaunchingFocus = true
            }
        }

        let task = activeCrewTasks.first(where: { $0.id == selectedCrewTaskID })
        let hostName = resolvedCurrentDisplayName

        do {
            let dto = try await crewStore.startCrewFocusSession(
                crewID: crewID,
                hostUserID: focusSession.currentUserID,
                hostName: hostName,
                title: task?.title ?? "\(selectedGoal.title) Focus",
                taskID: task?.id,
                taskTitle: task?.title,
                durationMinutes: resolvedMinutes,
                participantCount: selectedParticipantIDs.count
            )

            await crewStore.loadActiveFocusSession(for: crewID)
            await crewStore.loadFocusParticipants(sessionID: dto.id)

            let participants = crewStore.focusParticipantsBySession[dto.id] ?? []

            await MainActor.run {
                selectedMode = .crew

                focusSession.hydrateFromCrewSessionDTO(
                    dto,
                    crewID: crewID,
                    participantsDTO: participants,
                    preferredGoal: selectedGoal,
                    preferredStyle: selectedStyle
                )

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    focusSession.expandSession()
                }
            }

            // YENİ — Davet push için ek bilgiler
            let crewObject = crewStore.crews.first(where: { $0.id == crewID })
            let crewName = crewObject?.name ?? "Crew"

            let liveParticipantNames: [String] = {
                var names = participants.map(\.member_name)
                if names.isEmpty {
                    names = [hostName]
                }
                return names
            }()

            let totalCount = invitedParticipantIDs.count + 1

            await FocusInviteService.shared.sendInvites(
                sessionID: dto.id,
                crewID: crewID,
                participantIDs: Array(invitedParticipantIDs),
                hostName: hostName,
                duration: resolvedMinutes,
                taskTitle: task?.title,
                crewName: crewName,
                startedAt: Date(),
                participantNames: liveParticipantNames,
                totalParticipants: totalCount
            )
        } catch {
            Log.debug("CREW START SHEET ERROR:", error.localizedDescription)
        }

        try? await Task.sleep(nanoseconds: 250_000_000)

        await MainActor.run {
            isLaunchingFocus = false
        }
    }
    
    func isLockedParticipant(_ member: CrewMemberDTO) -> Bool {
        member.role.lowercased() == "owner" || member.user_id == focusSession.currentUserID
    }

    func loadCrewStartDependenciesIfNeeded() async {
        guard let crewID = selectedCrewID else { return }

        await crewStore.loadMembers(for: crewID)
        await crewStore.loadMemberProfiles(for: crewStore.crewMembers)
        await crewStore.loadTasks(for: crewID)
        await crewStore.loadActiveFocusSession(for: crewID)
    }
    
    var resolvedCurrentDisplayName: String {
        if let user = session.currentUser {
            let fullName = user.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !fullName.isEmpty {
                return fullName
            }

            let username = user.username.trimmingCharacters(in: .whitespacesAndNewlines)
            if !username.isEmpty {
                return username
            }

            let email = user.email.trimmingCharacters(in: .whitespacesAndNewlines)
            if !email.isEmpty {
                return email.components(separatedBy: "@").first ?? email
            }
        }

        return focusSession.currentUserDisplayName
    }

    var activeCrewTasks: [CrewTaskDTO] {
        guard let crewID = selectedCrewID else { return [] }
        return crewStore.crewTasks
            .filter { $0.crew_id == crewID && !$0.is_done }
    }

    var activeCrewMembers: [CrewMemberDTO] {
        guard let crewID = selectedCrewID else { return [] }
        return crewStore.crewMembers
            .filter { $0.crew_id == crewID }
    }

    var availableParticipantUserIDs: [UUID] {
        activeCrewMembers.map(\.user_id)
    }

    func displayName(for member: CrewMemberDTO) -> String {
        if let profile = crewStore.memberProfiles.first(where: { $0.id == member.user_id }) {
            if let username = profile.username?.trimmingCharacters(in: .whitespacesAndNewlines),
               !username.isEmpty {
                return username
            }

            if let fullName = profile.full_name?.trimmingCharacters(in: .whitespacesAndNewlines),
               !fullName.isEmpty {
                return fullName
            }
        }

        return tr("uname_w1")
    }

    var launchOverlay: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()

            Circle()
                .fill(selectedModeAccent.opacity(0.22))
                .frame(width: 280, height: 280)
                .blur(radius: 36)

            Circle()
                .stroke(Color.white.opacity(0.16), lineWidth: 14)
                .frame(width: 236, height: 236)

            Circle()
                .trim(from: 0, to: heroProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.98),
                            selectedModeAccent.opacity(0.95),
                            Color.white.opacity(0.98)
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 236, height: 236)

            VStack(spacing: 8) {
                Text(durationText)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text(tr("fv_focus_preparing"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
        }
    }

    var ambientBackground: some View {
        ZStack(alignment: .topLeading) {
            RadialGradient(
                colors: [
                    selectedModeAccent.opacity(0.12),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 50,
                endRadius: 320
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    selectedModeSecondaryAccent.opacity(0.10),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 60,
                endRadius: 300
            )
            .ignoresSafeArea()
        }
    }

    var selectedModeAccent: Color {
        switch selectedMode {
        case .personal:
            return Color(arenaHex: AppArenaPalette.cyan)
        case .crew:
            return Color(arenaHex: AppArenaPalette.coral)
        case .friend:
            return Color(arenaHex: AppArenaPalette.purple)
        }
    }

    var selectedModeSecondaryAccent: Color {
        switch selectedMode {
        case .personal:
            return Color(arenaHex: AppArenaPalette.purple)
        case .crew:
            return Color(arenaHex: AppArenaPalette.gold)
        case .friend:
            return Color(arenaHex: AppArenaPalette.blue)
        }
    }
    
    var resolvedMinutes: Int {
        switch selectedPreset {
        case .short: return 15
        case .medium: return 25
        case .long: return 45
        case .custom: return customMinutes
        }
    }

    var durationText: String {
        switch selectedPreset {
        case .short: return "15 dk"
        case .medium: return "25 dk"
        case .long: return "45 dk"
        case .custom: return "\(customMinutes) dk"
        }
    }

    var heroProgress: Double {
        if focusSession.isSessionActive && focusSession.selectedMode == selectedMode {
            return focusSession.progress
        }

        switch resolvedMinutes {
        case 0..<20: return 0.56
        case 20..<40: return 0.72
        default: return 0.84
        }
    }

    var heroStatusText: String {
        if focusSession.isSessionActive && focusSession.selectedMode == selectedMode {
            switch selectedMode {
            case .personal:
                return focusSession.isPaused ? tr("hv_paused") : "Aktif"
            case .crew:
                return tr("hf_ready_count", focusSession.readyCount, max(focusSession.participantCount, 1))
            case .friend:
                return focusSession.participantCount >= 2 ? tr("fv_two_ready") : "Bekleniyor"
            }
        }

        switch selectedMode {
        case .personal: return tr("hf_ready")
        case .crew: return tr("fv_team_ready")
        case .friend: return tr("fv_matched")
        }
    }

    var modeCTA: String {
        switch selectedMode {
        case .personal: return tr("fv_start_personal")
        case .crew: return tr("fv_start_crew")
        case .friend: return tr("fv_start_friend")
        }
    }

    // MARK: - Friend picker (duo focus)

    private var invitableFriends: [Friend] {
        let uid = session.currentUser?.id.uuidString
        return localFriends.filter {
            $0.backendUserID != nil && ($0.ownerUserID == nil || $0.ownerUserID == uid)
        }
    }

    var friendPickerSheet: some View {
        NavigationStack {
            ZStack {
                Color(arenaHex: "#07090F").ignoresSafeArea()

                if invitableFriends.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.3))
                        Text(tr("fv_no_friends"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 8) {
                            ForEach(invitableFriends) { friend in
                                Button {
                                    guard let backendID = friend.backendUserID else { return }
                                    HapticManager.shared.action()
                                    startFriendDuoSession(friendID: backendID, friendName: friend.name)
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(arenaHex: friend.colorHex).opacity(0.25))
                                                .frame(width: 42, height: 42)
                                            Text(String(friend.name.prefix(1)).uppercased())
                                                .font(.system(size: 16, weight: .black, design: .rounded))
                                                .foregroundStyle(.white)
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(friend.name)
                                                .font(.system(size: 15.5, weight: .bold))
                                                .foregroundStyle(.white)
                                            Text(tr("fv_friend_invite_sub", resolvedMinutes))
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(.white.opacity(0.45))
                                        }

                                        Spacer(minLength: 8)

                                        Image(systemName: "paperplane.fill")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(Color(arenaHex: AppArenaPalette.purple))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 11)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color.white.opacity(0.05))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(tr("fv_pick_friend_title"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("common_cancel")) { showFriendPickerSheet = false }
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func startFriendDuoSession(friendID: UUID, friendName: String) {
        showFriendPickerSheet = false

        withAnimation(.easeInOut(duration: 0.24)) {
            isLaunchingFocus = true
        }

        Task {
            try? await Task.sleep(nanoseconds: 320_000_000)

            let started = await focusSession.startRequestedSession(
                mode: .friend,
                durationMinutes: resolvedMinutes,
                goal: selectedGoal,
                style: selectedStyle,
                friendUserID: friendID,
                friendName: friendName
            )

            if !started {
                Log.debug("FRIEND FOCUS START FAILED")
            }

            try? await Task.sleep(nanoseconds: 280_000_000)

            await MainActor.run {
                isLaunchingFocus = false
            }
        }
    }

    var customDurationSheet: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Text(tr("fv_custom_duration"))
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(tr("fv_custom_sub"))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.white.opacity(0.05))

                    Picker("Dakika", selection: $customMinutes) {
                        ForEach(5...180, id: \.self) { minute in
                            Text("\(minute) dk").tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 180)
                    .padding(.horizontal, 8)
                }
                .frame(height: 200)

                HStack(spacing: 10) {
                    quickMinuteChip(10)
                    quickMinuteChip(25)
                    quickMinuteChip(45)
                    quickMinuteChip(60)
                    quickMinuteChip(90)
                }

                Button {
                    selectedPreset = .custom
                    showCustomDurationSheet = false
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "timer")
                            .font(.system(size: 15, weight: .bold))

                        Text("\(customMinutes) dk Kullan")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.95),
                                        Color.indigo.opacity(0.80)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(20)
        }
        .presentationDetents([.medium])
    }

    func quickMinuteChip(_ minute: Int) -> some View {
        Button {
            customMinutes = minute
        } label: {
            Text("\(minute) dk")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(customMinutes == minute ? .white : .primary.opacity(0.8))
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(
                    Capsule(style: .continuous)
                        .fill(customMinutes == minute ? Color.blue.opacity(0.9) : Color.white.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
    }

    var goalPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(tr("fv_pick_goal"))
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)

                Text(tr("fv_goal_sub"))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(FocusGoal.allCases) { goal in
                            Button {
                                selectedGoal = goal
                                showGoalPicker = false
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: goal.icon)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.92))
                                        .frame(width: 38, height: 38)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color.blue.opacity(0.95), Color.indigo.opacity(0.75)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                        )

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(goal.title)
                                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                                            .foregroundStyle(.primary)

                                        Text(goal.subtitle)
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if selectedGoal == goal {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.white.opacity(0.05))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)
                }

                Spacer()
            }
            .padding(20)
        }
        .presentationDetents([.medium, .large])
    }

    var stylePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(tr("fv_pick_sound"))
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Focus atmosferini belirle.")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(FocusStyle.allCases) { style in
                            Button {
                                selectedStyle = style
                                showStylePicker = false
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: style.icon)
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.white.opacity(0.92))
                                        .frame(width: 38, height: 38)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color.purple.opacity(0.95), Color.blue.opacity(0.75)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                        )

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(style.title)
                                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                                            .foregroundStyle(.primary)

                                        Text(style.subtitle)
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if selectedStyle == style {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.white.opacity(0.05))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)
                }

                Spacer()
            }
            .padding(20)
        }
        .presentationDetents([.medium, .large])
    }
}

/// Focus hero number rendered in the same serif-italic identity as the home
/// active-focus card (PremiumCountdownView): bold serif italic digits, a lighter
/// serif italic colon. Scales as a unit so MM:SS never overflows.
private struct FocusHeroDigits: View {
    let text: String
    let accent: Color
    var size: CGFloat = 112

    /// Premium brushed-silver fill: bright at the crown, settling into a deep
    /// graphite with only a whisper of the mode accent at the base. Reads dark
    /// and expensive rather than neon.
    private var fill: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.96),
                Color.white.opacity(0.74),
                Color(white: 0.42),
                accent.opacity(0.45)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        let parts = text.split(separator: ":").map(String.init)

        HStack(alignment: .firstTextBaseline, spacing: 0) {
            ForEach(Array(parts.enumerated()), id: \.offset) { idx, part in
                if idx > 0 {
                    Text(":")
                        .font(.system(size: size * 0.76, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(.white.opacity(0.32))
                        .offset(y: -size * 0.06)
                        .padding(.horizontal, 1)
                }

                Text(part)
                    .font(.system(size: size, weight: .bold, design: .serif))
                    .italic()
                    .foregroundStyle(fill)
                    .kerning(-size * 0.024)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.spring(response: 0.42, dampingFraction: 0.82), value: part)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.4)
        .shadow(color: Color.black.opacity(0.55), radius: 14, y: 8)
        .shadow(color: accent.opacity(0.16), radius: 26)
    }
}

private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

private extension View {
    /// Editorial minimal duration chip: faint base, accent outline + accent
    /// text when selected (no heavy gradient fill).
    func editorialDurationChip(selected: Bool, accent: Color) -> some View {
        self
            .font(.system(size: 13, weight: .black, design: .monospaced))
            .foregroundStyle(selected ? accent : Color.white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? accent.opacity(0.13) : Color.white.opacity(0.035))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(
                                selected ? accent.opacity(0.55) : Color.white.opacity(0.08),
                                lineWidth: selected ? 1.5 : 1
                            )
                    )
            )
    }
}

