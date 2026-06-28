//
//  UpdoWidgetTheme.swift
//  WidgetExtensionExtension
//
//  Created by Atakan Ortaç on 24.05.2026.
//

import SwiftUI

// MARK: - Updo Widget Theme
//
// Uygulamanın görsel kimliğini (koyu lacivert zemin, cyan→blue→purple gradient,
// glow vurgular) hem ScheduleWidget hem de Live Activity'lerde TEK kaynaktan
// kullanmak için ortak palet + helper'lar.
//
// NOT: Bu dosya WidgetExtension target'ına eklenmeli. Veri akışına (App Group,
// Attributes) dokunmaz — sadece görünüm katmanıdır.

enum UpdoWidgetPalette {
    // Ana arka plan tonları (app'teki #05060D / #070713 ile aynı)
    static let bgTop = Color(red: 0.04, green: 0.05, blue: 0.10)      // #0A0D1A civarı
    static let bgMid = Color(red: 0.03, green: 0.04, blue: 0.09)
    static let bgBottom = Color(red: 0.02, green: 0.03, blue: 0.06)

    // Accent paleti
    static let cyan = Color(red: 0.18, green: 0.83, blue: 1.00)       // #2DD4FF
    static let blue = Color(red: 0.08, green: 0.58, blue: 1.00)       // #1593FF
    static let purple = Color(red: 0.49, green: 0.23, blue: 0.93)     // #7C3AED
    static let green = Color(red: 0.20, green: 0.83, blue: 0.29)      // #34D44A

    // İmza gradient (blue → purple) — app'te her yerde
    static var signatureGradient: LinearGradient {
        LinearGradient(
            colors: [blue, purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Cyan → blue accent gradient (focus/live vurgu)
    static var liveGradient: LinearGradient {
        LinearGradient(
            colors: [cyan, blue],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Refined ("Apple/Updo") surface + ink tokens
    //
    // A calmer system used by the redesigned widgets & Live Activities: a single
    // deep surface, hairline borders, restrained text greys and one brand accent.

    static let surfaceTop = Color(red: 0.058, green: 0.069, blue: 0.114)   // ~#0F121D
    static let surfaceBottom = Color(red: 0.027, green: 0.033, blue: 0.060) // ~#070810

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.60)
    static let textTertiary = Color.white.opacity(0.38)

    static let hairline = Color.white.opacity(0.09)
    static let fillSoft = Color.white.opacity(0.055)
}

// MARK: - Refined typography helpers (SF Pro, restrained weights)

enum WidgetFont {
    /// Small section label (e.g. "TODAY"), used sparingly with low contrast.
    static func eyebrow(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .semibold) }
    static func title(_ size: CGFloat = 16) -> Font { .system(size: size, weight: .semibold) }
    static func body(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .medium) }
    static func caption(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .medium) }
    /// Hero timer numerals — rounded reads cleaner at large sizes.
    static func timer(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
}

// MARK: - Focus hero number style (mirrors the in-app FocusHeroDigits, 1:1)
//
// The app's focus screen renders its timer as bold *serif italic* digits filled
// with a brushed-silver gradient, rolling top→bottom via `.numericText(countsDown:)`.
// Widgets & Live Activities reuse the exact same identity so the numbers match.

enum WidgetBrushedSilver {
    static func fill(accent: Color) -> LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.96),
                Color.white.opacity(0.74),
                Color(white: 0.42),
                accent.opacity(0.45)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Solid near-silver used for *live* timers, where a gradient fill would
    /// freeze the system `Text(timerInterval:)`.
    static let solid = Color(white: 0.92)
}

/// Applies the focus hero-timer identity (serif italic, brushed silver) to any Text.
///
/// IMPORTANT: a `Text(timerInterval:)` renders its own system-driven ticking and
/// FREEZES if wrapped in layout/paint modifiers it can't update through — namely
/// `.contentTransition(.numericText())`, a gradient `foregroundStyle`, `.kerning`
/// or `.minimumScaleFactor`. So for `live: true` we use the minimal safe set
/// (serif italic font + monospaced digits + a solid silver color) which keeps the
/// timer ticking. Static numbers (`live: false`) get the full brushed-silver
/// gradient + the top→bottom numeric roll.
struct FocusHeroTextStyle: ViewModifier {
    var size: CGFloat
    var accent: Color
    var monospaced: Bool = true
    var live: Bool = false

    func body(content: Content) -> some View {
        if live {
            // Live system timer: a gradient `foregroundStyle` (and kerning /
            // minimumScaleFactor / contentTransition) freezes the ticking on device,
            // so a live timer MUST use a solid color. Confirmed on hardware.
            content
                .font(.system(size: size, weight: .bold, design: .serif))
                .italic()
                .monospacedDigit()
                .foregroundStyle(WidgetBrushedSilver.solid)
                .lineLimit(1)
        } else {
            content
                .font(.system(size: size, weight: .bold, design: .serif))
                .italic()
                .kerning(-size * 0.024)
                .monospacedDigit(monospaced)
                .foregroundStyle(WidgetBrushedSilver.fill(accent: accent))
                .contentTransition(.numericText(countsDown: true))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }
}

extension View {
    /// Convenience for the focus hero-number look. Set `live: true` for a
    /// `Text(timerInterval:)` so its system ticking is preserved.
    func focusHeroNumber(size: CGFloat, accent: Color, monospaced: Bool = true, live: Bool = false) -> some View {
        modifier(FocusHeroTextStyle(size: size, accent: accent, monospaced: monospaced, live: live))
    }

    /// Top→bottom numeric roll, applied only when `on` (skipped for live timers).
    @ViewBuilder
    func numericRoll(_ on: Bool) -> some View {
        if on { self.contentTransition(.numericText(countsDown: true)) } else { self }
    }
}

private extension View {
    /// `monospacedDigit()` only when requested (keeps live timers from jittering;
    /// lets static hero numbers keep the natural serif advance).
    @ViewBuilder
    func monospacedDigit(_ on: Bool) -> some View {
        if on { self.monospacedDigit() } else { self }
    }
}

// MARK: - Hex → Color (widget + live activity ortak)

