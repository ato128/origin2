//
//  AppOnboardingFlowView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 28.04.2026.
//

import SwiftUI
import SwiftData
import UIKit

enum AppOnboardingStage: String, CaseIterable {
    case welcome
    case student
    case focus
    case crew
    case community
    case ready
}

private enum OnboardingArenaPalette {
    static let backgroundTop = "#05060D"
    static let backgroundMid = "#070713"
    static let backgroundBottom = "#07040C"

    static let appBlue = "#1593FF"
    static let appBlueSoft = "#1E6BFF"
    static let appCyan = "#2DD4FF"
    static let appPurple = "#7C3AED"
    static let appViolet = "#8B5CF6"
    static let coral = "#FF5A44"
    static let gold = "#FBBF24"
    static let green = "#A3E635"

    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(arenaHex: appCyan),
                Color(arenaHex: appPurple),
                Color(arenaHex: coral)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var actionGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(arenaHex: appBlue),
                Color(arenaHex: appPurple),
                Color(arenaHex: coral)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var focusGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(arenaHex: appCyan),
                Color(arenaHex: appPurple)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var crewGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(arenaHex: coral),
                Color(arenaHex: gold)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var communityGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(arenaHex: gold),
                Color(arenaHex: coral),
                Color(arenaHex: appPurple)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var cardGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.055),
                Color(arenaHex: appBlue).opacity(0.040),
                Color(arenaHex: appPurple).opacity(0.050)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct AppOnboardingFlowView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var studentStore: StudentStore
    @EnvironmentObject var friendStore: FriendStore
    @EnvironmentObject var crewStore: CrewStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("appOnboardingStageV2") private var stageRawValue = AppOnboardingStage.welcome.rawValue
    @AppStorage("didFinishFullOnboardingV2") private var didFinishFullOnboarding = false

    @State private var isFinishing = false
    @State private var finishError: String?
    @State private var welcomeAppeared = false

    private var stage: AppOnboardingStage {
        AppOnboardingStage(rawValue: stageRawValue) ?? .welcome
    }

    var body: some View {
        ZStack {
            switch stage {
            case .welcome:
                welcomeScreen
                    .transition(screenTransition)

            case .student:
                // The AI flow calls onComplete deterministically after saving —
                // we no longer rely on observing the computed hasCompletedStudentProfile
                // (which didn't fire the live transition reliably).
                AIOnboardingFlowView(onComplete: { goToFocusPreview() })
                    .environmentObject(studentStore)
                    .transition(screenTransition)

            case .focus:
                // "Sell the app" — premium Arena showcase of all five pillars,
                // ending in the paywall, then enters the app.
                OnboardingShowcaseView(onFinish: { enterApp() })
                    .transition(screenTransition)

            case .crew:
                crewScreen
                    .transition(screenTransition)

            case .community:
                communityScreen
                    .transition(screenTransition)

            case .ready:
                readyScreen
                    .transition(screenTransition)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            normalizeStage()
            crewStore.setCurrentUser(session.currentUser?.id)
        }
        // NOTE: the live student→focus transition is driven (animated) by the
        // `.student` stage's own onChange → goToFocusPreview(). We deliberately do
        // NOT re-run normalizeStage() on that change, because its un-animated
        // stageRawValue write would pre-empt and "snap" the transition.
    }

    private var screenTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.985))
    }

    private func normalizeStage() {
        if didFinishFullOnboarding, studentStore.hasCompletedStudentProfile {
            stageRawValue = AppOnboardingStage.ready.rawValue
            return
        }

        if AppOnboardingStage(rawValue: stageRawValue) == nil {
            stageRawValue = studentStore.hasCompletedStudentProfile
                ? AppOnboardingStage.focus.rawValue
                : AppOnboardingStage.welcome.rawValue
            return
        }

        if stage == .student, studentStore.hasCompletedStudentProfile {
            stageRawValue = AppOnboardingStage.focus.rawValue
        }

        if (stage == .focus || stage == .crew || stage == .community || stage == .ready),
           !studentStore.hasCompletedStudentProfile {
            stageRawValue = AppOnboardingStage.student.rawValue
        }
    }

    private func goToStudentSetup() {
        setStage(.student, haptic: true)
    }

    private func goToFocusPreview() {
        setStage(.focus, haptic: true, success: true)
    }

    private func goToCrewPreview() {
        setStage(.crew, haptic: true)
    }

    private func goToCommunityPreview() {
        setStage(.community, haptic: true)
    }

    private func goToReady() {
        setStage(.ready, haptic: true)
    }

    private func setStage(_ newStage: AppOnboardingStage, haptic: Bool, success: Bool = false) {
        if haptic {
            success ? OnboardingHaptics.success() : OnboardingHaptics.softTap()
        }

        let update = {
            stageRawValue = newStage.rawValue
        }

        if reduceMotion {
            update()
        } else {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                update()
            }
        }
    }

    private func enterApp() {
        guard !isFinishing else { return }

        Task { @MainActor in
            isFinishing = true
            finishError = nil

            await studentStore.loadFromRemote()

            guard studentStore.hasCompletedStudentProfile else {
                isFinishing = false
                finishError = "Student setup could not be verified. Please complete setup again."
                OnboardingHaptics.warning()

                withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                    stageRawValue = AppOnboardingStage.student.rawValue
                }
                return
            }

            crewStore.setCurrentUser(session.currentUser?.id)
            await crewStore.loadCrews(force: true)
            await crewStore.loadCrewHomeSnapshot()
            await crewStore.loadFocusStateForAllCrews()

            OnboardingHaptics.success()

            try? await Task.sleep(nanoseconds: 260_000_000)

            withAnimation(.easeInOut(duration: 0.24)) {
                didFinishFullOnboarding = true
                stageRawValue = AppOnboardingStage.ready.rawValue
            }

            isFinishing = false
        }
    }
}

