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
    }

    private func handleSignIn() async {
        errorText = ""

        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorText = "Email boş olamaz."
            return
        }

        guard password.count >= 4 else {
            errorText = "Şifre en az 4 karakter olsun."
            return
        }

        do {
            try await session.signIn(email: email, password: password)
            dismiss()
        } catch {
            errorText = "Giriş yapılamadı."
        }
    }
}
