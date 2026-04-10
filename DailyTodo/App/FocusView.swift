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

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    @State private var selectedMode: FocusMode = .personal
    @State private var selectedPreset: FocusDurationPreset = .medium
    @State private var customMinutes: Int = 60
    @State private var showCustomDurationSheet = false
    @State private var pageAppeared = false
    
    @State private var selectedGoal: FocusGoal = .study
    @State private var selectedStyle: FocusStyle = .silent
    
    @State private var showGoalPicker = false
    @State private var showStylePicker = false

    var body: some View {
        ZStack {
            AppBackground()
            ambientBackground

            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        Color.clear
                            .frame(height: 2)

                        pageHeader

                        FocusModeSwitcherV3(selectedMode: $selectedMode)

                        if focusSession.isSessionActive {
                            activeSessionBanner
                        }
                        
                      

                        FocusHeroCardV3(
                            mode: selectedMode,
                            selectedPreset: selectedPreset,
                            customMinutes: customMinutes,
                            progress: heroProgress,
                            statusText: heroStatusText,
                            supportText: heroSupportText,
                            selectedGoal: selectedGoal,
                            selectedStyle: selectedStyle,
                            preSessionTitle: preSessionTitle,
                            preSessionSubtitle: preSessionSubtitle,
                            preSessionParticipants: preSessionParticipants,
                            preSessionCanStart: preSessionCanStart,
                            onSelectPreset: { preset in
                                if preset == .custom {
                                    showCustomDurationSheet = true
                                } else {
                                    selectedPreset = preset
                                }
                            },
                            onTapGoal: {
                                showGoalPicker = true
                            },
                            onTapStyle: {
                                showStylePicker = true
                            },
                            onTapCTA: {
                                startFocusSession()
                            }
                        )

                        FocusDetailSectionV3(mode: selectedMode)

                        Color.clear
                            .frame(height: 88)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
                    .frame(minHeight: geo.size.height, alignment: .top)
                }
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
        .fullScreenCover(isPresented: $focusSession.isExpanded) {
            ActiveFocusView()
                .environmentObject(focusSession)
        }
        .onAppear {
            pageAppeared = true
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

    var activeSessionBanner: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)

            Text(focusSession.statusLine)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText.opacity(0.9))

            Spacer()

            Button("Devam Et") {
                focusSession.expandSession()
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }

    var ambientBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.015, green: 0.02, blue: 0.07),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.blue.opacity(0.08))
                .frame(width: 270, height: 270)
                .blur(radius: 70)
                .offset(x: 128, y: -220)

            Circle()
                .fill(Color.purple.opacity(0.05))
                .frame(width: 230, height: 230)
                .blur(radius: 78)
                .offset(x: -145, y: 380)
        }
        .ignoresSafeArea()
    }

    var resolvedMinutes: Int {
        if selectedPreset == .custom {
            return customMinutes
        }
        return selectedPreset.minuteValue ?? customMinutes
    }

    var heroPreset: FocusDurationPreset {
        selectedPreset
    }

    var heroProgress: Double {
        if focusSession.isSessionActive && focusSession.selectedMode == selectedMode {
            return focusSession.progress
        }

        switch resolvedMinutes {
        case 0..<20: return 0.57
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
        case .personal:
            return "Hazır"
        case .crew:
            return "Takım hazır"
        case .friend:
            return "Eşleşti"
        }
    }

    var heroSupportText: String {
        switch selectedMode {
        case .personal:
            if focusSession.isSessionActive && focusSession.selectedMode == .personal {
                return focusSession.isPaused ? "devam etmeyi bekliyor" : "şu an çalışıyor"
            }
            return resolvedMinutes >= 60 ? "uzun süreli derin çalışma" : "başlamaya uygun"

        case .crew:
            if let hostName = focusSession.hostName, focusSession.selectedMode == .crew, focusSession.isSessionActive {
                return "host: \(hostName) • \(focusSession.readyCount)/\(focusSession.participantCount) hazır"
            }
            return "host ve katılımcılarla başlatılabilir"

        case .friend:
            if focusSession.selectedMode == .friend, focusSession.isSessionActive {
                return "eşleşme aktif • birlikte odaklanıyorsunuz"
            }
            return "beraber odaklanmaya hazır"
        }
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
                                                .fill(Color.purple.opacity(0.85))
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
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.purple.opacity(0.95), Color.blue.opacity(0.75)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
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
    
    var preSessionParticipants: [FocusParticipant] {
        switch selectedMode {
        case .personal:
            return []
        case .crew:
            return FocusParticipant.mockCrew
        case .friend:
            return FocusParticipant.mockFriend
        }
    }

    var preSessionHostName: String {
        preSessionParticipants.first(where: { $0.isHost })?.name ?? "Atakan"
    }

    var preSessionReadyCount: Int {
        preSessionParticipants.filter(\.isReady).count
    }

    var preSessionParticipantCount: Int {
        preSessionParticipants.count
    }

    var preSessionCanStart: Bool {
        switch selectedMode {
        case .personal:
            return true
        case .crew:
            return preSessionReadyCount >= 2
        case .friend:
            return preSessionReadyCount == preSessionParticipantCount && preSessionParticipantCount >= 2
        }
    }

    var preSessionTitle: String {
        switch selectedMode {
        case .personal:
            return "Hazırsın"
        case .crew:
            return "Crew lobby"
        case .friend:
            return "Pair lobby"
        }
    }

    var preSessionSubtitle: String {
        switch selectedMode {
        case .personal:
            return "Kişisel odak için her şey hazır."
        case .crew:
            return "\(preSessionHostName) host olarak bekliyor • \(preSessionReadyCount)/\(preSessionParticipantCount) hazır"
        case .friend:
            return "\(preSessionReadyCount)/\(preSessionParticipantCount) kişi hazır • birlikte başlayabilirsiniz"
        }
    }

    func startFocusSession() {
        guard preSessionCanStart else { return }

        let participants: [FocusParticipant]
        switch selectedMode {
        case .personal:
            participants = []
        case .crew:
            participants = FocusParticipant.mockCrew
        case .friend:
            participants = FocusParticipant.mockFriend
        }

        focusSession.startSession(
            mode: selectedMode,
            durationMinutes: resolvedMinutes,
            goal: selectedGoal,
            style: selectedStyle,
            participants: participants
        )
    }
    
    var focusSetupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Session Setup")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                Spacer()
            }

            HStack(spacing: 10) {
                setupCard(
                    title: "Goal",
                    value: selectedGoal.title,
                    subtitle: selectedGoal.subtitle,
                    icon: selectedGoal.icon
                )

                setupCard(
                    title: "Sound",
                    value: selectedStyle.title,
                    subtitle: selectedStyle.subtitle,
                    icon: selectedStyle.icon
                )
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(FocusGoal.allCases) { goal in
                        choiceChip(
                            title: goal.title,
                            isSelected: selectedGoal == goal
                        ) {
                            selectedGoal = goal
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(FocusStyle.allCases) { style in
                        choiceChip(
                            title: style.title,
                            isSelected: selectedStyle == style
                        ) {
                            selectedStyle = style
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.025))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }

    func setupCard(title: String, value: String, subtitle: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.9))

                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.secondaryText.opacity(0.7))
                    .tracking(1)
            }

            Text(value)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(palette.primaryText)

            Text(subtitle)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.secondaryText.opacity(0.75))
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }

    func choiceChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? Color.white.opacity(0.96) : palette.secondaryText.opacity(0.82))
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.white.opacity(0.10) : Color.white.opacity(0.04))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(isSelected ? 0.10 : 0.05), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    var customDurationSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Özel Focus Süresi")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)

                Text("5 ile 180 dakika arasında istediğin süreyi seç.")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Picker("Süre", selection: $customMinutes) {
                    ForEach(5...180, id: \.self) { minute in
                        Text("\(minute) dk").tag(minute)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 220)

                Button {
                    selectedPreset = .custom
                    showCustomDurationSheet = false
                } label: {
                    Text("Bu Süreyi Kullan")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.blue)
                        )
                }

                Spacer()
            }
            .padding(24)
        }
        .presentationDetents([.medium])
    }
}
