//
//  UpdoTheme.swift
//  DailyTodo
//
//  Central design tokens + shared design-system components.
//  Single source of truth for the Updo visual identity:
//    Background #080C18 · Surfaces #0E1420→#1C1C2E
//    Cyan #2DD4FF · Purple #7C3AED · Orange #F97316 · Lime #A3E635
//    Text #EEF4FF / muted #64748B
//

import SwiftUI
import UIKit

// MARK: - Color Tokens

enum UpdoTheme {

    // Backgrounds & surfaces
    static let background   = Color(updoHex: "#080C18")
    static let surface      = Color(updoHex: "#0E1420")
    static let surfaceHigh  = Color(updoHex: "#1C1C2E")

    // Accents
    static let cyan         = Color(updoHex: "#2DD4FF")   // primary actions, AI, highlights
    static let purple       = Color(updoHex: "#7C3AED")   // crew, social, premium
    static let orange       = Color(updoHex: "#F97316")   // focus, energy, streak
    static let lime         = Color(updoHex: "#A3E635")   // completion, success

    // Text
    static let textPrimary  = Color(updoHex: "#EEF4FF")
    static let textMuted    = Color(updoHex: "#64748B")

    // Border
    static let border       = Color.white.opacity(0.08)

    // Gradients
    static let gradientAI = LinearGradient(
        colors: [cyan, purple],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let gradientFocus = LinearGradient(
        colors: [orange, Color(updoHex: "#FBBF24")],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let gradientPro = LinearGradient(
        colors: [orange, Color(updoHex: "#EC4899")],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Card geometry
    static let cardRadius: CGFloat = 20
    static let innerRadius: CGFloat = 14
}

// MARK: - Section Header

/// ALL CAPS section label with a 2pt cyan left accent line.
/// Usage: `SectionHeader("BUGÜNÜN AKIŞI")`
struct SectionHeader: View {
    let title: String
    var accent: Color = UpdoTheme.cyan

    init(_ title: String, accent: Color = UpdoTheme.cyan) {
        self.title = title
        self.accent = accent
    }

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1)
                .fill(accent)
                .frame(width: 2, height: 12)

            Text(title.uppercased())
                .font(.caption.weight(.medium))
                .tracking(0.5)
                .foregroundStyle(UpdoTheme.textPrimary.opacity(0.85))
        }
    }
}

// MARK: - Skeleton Loading

/// Shimmering placeholder block for content loading.
/// Usage: `SkeletonView(width: 180, height: 16)` or omit width for full-width.
struct SkeletonView: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var radius: CGFloat = 8

    @State private var phase: CGFloat = -1.2

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .frame(width: width, height: height)
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.07),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: geo.size.width * phase)
                }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            }
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
            .onDisappear { phase = -1.2 }
    }
}

// MARK: - Haptic Manager

/// Singleton with pre-prepared, reused feedback generators.
/// Navigation → .light · Action → .medium · Success/Error → notification.
final class HapticManager {
    static let shared = HapticManager()

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let notification = UINotificationFeedbackGenerator()
    private let selectionGen = UISelectionFeedbackGenerator()

    private init() {
        light.prepare()
        medium.prepare()
        notification.prepare()
    }

    /// Navigation taps, chip selection
    func navigation() {
        light.impactOccurred()
        light.prepare()
    }

    /// Meaningful actions (start, send, add)
    func action() {
        medium.impactOccurred()
        medium.prepare()
    }

    /// Subtle ambient feedback
    func subtle(intensity: CGFloat = 0.5) {
        soft.impactOccurred(intensity: intensity)
        soft.prepare()
    }

    /// Completions, achievements
    func success() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    /// Failures shown to the user
    func error() {
        notification.notificationOccurred(.error)
        notification.prepare()
    }

    func selection() {
        selectionGen.selectionChanged()
        selectionGen.prepare()
    }
}

// MARK: - Hex init (single source, file-scoped name to avoid collisions)

extension Color {
    init(updoHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let r, g, b: UInt64
        switch cleaned.count {
        case 6:
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF
        default:
            r = 255; g = 255; b = 255
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
