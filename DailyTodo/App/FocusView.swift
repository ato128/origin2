//
//  FocusView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 8.04.2026.
//
import SwiftUI
import SwiftData

private struct CrewFocusInvitePayload: Identifiable {
    let id = UUID()
    let crewID: UUID
    let sessionID: UUID
    let hostName: String
    let durationMinutes: Int
    let taskTitle: String?
}

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
    @State private var invitePayload: CrewFocusInvitePayload?
    @State private var isJoiningInvite = false

    var body: some View {
        ZStack {
            AppBackground()
            ambientBackground

            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        Color.clear.frame(height: 2)

                        pageHeader

                        FocusModeSwitcherV3(selectedMode: $selectedMode)

                        FocusFullPageStageV7(
                            mode: effectiveStageMode,
                            durationText: effectiveStageDurationText,
                            statusText: effectiveStageStatusText,
                            metaText: effectiveStageMetaText,
                            progress: effectiveStageProgress,
                            isLaunching: isLaunchingFocus
                        )

                        compactControlsSection
                        
                        inviteBannerCard

                        bigStartButton

                        if selectedMode == .crew {
                            crewSummaryHint
                        }

                        Color.clear
                            .frame(height: 110)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
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
       
        .fullScreenCover(isPresented: $focusSession.isExpanded) {
            ActiveFocusView()
                .environmentObject(focusSession)
        }
        .onAppear {
            pageAppeared = true
            focusSession.configure(sessionStore: session, crewStore: crewStore)

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
        .onReceive(NotificationCenter.default.publisher(for: .presentCrewFocusInviteSheet)) { output in
            guard let userInfo = output.object as? [AnyHashable: Any],
                  let payload = parseInvitePayload(userInfo) else { return }
            invitePayload = payload
        }
        .onReceive(NotificationCenter.default.publisher(for: .presentActiveCrewFocusFromNotification)) { output in
            guard let crewIDString = output.object as? String,
                  let crewID = UUID(uuidString: crewIDString) else { return }

            Task {
                await crewStore.loadActiveFocusSession(for: crewID)

                guard let dto = crewStore.activeFocusSessionByCrew[crewID] else { return }

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
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private extension FocusView {
    var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Focus")
                .font(.system(size: 33, weight: .heavy, design: .rounded))
                .foregroundStyle(palette.primaryText)
                .tracking(-0.8)

            Text("Kendi ritmini başlat ve tek dokunuşla odakta kal")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.secondaryText.opacity(0.82))
                .lineLimit(2)
        }
        .padding(.top, 20)
        .opacity(pageAppeared ? 1 : 0)
        .offset(y: pageAppeared ? 0 : 8)
        .animation(.spring(response: 0.65, dampingFraction: 0.86), value: pageAppeared)
    }

    var compactControlsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ayarlar")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(palette.primaryText.opacity(0.94))

            durationRow

            HStack(spacing: 10) {
                compactInfoCard(
                    title: "Goal",
                    value: selectedGoal.title,
                    subtitle: selectedGoal.subtitle,
                    icon: selectedGoal.icon,
                    action: { showGoalPicker = true }
                )

                compactInfoCard(
                    title: "Sound",
                    value: selectedStyle.title,
                    subtitle: selectedStyle.subtitle,
                    icon: selectedStyle.icon,
                    action: { showStylePicker = true }
                )
            }
        }
        .opacity(isLaunchingFocus ? 0.0 : 1)
        .offset(y: isLaunchingFocus ? 10 : 0)
        .animation(.easeInOut(duration: 0.22), value: isLaunchingFocus)
    }

    var crewSummaryHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Crew başlatma")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.90))

            Text("Başlat dediğinde crew, görev ve katılımcı seçimi alttan açılır.")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.56))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
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
            selectedPreset = preset
        } label: {
            Text(text)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(selectedPreset == preset ? .white : palette.secondaryText.opacity(0.84))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            selectedPreset == preset
                            ? LinearGradient(
                                colors: [
                                    selectedModeAccent.opacity(0.30),
                                    Color.white.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color.white.opacity(0.05),
                                    Color.white.opacity(0.025)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(selectedPreset == preset ? 0.11 : 0.05), lineWidth: 1)
                        )
                )
                .shadow(color: selectedPreset == preset ? selectedModeAccent.opacity(0.18) : .clear, radius: 12, x: 0, y: 7)
        }
        .buttonStyle(.plain)
    }

    var customDurationChip: some View {
        Button {
            showCustomDurationSheet = true
        } label: {
            Text(selectedPreset == .custom ? "\(customMinutes) dk" : "Özel")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(selectedPreset == .custom ? .white : palette.secondaryText.opacity(0.84))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            selectedPreset == .custom
                            ? LinearGradient(
                                colors: [
                                    selectedModeAccent.opacity(0.30),
                                    Color.white.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color.white.opacity(0.05),
                                    Color.white.opacity(0.025)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(selectedPreset == .custom ? 0.11 : 0.05), lineWidth: 1)
                        )
                )
                .shadow(color: selectedPreset == .custom ? selectedModeAccent.opacity(0.18) : .clear, radius: 12, x: 0, y: 7)
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
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )

                Circle()
                    .fill(selectedModeAccent.opacity(0.14))
                    .frame(width: 90, height: 90)
                    .blur(radius: 24)
                    .offset(x: -48, y: 0)

                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.08))

                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.9))
                    }
                    .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.56))
                            .tracking(1)

                        Text(value)
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.96))
                            .lineLimit(1)

                        Text(subtitle)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.62))
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.34))
                }
                .padding(.horizontal, 14)
            }
            .frame(height: 88)
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
            return "Şu anda kişisel bir focus aktif"
        case .crew:
            return "Şu anda crew focus aktif"
        case .friend:
            return "Şu anda friend focus aktif"
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
                        .font(.system(size: 15, weight: .bold))

                    Text(focusSession.isSessionActive ? "Aktif Focusu Aç" : modeCTA)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))

                    Spacer()

                    Image(systemName: focusSession.isSessionActive ? "arrow.up.forward.app" : "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .opacity(0.86)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .frame(height: 60)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: focusSession.isSessionActive
                                ? [
                                    Color.orange.opacity(0.95),
                                    Color.red.opacity(0.88)
                                ]
                                : [
                                    selectedModeAccent.opacity(1.0),
                                    selectedModeSecondaryAccent.opacity(0.92)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.white.opacity(0.11), lineWidth: 1)
                        )
                )
                .shadow(
                    color: (focusSession.isSessionActive ? Color.orange : selectedModeAccent).opacity(0.24),
                    radius: 26,
                    x: 0,
                    y: 14
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

                            Text("\(activeSession.host_name) başlattı • \(activeSession.duration_minutes) dk")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("Katıl")
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
    
    func triggerFocusLaunch() {
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

        withAnimation(.easeInOut(duration: 0.24)) {
            isLaunchingFocus = true
        }

        Task {
            try? await Task.sleep(nanoseconds: 320_000_000)

            let started = await focusSession.startRequestedSession(
                mode: selectedMode,
                durationMinutes: resolvedMinutes,
                goal: selectedGoal,
                style: selectedStyle
            )

            if !started {
                print("FOCUS START FAILED")
            }

            try? await Task.sleep(nanoseconds: 280_000_000)

            await MainActor.run {
                isLaunchingFocus = false
            }
        }
    }
    
    var inviteBannerCard: some View {
        Group {
            if let payload = invitePayload {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Focus’a davet edildin")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text("\(payload.hostName) seni \(payload.durationMinutes) dk crew focusa çağırıyor.")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.76))

                    if let taskTitle = payload.taskTitle, !taskTitle.isEmpty {
                        Text("Görev: \(taskTitle)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    HStack(spacing: 10) {
                        Button {
                            Task {
                                await joinInviteSession(payload)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if isJoiningInvite {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "person.badge.plus")
                                }

                                Text(isJoiningInvite ? "Katılıyor..." : "Katıl")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.green)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isJoiningInvite)

                        Button {
                            invitePayload = nil
                        } label: {
                            Text("Şimdi değil")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.82))
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.green.opacity(0.22), lineWidth: 1)
                        )
                )
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
                return "Duraklatıldı"
            }

            switch focusSession.selectedMode {
            case .personal:
                return "Aktif session"
            case .crew:
                return "\(focusSession.readyCount)/\(max(focusSession.participantCount, 1)) hazır"
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
                    Text("Crew Focus Başlat")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("Crew, görev ve katılımcıları seç. Görevsiz de başlatabilirsin.")
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
                            Text("Crew Focus Başlat")
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
            Text("Özet")
                .font(.system(size: 15, weight: .heavy, design: .rounded))

            HStack(spacing: 10) {
                summaryMiniPill(
                    title: "Süre",
                    value: durationText
                )

                summaryMiniPill(
                    title: "Görev",
                    value: selectedCrewTaskID == nil ? "Yok" : "Seçili"
                )

                summaryMiniPill(
                    title: "Kişi",
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

                            Text("Crew alanı")
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
            Text("Görev")
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
                        Text("Görevsiz başlat")
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
                Text("Katılımcılar")
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

                            Text(isLocked ? "Zorunlu katılımcı" : member.role.capitalized)
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

    func crewInviteJoinSheet(payload: CrewFocusInvitePayload) -> some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Text("Takım odakta")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))

                    Text("\(payload.hostName) \(payload.durationMinutes) dk focus başlattı.")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if let taskTitle = payload.taskTitle, !taskTitle.isEmpty {
                        Text("Görev: \(taskTitle)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                }

                Button {
                    Task {
                        await joinInviteSession(payload)
                    }
                } label: {
                    HStack(spacing: 10) {
                        if isJoiningInvite {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "person.badge.plus")
                        }

                        Text(isJoiningInvite ? "Katılıyor..." : "Katıl")
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
                                        Color.green.opacity(0.95),
                                        Color.blue.opacity(0.85)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(isJoiningInvite)

                Button("Şimdi değil") {
                    invitePayload = nil
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))

                Spacer()
            }
            .padding(20)
        }
        .presentationDetents([.medium])
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
            print("CREW START BLOCKED: en az 1 davetli katılımcı seçilmeli")
            return
        }

        await MainActor.run {
            showCrewStartSheet = false
            withAnimation(.easeInOut(duration: 0.24)) {
                isLaunchingFocus = true
            }
        }

        let task = activeCrewTasks.first(where: { $0.id == selectedCrewTaskID })
        let hostName = focusSession.currentUserDisplayName

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
            }

            await FocusInviteService.shared.sendInvites(
                sessionID: dto.id,
                crewID: crewID,
                participantIDs: Array(invitedParticipantIDs),
                hostName: hostName,
                duration: resolvedMinutes,
                taskTitle: task?.title
            )
        } catch {
            print("CREW START SHEET ERROR:", error.localizedDescription)
        }

        try? await Task.sleep(nanoseconds: 250_000_000)

        await MainActor.run {
            isLaunchingFocus = false
        }
    }
    
    func isLockedParticipant(_ member: CrewMemberDTO) -> Bool {
        member.role.lowercased() == "owner" || member.user_id == focusSession.currentUserID
    }

    func joinInviteSession(_ payload: CrewFocusInvitePayload) async {
        isJoiningInvite = true
        defer { isJoiningInvite = false }

        do {
            try await crewStore.joinCrewFocusSession(
                sessionID: payload.sessionID,
                crewID: payload.crewID,
                userID: focusSession.currentUserID,
                memberName: focusSession.currentUserDisplayName
            )

            await crewStore.loadActiveFocusSession(for: payload.crewID)

            guard let dto = crewStore.activeFocusSessionByCrew[payload.crewID] else {
                await MainActor.run {
                    invitePayload = nil
                }
                return
            }

            await crewStore.loadFocusParticipants(sessionID: dto.id)
            let participants = crewStore.focusParticipantsBySession[dto.id] ?? []

            await MainActor.run {
                selectedMode = .crew
                focusSession.hydrateFromCrewSessionDTO(
                    dto,
                    crewID: payload.crewID,
                    participantsDTO: participants,
                    preferredGoal: selectedGoal,
                    preferredStyle: selectedStyle
                )
                invitePayload = nil
                focusSession.expandSession()
            }
        } catch {
            print("JOIN INVITE ERROR:", error.localizedDescription)
        }
    }

    func parseInvitePayload(_ userInfo: [AnyHashable: Any]) -> CrewFocusInvitePayload? {
        guard
            let crewIDString = userInfo["crew_id"] as? String,
            let sessionIDString = userInfo["session_id"] as? String,
            let hostName = userInfo["host_name"] as? String,
            let crewID = UUID(uuidString: crewIDString),
            let sessionID = UUID(uuidString: sessionIDString)
        else {
            return nil
        }

        let taskTitle = userInfo["task_title"] as? String

        let duration: Int
        if let intValue = userInfo["duration_minutes"] as? Int {
            duration = intValue
        } else if let stringValue = userInfo["duration_minutes"] as? String,
                  let parsed = Int(stringValue) {
            duration = parsed
        } else {
            duration = 25
        }

        return CrewFocusInvitePayload(
            crewID: crewID,
            sessionID: sessionID,
            hostName: hostName,
            durationMinutes: duration,
            taskTitle: taskTitle
        )
    }
    
    func loadCrewStartDependenciesIfNeeded() async {
        guard let crewID = selectedCrewID else { return }

        await crewStore.loadMembers(for: crewID)
        await crewStore.loadMemberProfiles(for: crewStore.crewMembers)
        await crewStore.loadTasks(for: crewID)
        await crewStore.loadActiveFocusSession(for: crewID)
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

        return "Kullanıcı"
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

                Text("Focus hazırlanıyor")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
        }
    }

    var ambientBackground: some View {
        ZStack(alignment: .topLeading) {
            RadialGradient(
                colors: [
                    selectedModeAccent.opacity(0.14),
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
                return focusSession.isPaused ? "Duraklatıldı" : "Aktif"
            case .crew:
                return "\(focusSession.readyCount)/\(max(focusSession.participantCount, 1)) hazır"
            case .friend:
                return focusSession.participantCount >= 2 ? "2/2 hazır" : "Bekleniyor"
            }
        }

        switch selectedMode {
        case .personal: return "Hazır"
        case .crew: return "Takım hazır"
        case .friend: return "Eşleşti"
        }
    }

    var selectedModeAccent: Color {
        switch selectedMode {
        case .personal:
            return Color(red: 0.42, green: 0.66, blue: 1.00)
        case .crew:
            return Color(red: 1.00, green: 0.46, blue: 0.54)
        case .friend:
            return Color(red: 0.88, green: 0.56, blue: 1.00)
        }
    }

    var selectedModeSecondaryAccent: Color {
        switch selectedMode {
        case .personal:
            return Color(red: 0.66, green: 0.54, blue: 1.00)
        case .crew:
            return Color(red: 1.00, green: 0.72, blue: 0.58)
        case .friend:
            return Color(red: 0.72, green: 0.60, blue: 1.00)
        }
    }

    var modeCTA: String {
        switch selectedMode {
        case .personal: return "Kişisel Focus Başlat"
        case .crew: return "Crew Focus Başlat"
        case .friend: return "Friend Focus Başlat"
        }
    }

    var customDurationSheet: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Text("Özel Süre")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("Focus oturumun için istediğin süreyi seç.")
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
                Text("Goal Seç")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Bu session’ın amacını belirle.")
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
                Text("Sound Seç")
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

private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}
