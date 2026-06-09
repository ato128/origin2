//
//  RootView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Binding var openFocusFromNotification: Bool

    @AppStorage("didFinishFullOnboardingV2") private var didFinishFullOnboarding = false
    @AppStorage("appOnboardingStageV2") private var appOnboardingStageRawValue = AppOnboardingStage.welcome.rawValue
    @AppStorage("lastCompletedFullOnboardingUserIDV2") private var lastCompletedFullOnboardingUserID = ""

    @State private var importExport: ScheduleExport? = nil
    @State private var showImportSheet: Bool = false

    @State private var didStartLaunchSequence = false
    @State private var didCompleteMinimumLaunch = false
    @State private var minimumLaunchTask: Task<Void, Never>?

    @State private var lastObservedUserID: String?

    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var friendStore: FriendStore
    @EnvironmentObject var studentStore: StudentStore
    @Environment(\.scenePhase) private var scenePhase

    private let minimumLaunchDurationNanoseconds: UInt64 = 680_000_000

    private var currentUserID: String? {
        guard let user = session.currentUser else { return nil }
        return user.id.uuidString
    }

    private var shouldWaitForStudentProfileResolve: Bool {
        session.isSignedIn &&
        !session.shouldShowEmailVerificationGate &&
        !studentStore.didResolveRemoteProfile
    }

    private var shouldShowBlockingLaunch: Bool {
        !didCompleteMinimumLaunch ||
        !session.didResolveInitialSession ||
        shouldWaitForStudentProfileResolve
    }

    private var hasFinishedLocalOnboardingForCurrentUser: Bool {
        guard let currentUserID else { return false }
        return didFinishFullOnboarding &&
        lastCompletedFullOnboardingUserID == currentUserID
    }

    private var shouldShowOnboarding: Bool {
        session.isSignedIn &&
        !session.shouldShowEmailVerificationGate &&
        (
            !studentStore.hasCompletedStudentProfile ||
            !hasFinishedLocalOnboardingForCurrentUser
        )
    }

    var body: some View {
        ZStack {
            if shouldShowBlockingLaunch {
                PremiumStudentLaunchView()
                    .transition(.opacity)

            } else if session.shouldShowEmailVerificationGate {
                EmailVerificationView()
                    .environmentObject(session)
                    .transition(.opacity)

            } else if !session.isSignedIn {
                AuthView()
                    .transition(.opacity)

            } else if shouldShowOnboarding {
                AppOnboardingFlowView()
                    .transition(.opacity)

            } else {
                MainTabView(
                    openFocusFromNotification: $openFocusFromNotification
                )
                .transition(.opacity)
                .onOpenURL { url in
                    handleIncomingFileURL(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: .openCrewFocusFromNotification)) { output in
                    let crewID = output.object as? String
                    print("🎯 OPEN CREW FOCUS TAB FROM NOTIFICATION:", crewID ?? "nil")

                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: .openFocusTabFromHome,
                            object: nil
                        )
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .presentFocusCompletionFromPush)) { output in
                    Task { @MainActor in
                        FocusSessionManager.shared.reconcileExpiredSessionIfNeeded(
                            reason: "presentFocusCompletionFromPush"
                        )

                        if let payload = output.object as? [AnyHashable: Any] {
                            await crewStore.reconcileFocusCompletionFromNotification(payload: payload)
                        } else {
                            await crewStore.loadCrewHomeSnapshot()
                            await crewStore.loadFocusStateForAllCrews()
                        }

                        NotificationCenter.default.post(
                            name: .openFocusTabFromHome,
                            object: nil
                        )
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .focusNotificationOpened)) { output in
                    Task { @MainActor in
                        FocusSessionManager.shared.reconcileExpiredSessionIfNeeded(
                            reason: "focusNotificationOpened"
                        )

                        if let payload = output.object as? [AnyHashable: Any] {
                            await crewStore.reconcileFocusCompletionFromNotification(payload: payload)
                        } else {
                            await crewStore.loadCrewHomeSnapshot()
                            await crewStore.loadFocusStateForAllCrews()
                        }
                    }
                }
                .sheet(isPresented: $showImportSheet) {
                    if let export = importExport {
                        ImportScheduleView(export: export)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.26), value: shouldShowBlockingLaunch)
        .animation(.easeInOut(duration: 0.24), value: shouldShowOnboarding)
        .animation(.easeInOut(duration: 0.24), value: session.shouldShowEmailVerificationGate)
        .task {
            startLaunchSequenceIfNeeded()
            await session.resolveInitialSessionIfNeeded()
        }
        .task(id: currentUserID) {
            await handleCurrentUserChange()
        }
        .onChange(of: studentStore.hasCompletedStudentProfile) { _, completed in
            guard completed else { return }

            Task { @MainActor in
                await hydrateMainAppData(reason: "RootView.studentProfileCompleted")
            }
        }
        .onChange(of: didFinishFullOnboarding) { _, completed in
            guard completed else { return }

            Task { @MainActor in
                markCurrentUserOnboardingCompletedIfNeeded()
                await hydrateMainAppData(reason: "RootView.didFinishFullOnboarding")
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }

            Task { @MainActor in
                AppBadgeManager.shared.clearBadge()

                FocusSessionManager.shared.reconcileExpiredSessionIfNeeded(
                    reason: "RootView.scenePhase.active"
                )

                guard session.isSignedIn,
                      !session.shouldShowEmailVerificationGate else {
                    return
                }

                if !studentStore.didResolveRemoteProfile || studentStore.profile == nil {
                    await studentStore.loadFromRemote()
                }

                guard studentStore.hasCompletedStudentProfile else {
                    resetLocalOnboardingForIncompleteCurrentUserIfNeeded()
                    return
                }

                guard hasFinishedLocalOnboardingForCurrentUser else {
                    return
                }

                await hydrateMainAppData(reason: "RootView.scenePhase.active")
            }
        }
        .onDisappear {
            minimumLaunchTask?.cancel()
            minimumLaunchTask = nil
        }
    }

    private func startLaunchSequenceIfNeeded() {
        guard !didStartLaunchSequence else { return }

        didStartLaunchSequence = true
        didCompleteMinimumLaunch = false

        minimumLaunchTask?.cancel()
        minimumLaunchTask = Task { @MainActor in
            print("🟡 ROOT COLD LAUNCH INTRO START")

            try? await Task.sleep(nanoseconds: minimumLaunchDurationNanoseconds)
            guard !Task.isCancelled else { return }

            didCompleteMinimumLaunch = true

            print("✅ ROOT COLD LAUNCH INTRO COMPLETE")
        }
    }

    private func handleCurrentUserChange() async {
        guard session.didResolveInitialSession else { return }

        let newUserID = currentUserID

        if lastObservedUserID != newUserID {
            print("🟡 ROOT USER CHANGED:", lastObservedUserID ?? "nil", "→", newUserID ?? "nil")
            lastObservedUserID = newUserID
        }

        guard session.isSignedIn else {
            studentStore.clearForSignOut()
            resetLocalOnboardingForSignedOutState()
            return
        }

        guard !session.shouldShowEmailVerificationGate else {
            return
        }

        await studentStore.loadFromRemote()

        if studentStore.hasCompletedStudentProfile {
            markCurrentUserOnboardingCompletedIfNeeded()
            await hydrateMainAppData(reason: "RootView.currentUserChanged.returningProfileCompleted")

            FocusSessionManager.shared.reconcileExpiredSessionIfNeeded(
                reason: "RootView.currentUserChanged.afterHydrate"
            )
        } else {
            resetLocalOnboardingForIncompleteCurrentUserIfNeeded()
        }
    }

    private func hydrateMainAppData(reason: String) async {
        guard session.isSignedIn,
              !session.shouldShowEmailVerificationGate,
              studentStore.hasCompletedStudentProfile,
              hasFinishedLocalOnboardingForCurrentUser else {
            return
        }

        print("🟡 ROOT HYDRATE START:", reason)

        if !studentStore.didResolveRemoteProfile || studentStore.profile == nil {
            await studentStore.loadFromRemote()
        }

        await crewStore.loadCrewHomeSnapshot()
        await crewStore.loadFocusStateForAllCrews()

        FocusSessionManager.shared.reconcileExpiredSessionIfNeeded(
            reason: "\(reason).afterHydrate"
        )

        print("✅ ROOT HYDRATE COMPLETE:", reason)
    }

    private func markCurrentUserOnboardingCompletedIfNeeded() {
        guard let currentUserID else { return }
        guard studentStore.hasCompletedStudentProfile else { return }

        if lastCompletedFullOnboardingUserID != currentUserID {
            lastCompletedFullOnboardingUserID = currentUserID
        }

        if !didFinishFullOnboarding {
            didFinishFullOnboarding = true
        }

        if appOnboardingStageRawValue != AppOnboardingStage.ready.rawValue {
            appOnboardingStageRawValue = AppOnboardingStage.ready.rawValue
        }
    }

    private func resetLocalOnboardingForIncompleteCurrentUserIfNeeded() {
        guard let currentUserID else { return }

        let isDifferentFromCompletedUser = lastCompletedFullOnboardingUserID != currentUserID

        if isDifferentFromCompletedUser {
            didFinishFullOnboarding = false
            appOnboardingStageRawValue = AppOnboardingStage.welcome.rawValue
        } else if !studentStore.hasCompletedStudentProfile {
            didFinishFullOnboarding = false
            appOnboardingStageRawValue = AppOnboardingStage.welcome.rawValue
        }
    }

    private func resetLocalOnboardingForSignedOutState() {
        appOnboardingStageRawValue = AppOnboardingStage.welcome.rawValue
    }

    private func handleIncomingFileURL(_ url: URL) {
        guard url.isFileURL else { return }

        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let tempURL = try copyToTemporaryIfNeeded(url)
            let export = try ScheduleShare.readJSON(from: tempURL)
            importExport = export
            showImportSheet = true
        } catch {
            print("Import error:", error)
        }
    }

    private func copyToTemporaryIfNeeded(_ url: URL) throws -> URL {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
        let targetURL = tempDir.appendingPathComponent(url.lastPathComponent)

        if fm.fileExists(atPath: targetURL.path) {
            try fm.removeItem(at: targetURL)
        }

        try fm.copyItem(at: url, to: targetURL)
        return targetURL
    }
}

