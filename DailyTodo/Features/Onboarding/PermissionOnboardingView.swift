//
//  PermissionOnboardingView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 14.03.2026.
//

import SwiftUI
import UserNotifications

struct PermissionOnboardingView: View {
    @AppStorage("didFinishPermissionOnboarding") private var didFinishPermissionOnboarding = false

    @State private var animateIcon = false
    @State private var animateCard = false
    @State private var isRequesting = false

    var body: some View {
        ZStack {
            permissionBackground

            VStack(spacing: 0) {
                topBar

                VStack(spacing: 28) {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.18))
                            .frame(width: 168, height: 168)
                            .blur(radius: 8)
                            .scaleEffect(animateIcon ? 1.06 : 0.94)
                            .animation(
                                .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                                value: animateIcon
                            )

                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 130, height: 130)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )

                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 46, weight: .bold))
                            .foregroundStyle(.orange)
                            .shadow(color: Color.orange.opacity(0.38), radius: 18)
                            .offset(y: animateIcon ? -4 : 4)
                            .animation(
                                .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                                value: animateIcon
                            )
                    }

                    VStack(spacing: 14) {
                        Text("Stay in the loop")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)

                        Text("Enable notifications to get focus reminders, task nudges and helpful updates from DailyTodo.")
                            .font(.system(size: 16, weight: .medium))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 22)
                    }

                    VStack(spacing: 12) {
                        permissionFeatureRow(
                            icon: "timer",
                            title: "Focus reminders",
                            subtitle: "Know when your session starts or ends",
                            tint: .orange
                        )

                        permissionFeatureRow(
                            icon: "checkmark.circle",
                            title: "Task nudges",
                            subtitle: "Stay on top of important tasks",
                            tint: .green
                        )

                        permissionFeatureRow(
                            icon: "sparkles",
                            title: "Useful updates",
                            subtitle: "Helpful prompts without the clutter",
                            tint: .blue
                        )
                    }
                    .opacity(animateCard ? 1 : 0)
                    .offset(y: animateCard ? 0 : 18)
                    .animation(.spring(response: 0.5, dampingFraction: 0.86), value: animateCard)

                    Spacer()

                    VStack(spacing: 14) {
                        Button {
                            requestNotifications()
                        } label: {
                            HStack(spacing: 10) {
                                if isRequesting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "bell.fill")
                                }

                                Text(isRequesting ? "Requesting..." : "Enable Notifications")
                            }
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.orange,
                                                Color.pink
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .shadow(color: Color.orange.opacity(0.28), radius: 16, y: 6)
                        }
                        .buttonStyle(.plain)
                        .disabled(isRequesting)

                        Button {
                            finishPermissionFlow()
                        } label: {
                            Text("Maybe Later")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    Capsule()
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 34)
                }
            }
        }
        .onAppear {
            animateIcon = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                animateCard = true
            }
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()

            Button {
                finishPermissionFlow()
            } label: {
                Text("Skip")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var permissionBackground: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.purple.opacity(0.22),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 320
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.blue.opacity(0.20),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 380
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.orange.opacity(0.14),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 30,
                endRadius: 260
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.white.opacity(0.018),
                    Color.clear,
                    Color.white.opacity(0.01)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.screen)
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func permissionFeatureRow(icon: String, title: String, subtitle: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
    }

    private func requestNotifications() {
        isRequesting = true

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isRequesting = false
                finishPermissionFlow()
            }
        }
    }

    private func finishPermissionFlow() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            didFinishPermissionOnboarding = true
        }
    }
}
