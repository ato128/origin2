//
//  SignUpView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.03.2026.
//
import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    let onShowSignIn: () -> Void

    @State private var fullName = ""
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var errorText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Spacer(minLength: 30)

                Text("Create Account")
                    .font(.system(size: 34, weight: .black, design: .rounded))

                Text("Create your account now and get ready for backend sync.")
                    .foregroundStyle(.secondary)

                VStack(spacing: 14) {
                    TextField("Full Name", text: $fullName)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )

                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )

                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
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
                        await handleSignUp()
                    }
                } label: {
                    HStack {
                        Spacer()
                        if session.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Create Account")
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
                    onShowSignIn()
                } label: {
                    Text("Already have an account? Sign in")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 20)
            }
            .padding(24)
        }
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func handleSignUp() async {
        errorText = ""

        guard fullName.trimmingCharacters(in: .whitespaces).count >= 2 else {
            errorText = "İsim çok kısa."
            return
        }

        guard email.contains("@") else {
            errorText = "Geçerli email gir."
            return
        }

        guard username.trimmingCharacters(in: .whitespaces).count >= 3 else {
            errorText = "Username en az 3 karakter olsun."
            return
        }

        guard password.count >= 4 else {
            errorText = "Şifre en az 4 karakter olsun."
            return
        }

        do {
            try await session.signUp(
                fullName: fullName,
                email: email,
                username: username,
                password: password
            )
            dismiss()
        } catch {
            errorText = "Kayıt oluşturulamadı."
        }
    }
}
