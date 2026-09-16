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
    @State private var heroIn = false

    private var cyan: Color { Color(arenaHex: AppArenaPalette.cyan) }
    private var blue: Color { Color(arenaHex: AppArenaPalette.blue) }
    private var purple: Color { Color(arenaHex: AppArenaPalette.purple) }
    private var coral: Color { Color(arenaHex: AppArenaPalette.coral) }
    private var pink: Color { Color(arenaHex: "#FF4FA3") }

    private var emailText: String {
        session.pendingVerificationEmail ?? (appLanguageIsEnglish() ? "your email" : "email adresin")
    }

    var body: some View {
        ZStack {
            // Adaptive field (light/dark) — glows tuned to the sticker's cyan / pink / coral palette.
            ArenaBackground(primaryGlow: cyan, secondaryGlow: pink, warmGlow: coral, intensity: 0.95)

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                VStack(spacing: 22) {
                    emblem
                        .opacity(heroIn ? 1 : 0)
                        .offset(y: heroIn ? 0 : 16)

                    VStack(spacing: 10) {
                        eyebrow
                        titleBlock

                        Text(tr("ev_subtitle"))
                            .font(.system(size: 15.5, weight: .semibold))
                            .foregroundStyle(UpdoTheme.filmy(0.6))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 24)
                    }
                    .opacity(heroIn ? 1 : 0)
                    .offset(y: heroIn ? 0 : 12)

                    emailCard

                    if let message = session.verificationMessage {
                        messageCard(message)
                    }
                }

                Spacer(minLength: 22)

                actions
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.84).delay(0.05)) { heroIn = true }
        }
        .task {
            await session.refreshEmailVerificationStatus()
        }
    }

    // MARK: - Emblem

    private var emblem: some View {
        ZStack {
            // Colour cloud in the emblem's own graffiti palette bleeding onto the screen.
            Circle().fill(cyan.opacity(0.32)).frame(width: 176, height: 176).blur(radius: 60).offset(x: -30, y: -22)
            Circle().fill(pink.opacity(0.26)).frame(width: 150, height: 150).blur(radius: 56).offset(x: 42, y: -2)
            Circle().fill(blue.opacity(0.22)).frame(width: 150, height: 150).blur(radius: 58).offset(x: 6, y: 52)

            Image("mail_verify_emblem")
                .resizable()
                .scaledToFit()
                .frame(width: 172, height: 172)
                .shadow(color: cyan.opacity(0.38), radius: 22, y: 8)
        }
        .scaleEffect(heroIn ? 1 : 0.84)
    }

    // MARK: - Title

    private var eyebrow: some View {
        HStack(spacing: 8) {
            Rectangle().fill(cyan.opacity(0.75)).frame(width: 18, height: 1)
            Text(tr("ev_eyebrow"))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(2.8)
                .foregroundStyle(cyan)
            Rectangle().fill(cyan.opacity(0.75)).frame(width: 18, height: 1)
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 1) {
            Text(tr("ev_title"))
                .font(.system(size: 33, weight: .black))
                .foregroundStyle(UpdoTheme.textPrimary)

            Text(tr("ev_title_accent"))
                .font(.system(size: 30, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(
                    LinearGradient(colors: [cyan, purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
        }
        .multilineTextAlignment(.center)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    // MARK: - Cards

    private var emailCard: some View {
        HStack(spacing: 13) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(cyan)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(UpdoTheme.filmy(0.075))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(tr("ev_pending_caps"))
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(UpdoTheme.filmy(0.42))

                Text(emailText)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(UpdoTheme.filmy(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer()
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .fill(UpdoTheme.filmy(0.060))
                .overlay(
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .stroke(UpdoTheme.filmy(0.085), lineWidth: 1)
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
                .foregroundStyle(UpdoTheme.filmy(0.78))
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

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 12) {
            Text(tr("ev_spam_tip"))
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(UpdoTheme.filmy(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.bottom, 2)

            Button {
                Task {
                    isChecking = true
                    await session.refreshEmailVerificationStatus()
                    isChecking = false
                }
            } label: {
                primaryButtonContent(
                    title: isChecking || session.isLoading ? tr("ev_checking") : tr("ev_confirmed_continue"),
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
                    .foregroundStyle(UpdoTheme.filmy(0.48))
                    .frame(height: 42)
            }
            .buttonStyle(.plain)
            .disabled(isChecking || isResending || session.isLoading)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 30)
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
        .foregroundStyle(UpdoTheme.onAccent)
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
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
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
                    .tint(cyan)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .black))
            }

            Text(title)
                .font(.system(size: 15, weight: .black, design: .rounded))
        }
        .foregroundStyle(cyan)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(
            Capsule()
                .fill(UpdoTheme.filmy(0.070))
                .overlay(
                    Capsule()
                        .stroke(UpdoTheme.filmy(0.10), lineWidth: 1)
                )
        )
    }
}
