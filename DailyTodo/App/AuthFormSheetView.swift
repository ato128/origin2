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
            sheetBackground

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    headerSection
                    formSection
                    submitSection
                }
                .padding(20)
                .padding(.bottom, 28)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close") {
                    dismiss()
                }
                .foregroundStyle(Color.white.opacity(0.82))
            }
        }
    }
}

private extension AuthFormSheetView {
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(mode.title)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(mode.subtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.7))
        }
    }

    var formSection: some View {
        VStack(spacing: 14) {
            if mode == .signup {
                premiumField(
                    title: "Name",
                    placeholder: "Your name",
                    text: $name,
                    systemImage: "person.fill"
                )
            }

            premiumField(
                title: "Email",
                placeholder: "you@example.com",
                text: $email,
                systemImage: "envelope.fill"
            )

            passwordField(
                title: "Password",
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
                Text(errorMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.red.opacity(0.95))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
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
                    }

                    Text((isLoading || session.isLoading) ? "Please wait..." : mode.buttonTitle)
                }
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .opacity(canSubmit ? 1 : 0.55)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit || isLoading || session.isLoading)

            if mode == .login {
                Text("Forgot password?")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 8)
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
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.78))

            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.white.opacity(0.5))
                    .frame(width: 18)

                TextField(placeholder, text: text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
    }

    func passwordField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        showText: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.78))

            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Color.white.opacity(0.5))
                    .frame(width: 18)

                Group {
                    if showText.wrappedValue {
                        TextField(placeholder, text: text)
                    } else {
                        SecureField(placeholder, text: text)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.white)

                Button {
                    showText.wrappedValue.toggle()
                } label: {
                    Image(systemName: showText.wrappedValue ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(Color.white.opacity(0.58))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
    }

    var sheetBackground: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.blue.opacity(0.16),
                    Color.purple.opacity(0.12),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

enum AuthMode {
    case login
    case signup

    var title: String {
        switch self {
        case .login: return "Login"
        case .signup: return "Create Account"
        }
    }

    var subtitle: String {
        switch self {
        case .login: return "Welcome back. Continue planning your day."
        case .signup: return "Start fresh with a new DailyTodo account."
        }
    }

    var buttonTitle: String {
        switch self {
        case .login: return "Login"
        case .signup: return "Create Account"
        }
    }
}
