//
//  JoinCrewSheet.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import SwiftUI
import UIKit

private enum JoinCrewArenaPalette {
    static let backgroundTop = Color(joinCrewHex: "#05060D")
    static let backgroundMid = Color(joinCrewHex: "#070713")
    static let backgroundBottom = Color(joinCrewHex: "#07040C")

    static let blue = Color(joinCrewHex: "#1593FF")
    static let cyan = Color(joinCrewHex: "#2DD4FF")
    static let purple = Color(joinCrewHex: "#7C3AED")
    static let coral = Color(joinCrewHex: "#FF5A44")
    static let gold = Color(joinCrewHex: "#FBBF24")
    static let green = Color(joinCrewHex: "#A3E635")
    static let surface = Color(joinCrewHex: "#101118")

    static var appGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(joinCrewHex: "#1E6BFF"),
                Color(joinCrewHex: "#7C3AED")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct JoinCrewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var session: SessionStore

    @State var code: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didCopy = false

    private var cleanCode: String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private var canJoin: Bool {
        !cleanCode.isEmpty && !isLoading
    }

    var body: some View {
        ZStack {
            background

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    Color.clear.frame(height: 4)

                    header

                    heroCard

                    codeInputCard

                    helpCard

                    if let errorMessage {
                        errorCard(errorMessage)
                    }

                    joinButton

                    Color.clear.frame(height: 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Layout

private extension JoinCrewSheet {
    var background: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    JoinCrewArenaPalette.backgroundTop,
                    JoinCrewArenaPalette.backgroundMid,
                    JoinCrewArenaPalette.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(JoinCrewArenaPalette.blue.opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 96)
                .offset(x: 165, y: -245)

            Circle()
                .fill(JoinCrewArenaPalette.purple.opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 110)
                .offset(x: -175, y: 500)

            Circle()
                .fill(JoinCrewArenaPalette.green.opacity(0.08))
                .frame(width: 270, height: 270)
                .blur(radius: 100)
                .offset(x: 170, y: 280)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.16),
                    Color.clear,
                    Color.black.opacity(0.42)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(Color.white.opacity(0.075))
                            .overlay(
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(isLoading)

            Spacer()

            VStack(spacing: 3) {
                Text("JOIN CREW")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(JoinCrewArenaPalette.cyan)

                Text(tr("jc_join_crew"))
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                Task {
                    await joinCrew()
                }
            } label: {
                ZStack {
                    if isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.black)
                    }
                }
                .frame(width: 46, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(canJoin ? JoinCrewArenaPalette.green : Color.white.opacity(0.12))
                )
            }
            .buttonStyle(.plain)
            .disabled(!canJoin)
            .opacity(canJoin ? 1 : 0.55)
        }
    }
}

// MARK: - Cards

