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

// MARK: - Adaptive Color Bridge

extension Color {
    /// Resolves to `light` in light appearance and `dark` in dark appearance,
    /// following the active `UITraitCollection`. This single primitive powers the
    /// whole adaptive palette — every token below flips automatically with the
    /// system (or in-app) color scheme, with NO change to existing call sites.
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - Color Tokens

enum UpdoTheme {

    // Backgrounds & surfaces — dark unchanged; light = warm "kırık beyaz" eggshell
    static let background   = Color.adaptive(light: Color(arenaHex: "#F4EEE1"), dark: Color(arenaHex: "#080C18"))
    static let surface      = Color.adaptive(light: Color(arenaHex: "#FCFAF4"), dark: Color(arenaHex: "#0E1420"))
    static let surfaceHigh  = Color.adaptive(light: Color(arenaHex: "#FFFFFF"), dark: Color(arenaHex: "#1C1C2E"))

    // Accents — deepened in light for legible contrast on cream
    static let cyan         = Color.adaptive(light: Color(arenaHex: "#0C93C0"), dark: Color(arenaHex: "#2DD4FF"))   // primary actions, AI, highlights
    static let purple       = Color.adaptive(light: Color(arenaHex: "#6D28D9"), dark: Color(arenaHex: "#7C3AED"))   // crew, social, premium
    static let orange       = Color.adaptive(light: Color(arenaHex: "#E4610A"), dark: Color(arenaHex: "#F97316"))   // focus, energy, streak
    static let lime         = Color.adaptive(light: Color(arenaHex: "#568A0A"), dark: Color(arenaHex: "#A3E635"))   // completion, success

    // Text — near-white on dark, warm ink on cream
    static let textPrimary  = Color.adaptive(light: Color(arenaHex: "#1A1712"), dark: Color(arenaHex: "#EEF4FF"))
    static let textMuted    = Color.adaptive(light: Color(arenaHex: "#6B655C"), dark: Color(arenaHex: "#64748B"))

    // Border / hairline
    static let border       = Color.adaptive(light: Color.black.opacity(0.12), dark: Color.white.opacity(0.08))

    /// Always-white label for text/icons sitting on a saturated accent fill
    /// (gradient / cyan / purple / orange buttons). Stays white in BOTH modes.
    static let onAccent     = Color.white

    /// Adaptive low-opacity film: white on dark, warm ink on cream. Drop-in for the
    /// old `Color.white.opacity(x)` fills, strokes, dividers and muted text so they
    /// stay visible on the eggshell background. Dark branch is byte-identical.
    static func filmy(_ opacity: Double) -> Color {
        Color.adaptive(
            light: Color(arenaHex: "#1A1712").opacity(opacity),
            dark: Color.white.opacity(opacity)
        )
    }

    /// Top/bottom darkening scrim used on the bespoke "arena" backgrounds. Present
    /// on dark; disappears on light (a black scrim would muddy the eggshell field).
    static func overlayScrim(_ opacity: Double) -> Color {
        Color.adaptive(light: .clear, dark: Color.black.opacity(opacity))
    }

    /// Drop-shadow tone for cards. Keeps the original black on dark, but a soft,
    /// warm, much lighter shadow on the eggshell (Apple-style light elevation).
    static func cardShadow(_ opacity: Double) -> Color {
        Color.adaptive(
            light: Color(arenaHex: "#5B4A2E").opacity(opacity * 0.34),
            dark: Color.black.opacity(opacity)
        )
    }

    // iMessage-style chat bubbles
    static let bubbleSentTop     = Color(arenaHex: "#0A84FF")   // sent (top) — blue in both modes
    static let bubbleSentBottom  = Color(arenaHex: "#0A6AF5")   // sent (bottom)
    static let bubbleReceived    = Color.adaptive(light: Color(arenaHex: "#E9E9EB"), dark: Color(arenaHex: "#2A2A2D"))   // received (light/dark gray)
    static let bubbleSentGradient = LinearGradient(
        colors: [bubbleSentTop, bubbleSentBottom],
        startPoint: .top,
        endPoint: .bottom
    )

    // Gradients
    static let gradientAI = LinearGradient(
        colors: [cyan, purple],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let gradientFocus = LinearGradient(
        colors: [orange, Color(arenaHex: "#FBBF24")],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let gradientPro = LinearGradient(
        colors: [orange, Color(arenaHex: "#EC4899")],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Card geometry
    static let cardRadius: CGFloat = 20
    static let innerRadius: CGFloat = 14
}

// MARK: - Appearance Mode (System / Light / Dark)

/// User-selectable appearance for the authenticated app. `system` follows the
/// phone (`.preferredColorScheme(nil)`); `light`/`dark` pin it. Persisted in
/// `@AppStorage("updoAppearanceMode")`, applied via `.updoColorScheme()`.
enum UpdoAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    var systemImage: String {
        switch self {
        case .system: return "iphone"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }
}

private struct UpdoColorSchemeModifier: ViewModifier {
    @AppStorage("updoAppearanceMode") private var raw = UpdoAppearanceMode.system.rawValue

    func body(content: Content) -> some View {
        content.preferredColorScheme(
            (UpdoAppearanceMode(rawValue: raw) ?? .system).colorScheme
        )
    }
}

extension View {
    /// Applies the user's chosen appearance (System/Light/Dark). Use on the app
    /// root and on any modally-presented main-app screen that should follow it.
    func updoColorScheme() -> some View { modifier(UpdoColorSchemeModifier()) }
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
            .fill(UpdoTheme.filmy(0.06))
            .frame(width: width, height: height)
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            UpdoTheme.filmy(0.0),
                            UpdoTheme.filmy(0.07),
                            UpdoTheme.filmy(0.0)
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

// MARK: - Liquid Glass

extension View {
    /// Apple **Liquid Glass** (`.glassEffect`) on iOS 26+, system `.ultraThinMaterial`
    /// fallback below. Uses ONLY system-rendered materials (GPU/Metal) — the same
    /// optimized path Apple's own UI rides, so there is no CPU cost from hand-drawn
    /// blur. Prefer this over custom LinearGradient "faux glass".
    @ViewBuilder
    func liquidGlass<S: InsettableShape>(in shape: S, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                glassEffect(.regular.tint(tint), in: shape)
            } else {
                glassEffect(.regular, in: shape)
            }
        } else {
            background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(UpdoTheme.border, lineWidth: 1))
        }
    }
}

// MARK: - Interactive Pop (swipe-to-go-back on nav-bar-hidden screens)

/// When a screen hides the navigation bar / back button, SwiftUI (UIKit under the
/// hood) also disables the system left-edge "swipe back" gesture. Our chat screens
/// hide the bar for the floating glass header, which left users with only the small
/// custom back button. This re-enables the native edge swipe so a swipe from the
/// left always goes back — independent of where the finger lands on the header.
private struct InteractivePopGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ uiViewController: Controller, context: Context) {}

    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            enable()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            enable()
        }

        private func enable() {
            guard let nav = navigationController else { return }
            nav.interactivePopGestureRecognizer?.isEnabled = true
            nav.interactivePopGestureRecognizer?.delegate = self
        }

        // Only allow the swipe when there is actually something to pop (so it is a
        // no-op when the chat is the root of a modally-presented NavigationStack).
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }
}

extension View {
    /// Re-enables the native left-edge swipe-to-go-back gesture on screens that hide
    /// the navigation bar. Safe no-op when there is nothing to pop.
    func enableInteractivePopGesture() -> some View {
        background(
            InteractivePopGestureEnabler()
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        )
    }
}