// MARK: - Screens

private extension AppOnboardingFlowView {
    var welcomeScreen: some View {
        ZStack {
            // The app's own signature field — multi-color edge-lit glows.
            ArenaBackground(
                primaryGlow: Color(arenaHex: AppArenaPalette.cyan),
                secondaryGlow: Color(arenaHex: AppArenaPalette.purple),
                warmGlow: Color(arenaHex: AppArenaPalette.coral),
                intensity: 1.0
            )

            VStack(spacing: 0) {
                Spacer()

                // App mark — directional brand glyph on the app gradient.
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(AppArenaPalette.appGradient)
                        .frame(width: 98, height: 98)
                        .shadow(color: Color(arenaHex: AppArenaPalette.purple).opacity(0.5), radius: 28, y: 14)
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 44, weight: .black))
                        .foregroundStyle(.white)
                }
                .scaleEffect(welcomeAppeared ? 1 : 0.82)
                .opacity(welcomeAppeared ? 1 : 0)

                // Monospaced tracked eyebrow with rule lines.
                HStack(spacing: 8) {
                    Rectangle().fill(Color(arenaHex: AppArenaPalette.cyan)).frame(width: 18, height: 1)
                    Text(tr("ob_sc_welcome_eyebrow"))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(2.4)
                        .foregroundStyle(Color(arenaHex: AppArenaPalette.cyan))
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Rectangle().fill(Color(arenaHex: AppArenaPalette.cyan)).frame(width: 18, height: 1)
                }
                .padding(.top, 30)
                .opacity(welcomeAppeared ? 1 : 0)

