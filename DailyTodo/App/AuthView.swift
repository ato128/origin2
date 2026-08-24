//
//  AuthView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.03.2026.
//
import SwiftUI
import AuthenticationServices
import CryptoKit
import PhotosUI

struct AuthView: View {
    @EnvironmentObject var session: SessionStore
    @State private var activeSheet: AuthSheet?
    @State private var appleNonce: String?
    @State private var isSocialWorking = false
    @State private var authError: String?

    var body: some View {
        ZStack {
            AuthArenaBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 42)

                heroSection

                Spacer(minLength: 28)

                actionSection

                Spacer(minLength: 30)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .preferredColorScheme(.dark)
        .sheet(item: $activeSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .login:
                    AuthFormSheetView(mode: .login)
                        .environmentObject(session)

                case .signup:
                    AuthFormSheetView(mode: .signup)
                        .environmentObject(session)
                }
            }
            .presentationDetents([.fraction(0.68), .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(30)
        }
        .alert(tr("av_social_error_title"), isPresented: Binding(
            get: { authError != nil },
            set: { if !$0 { authError = nil } }
        )) {
            Button(tr("common_ok"), role: .cancel) { authError = nil }
        } message: {
            Text(authError ?? "")
        }
    }

    // MARK: - Social sign-in

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = appleNonce
            else {
                authError = tr("av_social_error")
                return
            }

            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")

            isSocialWorking = true
            Task {
                do {
                    try await session.signInWithApple(
                        idToken: idToken,
                        nonce: nonce,
                        fullName: fullName.isEmpty ? nil : fullName
                    )
                    HapticManager.shared.success()
                } catch {
                    authError = error.localizedDescription
                }
                isSocialWorking = false
            }

        case .failure(let error):
            // User-cancelled taps are not errors worth surfacing.
            if (error as? ASAuthorizationError)?.code != .canceled {
                authError = error.localizedDescription
            }
        }
    }

    private func startGoogleSignIn() {
        HapticManager.shared.action()
        isSocialWorking = true

        Task {
            do {
                try await session.signInWithGoogle()
                HapticManager.shared.success()
            } catch {
                let text = error.localizedDescription.lowercased()
                // ASWebAuthenticationSession cancel → quiet.
                if !text.contains("cancel") {
                    authError = error.localizedDescription
                }
            }
            isSocialWorking = false
        }
    }

    // MARK: - Apple nonce

    private func makeNonce() -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        let randoms = (0..<32).map { _ in charset[Int.random(in: 0..<charset.count)] }
        return String(randoms)
    }

    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

// MARK: - Sections

