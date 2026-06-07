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

    @State private var importExport: ScheduleExport? = nil
    @State private var showImportSheet: Bool = false
    @State private var didFinishLaunchAnimation = false

    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var friendStore: FriendStore
    @EnvironmentObject var studentStore: StudentStore
    @Environment(\.scenePhase) private var scenePhase

    private var isStudentProfileReady: Bool {
        studentStore.didResolveRemoteProfile && !studentStore.isLoading
    }

    private var shouldShowBlockingLaunch: Bool {
        if !session.didResolveInitialSession {
            return true
        }

        if session.shouldShowEmailVerificationGate {
            return false
        }

        if !session.isSignedIn {
            return false
        }

        if !didFinishLaunchAnimation {
            return true
        }

        if !didFinishFullOnboarding {
            return false
        }

        return !isStudentProfileReady
    }

    var body: some View {
        ZStack {
            if shouldShowBlockingLaunch {
                PremiumStudentLaunchView {
                    didFinishLaunchAnimation = true
                }
                .transition(.opacity)

            } else if session.shouldShowEmailVerificationGate {
                EmailVerificationView()
                    .environmentObject(session)
                    .transition(.opacity)

            } else if !session.isSignedIn {
                AuthView()
                    .transition(.opacity)

            } else if !didFinishFullOnboarding {
                AppOnboardingFlowView()
                    .transition(.opacity)

            } else {
                MainTabView(
                    openFocusFromNotification: $openFocusFromNotification
                )
                .transition(.opacity.combined(with: .scale(scale: 1.012)))
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
        .animation(.easeInOut(duration: 0.34), value: session.isSignedIn)
        .animation(.easeInOut(duration: 0.34), value: shouldShowBlockingLaunch)
        .animation(.easeInOut(duration: 0.34), value: didFinishFullOnboarding)
        .animation(.easeInOut(duration: 0.34), value: session.didResolveInitialSession)
        .animation(.easeInOut(duration: 0.34), value: session.shouldShowEmailVerificationGate)
        .onChange(of: session.isSignedIn) { _, isSignedIn in
            didFinishLaunchAnimation = false
        }
        .task {
            await session.resolveInitialSessionIfNeeded()
        }
        .task(id: session.currentUser?.id) {
            guard session.didResolveInitialSession else { return }

            guard session.isSignedIn else {
                studentStore.clearForSignOut()
                return
            }

            guard didFinishFullOnboarding else {
                return
            }

            if !studentStore.didResolveRemoteProfile || studentStore.profile == nil {
                await studentStore.loadFromRemote()
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
                      didFinishFullOnboarding,
                      !session.shouldShowEmailVerificationGate else {
                    return
                }

                await crewStore.loadCrewHomeSnapshot()
                await crewStore.loadFocusStateForAllCrews()
            }
        }
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
    let onFinished: () -> Void

    @State private var appeared = false
    @State private var titleAppeared = false
    @State private var orbit = false
    @State private var glowPulse = false
    @State private var iconBreath = false
    @State private var arrowRise = false
    @State private var finishTask: Task<Void, Never>?

    private let minimumDurationNanoseconds: UInt64 = 900_000_000

    var body: some View {
        ZStack {
            launchBackground

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 28) {
                    premiumLogo

                    Text("Updo")
                        .font(.system(size: 58, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(updoGoldGradient)
                        .shadow(color: Color(rootHex: "#FBBF24").opacity(0.20), radius: 18, y: 8)
                        .offset(y: titleAppeared ? 0 : 34)
                        .opacity(titleAppeared ? 1 : 0)
                        .animation(
                            .spring(response: 0.82, dampingFraction: 0.84).delay(0.22),
                            value: titleAppeared
                        )
                }
                .offset(y: -8)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            appeared = true
            titleAppeared = true
            orbit = true
            glowPulse = true
            iconBreath = true
            arrowRise = true

            finishTask?.cancel()
            finishTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: minimumDurationNanoseconds)
                guard !Task.isCancelled else { return }

                withAnimation(.easeInOut(duration: 0.28)) {
                    onFinished()
                }
            }
        }
        .onDisappear {
            finishTask?.cancel()
            finishTask = nil
        }
    }

    private var launchBackground: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(rootHex: "#03050A"),
                    Color(rootHex: "#060817"),
                    Color(rootHex: "#05040A")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(rootHex: "#0B5CFF").opacity(0.105))
                .frame(width: 330, height: 330)
                .blur(radius: 125)
                .offset(x: 175, y: -260)

            Circle()
                .fill(Color(rootHex: "#5B21B6").opacity(0.13))
                .frame(width: 390, height: 390)
                .blur(radius: 138)
                .offset(x: -210, y: 425)

            Circle()
                .fill(Color(rootHex: "#B7791F").opacity(0.055))
                .frame(width: 280, height: 280)
                .blur(radius: 126)
                .offset(x: 140, y: 360)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.22),
                    Color.clear,
                    Color.black.opacity(0.52)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var premiumLogo: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(rootHex: "#0EA5E9").opacity(glowPulse ? 0.20 : 0.11),
                            Color(rootHex: "#1D4ED8").opacity(glowPulse ? 0.13 : 0.07),
                            Color(rootHex: "#312E81").opacity(glowPulse ? 0.12 : 0.06),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 105
                    )
                )
                .frame(width: 230, height: 230)
                .blur(radius: 2)
                .animation(.easeInOut(duration: 1.70).repeatForever(autoreverses: true), value: glowPulse)

            ZStack {
                Image(systemName: "scope")
                    .font(.system(size: 154, weight: .ultraLight))
                    .foregroundStyle(scopeGradient)
                    .shadow(color: Color(rootHex: "#2563EB").opacity(0.22), radius: 24, y: 10)

                ScopeGoldOrbit(orbit: orbit)
                    .frame(width: 156, height: 156)

                Image(systemName: "location.north.fill")
                    .font(.system(size: 56, weight: .black))
                    .foregroundStyle(arrowGradient)
                    .offset(y: arrowRise ? -1 : 10)
                    .opacity(arrowRise ? 1 : 0)
                    .shadow(color: Color(rootHex: "#22D3EE").opacity(0.25), radius: 18, y: 7)
                    .animation(
                        .spring(response: 0.78, dampingFraction: 0.78).delay(0.12),
                        value: arrowRise
                    )
            }
            .scaleEffect(iconBreath ? 1.018 : 0.988)
            .animation(.easeInOut(duration: 1.55).repeatForever(autoreverses: true), value: iconBreath)
        }
        .frame(width: 240, height: 240)
        .scaleEffect(appeared ? 1 : 0.86)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.80, dampingFraction: 0.84), value: appeared)
    }

    private var scopeGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(rootHex: "#F8FBFF"),
                Color(rootHex: "#BFDFFF"),
                Color(rootHex: "#60A5FA"),
                Color(rootHex: "#4F46E5"),
                Color(rootHex: "#312E81")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var arrowGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(rootHex: "#F8FBFF"),
                Color(rootHex: "#9EE7FF"),
                Color(rootHex: "#2563EB"),
                Color(rootHex: "#312E81")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var updoGoldGradient: LinearGradient {
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

// MARK: - Gold Orbit

private struct ScopeGoldOrbit: View {
    let orbit: Bool

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0.00, to: 0.105)
                .stroke(
                    goldGradient,
                    style: StrokeStyle(lineWidth: 3.2, lineCap: .round)
                )
                .rotationEffect(.degrees(orbit ? 360 : 0))
                .animation(.linear(duration: 1.42).repeatForever(autoreverses: false), value: orbit)

            Circle()
                .trim(from: 0.18, to: 0.225)
                .stroke(
                    softGoldGradient,
                    style: StrokeStyle(lineWidth: 2.1, lineCap: .round)
                )
                .rotationEffect(.degrees(orbit ? 360 : 0))
                .animation(.linear(duration: 1.42).repeatForever(autoreverses: false), value: orbit)

            Circle()
                .fill(Color(rootHex: "#FFF7CC"))
                .frame(width: 7.4, height: 7.4)
                .offset(y: -78)
                .rotationEffect(.degrees(orbit ? 360 : 0))
                .shadow(color: Color(rootHex: "#FBBF24").opacity(0.85), radius: 10)
                .animation(.linear(duration: 1.42).repeatForever(autoreverses: false), value: orbit)
        }
        .shadow(color: Color(rootHex: "#FBBF24").opacity(0.30), radius: 12)
    }

    private var goldGradient: AngularGradient {
        AngularGradient(
            colors: [
                Color(rootHex: "#FBBF24").opacity(0.02),
                Color(rootHex: "#FFF7CC"),
                Color(rootHex: "#FBBF24"),
                Color(rootHex: "#B45309").opacity(0.70),
                Color(rootHex: "#FBBF24").opacity(0.02)
            ],
            center: .center
        )
    }

    private var softGoldGradient: AngularGradient {
        AngularGradient(
            colors: [
                Color(rootHex: "#FBBF24").opacity(0.02),
                Color(rootHex: "#FDE68A").opacity(0.72),
                Color(rootHex: "#FBBF24").opacity(0.20),
                Color(rootHex: "#FBBF24").opacity(0.02)
            ],
            center: .center
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