                // Wordmark — "Up" black + "do" italic serif blue (brand identity).
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("Up")
                        .font(.system(size: 64, weight: .black))
                        .foregroundStyle(.white)
                    Text("do")
                        .font(.system(size: 60, weight: .regular, design: .serif)).italic()
                        .foregroundStyle(Color(arenaHex: AppArenaPalette.blue))
                }
                .padding(.top, 12)
                .opacity(welcomeAppeared ? 1 : 0)

                Text(tr("ob_sc_welcome_sub"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.56))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 44)
                    .padding(.top, 12)
                    .opacity(welcomeAppeared ? 1 : 0)

                Spacer()

                Button {
                    HapticManager.shared.action()
                    goToStudentSetup()
                } label: {
                    HStack(spacing: 8) {
                        Text(tr("ob_sc_welcome_cta"))
                            .font(.system(size: 17, weight: .black))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .black))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [Color(arenaHex: AppArenaPalette.cyan), Color(arenaHex: AppArenaPalette.blue)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .shadow(color: Color(arenaHex: AppArenaPalette.cyan).opacity(0.3), radius: 16, y: 8)
                    )
                }
                .buttonStyle(OnboardingScaleButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.78).delay(0.12)) { welcomeAppeared = true }
        }
    }

    var focusScreen: some View {
        OnboardingShell(
            progressText: "3 / 6",
            title: tr("ob_sc_focus_title"),
            accent: tr("ob_sc_focus_accent"),
            subtitle: tr("ob_sc_focus_sub"),
            keywords: tr("ob_sc_focus_keywords"),
            primaryTitle: tr("ob_sc_continue"),
            primaryIcon: "arrow.right",
            isPrimaryLoading: false,
            primaryAction: goToCrewPreview
        ) {
            FocusExperienceHero()
        }
    }

    var crewScreen: some View {
        OnboardingShell(
            progressText: "4 / 6",
            title: tr("ob_sc_crew_title"),
            accent: tr("ob_sc_crew_accent"),
            subtitle: tr("ob_sc_crew_sub"),
            keywords: tr("ob_sc_crew_keywords"),
            primaryTitle: tr("ob_sc_continue"),
            primaryIcon: "arrow.right",
            isPrimaryLoading: false,
            primaryAction: goToCommunityPreview
        ) {
            CrewExperienceHero()
        }
    }

    var communityScreen: some View {
        OnboardingShell(
            progressText: "5 / 6",
            title: tr("ob_sc_comm_title"),
            accent: tr("ob_sc_comm_accent"),
            subtitle: tr("ob_sc_comm_sub"),
            keywords: tr("ob_sc_comm_keywords"),
            primaryTitle: tr("ob_sc_continue"),
            primaryIcon: "arrow.right",
            isPrimaryLoading: false,
            primaryAction: goToReady
        ) {
            CommunityExperienceHero()
        }
    }

    var readyScreen: some View {
        OnboardingShell(
            progressText: "6 / 6",
            title: tr("ob_sc_ready_title"),
            accent: tr("ob_sc_ready_accent"),
            subtitle: tr("ob_sc_ready_sub"),
            keywords: tr("ob_sc_ready_keywords"),
            primaryTitle: isFinishing ? tr("ob_sc_preparing") : tr("ob_sc_enter_updo"),
            primaryIcon: isFinishing ? "clock" : "arrow.right.circle.fill",
            isPrimaryLoading: isFinishing,
            primaryAction: enterApp
        ) {
            ReadyExperienceHero(
                educationText: educationSummary,
                coursesCount: max(studentStore.courses.count, 1),
                dailyGoal: studentStore.profile?.dailyStudyGoalMinutes ?? 120,
                finishError: finishError
            )
        }
    }

    private var educationSummary: String {
        guard let profile = studentStore.profile else {
            return "Student profile"
        }

        if profile.educationLevel == "high_school" {
            let grade = profile.gradeLevel
            let track = profile.highSchoolTrack ?? "Track"
            return "High School • \(grade) • \(track)"
        }

        let year = profile.gradeLevel == "prep" ? "Prep" : "\(profile.gradeLevel). Year"
        let major = profile.majorName ?? "Major"
        return "\(year) • \(major)"
    }
}

// MARK: - Shell

private struct OnboardingShell<Content: View>: View {
    let progressText: String
    let title: String
    let accent: String
    let subtitle: String
    let keywords: String
    let primaryTitle: String
    let primaryIcon: String
    let isPrimaryLoading: Bool
    let primaryAction: () -> Void
    let content: Content

    init(
        progressText: String,
        title: String,
        accent: String,
        subtitle: String,
        keywords: String,
        primaryTitle: String,
        primaryIcon: String,
        isPrimaryLoading: Bool,
        primaryAction: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.progressText = progressText
        self.title = title
        self.accent = accent
        self.subtitle = subtitle
        self.keywords = keywords
        self.primaryTitle = primaryTitle
        self.primaryIcon = primaryIcon
        self.isPrimaryLoading = isPrimaryLoading
        self.primaryAction = primaryAction
        self.content = content()
    }