private extension AuthView {
    var heroSection: some View {
        VStack(spacing: 20) {
            UpdoAIOrb(mode: .idle, size: 96)

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(Color(arenaHex: AuthArenaPalette.appCyan).opacity(0.7))
                        .frame(width: 18, height: 1)

                    Text(tr("av_eyebrow_caps"))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(2.8)
                        .foregroundStyle(Color(arenaHex: AuthArenaPalette.appCyan))

                    Rectangle()
                        .fill(Color(arenaHex: AuthArenaPalette.appCyan).opacity(0.7))
                        .frame(width: 18, height: 1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("Up")
                        .font(.system(size: 50, weight: .black))
                        .foregroundStyle(UpdoTheme.textPrimary)

                    Text("do")
                        .font(.system(size: 48, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(arenaHex: AuthArenaPalette.appCyan),
                                    Color(arenaHex: AuthArenaPalette.appPurple)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .lineLimit(1)

                Text(tr("av_subtitle"))
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundStyle(UpdoTheme.filmy(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 6)
            }
        }
    }

    var actionSection: some View {
        VStack(spacing: 12) {
            // Apple — HIG-styled native button, capsule-clipped to match.
            SignInWithAppleButton(.continue) { request in
                let nonce = makeNonce()
                appleNonce = nonce
                request.requestedScopes = [.fullName, .email]
                request.nonce = sha256(nonce)
            } onCompletion: { result in
                handleAppleCompletion(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 54)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.28), radius: 12, y: 5)

            // Google — same weight, white capsule with the real multi-color mark.
            Button(action: startGoogleSignIn) {
                HStack(spacing: 10) {
                    GoogleGLogo(size: 20)

                    Text(tr("av_continue_google"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Capsule().fill(.white))
                .shadow(color: .black.opacity(0.28), radius: 12, y: 5)
            }
            .buttonStyle(AuthPressButtonStyle())

            // Divider
            HStack(spacing: 12) {
                Rectangle().fill(UpdoTheme.filmy(0.12)).frame(height: 1)
                Text(tr("av_or_caps"))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(UpdoTheme.filmy(0.35))
                Rectangle().fill(UpdoTheme.filmy(0.12)).frame(height: 1)
            }
            .padding(.vertical, 4)

            // Email path — quiet hairline capsule + signup text link.
            Button {
                HapticManager.shared.navigation()
                activeSheet = .login
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(tr("av_continue_email"))
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(UpdoTheme.filmy(0.92))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    Capsule()
                        .fill(UpdoTheme.filmy(0.06))
                        .overlay(Capsule().strokeBorder(UpdoTheme.filmy(0.14), lineWidth: 1))
                )
            }
            .buttonStyle(AuthPressButtonStyle())

            Button {
                HapticManager.shared.navigation()
                activeSheet = .signup
            } label: {
                HStack(spacing: 5) {
                    Text(tr("av_no_account"))
                        .foregroundStyle(UpdoTheme.filmy(0.5))
                    Text(tr("auth_signup"))
                        .foregroundStyle(Color(arenaHex: AuthArenaPalette.appCyan))
                }
                .font(.system(size: 13.5, weight: .semibold))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            Text(tr("av_terms_note"))
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(UpdoTheme.filmy(0.32))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.top, 8)
        }
        .overlay {
            if isSocialWorking || session.isLoading {
                ZStack {
                    Color.black.opacity(0.45)
                    ProgressView().tint(Color(arenaHex: AuthArenaPalette.appCyan))
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSocialWorking)
    }
}

// MARK: - Palette

private enum AuthArenaPalette {
    static let backgroundTop = "#05060D"
    static let backgroundMid = "#070713"
    static let backgroundBottom = "#07040C"

    static let appBlue = "#1593FF"
    static let appBlueSoft = "#1E6BFF"
    static let appCyan = "#2DD4FF"
    static let appPurple = "#7C3AED"
    static let coral = "#FF5A44"
    static let gold = "#FBBF24"

    static var appGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(arenaHex: appBlueSoft),
                Color(arenaHex: appPurple)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var highlightedCardGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(arenaHex: appBlue).opacity(0.14),
                Color(arenaHex: appPurple).opacity(0.12),
                UpdoTheme.filmy(0.045)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var surfaceGradient: LinearGradient {
        LinearGradient(
            colors: [
                UpdoTheme.filmy(0.075),
                UpdoTheme.filmy(0.045),
                UpdoTheme.filmy(0.030)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Background

private struct AuthArenaBackground: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(arenaHex: AuthArenaPalette.backgroundTop),
                    Color(arenaHex: AuthArenaPalette.backgroundMid),
                    Color(arenaHex: AuthArenaPalette.backgroundBottom)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(arenaHex: AuthArenaPalette.appBlue).opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 100)
                .offset(x: 170, y: -250)

            Circle()
                .fill(Color(arenaHex: AuthArenaPalette.appPurple).opacity(0.18))
                .frame(width: 330, height: 330)
                .blur(radius: 115)
                .offset(x: -180, y: 500)

            Circle()
                .fill(Color(arenaHex: AuthArenaPalette.coral).opacity(0.075))
                .frame(width: 280, height: 280)
                .blur(radius: 105)
                .offset(x: 170, y: 300)

            Circle()
                .fill(Color(arenaHex: AuthArenaPalette.gold).opacity(0.050))
                .frame(width: 240, height: 240)
                .blur(radius: 95)
                .offset(x: -170, y: -180)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.44)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Google logo

/// Official multi-color Google "G", rendered from the brand SVG path data
/// (48×48 viewBox) — exact logo, crisp at any size, no bundled asset needed.
private struct GoogleGLogo: View {
    var size: CGFloat = 20

    private static let blue = Color(red: 66/255, green: 133/255, blue: 244/255)
    private static let green = Color(red: 52/255, green: 168/255, blue: 83/255)
    private static let yellow = Color(red: 251/255, green: 188/255, blue: 5/255)
    private static let red = Color(red: 234/255, green: 67/255, blue: 53/255)

    var body: some View {
        ZStack {
            SVGPathShape("M45.12 24.5c0-1.56-.14-3.06-.4-4.5H24v8.51h11.84c-.51 2.75-2.06 5.08-4.39 6.64v5.52h7.11c4.16-3.83 6.56-9.47 6.56-16.17z")
                .fill(Self.blue)
            SVGPathShape("M24 46c5.94 0 10.92-1.97 14.56-5.33l-7.11-5.52c-1.97 1.32-4.49 2.1-7.45 2.1-5.73 0-10.58-3.87-12.31-9.07H4.34v5.7C7.96 41.07 15.4 46 24 46z")
                .fill(Self.green)
            SVGPathShape("M11.69 28.18C11.25 26.86 11 25.45 11 24s.25-2.86.69-4.18v-5.7H4.34C2.85 17.09 2 20.45 2 24s.85 6.91 2.34 9.88l7.35-5.7z")
                .fill(Self.yellow)
            SVGPathShape("M24 10.75c3.23 0 6.13 1.11 8.41 3.29l6.31-6.31C34.91 4.18 29.93 2 24 2 15.4 2 7.96 6.93 4.34 14.12l7.35 5.7c1.73-5.2 6.58-9.07 12.31-9.07z")
                .fill(Self.red)
        }
        .frame(width: size, height: size)
    }
}

/// Minimal SVG path renderer (M m L l H h V v C c S s Z z) for a 48×48
/// viewBox, scaled to fill the rect. Enough to draw the Google mark exactly.
private struct SVGPathShape: Shape {
    let data: String
    private let viewBox: CGFloat = 48

    init(_ data: String) { self.data = data }

    private enum Token { case command(Character); case number(Double) }

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / viewBox
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * scale, y: y * scale) }

        let tokens = Self.tokenize(data)
        var path = Path()
        var idx = 0
        var cp = CGPoint.zero        // current point (viewBox coords)
        var startPt = CGPoint.zero   // subpath start
        var lastCtrl: CGPoint?       // last cubic control point (viewBox)
        var cmd: Character = " "

        func num() -> CGFloat {
            if idx < tokens.count, case let .number(v) = tokens[idx] { idx += 1; return CGFloat(v) }
            return 0
        }

        while idx < tokens.count {
            let idxBefore = idx
            if case let .command(c) = tokens[idx] { cmd = c; idx += 1 }

            let rel = cmd.isLowercase
            switch Character(cmd.uppercased()) {
            case "M":
                let x = num(); let y = num()
                cp = rel ? CGPoint(x: cp.x + x, y: cp.y + y) : CGPoint(x: x, y: y)
                path.move(to: P(cp.x, cp.y)); startPt = cp; lastCtrl = nil
                cmd = rel ? "l" : "L"
            case "L":
                let x = num(); let y = num()
                cp = rel ? CGPoint(x: cp.x + x, y: cp.y + y) : CGPoint(x: x, y: y)
                path.addLine(to: P(cp.x, cp.y)); lastCtrl = nil
            case "H":
                let x = num()
                cp = rel ? CGPoint(x: cp.x + x, y: cp.y) : CGPoint(x: x, y: cp.y)
                path.addLine(to: P(cp.x, cp.y)); lastCtrl = nil
            case "V":
                let y = num()
                cp = rel ? CGPoint(x: cp.x, y: cp.y + y) : CGPoint(x: cp.x, y: y)
                path.addLine(to: P(cp.x, cp.y)); lastCtrl = nil
            case "C":
                let x1 = num(), y1 = num(), x2 = num(), y2 = num(), x = num(), y = num()
                let c1 = rel ? CGPoint(x: cp.x + x1, y: cp.y + y1) : CGPoint(x: x1, y: y1)
                let c2 = rel ? CGPoint(x: cp.x + x2, y: cp.y + y2) : CGPoint(x: x2, y: y2)
                let end = rel ? CGPoint(x: cp.x + x, y: cp.y + y) : CGPoint(x: x, y: y)
                path.addCurve(to: P(end.x, end.y), control1: P(c1.x, c1.y), control2: P(c2.x, c2.y))
                lastCtrl = c2; cp = end
            case "S":
                let x2 = num(), y2 = num(), x = num(), y = num()
                let c2 = rel ? CGPoint(x: cp.x + x2, y: cp.y + y2) : CGPoint(x: x2, y: y2)
                let end = rel ? CGPoint(x: cp.x + x, y: cp.y + y) : CGPoint(x: x, y: y)
                let c1 = lastCtrl.map { CGPoint(x: 2 * cp.x - $0.x, y: 2 * cp.y - $0.y) } ?? cp
                path.addCurve(to: P(end.x, end.y), control1: P(c1.x, c1.y), control2: P(c2.x, c2.y))
                lastCtrl = c2; cp = end
            case "Z":
                path.closeSubpath(); cp = startPt; lastCtrl = nil
            default:
                break
            }

            if idx == idxBefore { idx += 1 } // never stall
        }
        return path
    }

    private static func tokenize(_ s: String) -> [Token] {
        var tokens: [Token] = []
        let chars = Array(s)
        var i = 0

        func scanNumber() -> Double? {
            var str = ""
            if i < chars.count, chars[i] == "-" || chars[i] == "+" { str.append(chars[i]); i += 1 }
            var hasDot = false
            while i < chars.count {
                let c = chars[i]
                if c.isNumber { str.append(c); i += 1 }
                else if c == "." && !hasDot { hasDot = true; str.append(c); i += 1 }
                else if c == "e" || c == "E" {
                    str.append(c); i += 1
                    if i < chars.count, chars[i] == "-" || chars[i] == "+" { str.append(chars[i]); i += 1 }
                } else { break }
            }
            return Double(str)
        }

        while i < chars.count {
            let c = chars[i]
            if c.isLetter { tokens.append(.command(c)); i += 1 }
            else if c == " " || c == "," || c == "\n" || c == "\t" || c == "\r" { i += 1 }
            else if c.isNumber || c == "-" || c == "+" || c == "." {
                let before = i
                if let n = scanNumber() { tokens.append(.number(n)) }
                if i == before { i += 1 }
            } else { i += 1 }
        }
        return tokens
    }
}

// MARK: - Helpers

private struct AuthPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

// MARK: - Sheet Type

enum AuthSheet: Identifiable {
    case login
    case signup

    var id: String {
        switch self {
        case .login: return "login"
        case .signup: return "signup"
        }
    }
}

// MARK: - Profile Setup

/// One-time gate shown right after sign-in: pick a unique @username (friends
/// add you by it), then optionally set a profile photo — so the user never has
/// to hunt for either of these inside the app later.
struct ProfileSetupView: View {
    @EnvironmentObject var session: SessionStore
    @ObservedObject private var avatarStore = ProfileAvatarStore.shared

    enum Step { case username, photo }
    @State private var step: Step = .username

    // Username step
    @State private var username = ""
    @State private var availability: Availability = .idle
    @State private var checkTask: Task<Void, Never>?
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var fieldFocused: Bool

    // Photo step
    @State private var photoItem: PhotosPickerItem?
    @State private var isFinishing = false

    private enum Availability {
        case idle, checking, available, taken, invalid
    }

    private var isEnglish: Bool { appLanguageIsEnglish() }

    private var canContinue: Bool {
        availability == .available && !isSubmitting
    }

    var body: some View {
        ZStack {
            AuthArenaBackground()

            Group {
                switch step {
                case .username: usernameStep
                case .photo: photoStep
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 22)
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.3), value: step)
        .onAppear {
            if username.isEmpty {
                username = session.suggestedUsername()
            }
            // A handle already exists (defensive) → go straight to the photo step.
            let existing = (session.currentUser?.username ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !existing.isEmpty { step = .photo }

            scheduleAvailabilityCheck()
            if step == .username {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    fieldFocused = true
                }
            }
        }
    }
}

// MARK: - Profile Setup sections

private extension ProfileSetupView {
    var usernameStep: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 46)
            heroSection
            Spacer(minLength: 30)
            fieldSection
            Spacer(minLength: 22)
            continueSection
            Spacer(minLength: 18)
        }
    }

    var heroSection: some View {
        VStack(spacing: 20) {
            UpdoAIOrb(mode: .idle, size: 82)

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(Color(arenaHex: AuthArenaPalette.appCyan).opacity(0.7))
                        .frame(width: 18, height: 1)

                    Text(isEnglish ? "COMPLETE YOUR ACCOUNT" : "HESABINI TAMAMLA")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(2.6)
                        .foregroundStyle(Color(arenaHex: AuthArenaPalette.appCyan))

                    Rectangle()
                        .fill(Color(arenaHex: AuthArenaPalette.appCyan).opacity(0.7))
                        .frame(width: 18, height: 1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(isEnglish ? "Pick a" : "Kullanıcı")
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(UpdoTheme.textPrimary)

                    Text(isEnglish ? "handle" : "adını")
                        .font(.system(size: 32, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(arenaHex: AuthArenaPalette.appCyan),
                                    Color(arenaHex: AuthArenaPalette.appPurple)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)

                Text(isEnglish
                     ? "Friends will find and add you by this username. You can change it later in your profile."
                     : "Arkadaşların seni bu kullanıcı adıyla bulup ekleyecek. İstersen sonra profilinden değiştirebilirsin.")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(UpdoTheme.filmy(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 8)
            }
        }
    }

    var fieldSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("@")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(Color(arenaHex: AuthArenaPalette.appCyan))

                TextField("username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .submitLabel(.done)
                    .focused($fieldFocused)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(UpdoTheme.textPrimary)
                    .tint(Color(arenaHex: AuthArenaPalette.appCyan))
                    .onChange(of: username) { _, newValue in
                        let normalized = String(SessionStore.normalizedUsername(newValue).prefix(20))
                        if normalized != newValue {
                            username = normalized
                        }
                        errorMessage = nil
                        scheduleAvailabilityCheck()
                    }
                    .onSubmit { submit() }

                availabilityBadge
            }
            .padding(.horizontal, 18)
            .frame(height: 60)
            .background(fieldSurface)

            statusLine
                .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    var availabilityBadge: some View {
        switch availability {
        case .checking:
            ProgressView()
                .controlSize(.small)
                .tint(UpdoTheme.filmy(0.6))
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(arenaHex: AuthArenaPalette.appCyan))
                .transition(.scale.combined(with: .opacity))
        case .taken:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(arenaHex: AuthArenaPalette.coral))
                .transition(.scale.combined(with: .opacity))
        case .idle, .invalid:
            EmptyView()
        }
    }

    @ViewBuilder
    var statusLine: some View {
        if let errorMessage {
            statusText(errorMessage, tint: AuthArenaPalette.coral, icon: "exclamationmark.triangle.fill")
        } else {
            switch availability {
            case .available:
                statusText(isEnglish ? "Available" : "Müsait",
                           tint: AuthArenaPalette.appCyan, icon: "checkmark")
            case .taken:
                statusText(isEnglish ? "Already taken" : "Alınmış",
                           tint: AuthArenaPalette.coral, icon: "xmark")
            case .invalid:
                statusText(isEnglish ? "3–20 characters: letters, numbers or _" : "3–20 karakter: harf, rakam ya da _",
                           tint: "#8A8AA0", icon: "info.circle")
            case .idle, .checking:
                statusText(isEnglish ? "Letters, numbers and _ only" : "Sadece harf, rakam ve _",
                           tint: "#8A8AA0", icon: "at")
            }
        }
    }

    func statusText(_ text: String, tint: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(.system(size: 12.5, weight: .semibold))
        }
        .foregroundStyle(Color(arenaHex: tint).opacity(0.9))
    }

