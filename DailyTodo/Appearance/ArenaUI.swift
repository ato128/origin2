//
//  ArenaUI.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 4.05.2026.
//

import SwiftUI

enum AppArenaPalette {
    static let backgroundTop = "#05060D"
    static let backgroundMid = "#070713"
    static let backgroundBottom = "#07040C"

    static let blue = "#1593FF"
    static let blueSoft = "#4F8CFF"
    static let cyan = "#2DD4FF"
    static let purple = "#7C3AED"
    static let purpleSoft = "#A78BFA"
    static let coral = "#FF5A44"
    static let coralSoft = "#FF7A59"
    static let gold = "#FBBF24"
    static let goldSoft = "#FFD166"
    static let green = "#A3E635"
    static let greenDeep = "#22C55E"

    static let surface = "#101118"
    static let surfaceSoft = "#161821"
    static let border = "#FFFFFF"

    // Adaptive card surfaces: warm off-white on light, original dark on dark.
    static let surfaceColor     = Color.adaptive(light: Color(arenaHex: "#FCFAF4"), dark: Color(arenaHex: surface))
    static let surfaceSoftColor = Color.adaptive(light: Color(arenaHex: "#F4EEE2"), dark: Color(arenaHex: surfaceSoft))

    static var appGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(arenaHex: blue),
                Color(arenaHex: purple)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var warmGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(arenaHex: coral),
                Color(arenaHex: coralSoft),
                Color(arenaHex: gold)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var focusGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(arenaHex: blue),
                Color(arenaHex: purple),
                Color(arenaHex: cyan)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var liveGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(arenaHex: greenDeep),
                Color(arenaHex: green)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Background

struct ArenaBackground: View {
    var primaryGlow: Color = Color(arenaHex: AppArenaPalette.blue)
    var secondaryGlow: Color = Color(arenaHex: AppArenaPalette.purple)
    var warmGlow: Color = Color(arenaHex: AppArenaPalette.coral)
    var intensity: Double = 1.0

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if colorScheme == .light {
            lightBody
        } else {
            darkBody
        }
    }

    // Dark: the original deep-space field (unchanged).
    private var darkBody: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(arenaHex: AppArenaPalette.backgroundTop),
                    Color(arenaHex: AppArenaPalette.backgroundMid),
                    Color(arenaHex: AppArenaPalette.backgroundBottom)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(primaryGlow.opacity(0.10 * intensity))
                .frame(width: 280, height: 280)
                .blur(radius: 100)
                .offset(x: 170, y: -250)

            Circle()
                .fill(secondaryGlow.opacity(0.15 * intensity))
                .frame(width: 320, height: 320)
                .blur(radius: 110)
                .offset(x: -190, y: 520)

            Circle()
                .fill(warmGlow.opacity(0.08 * intensity))
                .frame(width: 280, height: 280)
                .blur(radius: 105)
                .offset(x: 180, y: 350)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.clear,
                    Color.black.opacity(0.44)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    // Light: calm warm "kırık beyaz" eggshell with faint accent blooms.
    private var lightBody: some View {
        ZStack {
            UpdoTheme.background.ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(arenaHex: "#FBF6EC"),
                    Color(arenaHex: "#F4EEE1"),
                    Color(arenaHex: "#EFE7D6")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(primaryGlow.opacity(0.07 * intensity))
                .frame(width: 300, height: 300)
                .blur(radius: 120)
                .offset(x: 175, y: -255)

            Circle()
                .fill(secondaryGlow.opacity(0.08 * intensity))
                .frame(width: 340, height: 340)
                .blur(radius: 130)
                .offset(x: -195, y: 520)

            Circle()
                .fill(warmGlow.opacity(0.06 * intensity))
                .frame(width: 300, height: 300)
                .blur(radius: 120)
                .offset(x: 185, y: 350)

            // Soft top light + gentle bottom warmth for depth (no black scrim).
            LinearGradient(
                colors: [
                    Color.white.opacity(0.30),
                    Color.clear,
                    Color(arenaHex: "#B8A47E").opacity(0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Header / Title

struct ArenaLargeTitle: View {
    let eyebrow: String?
    let title: String
    let accent: String?
    var accentColor: Color = Color(arenaHex: AppArenaPalette.cyan)

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let eyebrow {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(accentColor)
                        .frame(width: 20, height: 1)

                    Text(eyebrow)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(2.4)
                        .foregroundStyle(accentColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(title)
                    .font(.system(size: 39, weight: .black))
                    .foregroundStyle(UpdoTheme.textPrimary)

                if let accent {
                    Text(accent)
                        .font(.system(size: 36, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(accentColor)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.72)
        }
    }
}

struct ArenaSectionTitle: View {
    let eyebrow: String?
    let title: String
    let italic: String?
    var accent: Color = Color.white

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let eyebrow {
                Text("— \(eyebrow) —")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2.4)
                    .foregroundStyle(UpdoTheme.filmy(0.34))
                    .lineLimit(1)
                    .minimumScaleFactor(0.60)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(UpdoTheme.textPrimary)

                if let italic {
                    Text(italic)
                        .font(.system(size: 23, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(accent)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.72)
        }
    }
}

// MARK: - Buttons

struct ArenaIconButton: View {
    let systemName: String
    var tint: Color = .white
    var emphasized: Bool = false
    var badge: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemName)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(emphasized ? .black : tint)
                    .frame(width: 46, height: 46)
                    .background(background)

                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Circle().fill(Color(arenaHex: AppArenaPalette.gold)))
                        .offset(x: 5, y: -5)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var background: some View {
        if emphasized {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(tint)
                .shadow(color: tint.opacity(0.25), radius: 12, y: 6)
        } else {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            UpdoTheme.filmy(0.090),
                            UpdoTheme.filmy(0.055)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(UpdoTheme.filmy(0.11), lineWidth: 1)
                )
                .shadow(color: UpdoTheme.cardShadow(0.24), radius: 12, y: 6)
        }
    }
}

// MARK: - Header Scrim

struct ArenaHeaderScrim: View {
    var height: CGFloat = 168
    var materialHeight: CGFloat = 96

    @Environment(\.colorScheme) private var colorScheme

    /// Fades content toward the page background under the floating header:
    /// black on dark, warm eggshell on light (never a black scrim on cream).
    private var scrimBase: Color {
        colorScheme == .light ? Color(arenaHex: "#F4EEE1") : .black
    }

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                stops: [
                    .init(color: scrimBase.opacity(0.94), location: 0.00),
                    .init(color: scrimBase.opacity(0.86), location: 0.24),
                    .init(color: scrimBase.opacity(0.62), location: 0.50),
                    .init(color: scrimBase.opacity(0.30), location: 0.74),
                    .init(color: scrimBase.opacity(0.10), location: 0.90),
                    .init(color: Color.clear, location: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(scrimBase.opacity(0.10))
                    .frame(height: 34)
                    .blur(radius: 18)
                    .offset(y: 12)
            }

            Spacer(minLength: 0)
        }
        .background(
            VStack(spacing: 0) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.16)
                    .frame(height: materialHeight)

                Spacer(minLength: 0)
            }
        )
    }
}

// MARK: - Color Hex

extension Color {
    init(arenaHex hex: String) {
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
