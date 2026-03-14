//
//  ThemePalette.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 14.03.2026.
//

import SwiftUI

struct ThemePalette {
    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue

    private var isLight: Bool {
        appTheme == AppTheme.light.rawValue
    }

    private var isGradient: Bool {
        appTheme == AppTheme.gradient.rawValue
    }

    var screenBackground: Color {
        switch appTheme {
        case AppTheme.dark.rawValue, AppTheme.amoled.rawValue, AppTheme.gradient.rawValue:
            return .black
        case AppTheme.light.rawValue:
            return Color(.systemGray6)
        default:
            return .black
        }
    }

    var cardFill: Color {
        switch appTheme {
        case AppTheme.light.rawValue:
            return .white
        case AppTheme.dark.rawValue:
            return Color.white.opacity(0.05)
        case AppTheme.amoled.rawValue:
            return Color.white.opacity(0.04)
        default:
            return Color.white.opacity(0.06)
        }
    }

    var secondaryCardFill: Color {
        switch appTheme {
        case AppTheme.light.rawValue:
            return Color.black.opacity(0.04)
        case AppTheme.dark.rawValue:
            return Color.white.opacity(0.04)
        case AppTheme.amoled.rawValue:
            return Color.white.opacity(0.035)
        default:
            return Color.white.opacity(0.04)
        }
    }

    var cardStroke: Color {
        switch appTheme {
        case AppTheme.light.rawValue:
            return Color.black.opacity(0.07)
        case AppTheme.dark.rawValue:
            return Color.white.opacity(0.06)
        case AppTheme.amoled.rawValue:
            return Color.white.opacity(0.05)
        default:
            return Color.white.opacity(0.08)
        }
    }

    var primaryText: Color {
        isLight ? .black : .white
    }

    var secondaryText: Color {
        isLight ? Color.black.opacity(0.65) : Color.white.opacity(0.68)
    }

    var tertiaryText: Color {
        isLight ? Color.black.opacity(0.45) : Color.white.opacity(0.48)
    }

    var capsuleFill: Color {
        isLight ? Color.black.opacity(0.05) : Color.white.opacity(0.06)
    }

    var divider: Color {
        isLight ? Color.black.opacity(0.06) : Color.white.opacity(0.05)
    }

    var glassFill: AnyShapeStyle {
        if isLight {
            return AnyShapeStyle(Color.white.opacity(0.88))
        } else {
            return AnyShapeStyle(.ultraThinMaterial)
        }
    }

    var shadowColor: Color {
        isLight ? Color.black.opacity(0.08) : Color.black.opacity(0.18)
    }
}