    var continueSection: some View {
        VStack(spacing: 16) {
            Button {
                submit()
            } label: {
                HStack(spacing: 10) {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text(isEnglish ? "Continue" : "Devam et")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .black))
                    }
                }
                .foregroundStyle(UpdoTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    Capsule().fill(
                        canContinue
                        ? AnyShapeStyle(AuthArenaPalette.appGradient)
                        : AnyShapeStyle(UpdoTheme.filmy(0.10))
                    )
                )
                .overlay(
                    Capsule().stroke(UpdoTheme.filmy(canContinue ? 0.16 : 0.06), lineWidth: 1)
                )
                .shadow(
                    color: canContinue ? Color(arenaHex: AuthArenaPalette.appPurple).opacity(0.26) : .clear,
                    radius: 16, y: 8
                )
                .opacity(canContinue ? 1 : 0.7)
            }
            .buttonStyle(AuthPressButtonStyle())
            .disabled(!canContinue)

            Button {
                session.signOut()
            } label: {
                Text(isEnglish ? "Sign out" : "Oturumu kapat")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(UpdoTheme.filmy(0.42))
            }
            .buttonStyle(.plain)
        }
    }

    var fieldSurface: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(UpdoTheme.filmy(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        availability == .available
                        ? Color(arenaHex: AuthArenaPalette.appCyan).opacity(0.5)
                        : (availability == .taken
                           ? Color(arenaHex: AuthArenaPalette.coral).opacity(0.5)
                           : UpdoTheme.filmy(0.09)),
                        lineWidth: 1
                    )
            )
    }

    func scheduleAvailabilityCheck() {
        checkTask?.cancel()

        let normalized = SessionStore.normalizedUsername(username)

        guard SessionStore.isValidUsername(normalized) else {
            withAnimation(.easeInOut(duration: 0.15)) {
                availability = normalized.isEmpty ? .idle : .invalid
            }
            return
        }

        withAnimation(.easeInOut(duration: 0.15)) { availability = .checking }

        checkTask = Task {
            try? await Task.sleep(nanoseconds: 420_000_000)
            if Task.isCancelled { return }

            let ok = await session.isUsernameAvailable(normalized)
            if Task.isCancelled { return }

            await MainActor.run {
                // Ignore stale results if the field changed meanwhile.
                guard SessionStore.normalizedUsername(username) == normalized else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    availability = ok ? .available : .taken
                }
            }
        }
    }

    func submit() {
        guard canContinue else { return }

        fieldFocused = false
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                try await session.chooseUsername(username)
                HapticManager.shared.success()
                // Handle claimed — move on to the optional photo step. The gate
                // stays open (it keys off the profile-setup flag, not username).
                withAnimation(.easeInOut(duration: 0.3)) { step = .photo }
            } catch {
                errorMessage = (error as? UsernameSetupError)?.errorDescription
                    ?? error.localizedDescription
                availability = .taken
            }
            isSubmitting = false
        }
    }

    // MARK: Photo step

    var photoStep: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 46)
            photoHeroSection
            Spacer(minLength: 34)
            photoPickerSection
            Spacer(minLength: 26)
            photoContinueSection
            Spacer(minLength: 18)
        }
    }

    var photoHeroSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color(arenaHex: AuthArenaPalette.appCyan).opacity(0.7))
                    .frame(width: 18, height: 1)

                Text(isEnglish ? "ONE LAST STEP" : "SON BİR ADIM")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(2.6)
                    .foregroundStyle(Color(arenaHex: AuthArenaPalette.appCyan))

                Rectangle()
                    .fill(Color(arenaHex: AuthArenaPalette.appCyan).opacity(0.7))
                    .frame(width: 18, height: 1)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(isEnglish ? "Add a" : "Profil")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(UpdoTheme.textPrimary)

                Text(isEnglish ? "photo" : "fotoğrafın")
                    .font(.system(size: 32, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(arenaHex: AuthArenaPalette.appCyan),
                                Color(arenaHex: AuthArenaPalette.appPurple)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Text(isEnglish
                 ? "Friends recognize you faster with a photo. It's optional — you can add it now or later."
                 : "Fotoğrafla arkadaşların seni daha kolay tanır. İsteğe bağlı — şimdi ya da sonra ekleyebilirsin.")
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(UpdoTheme.filmy(0.6))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 8)
        }
    }

    var photoPickerSection: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                ProfileAvatarCircle(
                    image: avatarStore.image,
                    name: session.currentUser?.fullName ?? "U",
                    accent: Color(arenaHex: AuthArenaPalette.appCyan),
                    size: 168
                )
                .overlay(
                    Circle().stroke(UpdoTheme.filmy(0.14), lineWidth: 1)
                )
                .shadow(color: Color(arenaHex: AuthArenaPalette.appPurple).opacity(0.28), radius: 22, y: 10)

                Circle()
                    .fill(AuthArenaPalette.appGradient)
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(UpdoTheme.textPrimary)
                    )
                    .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 3))
                    .offset(x: 4, y: 4)
            }
        }
        .buttonStyle(AuthPressButtonStyle())
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task { await applyPhoto(newItem) }
        }
    }

    var photoContinueSection: some View {
        VStack(spacing: 16) {
            Button {
                finish()
            } label: {
                HStack(spacing: 10) {
                    if isFinishing {
                        ProgressView().tint(.white)
                    } else {
                        Text(avatarStore.image == nil
                             ? (isEnglish ? "Skip for now" : "Şimdilik geç")
                             : (isEnglish ? "Continue" : "Devam et"))
                            .font(.system(size: 18, weight: .black, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .black))
                    }
                }
                .foregroundStyle(UpdoTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    Capsule().fill(
                        avatarStore.image == nil
                        ? AnyShapeStyle(UpdoTheme.filmy(0.10))
                        : AnyShapeStyle(AuthArenaPalette.appGradient)
                    )
                )
                .overlay(
                    Capsule().stroke(UpdoTheme.filmy(avatarStore.image == nil ? 0.10 : 0.16), lineWidth: 1)
                )
                .shadow(
                    color: avatarStore.image == nil ? .clear : Color(arenaHex: AuthArenaPalette.appPurple).opacity(0.26),
                    radius: 16, y: 8
                )
            }
            .buttonStyle(AuthPressButtonStyle())
            .disabled(isFinishing)

            Text(isEnglish
                 ? "You can always change it in your profile."
                 : "İstediğin zaman profilinden değiştirebilirsin.")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(UpdoTheme.filmy(0.4))
                .multilineTextAlignment(.center)
        }
    }

    func applyPhoto(_ item: PhotosPickerItem) async {
        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let uiImage = UIImage(data: data)
        else { return }

        avatarStore.save(uiImage, for: session.currentUser?.id.uuidString)
        HapticManager.shared.success()
    }

    func finish() {
        isFinishing = true
        HapticManager.shared.success()
        // Flips needsProfileSetup → false, so RootView moves on to onboarding/app.
        session.markProfileSetupDone()
    }
}