    var body: some View {
        ZStack {
            OnboardingArenaBackground()
                .ignoresSafeArea()

            GeometryReader { proxy in
                VStack(spacing: 0) {
                    topBar

                    VStack(alignment: .leading, spacing: spacing(for: proxy.size.height)) {
                        hero
                        content
                            .frame(maxWidth: .infinity)
                            .frame(height: visualHeight(for: proxy.size.height))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .safeAreaInset(edge: .bottom) {
                    bottomButton
                }
            }
        }
    }

    private func spacing(for height: CGFloat) -> CGFloat {
        height < 720 ? 15 : 19
    }

    private func visualHeight(for height: CGFloat) -> CGFloat {
        if height < 700 { return 350 }
        if height < 760 { return 380 }
        return 410
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 7) {
                Capsule()
                    .fill(OnboardingArenaPalette.brandGradient)
                    .frame(width: 20, height: 2)

                Text(progressText)
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color(arenaHex: OnboardingArenaPalette.appCyan))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.055))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.090), lineWidth: 1)
                    )
            )

            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 48, weight: .heavy))
                .foregroundStyle(.white)
                .tracking(-1.25)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Text(accent)
                .font(.system(size: 29, weight: .semibold))
                .foregroundStyle(OnboardingArenaPalette.brandGradient)
                .tracking(-0.45)
                .lineLimit(1)
                .minimumScaleFactor(0.70)

            Text(subtitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(2)
                .minimumScaleFactor(0.84)
                .padding(.top, 2)

            Text(keywords)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(Color(arenaHex: OnboardingArenaPalette.appCyan).opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .padding(.top, 5)
        }
    }

    private var bottomButton: some View {
        Button(action: primaryAction) {
            HStack(spacing: 10) {
                if isPrimaryLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.84)
                }

                Text(primaryTitle)
                    .font(.system(size: 16, weight: .heavy))

                Image(systemName: primaryIcon)
                    .font(.system(size: 16, weight: .heavy))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Capsule()
                    .fill(OnboardingArenaPalette.actionGradient)
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(
                color: Color(arenaHex: OnboardingArenaPalette.appPurple).opacity(0.28),
                radius: 18,
                y: 9
            )
        }
        .buttonStyle(OnboardingPressButtonStyle())
        .disabled(isPrimaryLoading)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.78),
                    Color.black.opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

// MARK: - Welcome

private struct BrandOpeningHero: View {
    @State private var pulse = false
    @State private var rotate = false

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color(arenaHex: OnboardingArenaPalette.appCyan).opacity(0.18),
                    Color(arenaHex: OnboardingArenaPalette.appPurple).opacity(0.15),
                    Color(arenaHex: OnboardingArenaPalette.coral).opacity(0.08),
                    Color.clear
                ],
                center: .center,
                startRadius: 18,
                endRadius: 220
            )
            .blur(radius: 4)
            .scaleEffect(pulse ? 1.06 : 0.96)

            Circle()
                .stroke(Color.white.opacity(0.060), lineWidth: 1)
                .frame(width: 265, height: 265)

            Circle()
                .stroke(Color.white.opacity(0.045), lineWidth: 1)
                .frame(width: 185, height: 185)

            Circle()
                .trim(from: 0.08, to: 0.76)
                .stroke(
                    OnboardingArenaPalette.brandGradient,
                    style: StrokeStyle(lineWidth: 3.2, lineCap: .round)
                )
                .frame(width: 250, height: 250)
                .rotationEffect(.degrees(rotate ? 360 : 0))
                .opacity(0.85)

            ZStack {
                Circle()
                    .fill(OnboardingArenaPalette.brandGradient)
                    .frame(width: 104, height: 104)
                    .shadow(
                        color: Color(arenaHex: OnboardingArenaPalette.appPurple).opacity(0.36),
                        radius: 24,
                        y: 10
                    )

                Image(systemName: "location.north.fill")
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundStyle(.white)
                    .offset(y: -2)
            }
            .scaleEffect(pulse ? 1.02 : 1.0)

            EnergyNode(text: "PLAN", color: Color(arenaHex: OnboardingArenaPalette.appCyan))
                .offset(x: -118, y: -78)

            EnergyNode(text: "FOCUS", color: Color(arenaHex: OnboardingArenaPalette.appPurple))
                .offset(x: 118, y: -42)

            EnergyNode(text: "CREW", color: Color(arenaHex: OnboardingArenaPalette.coral))
                .offset(x: -92, y: 102)

            EnergyNode(text: "GROW", color: Color(arenaHex: OnboardingArenaPalette.green))
                .offset(x: 112, y: 90)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                pulse = true
            }

            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                rotate = true
            }
        }
    }
}

