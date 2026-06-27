//
//  AuthFormSheetView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 22.03.2026.
//

import SwiftUI

struct AuthFormSheetView: View {
    let mode: AuthMode

    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            AuthFormArenaBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    headerSection
                    formSection
                    submitSection
                }
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 34)
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 7) {
                        Text(tr("event_close"))
                            .font(.system(size: 13, weight: .black, design: .rounded))

                        Image(systemName: "xmark").accessibilityLabel(tr("event_close"))
                            .font(.system(size: 12, weight: .black))
                    }
                    .foregroundStyle(.white.opacity(0.82))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.075))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private extension AuthFormSheetView {
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("— \(mode.eyebrow) —")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(2.5)
                .foregroundStyle(Color(arenaHex: AuthFormPalette.appCyan))

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(mode.titleFirst)
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(.white)

                Text(mode.titleAccent)
                    .font(.system(size: 34, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(arenaHex: AuthFormPalette.appCyan),
                                Color(arenaHex: AuthFormPalette.appPurple)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .lineLimit(2)
            .minimumScaleFactor(0.70)

            Text(mode.subtitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.58))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    var formSection: some View {
        VStack(spacing: 15) {
            if mode == .signup {
                premiumField(
                    title: tr("afs_name"),
                    placeholder: tr("afs_name_ph"),
                    text: $name,
                    systemImage: "person.fill",
                    capitalization: .words
                )
            }

            premiumField(
                title: tr("afs_email"),
                placeholder: "you@example.com",
                text: $email,
                systemImage: "envelope.fill",
                capitalization: .never
            )

            passwordField(
                title: tr("afs_password"),
                placeholder: "Password",
                text: $password,
                showText: $showPassword
            )

            if mode == .signup {
                passwordField(
                    title: "Confirm Password",
                    placeholder: "Confirm password",
                    text: $confirmPassword,
                    showText: $showConfirmPassword
                )
            }

            if let errorMessage {
                errorCard(errorMessage)
            }
        }
    }

    var submitSection: some View {
        VStack(spacing: 14) {
            Button {
                Task {
                    await submit()
                }
            } label: {
                HStack(spacing: 10) {
                    if isLoading || session.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: mode == .login ? "arrow.right.circle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .black))
                    }

                    Text((isLoading || session.isLoading) ? "Please wait..." : mode.buttonTitle)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    Capsule()
                        .fill(
                            canSubmit
                            ? AnyShapeStyle(AuthFormPalette.hotGradient)
                            : AnyShapeStyle(Color.white.opacity(0.10))
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(canSubmit ? 0.16 : 0.06), lineWidth: 1)
                )
                .shadow(
                    color: canSubmit ? Color(arenaHex: AuthFormPalette.appPurple).opacity(0.24) : .clear,
                    radius: 16,
                    y: 8
                )
                .opacity(canSubmit ? 1 : 0.70)
            }
            .buttonStyle(AuthFormPressButtonStyle())
            .disabled(!canSubmit || isLoading || session.isLoading)

            if mode == .login {
                Text("Forgot password?")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.48))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 4)
    }

    var canSubmit: Bool {
        switch mode {
        case .login:
            return !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !password.isEmpty

        case .signup:
            return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !password.isEmpty &&
                   !confirmPassword.isEmpty
        }
    }

    @MainActor
    func submit() async {
        errorMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanConfirmPassword = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty else {
            errorMessage = "Please enter your email."
            return
        }

        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            errorMessage = "Please enter a valid email."
            return
        }

        guard !cleanPassword.isEmpty else {
            errorMessage = "Please enter your password."
            return
        }

        if mode == .signup {
            guard !trimmedName.isEmpty else {
                errorMessage = "Please enter your name."
                return
            }

            guard cleanPassword.count >= 6 else {
                errorMessage = "Password must be at least 6 characters."
                return
            }

            guard cleanPassword == cleanConfirmPassword else {
                errorMessage = "Passwords do not match."
                return
            }
        }

        isLoading = true
        defer { isLoading = false }

        do {
            switch mode {
            case .login:
                try await session.signIn(email: trimmedEmail, password: cleanPassword)

            case .signup:
                let generatedUsername = makeUsername(from: trimmedName, email: trimmedEmail)
                try await session.signUp(
                    fullName: trimmedName,
                    email: trimmedEmail,
                    username: generatedUsername,
                    password: cleanPassword
                )
            }

            dismiss()
        } catch {
            errorMessage = readableError(from: error)
        }
    }

    func makeUsername(from name: String, email: String) -> String {
        let baseName = name
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .filter { $0.isLetter || $0.isNumber }

        if !baseName.isEmpty {
            return baseName
        }

        let emailPart = email.components(separatedBy: "@").first ?? "user"
        let cleaned = emailPart
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }

        return cleaned.isEmpty ? "user" : cleaned
    }

    func readableError(from error: Error) -> String {
        let message = error.localizedDescription.lowercased()

        if message.contains("invalid login credentials") {
            return "Email or password is incorrect."
        }

        if message.contains("email not confirmed") {
            return "Please confirm your email before logging in."
        }

        if message.contains("user already registered") {
            return "This email is already registered."
        }

        if message.contains("password should be at least") {
            return "Password must be at least 6 characters."
        }

        return error.localizedDescription
    }

    func premiumField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        systemImage: String,
        capitalization: TextInputAutocapitalization
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color.white.opacity(0.46))

            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color(arenaHex: AuthFormPalette.appCyan))
                    .frame(width: 20)

                TextField(placeholder, text: text)
                    .textInputAutocapitalization(capitalization)
                    .autocorrectionDisabled()
                    .keyboardType(title.lowercased() == "email" ? .emailAddress : .default)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .tint(Color(arenaHex: AuthFormPalette.appCyan))
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(authFormFieldSurface)
        }
    }

    func passwordField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        showText: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color.white.opacity(0.46))

            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color(arenaHex: AuthFormPalette.appCyan))
                    .frame(width: 20)

                Group {
                    if showText.wrappedValue {
                        TextField(placeholder, text: text)
                    } else {
                        SecureField(placeholder, text: text)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .tint(Color(arenaHex: AuthFormPalette.appCyan))

                Button {
                    showText.wrappedValue.toggle()
                } label: {
                    Image(systemName: showText.wrappedValue ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Color.white.opacity(0.52))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(authFormFieldSurface)
        }
    }

    var authFormFieldSurface: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.070))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.085), lineWidth: 1)
            )
    }

    func errorCard(_ text: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Color(arenaHex: AuthFormPalette.coral))

            Text(text)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(Color(arenaHex: AuthFormPalette.coral).opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(Color(arenaHex: AuthFormPalette.coral).opacity(0.22), lineWidth: 1)
        )
    }
}

