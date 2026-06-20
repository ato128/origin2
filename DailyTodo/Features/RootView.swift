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
                    Log.debug("🎯 OPEN CREW FOCUS TAB FROM NOTIFICATION:", crewID ?? "nil")

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
            Log.debug("🟡 ROOT COLD LAUNCH INTRO START")

            try? await Task.sleep(nanoseconds: minimumLaunchDurationNanoseconds)
            guard !Task.isCancelled else { return }

            didCompleteMinimumLaunch = true

            Log.debug("✅ ROOT COLD LAUNCH INTRO COMPLETE")
        }
    }

    private func handleCurrentUserChange() async {
        guard session.didResolveInitialSession else { return }

        let newUserID = currentUserID

        if lastObservedUserID != newUserID {
            Log.debug("🟡 ROOT USER CHANGED:", lastObservedUserID ?? "nil", "→", newUserID ?? "nil")
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

        Log.debug("🟡 ROOT HYDRATE START:", reason)

        if !studentStore.didResolveRemoteProfile || studentStore.profile == nil {
            await studentStore.loadFromRemote()
        }

        await crewStore.loadCrewHomeSnapshot()
        await crewStore.loadFocusStateForAllCrews()

        FocusSessionManager.shared.reconcileExpiredSessionIfNeeded(
            reason: "\(reason).afterHydrate"
        )

        Log.debug("✅ ROOT HYDRATE COMPLETE:", reason)
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
            Log.debug("Import error:", error)
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
    @State private var wordReveal = false
    @State private var shimmer = false

    /// Logo + wordmark color follow the currently selected app icon.
    private var theme: (fg: AnyShapeStyle, glow: Color, word: AnyShapeStyle) { UpdoIconTheme.current() }

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
                        .foregroundStyle(theme.word)
                        .shadow(
                            color: theme.glow.opacity(0.32),
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

            // Wordmark reveals after the logo mark has started drawing in.
            withAnimation(.spring(response: 0.62, dampingFraction: 0.90).delay(0.62)) {
                wordReveal = true
            }

            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: false).delay(0.7)) {
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
        // Mirrors the currently selected app icon — change the icon, the launch
        // animation follows.
        UpdoLogoMark(fg: theme.fg, glow: theme.glow, size: 176)
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

// MARK: - Shared Updo logo mark (single source for icon + launch animation)

import UIKit

/// The brand mark: a crosshair ring + 4 ticks + a north arrow — identical to the
/// app icon art. Self-animates on appear (ring draws in, ticks pop, arrow rises).
struct UpdoLogoMark: View {
    var fg: AnyShapeStyle
    var glow: Color
    var size: CGFloat = 168
    var animated: Bool = true

    @State private var ringIn = false
    @State private var ticksIn = false
    @State private var arrowIn = false
    @State private var breathe = false

    var body: some View {
        let lw = size * 0.052
        let r = size * 0.285
        let tick = size * 0.20

        ZStack {
            Circle()
                .fill(RadialGradient(colors: [glow.opacity(0.30), .clear], center: .center, startRadius: 2, endRadius: size * 0.6))
                .frame(width: size * 1.5, height: size * 1.5)
                .blur(radius: 8)
                .opacity(animated ? (ringIn ? 1 : 0) : 1)

            // ring — draws in
            Circle()
                .trim(from: 0, to: animated ? (ringIn ? 1 : 0) : 1)
                .stroke(fg, style: StrokeStyle(lineWidth: lw, lineCap: .round))
                .frame(width: r * 2, height: r * 2)
                .rotationEffect(.degrees(-90))

            // ticks — pop in
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(fg)
                    .frame(width: lw, height: tick)
                    .offset(y: -r)
                    .rotationEffect(.degrees(Double(i) * 90))
                    .scaleEffect(animated ? (ticksIn ? 1 : 0.15) : 1, anchor: .center)
                    .opacity(animated ? (ticksIn ? 1 : 0) : 1)
            }

            // arrow — rises
            UpdoCrosshairArrow()
                .fill(fg)
                .frame(width: size * 0.215, height: size * 0.235)
                .offset(y: animated ? (arrowIn ? -size * 0.005 : size * 0.055) : -size * 0.005)
                .opacity(animated ? (arrowIn ? 1 : 0) : 1)
                .scaleEffect(animated ? (arrowIn ? 1 : 0.6) : 1)
        }
        .frame(width: size, height: size)
        .scaleEffect(breathe ? 1.015 : 0.992)
        .shadow(color: glow.opacity(0.35), radius: size * 0.05, y: size * 0.02)
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 0.78)) { ringIn = true }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.68).delay(0.46)) { ticksIn = true }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.74).delay(0.58)) { arrowIn = true }
            withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true).delay(0.9)) { breathe = true }
        }
    }
}

