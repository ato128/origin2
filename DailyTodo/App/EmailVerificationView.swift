//
//  EmailVerificationView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 4.06.2026.
//

import SwiftUI

struct EmailVerificationView: View {
    @EnvironmentObject var session: SessionStore

    @State private var isChecking = false
    @State private var isResending = false

    private var emailText: String {
        session.pendingVerificationEmail ?? "email adresin"
    }

    var body: some View {
        ZStack {
            verificationBackground

            VStack(spacing: 0) {
                Spacer(minLength: 44)

                VStack(spacing: 24) {
                    iconSection

                    VStack(spacing: 12) {
                        Text("Emailini onayla")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text(tr("ev_subtitle"))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.62))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.horizontal, 12)
                    }

                    emailCard

                    if let message = session.verificationMessage {
                        messageCard(message)
                    }
                }

                Spacer(minLength: 28)

                VStack(spacing: 12) {
                    Button {
                        Task {
                            isChecking = true
                            await session.refreshEmailVerificationStatus()
                            isChecking = false
                        }
                    } label: {
                        primaryButtonContent(
                            title: isChecking || session.isLoading ? "Kontrol ediliyor..." : tr("ev_confirmed_continue"),
                            systemImage: "checkmark.circle.fill",
                            isLoading: isChecking || session.isLoading
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isChecking || isResending || session.isLoading)

                    Button {
                        Task {
                            isResending = true
                            await session.resendVerificationEmail()
                            isResending = false
                        }
                    } label: {
                        secondaryButtonContent(
                            title: isResending ? tr("ev_sending") : tr("ev_resend"),
                            systemImage: "paperplane.fill",
                            isLoading: isResending
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isChecking || isResending || session.isLoading)

                    Button {
                        session.signOut()
                    } label: {
                        Text(tr("ev_different_account"))
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.48))
                            .frame(height: 42)
                    }
                    .buttonStyle(.plain)
                    .disabled(isChecking || isResending || session.isLoading)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await session.refreshEmailVerificationStatus()
        }
    }

    private var iconSection: some View {
        ZStack {
            Circle()
                .fill(Color(arenaHex: "#1593FF").opacity(0.16))
                .frame(width: 160, height: 160)
                .blur(radius: 8)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(arenaHex: "#1593FF").opacity(0.30),
                            Color(arenaHex: "#7C3AED").opacity(0.24),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 118, height: 118)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color(arenaHex: "#7C3AED").opacity(0.24), radius: 24, y: 12)

            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 46, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(arenaHex: "#2DD4FF"),
                            Color(arenaHex: "#7C3AED")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private var emailCard: some View {
        HStack(spacing: 13) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(Color(arenaHex: "#2DD4FF"))
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.white.opacity(0.075))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("ONAY BEKLEYEN EMAIL")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.42))

                Text(emailText)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer()
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(Color.white.opacity(0.060))
                .overlay(
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .stroke(Color.white.opacity(0.085), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
    }

    private func messageCard(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Color(arenaHex: "#FBBF24"))

            Text(text)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(arenaHex: "#FBBF24").opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(arenaHex: "#FBBF24").opacity(0.18), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
    }

    private func primaryButtonContent(
        title: String,
        systemImage: String,
        isLoading: Bool
    ) -> some View {
        HStack(spacing: 10) {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .black))
            }

            Text(title)
                .font(.system(size: 17, weight: .black, design: .rounded))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(arenaHex: "#1593FF"),
                            Color(arenaHex: "#7C3AED"),
                            Color(arenaHex: "#FF5A44")
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color(arenaHex: "#7C3AED").opacity(0.26), radius: 18, y: 9)
    }

    private func secondaryButtonContent(
        title: String,
        systemImage: String,
        isLoading: Bool
    ) -> some View {
        HStack(spacing: 10) {
            if isLoading {
                ProgressView()
                    .tint(Color(arenaHex: "#2DD4FF"))
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .black))
            }

            Text(title)
                .font(.system(size: 15, weight: .black, design: .rounded))
        }
        .foregroundStyle(Color(arenaHex: "#2DD4FF"))
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.070))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private var verificationBackground: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(arenaHex: "#05060D"),
                    Color(arenaHex: "#070713"),
                    Color(arenaHex: "#07040C")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(arenaHex: "#1593FF").opacity(0.12))
                .frame(width: 300, height: 300)
                .blur(radius: 110)
                .offset(x: 170, y: -250)

            Circle()
                .fill(Color(arenaHex: "#7C3AED").opacity(0.18))
                .frame(width: 340, height: 340)
                .blur(radius: 120)
                .offset(x: -185, y: 480)

            Circle()
                .fill(Color(arenaHex: "#FF5A44").opacity(0.075))
                .frame(width: 270, height: 270)
                .blur(radius: 100)
                .offset(x: 175, y: 260)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.16),
                    Color.black.opacity(0),
                    Color.black.opacity(0.44)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}