private extension JoinCrewSheet {
    var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(JoinCrewArenaPalette.appGradient)
                    .frame(width: 66, height: 66)
                    .overlay(
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 29, weight: .black))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text("INVITE CODE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(JoinCrewArenaPalette.cyan)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Crew")
                            .font(.system(size: 30, weight: .black))
                            .foregroundStyle(.white)

                        Text(tr("jc_join_space"))
                            .font(.system(size: 25, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(JoinCrewArenaPalette.cyan)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)

                    Text(tr("jc_subtitle"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                        .lineLimit(2)
                }

                Spacer()
            }

            HStack(spacing: 9) {
                pill(text: "CODE", tint: JoinCrewArenaPalette.green)

                if !cleanCode.isEmpty {
                    pill(text: cleanCode, tint: JoinCrewArenaPalette.gold)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            JoinCrewArenaPalette.blue.opacity(0.12),
                            JoinCrewArenaPalette.purple.opacity(0.12),
                            JoinCrewArenaPalette.surface.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(JoinCrewArenaPalette.blue.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.24), radius: 20, y: 12)
        )
    }

    var codeInputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                eyebrow: "CREW CODE",
                title: "Davet",
                italic: "kodu"
            )

            fieldBox(
                title: "INVITE CODE",
                icon: "number",
                tint: JoinCrewArenaPalette.cyan
            ) {
                TextField(String(localized: "join_crew_code_placeholder"), text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(2)
                    .submitLabel(.join)
                    .onSubmit {
                        guard canJoin else { return }
                        Task {
                            await joinCrew()
                        }
                    }
                    .onChange(of: code) { _, newValue in
                        let filtered = newValue
                            .uppercased()
                            .filter { $0.isLetter || $0.isNumber }

                        if filtered != newValue {
                            code = filtered
                        }
                    }

                Text(tr("jc_code_hint"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.38))
            }

            HStack(spacing: 10) {
                Button {
                    UIPasteboard.general.string = cleanCode
                    didCopy = true
                } label: {
                    actionPill(
                        icon: didCopy ? "checkmark" : "doc.on.doc",
                        title: didCopy ? tr("jc_copied") : "Kopyala",
                        tint: JoinCrewArenaPalette.cyan,
                        filled: false
                    )
                }
                .buttonStyle(.plain)
                .disabled(cleanCode.isEmpty)
                .opacity(cleanCode.isEmpty ? 0.45 : 1)

                Button {
                    if let pasted = UIPasteboard.general.string {
                        code = pasted
                            .uppercased()
                            .filter { $0.isLetter || $0.isNumber }
                    }
                } label: {
                    actionPill(
                        icon: "arrow.down.doc",
                        title: tr("jc_paste"),
                        tint: JoinCrewArenaPalette.blue,
                        filled: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    var helpCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                eyebrow: "HOW IT WORKS",
                title: tr("how_w1"),
                italic: tr("how_w2")
            )

            HStack(alignment: .top, spacing: 13) {
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(JoinCrewArenaPalette.gold)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(JoinCrewArenaPalette.gold.opacity(0.13))
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(tr("jc_step1"))
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.white)

                    Text(tr("jc_step2"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.48))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(14)
            .background(detailSurface(cornerRadius: 22, tint: JoinCrewArenaPalette.gold))
        }
        .padding(18)
        .background(cardBackground)
    }

    var joinButton: some View {
        Button {
            Task {
                await joinCrew()
            }
        } label: {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(.black)
                } else {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 18, weight: .black))
                }

                Text(tr("jc_join_crew"))
                    .font(.system(size: 16, weight: .black))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Capsule()
                    .fill(canJoin ? JoinCrewArenaPalette.green : Color.white.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .disabled(!canJoin)
        .opacity(canJoin ? 1 : 0.55)
    }
}

// MARK: - Components

private extension JoinCrewSheet {
    func sectionTitle(eyebrow: String, title: String, italic: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("— \(eyebrow) —")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2.4)
                .foregroundStyle(.white.opacity(0.34))
                .lineLimit(1)
                .minimumScaleFactor(0.60)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)

                Text(italic)
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(.white)
            }
        }
    }

    func fieldBox<Content: View>(
        title: String,
        icon: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(tint.opacity(0.13))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.36))

                content()
            }
        }
        .padding(14)
        .background(detailSurface(cornerRadius: 22, tint: tint))
    }

    func actionPill(icon: String, title: String, tint: Color, filled: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .black))

            Text(title)
                .font(.system(size: 13, weight: .black))
                .lineLimit(1)
        }
        .foregroundStyle(filled ? .black : tint)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(
            Capsule()
                .fill(filled ? tint : tint.opacity(0.13))
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(filled ? 0 : 0.22), lineWidth: 1)
                )
        )
    }

    func pill(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.20), lineWidth: 1)
                    )
            )
            .lineLimit(1)
    }

    func errorCard(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(JoinCrewArenaPalette.coral)

            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.74))
                .lineLimit(3)

            Spacer()
        }
        .padding(16)
        .background(detailSurface(cornerRadius: 22, tint: JoinCrewArenaPalette.coral))
    }

    func detailSurface(cornerRadius: CGFloat, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.055),
                        JoinCrewArenaPalette.purple.opacity(0.040),
                        Color.white.opacity(0.038)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tint.opacity(0.13), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 14, y: 8)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        JoinCrewArenaPalette.blue.opacity(0.035),
                        JoinCrewArenaPalette.purple.opacity(0.045),
                        Color.white.opacity(0.040)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 16, y: 9)
    }
}

// MARK: - Logic

private extension JoinCrewSheet {
    @MainActor
    func joinCrew() async {
        guard !cleanCode.isEmpty else { return }

        guard let user = session.currentUser else {
            errorMessage = String(localized: "join_crew_user_session_not_found")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await crewStore.joinCrew(with: cleanCode, userID: user.id)
            await crewStore.loadCrews(force: true)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Color Hex

private extension Color {
    init(joinCrewHex hex: String) {
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
            r = 255
            g = 255
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