private struct EnergyNode: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .tracking(1.4)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(color.opacity(0.34), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Focus

private struct FocusExperienceHero: View {
    @State private var progress: CGFloat = 0.70
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 14) {
            ProductStageCard {
                VStack(spacing: 15) {
                    HStack {
                        Text("SESSION")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(1.8)
                            .foregroundStyle(Color(arenaHex: OnboardingArenaPalette.appCyan))

                        Spacer()

                        Text("LIVE")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.78))
                            .padding(.horizontal, 10)
                            .frame(height: 27)
                            .background(
                                Capsule()
                                    .fill(Color(arenaHex: OnboardingArenaPalette.green))
                            )
                    }

                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(arenaHex: OnboardingArenaPalette.appCyan).opacity(0.16),
                                        Color(arenaHex: OnboardingArenaPalette.appPurple).opacity(0.10),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 120
                                )
                            )
                            .frame(width: 205, height: 205)
                            .blur(radius: 7)

                        Circle()
                            .stroke(Color.white.opacity(0.070), lineWidth: 11)
                            .frame(width: 160, height: 160)

                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                OnboardingArenaPalette.focusGradient,
                                style: StrokeStyle(lineWidth: 11, lineCap: .round)
                            )
                            .frame(width: 160, height: 160)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 2) {
                            Text("18:42")
                                .font(.system(size: 40, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.white)

                            Text("Deep Work")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(arenaHex: OnboardingArenaPalette.appCyan))
                        }
                    }
                    .frame(height: 168)

                    HStack(spacing: 10) {
                        MicroProductCard(title: "GOAL", value: "Study", icon: "target", tint: Color(arenaHex: OnboardingArenaPalette.appCyan))
                        MicroProductCard(title: "LIVE", value: "Island", icon: "iphone", tint: Color(arenaHex: OnboardingArenaPalette.appPurple))
                    }
                }
            }

            LiveActivityPreview()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                progress = 0.84
                pulse = true
            }
        }
    }
}

private struct LiveActivityPreview: View {
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.11), lineWidth: 5)
                    .frame(width: 38, height: 38)

                Circle()
                    .trim(from: 0, to: 0.68)
                    .stroke(
                        OnboardingArenaPalette.focusGradient,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 38, height: 38)
                    .rotationEffect(.degrees(-90))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(tr("ob_sc_study_focus"))
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.white)

                Text(tr("ob_sc_live_on_lock"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
            }

            Spacer()

            Image(systemName: "bolt.fill")
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(Color(arenaHex: OnboardingArenaPalette.gold))
        }
        .padding(.horizontal, 15)
        .frame(height: 70)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.060))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.080), lineWidth: 1)
                )
        )
    }
}

// MARK: - Crew

private struct CrewExperienceHero: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 14) {
            ProductStageCard {
                VStack(spacing: 15) {
                    HStack {
                        Text("CREW ROOM")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(1.8)
                            .foregroundStyle(Color(arenaHex: OnboardingArenaPalette.coral))

                        Spacer()

                        Text("3 LIVE")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Color(arenaHex: OnboardingArenaPalette.gold))
                            .padding(.horizontal, 10)
                            .frame(height: 27)
                            .background(
                                Capsule()
                                    .fill(Color(arenaHex: OnboardingArenaPalette.gold).opacity(0.13))
                            )
                    }

                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.060), style: StrokeStyle(lineWidth: 1, dash: [4, 7]))
                            .frame(width: 178, height: 178)

                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(arenaHex: OnboardingArenaPalette.coral).opacity(0.18),
                                        Color(arenaHex: OnboardingArenaPalette.appPurple).opacity(0.12),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 18,
                                    endRadius: 130
                                )
                            )
                            .frame(width: 215, height: 215)
                            .blur(radius: 7)

                        CrewAvatarBubble(letter: "A", color: Color(arenaHex: OnboardingArenaPalette.appCyan))
                            .offset(x: 0, y: -77)

                        CrewAvatarBubble(letter: "E", color: Color(arenaHex: OnboardingArenaPalette.coral))
                            .offset(x: -75, y: 42)

                        CrewAvatarBubble(letter: "M", color: Color(arenaHex: OnboardingArenaPalette.green))
                            .offset(x: 75, y: 42)

                        ZStack {
                            Circle()
                                .fill(OnboardingArenaPalette.crewGradient)
                                .frame(width: 86, height: 86)
                                .shadow(
                                    color: Color(arenaHex: OnboardingArenaPalette.coral).opacity(0.26),
                                    radius: 22,
                                    y: 9
                                )

                            Image(systemName: "person.3.fill")
                                .font(.system(size: 32, weight: .heavy))
                                .foregroundStyle(.black.opacity(0.74))
                        }
                        .scaleEffect(pulse ? 1.025 : 1.0)
                    }
                    .frame(height: 178)

                    HStack(spacing: 10) {
                        MicroProductCard(title: "FOCUS", value: "Room", icon: "timer", tint: Color(arenaHex: OnboardingArenaPalette.coral))
                        MicroProductCard(title: "TASKS", value: "Shared", icon: "checklist", tint: Color(arenaHex: OnboardingArenaPalette.gold))
                    }
                }
            }

            CrewMessageStrip()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct CrewAvatarBubble: View {
    let letter: String
    let color: Color

    var body: some View {
        Circle()
            .fill(color.opacity(0.18))
            .frame(width: 44, height: 44)
            .overlay(
                Circle()
                    .stroke(color.opacity(0.85), lineWidth: 1.3)
            )
            .overlay(
                Text(letter)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(color)
            )
    }
}

