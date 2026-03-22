//
//  AuthView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.03.2026.
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject var session: SessionStore
    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue

    private let palette = ThemePalette()

    @State private var isLogin = true

    @State private var fullName = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""

    @State private var errorMessage: String?
    @State private var didAnimateIn = false

    private var cleanFullName: String {
        fullName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var cleanEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var cleanPassword: String {
        password.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var formIsValid: Bool {
        if isLogin {
            return !cleanEmail.isEmpty && !cleanPassword.isEmpty
        } else {
            return !cleanFullName.isEmpty &&
                   !cleanUsername.isEmpty &&
                   !cleanEmail.isEmpty &&
                   !cleanPassword.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                authBackground

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Spacer(minLength: 36)

                        headerSection
                            .opacity(didAnimateIn ? 1 : 0)
                            .offset(y: didAnimateIn ? 0 : 18)

                        modePicker
                            .opacity(didAnimateIn ? 1 : 0)
                            .offset(y: didAnimateIn ? 0 : 22)

                        formCard
                            .opacity(didAnimateIn ? 1 : 0)
                            .offset(y: didAnimateIn ? 0 : 26)

                        actionButton
                            .opacity(didAnimateIn ? 1 : 0)
                            .offset(y: didAnimateIn ? 0 : 30)

                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                guard !didAnimateIn else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                    didAnimateIn = true
                }
            }
        }
    }
}

// MARK: - UI

private extension AuthView {

    var authBackground: some View {
        ZStack {
            AppBackground()

            if appTheme == AppTheme.gradient.rawValue {
                RadialGradient(
                    colors: [
                        Color.purple.opacity(0.22),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 40,
                    endRadius: 320
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        Color.blue.opacity(0.18),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 70,
                    endRadius: 380
                )
                .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.06),
                        Color.clear,
                        Color.black.opacity(0.10)
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
                .ignoresSafeArea()
            }
        }
    }

    var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.14))
                    .frame(width: 112, height: 112)

                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 86, height: 86)

                Image(systemName: "checklist")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 10) {
                Text("DailyTodo")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                Text(
                    isLogin
                    ? "Sign in and continue planning your day."
                    : "Create your account and start building your routine."
                )
                .font(.title3.weight(.medium))
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 34)
    }

    var modePicker: some View {
        HStack(spacing: 10) {
            authModeButton(title: "Login", selected: isLogin) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    isLogin = true
                    errorMessage = nil
                }
            }

            authModeButton(title: "Sign Up", selected: !isLogin) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    isLogin = false
                    errorMessage = nil
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(palette.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
    }

    func authModeButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(selected ? palette.primaryText : palette.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            selected
                            ? LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.24),
                                    Color.accentColor.opacity(0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    palette.secondaryCardFill,
                                    palette.secondaryCardFill.opacity(0.75)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            selected ? Color.accentColor.opacity(0.32) : palette.cardStroke,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    var formCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !isLogin {
                authField(
                    title: "Full Name",
                    placeholder: "Your name",
                    text: $fullName,
                    autocap: .words
                )

                authField(
                    title: "Username",
                    placeholder: "yourusername",
                    text: $username,
                    autocap: .never
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }

            authField(
                title: "Email",
                placeholder: "you@example.com",
                text: $email,
                autocap: .never
            )
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            VStack(alignment: .leading, spacing: 10) {
                Text("Password")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.primaryText)

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(palette.secondaryCardFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(palette.cardStroke, lineWidth: 1)
                            )
                    )
                    .foregroundStyle(palette.primaryText)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.red)
                    .padding(.top, 2)
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    func authField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        autocap: TextInputAutocapitalization
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.primaryText)

            TextField(placeholder, text: text)
                .textInputAutocapitalization(autocap)
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(palette.secondaryCardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(palette.cardStroke, lineWidth: 1)
                        )
                )
                .foregroundStyle(palette.primaryText)
        }
    }

    var actionButton: some View {
        Button {
            Task {
                await handleAuth()
            }
        } label: {
            HStack(spacing: 10) {
                if session.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: isLogin ? "arrow.right.circle.fill" : "person.badge.plus")
                }

                Text(isLogin ? "Login" : "Create Account")
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: formIsValid
                            ? [Color.blue.opacity(0.92), Color.purple.opacity(0.92)]
                            : [Color.blue.opacity(0.45), Color.blue.opacity(0.35)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .scaleEffect(session.isLoading ? 0.985 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!formIsValid || session.isLoading)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }
}

// MARK: - Logic

private extension AuthView {
    func handleAuth() async {
        errorMessage = nil

        do {
            if isLogin {
                try await session.signIn(
                    email: cleanEmail,
                    password: cleanPassword
                )
            } else {
                try await session.signUp(
                    fullName: cleanFullName,
                    email: cleanEmail,
                    username: cleanUsername,
                    password: cleanPassword
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
