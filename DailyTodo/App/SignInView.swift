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

struct ForgotPasswordSheet: View {
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

    private var cyan: Color { UpdoTheme.cyan }
    private var purple: Color { UpdoTheme.purple }

    var body: some View {
        NavigationStack {
            ZStack {
                UpdoTheme.background.ignoresSafeArea()

                Circle().fill(cyan.opacity(0.10)).frame(width: 300, height: 300)
                    .blur(radius: 100).offset(x: 150, y: -240).ignoresSafeArea()
                Circle().fill(purple.opacity(0.12)).frame(width: 320, height: 320)
                    .blur(radius: 110).offset(x: -160, y: 360).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 8) {
                            Rectangle().fill(cyan).frame(width: 20, height: 1)
                            Text(isEN ? "PASSWORD RESET" : "ŞİFRE SIFIRLAMA")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .tracking(2.3)
                                .foregroundStyle(cyan)
                        }
                        .padding(.top, 8)

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(isEN ? "Reset" : "Şifreni")
                                .font(.system(size: 38, weight: .black))
                                .foregroundStyle(.white)
                            Text(isEN ? "password" : "sıfırla")
                                .font(.system(size: 35, weight: .regular, design: .serif))
                                .italic()
                                .foregroundStyle(
                                    LinearGradient(colors: [cyan, purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                        Text(step == .email
                             ? (isEN ? "Enter your email — we'll send a 6-digit code." : "E-postanı gir — 6 haneli bir kod göndereceğiz.")
                             : (isEN ? "Enter the code from your email and a new password." : "E-postana gelen kodu ve yeni şifreni gir."))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))

                        VStack(spacing: 12) {
                            if step == .email {
                                boxedField(placeholder: "Email", text: $email, secure: false, icon: "envelope.fill")
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                primaryButton(isEN ? "Send code" : "Kod gönder") { await sendCode() }
                            } else {
                                boxedField(placeholder: isEN ? "6-digit code" : "6 haneli kod", text: $code, secure: false, icon: "number")
                                    .keyboardType(.numberPad)
                                boxedField(placeholder: isEN ? "New password" : "Yeni şifre", text: $newPassword, secure: true, icon: "lock.fill")
                                primaryButton(isEN ? "Update password" : "Şifreyi güncelle") { await verifyAndUpdate() }
                                Button { Task { await sendCode() } } label: {
                                    Text(isEN ? "Resend code" : "Kodu tekrar gönder")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(cyan)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                                .disabled(isBusy)
                            }
                        }
                        .padding(.top, 4)

                        if !errorText.isEmpty {
                            statusBanner(errorText, color: Color(arenaHex: "#FF6B57"), icon: "exclamationmark.triangle.fill")
                        }
                        if !infoText.isEmpty {
                            statusBanner(infoText, color: Color(arenaHex: "#22C55E"), icon: "checkmark.circle.fill")
                        }

                        Spacer(minLength: 8)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEN ? "Close" : "Kapat") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .onAppear { if email.isEmpty { email = prefillEmail } }
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
    }

    @ViewBuilder
    private func boxedField(placeholder: String, text: Binding<String>, secure: Bool, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(cyan)
                .frame(width: 20)
            Group {
                if secure { SecureField(placeholder, text: text) } else { TextField(placeholder, text: text) }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func primaryButton(_ title: String, _ action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            HStack {
                Spacer()
                if isBusy {
                    ProgressView().tint(.white)
                } else {
                    Text(title).font(.system(size: 17, weight: .black)).foregroundStyle(.white)
                }
                Spacer()
            }
            .padding(.vertical, 17)
            .background(
                Capsule().fill(
                    LinearGradient(colors: [cyan, purple], startPoint: .leading, endPoint: .trailing)
                )
            )
            .shadow(color: purple.opacity(0.30), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }

    private func statusBanner(_ text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(color.opacity(0.22), lineWidth: 1)
                )
        )
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