// MARK: - Premium Launch Loading

private struct PremiumStudentLaunchView: View {
    @State private var appear = false
    @State private var logoReveal = false
    @State private var arrowReveal = false
    @State private var wordReveal = false
    @State private var breathe = false
    @State private var shimmer = false

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 30) {
                    logoScene

                    Text("Updo")
                        .font(.system(size: 62, weight: .regular, design: .serif))
                        .italic()
                        .tracking(-1.45)
                        .foregroundStyle(wordmarkGradient)
                        .shadow(
                            color: Color(rootHex: "#1D4ED8").opacity(0.18),
                            radius: 18,
                            y: 8
                        )
                        .overlay(alignment: .leading) {
                            wordmarkShimmer
                        }
                        .mask {
                            Text("Updo")
                                .font(.system(size: 62, weight: .regular, design: .serif))
                                .italic()
                                .tracking(-1.45)
                        }
                        .opacity(wordReveal ? 1 : 0)
                        .offset(y: wordReveal ? 0 : 16)
                        .blur(radius: wordReveal ? 0 : 6)
                        .animation(
                            .spring(response: 0.62, dampingFraction: 0.90).delay(0.18),
                            value: wordReveal
                        )
                }
                .offset(y: -14)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.18)) {
                appear = true
            }

            withAnimation(.spring(response: 0.72, dampingFraction: 0.82).delay(0.04)) {
                logoReveal = true
            }

            withAnimation(.spring(response: 0.56, dampingFraction: 0.80).delay(0.20)) {
                arrowReveal = true
            }

            withAnimation(.spring(response: 0.62, dampingFraction: 0.90).delay(0.23)) {
                wordReveal = true
            }

            withAnimation(.easeInOut(duration: 1.85).repeatForever(autoreverses: true).delay(0.42)) {
                breathe = true
            }

            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: false).delay(0.30)) {
                shimmer = true
            }
        }
    }

    private var background: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(rootHex: "#01020A"),
                    Color(rootHex: "#050713"),
                    Color(rootHex: "#02030A")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(rootHex: "#0B3B8F").opacity(0.11))
                .frame(width: 340, height: 340)
                .blur(radius: 110)
                .offset(x: 185, y: -295)

            Circle()
                .fill(Color(rootHex: "#28135F").opacity(0.13))
                .frame(width: 410, height: 410)
                .blur(radius: 128)
                .offset(x: -235, y: 420)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.22),
                    Color.clear,
                    Color.black.opacity(0.62)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .opacity(appear ? 1 : 0)
    }

    private var logoScene: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color(rootHex: "#1D4ED8").opacity(logoReveal ? 0.24 : 0.00),
                    Color(rootHex: "#312E81").opacity(logoReveal ? 0.15 : 0.00),
                    Color.clear
                ],
                center: .center,
                startRadius: 8,
                endRadius: 124
            )
            .frame(width: 265, height: 265)
            .blur(radius: 5)

            ZStack {
                Image(systemName: "scope")
                    .font(.system(size: 156, weight: .ultraLight))
                    .foregroundStyle(scopeGradient)
                    .shadow(
                        color: Color(rootHex: "#1D4ED8").opacity(0.24),
                        radius: 22,
                        y: 9
                    )

                Image(systemName: "location.north.fill")
                    .font(.system(size: 56, weight: .black))
                    .foregroundStyle(arrowGradient)
                    .offset(y: arrowReveal ? -2 : 18)
                    .opacity(arrowReveal ? 1 : 0)
                    .scaleEffect(arrowReveal ? 1 : 0.64)
                    .shadow(
                        color: Color(rootHex: "#38BDF8").opacity(0.24),
                        radius: 16,
                        y: 7
                    )
            }
            .rotationEffect(.degrees(logoReveal ? 360 : -55))
            .scaleEffect(logoReveal ? (breathe ? 1.012 : 0.996) : 0.70)
            .opacity(logoReveal ? 1 : 0)
            .blur(radius: logoReveal ? 0 : 10)
            .animation(.spring(response: 0.72, dampingFraction: 0.82), value: logoReveal)
            .animation(.easeInOut(duration: 1.85).repeatForever(autoreverses: true), value: breathe)
        }
        .frame(width: 270, height: 270)
    }

    private var wordmarkShimmer: some View {
        LinearGradient(
            colors: [
                Color.clear,
                Color.white.opacity(0.32),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: 42)
        .rotationEffect(.degrees(18))
        .offset(x: shimmer ? 178 : -96)
        .opacity(wordReveal ? 1 : 0)
    }

    private var scopeGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(rootHex: "#F8FBFF"),
                Color(rootHex: "#BFDFFF"),
                Color(rootHex: "#60A5FA"),
                Color(rootHex: "#2563EB"),
                Color(rootHex: "#111827")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var arrowGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(rootHex: "#FFFFFF"),
                Color(rootHex: "#BAE6FD"),
                Color(rootHex: "#2563EB"),
                Color(rootHex: "#1E1B4B")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var wordmarkGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(rootHex: "#FFF7CC"),
                Color(rootHex: "#FDE68A"),
                Color(rootHex: "#FBBF24"),
                Color(rootHex: "#B45309")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Local Hex Color

private extension Color {
    init(rootHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64

        switch cleaned.count {
        case 3:
            a = 255
            r = ((int >> 8) & 0xF) * 17
            g = ((int >> 4) & 0xF) * 17
            b = (int & 0xF) * 17

        case 6:
            a = 255
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        case 8:
            a = (int >> 24) & 0xFF
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        default:
            a = 255
            r = 255
            g = 255
            b = 255
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
