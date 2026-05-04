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

    var body: some View {
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
}

// MARK: - Cards

struct ArenaGlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 26
    var tint: Color = Color(arenaHex: AppArenaPalette.blue)
    var intensity: Double = 1.0
    var shadow: Bool = true

    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.050 * intensity),
                                Color(arenaHex: AppArenaPalette.purple).opacity(0.040 * intensity),
                                Color.white.opacity(0.040)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.075), lineWidth: 1)
                    )
                    .shadow(
                        color: Color.black.opacity(shadow ? 0.22 : 0),
                        radius: shadow ? 16 : 0,
                        y: shadow ? 9 : 0
                    )
            )
    }
}

struct ArenaFilledCard<Content: View>: View {
    var cornerRadius: CGFloat = 30
    var tint: Color = Color(arenaHex: AppArenaPalette.blue)
    var gradient: LinearGradient? = nil

    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        gradient ??
                        LinearGradient(
                            colors: [
                                tint.opacity(0.14),
                                Color(arenaHex: AppArenaPalette.purple).opacity(0.10),
                                Color(arenaHex: AppArenaPalette.surface).opacity(0.96)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(tint.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.24), radius: 20, y: 12)
            )
    }
}

struct ArenaCompactSurface<Content: View>: View {
    var cornerRadius: CGFloat = 20
    var tint: Color = Color(arenaHex: AppArenaPalette.blue)

    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.060),
                                Color.white.opacity(0.040)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(tint.opacity(0.13), lineWidth: 1)
                    )
            )
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
                    .foregroundStyle(.white)

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
                    .foregroundStyle(.white.opacity(0.34))
                    .lineLimit(1)
                    .minimumScaleFactor(0.60)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)

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
                            Color.white.opacity(0.090),
                            Color.white.opacity(0.055)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(Color.white.opacity(0.11), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.24), radius: 12, y: 6)
        }
    }
}

struct ArenaCapsuleButton: View {
    let title: String
    var systemName: String? = nil
    var tint: Color = Color(arenaHex: AppArenaPalette.blue)
    var filled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemName {
                    Image(systemName: systemName)
                        .font(.system(size: 14, weight: .black))
                }

                Text(title)
                    .font(.system(size: 14, weight: .black))
                    .lineLimit(1)
            }
            .foregroundStyle(filled ? .black : tint)
            .padding(.horizontal, 15)
            .frame(height: 42)
            .background(
                Capsule()
                    .fill(filled ? tint : tint.opacity(0.13))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(filled ? 0 : 0.22), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Metrics

struct ArenaMetricPill: View {
    let value: String
    let title: String
    var tint: Color = Color(arenaHex: AppArenaPalette.blue)

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 21, weight: .black))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.70)

            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.38))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(0.075))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(0.14), lineWidth: 1)
                )
        )
    }
}

struct ArenaStatusPill: View {
    let text: String
    var tint: Color = Color(arenaHex: AppArenaPalette.green)
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .black))
            }

            Text(text)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .lineLimit(1)
        }
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
    }
}

// MARK: - Text Field Surface

struct ArenaInputSurface<Content: View>: View {
    let title: String
    let icon: String
    var tint: Color = Color(arenaHex: AppArenaPalette.cyan)
    @ViewBuilder let content: Content

    var body: some View {
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

                content
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.055),
                            Color(arenaHex: AppArenaPalette.purple).opacity(0.040),
                            Color.white.opacity(0.038)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(tint.opacity(0.13), lineWidth: 1)
                )
        )
    }
}

// MARK: - Header Scrim

struct ArenaHeaderScrim: View {
    var height: CGFloat = 168
    var materialHeight: CGFloat = 96

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.94), location: 0.00),
                    .init(color: Color.black.opacity(0.86), location: 0.24),
                    .init(color: Color.black.opacity(0.62), location: 0.50),
                    .init(color: Color.black.opacity(0.30), location: 0.74),
                    .init(color: Color.black.opacity(0.10), location: 0.90),
                    .init(color: Color.clear, location: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.black.opacity(0.10))
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
