//
//  AuthView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.03.2026.
//
import SwiftUI

struct AuthView: View {
    @EnvironmentObject var session: SessionStore
    @State private var activeSheet: AuthSheet?

    var body: some View {
        ZStack {
            authBackground

            VStack(spacing: 0) {
                Spacer(minLength: 40)

                heroSection

                Spacer(minLength: 28)

                actionSection

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .sheet(item: $activeSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .login:
                    AuthFormSheetView(mode: .login)
                        .environmentObject(session)

                case .signup:
                    AuthFormSheetView(mode: .signup)
                        .environmentObject(session)
                }
            }
            .presentationDetents([.fraction(0.68), .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
    }
}

// MARK: - Sections
private extension AuthView {
    var heroSection: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.16))
                    .frame(width: 132, height: 132)
                    .blur(radius: 2)

                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 108, height: 108)

                Image(systemName: "checklist.checked")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 10) {
                Text("DailyTodo")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Plan smarter, stay focused, and keep your day under control.")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            HStack(spacing: 10) {
                authFeaturePill(icon: "sparkles", text: "Premium flow")
                authFeaturePill(icon: "timer", text: "Focus ready")
                authFeaturePill(icon: "chart.bar.fill", text: "Insights")
            }
            .padding(.top, 4)
        }
    }

    var actionSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 14) {
                premiumActionButton(
                    title: "Login",
                    subtitle: "Continue with your account",
                    systemImage: "arrow.right.circle.fill",
                    highlighted: true
                ) {
                    activeSheet = .login
                }

                premiumActionButton(
                    title: "Sign Up",
                    subtitle: "Create a new account",
                    systemImage: "person.crop.circle.badge.plus",
                    highlighted: false
                ) {
                    activeSheet = .signup
                }
            }

            Text("By continuing, you agree to the app experience and account flow.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.42))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
    }

    var authBackground: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.purple.opacity(0.28),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 360
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.blue.opacity(0.24),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.accentColor.opacity(0.12),
                    Color.clear
                ],
                center: .bottom,
                startRadius: 40,
                endRadius: 360
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.white.opacity(0.02),
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

    func authFeaturePill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))

            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(Color.white.opacity(0.9))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    func premiumActionButton(
        title: String,
        subtitle: String,
        systemImage: String,
        highlighted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(highlighted ? Color.white.opacity(0.16) : Color.accentColor.opacity(0.12))
                        .frame(width: 52, height: 52)

                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(highlighted ? .white : Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.68))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        highlighted
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.95),
                                    Color.purple.opacity(0.95)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        : AnyShapeStyle(Color.white.opacity(0.05))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(
                        highlighted
                        ? Color.white.opacity(0.08)
                        : Color.white.opacity(0.06),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: highlighted ? Color.accentColor.opacity(0.22) : .clear,
                radius: highlighted ? 16 : 0,
                y: 8
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sheet Type
enum AuthSheet: Identifiable {
    case login
    case signup

    var id: String {
        switch self {
        case .login: return "login"
        case .signup: return "signup"
        }
    }
}