// MARK: - Palette

private enum AuthFormPalette {
    static let backgroundTop = "#05060D"
    static let backgroundMid = "#070713"
    static let backgroundBottom = "#07040C"

    static let appBlue = "#1593FF"
    static let appBlueSoft = "#1E6BFF"
    static let appCyan = "#2DD4FF"
    static let appPurple = "#7C3AED"
    static let coral = "#FF5A44"
    static let gold = "#FBBF24"

    static var hotGradient: LinearGradient {
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
}

// MARK: - Background

private struct AuthFormArenaBackground: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(arenaHex: AuthFormPalette.backgroundTop),
                    Color(arenaHex: AuthFormPalette.backgroundMid),
                    Color(arenaHex: AuthFormPalette.backgroundBottom)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(arenaHex: AuthFormPalette.appBlue).opacity(0.12))
                .frame(width: 270, height: 270)
                .blur(radius: 98)
                .offset(x: 165, y: -220)

            Circle()
                .fill(Color(arenaHex: AuthFormPalette.appPurple).opacity(0.16))
                .frame(width: 330, height: 330)
                .blur(radius: 115)
                .offset(x: -180, y: 500)

            Circle()
                .fill(Color(arenaHex: AuthFormPalette.coral).opacity(0.070))
                .frame(width: 280, height: 280)
                .blur(radius: 105)
                .offset(x: 170, y: 285)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.16),
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.42)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Button Style

private struct AuthFormPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

// MARK: - Color Hex

// MARK: - Mode

enum AuthMode {
    case login
    case signup

    var eyebrow: String {
        switch self {
        case .login: return "WELCOME BACK"
        case .signup: return "NEW ACCOUNT"
        }
    }

    var titleFirst: String {
        switch self {
        case .login: return "Login"
        case .signup: return "Create"
        }
    }

    var titleAccent: String {
        switch self {
        case .login: return "now"
        case .signup: return "account"
        }
    }

    var title: String {
        switch self {
        case .login: return "Login"
        case .signup: return "Create Account"
        }
    }

    var subtitle: String {
        switch self {
        case .login:
            return "Welcome back. Continue planning your day."
        case .signup:
            return "Start fresh with a new Updo account."
        }
    }

    var buttonTitle: String {
        switch self {
        case .login: return "Login"
        case .signup: return "Create Account"
        }
    }
}