struct UpdoCrosshairArrow: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let pts = [
            CGPoint(x: rect.minX + 0.50 * w, y: rect.minY + 0.02 * h),
            CGPoint(x: rect.minX + 0.97 * w, y: rect.minY + 0.97 * h),
            CGPoint(x: rect.minX + 0.50 * w, y: rect.minY + 0.66 * h),
            CGPoint(x: rect.minX + 0.03 * w, y: rect.minY + 0.97 * h)
        ]
        let radius = min(w, h) * 0.10
        var path = Path()
        let n = pts.count
        for i in 0..<n {
            let cur = pts[i], pr = pts[(i - 1 + n) % n], nx = pts[(i + 1) % n]
            let tP = unit(cur, pr), tN = unit(cur, nx)
            let rP = min(radius, dist(cur, pr) / 2), rN = min(radius, dist(cur, nx) / 2)
            let st = CGPoint(x: cur.x + tP.x * rP, y: cur.y + tP.y * rP)
            let en = CGPoint(x: cur.x + tN.x * rN, y: cur.y + tN.y * rN)
            if i == 0 { path.move(to: st) } else { path.addLine(to: st) }
            path.addQuadCurve(to: en, control: cur)
        }
        path.closeSubpath()
        return path
    }
    private func unit(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        let dx = b.x - a.x, dy = b.y - a.y, l = max((dx * dx + dy * dy).squareRoot(), 0.0001)
        return CGPoint(x: dx / l, y: dy / l)
    }
    private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat { ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot() }
}

/// Maps the currently selected app icon to a matching logo color/glow so the
/// launch animation always mirrors the chosen icon.
enum UpdoIconTheme {
    /// fg  = mark gradient (matches the app icon)
    /// glow = halo / shadow color
    /// word = a brighter 2-stop gradient for the "Updo" wordmark (legible on dark)
    static func current() -> (fg: AnyShapeStyle, glow: Color, word: AnyShapeStyle) {
        func grad(_ hexes: [String]) -> AnyShapeStyle {
            AnyShapeStyle(LinearGradient(colors: hexes.map { Color(rootHex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        switch UIApplication.shared.alternateIconName {
        case "AppIcon-Gold":    return (grad(["#FCD34D", "#FBBF24", "#D97706"]), Color(rootHex: "#F59E0B"), grad(["#FFE9A8", "#FBBF24"]))
        case "AppIcon-Chrome":  return (grad(["#EEF3F7", "#9AA7B0", "#5B6770"]), Color(rootHex: "#AEB9C2"), grad(["#FFFFFF", "#9AA7B0"]))
        case "AppIcon-Aurora":  return (grad(["#22D3EE", "#7C3AED", "#EC4899"]), Color(rootHex: "#7C3AED"), grad(["#67E8F9", "#C084FC"]))
        case "AppIcon-Sunset":  return (grad(["#FBBF24", "#FB7185", "#F472B6"]), Color(rootHex: "#FB7185"), grad(["#FDE68A", "#FB7185"]))
        case "AppIcon-Emerald": return (grad(["#6EE7B7", "#10B981", "#047857"]), Color(rootHex: "#10B981"), grad(["#A7F3D0", "#34D399"]))
        case "AppIcon-Noir":    return (AnyShapeStyle(Color(rootHex: "#F2F4F7")), Color(rootHex: "#FFFFFF"), grad(["#FFFFFF", "#D1D5DB"]))
        case "AppIcon-Carbon":  return (grad(["#A8B0BA", "#4B5563", "#1F2937"]), Color(rootHex: "#6B7280"), grad(["#E5E7EB", "#9CA3AF"]))
        case "AppIcon-Ice":     return (grad(["#EAF7FF", "#7DD3FC", "#38BDF8"]), Color(rootHex: "#7DD3FC"), grad(["#F0FBFF", "#7DD3FC"]))
        default:                return (grad(["#7FCBDD", "#5AB6CC", "#2E7C92"]), Color(rootHex: "#3C8FA6"), grad(["#BDEAF4", "#5AB6CC"])) // Steel
        }
    }
}