private struct CrewMessageStrip: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(arenaHex: OnboardingArenaPalette.green))
                .frame(width: 42, height: 42)
                .overlay(
                    Text("B")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.black.opacity(0.78))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Burak")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.white)

                Text(tr("ob_demo_msg"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.50))
                    .lineLimit(1)
            }

            Spacer()

            Text("now")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.36))
        }
        .padding(.horizontal, 15)
        .frame(height: 68)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.080), lineWidth: 1)
                )
        )
    }
}

// MARK: - Community

private struct CommunityExperienceHero: View {
    var body: some View {
        VStack(spacing: 14) {
            ProductStageCard {
                VStack(spacing: 15) {
                    HStack {
                        Text("ARENA")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(1.8)
                            .foregroundStyle(Color(arenaHex: OnboardingArenaPalette.gold))

                        Spacer()

                        Text("RANK #3")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Color(arenaHex: OnboardingArenaPalette.gold))
                            .padding(.horizontal, 10)
                            .frame(height: 27)
                            .background(
                                Capsule()
                                    .fill(Color(arenaHex: OnboardingArenaPalette.gold).opacity(0.13))
                            )
                    }

                    VStack(spacing: 10) {
                        LeaderboardRow(rank: "1", name: "Mert", value: "7h 20m", color: Color(arenaHex: OnboardingArenaPalette.gold), isCurrent: false)
                        LeaderboardRow(rank: "2", name: "Ece", value: "6h 45m", color: Color(arenaHex: OnboardingArenaPalette.green), isCurrent: false)
                        LeaderboardRow(rank: "3", name: "You", value: "5h 10m", color: Color(arenaHex: OnboardingArenaPalette.coral), isCurrent: true)
                    }
                    .padding(.vertical, 4)

                    HStack(spacing: 10) {
                        MicroProductCard(title: "SCOPE", value: "Campus", icon: "building.columns.fill", tint: Color(arenaHex: OnboardingArenaPalette.gold))
                        MicroProductCard(title: "MOTION", value: "Weekly", icon: "flame.fill", tint: Color(arenaHex: OnboardingArenaPalette.coral))
                    }
                }
            }

            HStack(spacing: 10) {
                CommunityMiniStat(title: "Arena", value: "Live")
                CommunityMiniStat(title: "Discover", value: "Crews")
                CommunityMiniStat(title: "Compete", value: "Weekly")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LeaderboardRow: View {
    let rank: String
    let name: String
    let value: String
    let color: Color
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(color)
                .frame(width: 44, alignment: .leading)

            Circle()
                .fill(color.opacity(isCurrent ? 0.95 : 0.24))
                .frame(width: 38, height: 38)
                .overlay(
                    Text(String(name.prefix(1)))
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(isCurrent ? .black.opacity(0.78) : color)
                )

            Text(name)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.white)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(isCurrent ? Color(arenaHex: OnboardingArenaPalette.coral) : .white.opacity(0.72))
        }
        .padding(.horizontal, 13)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isCurrent ? color.opacity(0.12) : Color.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isCurrent ? color.opacity(0.24) : Color.white.opacity(0.060), lineWidth: 1)
                )
        )
    }
}

private struct CommunityMiniStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.white)

            Text(title.uppercased())
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(Color(arenaHex: OnboardingArenaPalette.gold).opacity(0.78))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(arenaHex: OnboardingArenaPalette.gold).opacity(0.070))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(arenaHex: OnboardingArenaPalette.gold).opacity(0.14), lineWidth: 1)
                )
        )
    }
}

