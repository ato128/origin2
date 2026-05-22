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
            AuthArenaBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 42)

                heroSection

                Spacer(minLength: 28)

                actionSection

                Spacer(minLength: 34)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .preferredColorScheme(.dark)
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
            .presentationCornerRadius(30)
        }
    }
}

// MARK: - Sections

private extension AuthView {
    var heroSection: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(Color(authHex: AuthArenaPalette.appBlue).opacity(0.16))
                    .frame(width: 150, height: 150)
                    .blur(radius: 2)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(authHex: AuthArenaPalette.appBlue).opacity(0.26),
                                Color(authHex: AuthArenaPalette.appPurple).opacity(0.20),
                                Color.white.opacity(0.055)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 118, height: 118)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .shadow(color: Color(authHex: AuthArenaPalette.appPurple).opacity(0.22), radius: 22, y: 12)

                Image(systemName: "checklist.checked")
                    .font(.system(size: 46, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(authHex: AuthArenaPalette.appCyan),
                                Color(authHex: AuthArenaPalette.appPurple)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 12) {
                Text("— STUDENT OS —")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(2.8)
                    .foregroundStyle(Color(authHex: AuthArenaPalette.appCyan))

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("Up")
                        .font(.system(size: 50, weight: .black))
                        .foregroundStyle(.white)

                    Text("do")
                        .font(.system(size: 48, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(authHex: AuthArenaPalette.appCyan),
                                    Color(authHex: AuthArenaPalette.appPurple)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .lineLimit(1)

                Text("Öğrenci hayatını görevler, ders programı, focus ve arkadaşlarınla tek sistemde yönet.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 6)
            }

            HStack(spacing: 9) {
                authFeaturePill(icon: "sparkles", text: "Premium")
                authFeaturePill(icon: "timer", text: "Focus")
                authFeaturePill(icon: "chart.bar.fill", text: "Insights")
            }
            .padding(.top, 2)
        }
    }

    var actionSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 14) {
                premiumActionButton(
                    eyebrow: "WELCOME BACK",
                    title: "Login",
                    subtitle: "Hesabınla devam et",
                    systemImage: "arrow.right.circle.fill",
                    highlighted: true
                ) {
                    activeSheet = .login
                }

                premiumActionButton(
                    eyebrow: "NEW ACCOUNT",
                    title: "Sign Up",
                    subtitle: "Yeni öğrenci sistemini oluştur",
                    systemImage: "person.crop.circle.badge.plus",
                    highlighted: false
                ) {
                    activeSheet = .signup
                }
            }

            Text("Devam ederek Updo deneyimi ve hesap akışını kullanmayı kabul edersin.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.38))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
        }
    }

    func authFeaturePill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .black))

            Text(text)
                .font(.system(size: 12, weight: .black, design: .rounded))
        }
        .foregroundStyle(Color.white.opacity(0.90))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.070))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    func premiumActionButton(
        eyebrow: String,
        title: String,
        subtitle: String,
        systemImage: String,
        highlighted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            highlighted
                            ? AnyShapeStyle(AuthArenaPalette.appGradient)
                            : AnyShapeStyle(Color.white.opacity(0.075))
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )

                    Image(systemName: systemImage)
                        .font(.system(size: 21, weight: .black))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrow)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(
                            highlighted
                            ? Color(authHex: AuthArenaPalette.appCyan)
                            : Color.white.opacity(0.38)
                        )

                    Text(title)
                        .font(.system(size: 23, weight: .black))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.54))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(highlighted ? Color(authHex: AuthArenaPalette.appCyan) : Color.white.opacity(0.38))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(
                        highlighted
                        ? AuthArenaPalette.highlightedCardGradient
                        : AuthArenaPalette.surfaceGradient
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .stroke(
                        highlighted
                        ? Color(authHex: AuthArenaPalette.appBlue).opacity(0.20)
                        : Color.white.opacity(0.075),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: highlighted ? Color(authHex: AuthArenaPalette.appPurple).opacity(0.20) : Color.black.opacity(0.20),
                radius: highlighted ? 18 : 12,
                y: highlighted ? 10 : 7
            )
        }
        .buttonStyle(AuthPressButtonStyle())
    }
}

// MARK: - Palette

private enum AuthArenaPalette {
    static let backgroundTop = "#05060D"
    static let backgroundMid = "#070713"
    static let backgroundBottom = "#07040C"

    static let appBlue = "#1593FF"
    static let appBlueSoft = "#1E6BFF"
    static let appCyan = "#2DD4FF"
    static let appPurple = "#7C3AED"
    static let coral = "#FF5A44"
    static let gold = "#FBBF24"

    static var appGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(authHex: appBlueSoft),
                Color(authHex: appPurple)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var highlightedCardGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(authHex: appBlue).opacity(0.14),
                Color(authHex: appPurple).opacity(0.12),
                Color.white.opacity(0.045)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var surfaceGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.075),
                Color.white.opacity(0.045),
                Color.white.opacity(0.030)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Background

private struct AuthArenaBackground: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(authHex: AuthArenaPalette.backgroundTop),
                    Color(authHex: AuthArenaPalette.backgroundMid),
                    Color(authHex: AuthArenaPalette.backgroundBottom)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(authHex: AuthArenaPalette.appBlue).opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 100)
                .offset(x: 170, y: -250)

            Circle()
                .fill(Color(authHex: AuthArenaPalette.appPurple).opacity(0.18))
                .frame(width: 330, height: 330)
                .blur(radius: 115)
                .offset(x: -180, y: 500)

            Circle()
                .fill(Color(authHex: AuthArenaPalette.coral).opacity(0.075))
                .frame(width: 280, height: 280)
                .blur(radius: 105)
                .offset(x: 170, y: 300)

            Circle()
                .fill(Color(authHex: AuthArenaPalette.gold).opacity(0.050))
                .frame(width: 240, height: 240)
                .blur(radius: 95)
                .offset(x: -170, y: -180)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.44)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Helpers

private struct AuthPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

private extension Color {
    init(authHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64

        switch cleaned.count {
        case 3:
            a = 255
            r = (int >> 8) * 17
            g = ((int >> 4) & 0xF) * 17
            b = (int & 0xF) * 17

        case 6:
            a = 255
            r = int >> 16
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        case 8:
            a = int >> 24
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        default:
            a = 255
            r = 21
            g = 147
            b = 255
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
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
