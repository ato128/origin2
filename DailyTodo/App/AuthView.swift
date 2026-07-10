//
//  AuthView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.03.2026.
//
import SwiftUI
import AuthenticationServices
import CryptoKit

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
                        .foregroundStyle(.white)

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
                    .foregroundStyle(Color.white.opacity(0.6))
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
            .frame(height: 52)
            .clipShape(Capsule())

            // Google — same weight, white capsule with the brand "G".
            Button(action: startGoogleSignIn) {
                HStack(spacing: 8) {
                    Text("G")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(Color(arenaHex: "#4285F4"))

                    Text(tr("av_continue_google"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Capsule().fill(.white))
            }
            .buttonStyle(AuthPressButtonStyle())

            // Divider
            HStack(spacing: 12) {
                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
                Text(tr("av_or_caps"))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(.white.opacity(0.35))
                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
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
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.055))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.13), lineWidth: 1))
                )
            }
            .buttonStyle(AuthPressButtonStyle())

            Button {
                HapticManager.shared.navigation()
                activeSheet = .signup
            } label: {
                HStack(spacing: 5) {
                    Text(tr("av_no_account"))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(tr("auth_signup"))
                        .foregroundStyle(Color(arenaHex: AuthArenaPalette.appCyan))
                }
                .font(.system(size: 13.5, weight: .semibold))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            Text(tr("av_terms_note"))
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.32))
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
                Color.white.opacity(0.045)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var surfaceGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.075),
                Color.white.opacity(0.045),
                Color.white.opacity(0.030)
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