// MARK: - Ready

private struct ReadyExperienceHero: View {
    let educationText: String
    let coursesCount: Int
    let dailyGoal: Int
    let finishError: String?

    @State private var pulse = false

    var body: some View {
        VStack(spacing: 14) {
            ProductStageCard {
                VStack(spacing: 17) {
                    ZStack {
                        RadialGradient(
                            colors: [
                                Color(arenaHex: OnboardingArenaPalette.green).opacity(0.25),
                                Color(arenaHex: OnboardingArenaPalette.appCyan).opacity(0.10),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 110
                        )
                        .frame(width: 200, height: 150)
                        .blur(radius: 8)

                        Circle()
                            .fill(Color(arenaHex: OnboardingArenaPalette.green))
                            .frame(width: 78, height: 78)
                            .shadow(
                                color: Color(arenaHex: OnboardingArenaPalette.green).opacity(0.28),
                                radius: 20,
                                y: 8
                            )
                            .scaleEffect(pulse ? 1.035 : 1.0)

                        Image(systemName: "checkmark")
                            .font(.system(size: 31, weight: .heavy))
                            .foregroundStyle(.black.opacity(0.76))
                    }
                    .frame(height: 126)

                    VStack(spacing: 9) {
                        ReadyRow(icon: "graduationcap.fill", title: "Profile", value: educationText)
                        ReadyRow(icon: "book.closed.fill", title: "Courses", value: "\(coursesCount) selected")
                        ReadyRow(icon: "target", title: "Daily goal", value: "\(dailyGoal) min")
                    }
                }
            }

            HStack(spacing: 10) {
                CommunityMiniStat(title: "Home", value: "Ready")
                CommunityMiniStat(title: "Focus", value: "Ready")
                CommunityMiniStat(title: "Crew", value: "Ready")
            }

            if let finishError {
                StatusCard(text: finishError)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct ReadyRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(Color(arenaHex: OnboardingArenaPalette.appCyan))
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(Color(arenaHex: OnboardingArenaPalette.appBlue).opacity(0.13))
                )

            Text(title)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.white.opacity(0.58))

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .padding(.horizontal, 12)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(Color.white.opacity(0.060), lineWidth: 1)
                )
        )
    }
}

private struct StatusCard: View {
    let text: String

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(Color(arenaHex: OnboardingArenaPalette.gold))

            Text(text)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(Color(arenaHex: OnboardingArenaPalette.gold).opacity(0.13))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(Color(arenaHex: OnboardingArenaPalette.gold).opacity(0.22), lineWidth: 1)
        )
    }
}

// MARK: - Shared Product UI

private struct ProductStageCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.065),
                                Color(arenaHex: OnboardingArenaPalette.appBlue).opacity(0.040),
                                Color(arenaHex: OnboardingArenaPalette.appPurple).opacity(0.050),
                                Color.black.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(Color.white.opacity(0.080), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.20), radius: 18, y: 10)
            )
    }
}

private struct MicroProductCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(tint.opacity(0.13))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.36))

                Text(value)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(0.13), lineWidth: 1)
                )
        )
    }
}

// MARK: - Background / System

private struct OnboardingArenaBackground: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(arenaHex: OnboardingArenaPalette.backgroundTop),
                    Color(arenaHex: OnboardingArenaPalette.backgroundMid),
                    Color(arenaHex: OnboardingArenaPalette.backgroundBottom)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(arenaHex: OnboardingArenaPalette.appBlue).opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 100)
                .offset(x: 172, y: -250)

            Circle()
                .fill(Color(arenaHex: OnboardingArenaPalette.appPurple).opacity(0.14))
                .frame(width: 330, height: 330)
                .blur(radius: 120)
                .offset(x: -190, y: 490)

            Circle()
                .fill(Color(arenaHex: OnboardingArenaPalette.coral).opacity(0.060))
                .frame(width: 270, height: 270)
                .blur(radius: 108)
                .offset(x: 160, y: 300)

            Circle()
                .fill(Color(arenaHex: OnboardingArenaPalette.gold).opacity(0.045))
                .frame(width: 230, height: 230)
                .blur(radius: 98)
                .offset(x: -150, y: -170)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.46)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

private struct OnboardingPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

private enum OnboardingHaptics {
    static func softTap() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.72)
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
}
