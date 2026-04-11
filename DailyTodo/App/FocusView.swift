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

    @State private var selectedGoal: FocusGoal = .study
    @State private var selectedStyle: FocusStyle = .silent

    @State private var showCustomDurationSheet = false
    @State private var showGoalPicker = false
    @State private var showStylePicker = false

    @State private var pageAppeared = false
    @State private var isLaunchingFocus = false

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
                            mode: selectedMode,
                            durationText: durationText,
                            statusText: heroStatusText,
                            metaText: "\(selectedGoal.title) • \(selectedStyle.title)",
                            progress: heroProgress,
                            isLaunching: isLaunchingFocus
                        )

                        compactControlsSection

                        bigStartButton

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
                .foregroundStyle(selectedPreset == preset ? Color.white : palette.secondaryText.opacity(0.84))
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
                .foregroundStyle(selectedPreset == .custom ? Color.white : palette.secondaryText.opacity(0.84))
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
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.34))
                }
                .padding(.horizontal, 14)
            }
            .frame(height: 84)
        }
        .buttonStyle(.plain)
    }

    var bigStartButton: some View {
        Button {
            triggerFocusLaunch()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .bold))

                Text(modeCTA)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .opacity(0.86)
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 22)
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                selectedModeAccent.opacity(1.0),
                                selectedModeAccent.opacity(0.80)
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
            .shadow(color: selectedModeAccent.opacity(0.34), radius: 22, x: 0, y: 12)
        }
        .buttonStyle(PressScaleButtonStyle())
        .padding(.top, 2)
        .opacity(isLaunchingFocus ? 0.0 : 1)
        .offset(y: isLaunchingFocus ? 8 : 0)
        .animation(.easeInOut(duration: 0.18), value: isLaunchingFocus)
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
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.01, green: 0.02, blue: 0.07),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(selectedModeAccent.opacity(0.16))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: 135, y: -220)

            Circle()
                .fill(selectedModeSecondaryAccent.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 96)
                .offset(x: -150, y: 380)
        }
        .ignoresSafeArea()
    }

    var resolvedMinutes: Int {
        switch selectedPreset {
        case .short:
            return 15
        case .medium:
            return 25
        case .long:
            return 45
        case .custom:
            return customMinutes
        }
    }

    var durationText: String {
        switch selectedPreset {
        case .short:
            return "15 dk"
        case .medium:
            return "25 dk"
        case .long:
            return "45 dk"
        case .custom:
            return "\(customMinutes) dk"
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
        case .personal:
            return "Hazır"
        case .crew:
            return "Takım hazır"
        case .friend:
            return "Eşleşti"
        }
    }

    var selectedModeAccent: Color {
        switch selectedMode {
        case .personal:
            return Color(red: 0.40, green: 0.62, blue: 1.00)
        case .crew:
            return Color(red: 1.00, green: 0.42, blue: 0.50)
        case .friend:
            return Color(red: 0.86, green: 0.52, blue: 1.00)
        }
    }

    var selectedModeSecondaryAccent: Color {
        switch selectedMode {
        case .personal:
            return Color(red: 0.56, green: 0.44, blue: 1.00)
        case .crew:
            return Color(red: 1.00, green: 0.62, blue: 0.46)
        case .friend:
            return Color(red: 0.58, green: 0.50, blue: 1.00)
        }
    }

    var modeCTA: String {
        switch selectedMode {
        case .personal:
            return "Kişisel Focus Başlat"
        case .crew:
            return "Crew Focus Başlat"
        case .friend:
            return "Friend Focus Başlat"
        }
    }

    func triggerFocusLaunch() {
        withAnimation(.easeInOut(duration: 0.24)) {
            isLaunchingFocus = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            startFocusSession()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) {
            isLaunchingFocus = false
        }
    }

    func startFocusSession() {
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
