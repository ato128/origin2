//
//  SignInView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.03.2026.
//

import SwiftUI

struct SignInView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    let onShowSignUp: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var errorText = ""
    @State private var showForgotSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Spacer(minLength: 30)

                Text("Welcome Back")
                    .font(.system(size: 34, weight: .black, design: .rounded))

                Text("Sign in to sync your account, friends, crews and shared focus later.")
                    .foregroundStyle(.secondary)

                VStack(spacing: 14) {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )

                    SecureField("Password", text: $password)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                }

                if !errorText.isEmpty {
                    Text(errorText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                }

                Button {
                    Task {
                        await handleSignIn()
                    }
                } label: {
                    HStack {
                        Spacer()
                        if session.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Sign In")
                                .font(.headline.bold())
                        }
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(Color.accentColor)
                    )
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button {
                    showForgotSheet = true
                } label: {
                    Text(appLanguageIsEnglish() ? "Forgot your password?" : "Şifreni mi unuttun?")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    onShowSignUp()
                } label: {
                    Text("Don’t have an account? Create one")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 20)
            }
            .padding(24)
        }
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showForgotSheet) {
            ForgotPasswordSheet(prefillEmail: email)
                .environmentObject(session)
        }
    }

    private func handleSignIn() async {
        errorText = ""

        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorText = tr("si_email_empty")
            return
        }

        guard password.count >= 4 else {
            errorText = tr("si_pw_short")
            return
        }

        do {
            try await session.signIn(email: email, password: password)
            dismiss()
        } catch {
            errorText = tr("si_signin_failed")
        }
    }
}

// MARK: - Şifre sıfırlama (e-postaya kod)

private struct ForgotPasswordSheet: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    let prefillEmail: String

    private enum Step { case email, code }
    @State private var step: Step = .email
    @State private var email = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var errorText = ""
    @State private var infoText = ""
    @State private var isBusy = false

    private var isEN: Bool { appLanguageIsEnglish() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(isEN ? "Reset password" : "Şifreyi sıfırla")
                        .font(.system(size: 28, weight: .black, design: .rounded))

                    if step == .email {
                        Text(isEN ? "Enter your email — we'll send a 6-digit code."
                                  : "E-postanı gir — 6 haneli bir kod göndereceğiz.")
                            .foregroundStyle(.secondary)

                        boxedField(placeholder: "Email", text: $email, secure: false)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)

                        primaryButton(isEN ? "Send code" : "Kod gönder") { await sendCode() }
                    } else {
                        Text(isEN ? "Enter the code from your email and a new password."
                                  : "E-postana gelen kodu ve yeni şifreni gir.")
                            .foregroundStyle(.secondary)

                        boxedField(placeholder: isEN ? "6-digit code" : "6 haneli kod", text: $code, secure: false)
                            .keyboardType(.numberPad)

                        boxedField(placeholder: isEN ? "New password" : "Yeni şifre", text: $newPassword, secure: true)

                        primaryButton(isEN ? "Update password" : "Şifreyi güncelle") { await verifyAndUpdate() }

                        Button {
                            Task { await sendCode() }
                        } label: {
                            Text(isEN ? "Resend code" : "Kodu tekrar gönder")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                        .disabled(isBusy)
                    }

                    if !errorText.isEmpty {
                        Text(errorText).font(.subheadline.weight(.semibold)).foregroundStyle(.red)
                    }
                    if !infoText.isEmpty {
                        Text(infoText).font(.subheadline.weight(.semibold)).foregroundStyle(.green)
                    }

                    Spacer(minLength: 8)
                }
                .padding(24)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isEN ? "Cancel" : "Vazgeç") { dismiss() }
                }
            }
        }
        .onAppear { if email.isEmpty { email = prefillEmail } }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func boxedField(placeholder: String, text: Binding<String>, secure: Bool) -> some View {
        Group {
            if secure { SecureField(placeholder, text: text) } else { TextField(placeholder, text: text) }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06)))
    }

    private func primaryButton(_ title: String, _ action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            HStack {
                Spacer()
                if isBusy { ProgressView().tint(.white) } else { Text(title).font(.headline.bold()) }
                Spacer()
            }
            .padding(.vertical, 15)
            .background(Capsule().fill(Color.accentColor))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }

    private func sendCode() async {
        errorText = ""; infoText = ""
        let clean = email.trimmingCharacters(in: .whitespaces)
        guard clean.contains("@") else {
            errorText = isEN ? "Enter a valid email." : "Geçerli bir e-posta gir."
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            try await session.sendPasswordReset(email: clean)
            infoText = isEN ? "Code sent — check your email." : "Kod gönderildi — e-postanı kontrol et."
            step = .code
        } catch {
            errorText = isEN ? "Couldn't send the code." : "Kod gönderilemedi."
        }
    }

    private func verifyAndUpdate() async {
        errorText = ""; infoText = ""
        guard code.trimmingCharacters(in: .whitespaces).count >= 6 else {
            errorText = isEN ? "Enter the 6-digit code." : "6 haneli kodu gir."
            return
        }
        guard newPassword.count >= 6 else {
            errorText = isEN ? "Password must be at least 6 characters." : "Şifre en az 6 karakter olmalı."
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            try await session.verifyResetCode(email: email, code: code)
            try await session.updatePassword(newPassword)
            infoText = isEN ? "Password updated! 🎉" : "Şifren güncellendi! 🎉"
            try? await Task.sleep(nanoseconds: 900_000_000)
            dismiss()
        } catch {
            errorText = isEN ? "Invalid or expired code." : "Kod geçersiz ya da süresi dolmuş."
        }
    }
}
