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
    @FocusState private var focusedField: Field?

    private enum Field {
        case fullName
        case username
        case email
        case password
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if appTheme == AppTheme.gradient.rawValue {
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.18),
                            Color.blue.opacity(0.10),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                }

                ScrollView {
                    VStack(spacing: 22) {
                        Spacer(minLength: 30)

                        headerSection
                        modePicker
                        formCard
                        actionButton

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarHidden(true)
        }
    }
}

private extension AuthView {
    var headerSection: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.14))
                    .frame(width: 84, height: 84)

                Image(systemName: "checklist")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }

            Text("DailyTodo")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(palette.primaryText)

            Text(isLogin
                 ? "Sign in and continue planning your day."
                 : "Create your account and start building your routine.")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
        }
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
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(palette.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
    }

    func authModeButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? palette.primaryText : palette.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            selected
                            ? Color.accentColor.opacity(0.18)
                            : palette.secondaryCardFill
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            selected ? Color.accentColor.opacity(0.32) : palette.cardStroke,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    var formCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !isLogin {
                inputField(
                    title: "Full Name",
                    placeholder: "Your name",
                    text: $fullName,
                    field: .fullName,
                    submitLabel: .next,
                    isSecure: false
                ) {
                    focusedField = .username
                }

                inputField(
                    title: "Username",
                    placeholder: "yourusername",
                    text: $username,
                    field: .username,
                    submitLabel: .next,
                    isSecure: false
                ) {
                    focusedField = .email
                }
            }

            inputField(
                title: "Email",
                placeholder: "you@example.com",
                text: $email,
                field: .email,
                submitLabel: .next,
                isSecure: false
            ) {
                focusedField = .password
            }

            inputField(
                title: "Password",
                placeholder: "Password",
                text: $password,
                field: .password,
                submitLabel: .go,
                isSecure: true
            ) {
                Task {
                    await handleAuth()
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 2)
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private func inputField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        submitLabel: SubmitLabel,
        isSecure: Bool,
        onSubmit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.primaryText)

            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                        .textInputAutocapitalization(
                            field == .email || field == .username ? .never : .words
                        )
                        .autocorrectionDisabled(field == .email || field == .username)
                }
            }
            .focused($focusedField, equals: field)
            .submitLabel(submitLabel)
            .onSubmit(onSubmit)
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(palette.secondaryCardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
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
            HStack {
                if session.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: isLogin ? "arrow.right.circle.fill" : "person.badge.plus")
                    Text(isLogin ? "Login" : "Create Account")
                }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.accentColor)
            )
        }
        .buttonStyle(.plain)
        .disabled(session.isLoading || !canSubmit)
        .opacity(session.isLoading || !canSubmit ? 0.7 : 1)
    }

    var canSubmit: Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        if isLogin {
            return !cleanEmail.isEmpty && !cleanPassword.isEmpty
        } else {
            let cleanFullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            return !cleanFullName.isEmpty && !cleanUsername.isEmpty && !cleanEmail.isEmpty && !cleanPassword.isEmpty
        }
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }

    func validateInputs() -> String? {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanEmail.isEmpty {
            return "Email is required."
        }

        if !cleanEmail.contains("@") {
            return "Please enter a valid email."
        }

        if cleanPassword.count < 6 {
            return "Password must be at least 6 characters."
        }

        if !isLogin {
            let cleanFullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

            if cleanFullName.isEmpty {
                return "Full name is required."
            }

            if cleanUsername.count < 3 {
                return "Username must be at least 3 characters."
            }
        }

        return nil
    }

    func handleAuth() async {
        errorMessage = nil

        if let validationError = validateInputs() {
            errorMessage = validationError
            return
        }

        do {
            if isLogin {
                try await session.signIn(
                    email: email,
                    password: password
                )
            } else {
                try await session.signUp(
                    fullName: fullName,
                    email: email,
                    username: username,
                    password: password
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
