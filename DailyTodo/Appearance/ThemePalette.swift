//
//  ThemePalette.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 14.03.2026.
//

import SwiftUI

struct ThemePalette {
    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue

    var theme: AppTheme {
        AppTheme(rawValue: appTheme) ?? .gradient
    }

    var isLight: Bool {
        theme == .light
    }

    var isGradient: Bool {
        theme == .gradient
    }

    var screenBackground: Color {
        switch theme {
        case .light:
            return Color(red: 0.965, green: 0.935, blue: 0.875)
        case .dark:
            return Color(red: 0.030, green: 0.032, blue: 0.050)
        case .amoled:
            return .black
        case .gradient:
            return Color(red: 0.008, green: 0.010, blue: 0.020)
        }
    }

    var cardFill: Color {
        switch theme {
        case .light:
            return Color.white.opacity(0.70)
        case .dark:
            return Color.white.opacity(0.052)
        case .amoled:
            return Color.white.opacity(0.038)
        case .gradient:
            return Color.white.opacity(0.055)
        }
    }

    var cardStroke: Color {
        switch theme {
        case .light:
            return Color.white.opacity(0.86)
        case .dark:
            return Color.white.opacity(0.055)
        case .amoled:
            return Color.white.opacity(0.045)
        case .gradient:
            return Color.white.opacity(0.070)
        }
    }

    var shadowColor: Color {
        isLight
        ? Color(red: 0.42, green: 0.34, blue: 0.26).opacity(0.15)
        : Color.black.opacity(0.20)
    }
    
    var secondaryCardFill: Color {
        switch appTheme {
        case AppTheme.light.rawValue:
            return Color.white.opacity(0.55)

        case AppTheme.dark.rawValue:
            return Color.white.opacity(0.040)

        case AppTheme.amoled.rawValue:
            return Color.white.opacity(0.030)

        default:
            return Color.white.opacity(0.045)
        }
    }

    var primaryText: Color {
        isLight ? Color(red: 0.105, green: 0.090, blue: 0.075) : .white
    }

    var secondaryText: Color {
        isLight ? Color.black.opacity(0.64) : Color.white.opacity(0.68)
    }

    var tertiaryText: Color {
        isLight ? Color.black.opacity(0.44) : Color.white.opacity(0.48)
    }

    var capsuleFill: Color {
        isLight ? Color.white.opacity(0.62) : Color.white.opacity(0.06)
    }

    var divider: Color {
        isLight ? Color.black.opacity(0.055) : Color.white.opacity(0.05)
    }

    var glassFill: AnyShapeStyle {
        if isLight {
            return AnyShapeStyle(Color.white.opacity(0.68))
        } else {
            return AnyShapeStyle(Color.white.opacity(0.055))
        }
    }

   
    var accent: Color {
        Color.accentColor
    }

    var cardShadow: Color {
        isLight ? Color.black.opacity(0.10) : Color.black.opacity(0.18)
    }
}
