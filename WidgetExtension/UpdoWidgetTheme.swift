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
}

// MARK: - Hex → Color (widget + live activity ortak)

