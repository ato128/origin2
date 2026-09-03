//
//  AppBackground.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 14.03.2026.
//
import SwiftUI

struct AppBackground: View {
    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    @Environment(\.colorScheme) private var colorScheme

    private var theme: AppTheme {
        AppTheme(rawValue: appTheme) ?? .gradient
    }

    var body: some View {
        ZStack {
            // Light appearance always shows the warm eggshell field; the dark
            // "style" choice (gradient / dark / amoled) applies only in dark mode.
            if colorScheme == .light {
                premiumCreamBackground
            } else {
                switch theme {
                case .light:
                    premiumCreamBackground
                case .dark:
                    darkBackground
                case .amoled:
                    amoledBackground
                case .gradient:
                    gradientBackground
                }
            }
        }
        .ignoresSafeArea()
    }
}

private extension AppBackground {

    var premiumCreamBackground: some View {
        PremiumLightField()
    }
    var darkBackground: some View {
        ZStack {
            Color(red: 0.030, green: 0.032, blue: 0.050)

            edgeLitField(
                topBase: Color(red: 0.024, green: 0.020, blue: 0.050),
                bottomBase: Color(red: 0.010, green: 0.012, blue: 0.022),
                leftPinkOpacity: 0.12,
                leftPurpleOpacity: 0.10,
                rightBlueOpacity: 0.09,
                rightVioletOpacity: 0.08
            )
        }
    }

    var amoledBackground: some View {
        ZStack {
            Color.black

            edgeLitField(
                topBase: Color(red: 0.018, green: 0.016, blue: 0.038),
                bottomBase: Color(red: 0.004, green: 0.006, blue: 0.014),
                leftPinkOpacity: 0.10,
                leftPurpleOpacity: 0.09,
                rightBlueOpacity: 0.08,
                rightVioletOpacity: 0.07
            )
        }
    }

    var gradientBackground: some View {
        ZStack {
            Color(red: 0.008, green: 0.010, blue: 0.020)

            edgeLitField(
                topBase: Color(red: 0.030, green: 0.020, blue: 0.070),
                bottomBase: Color(red: 0.008, green: 0.010, blue: 0.020),
                leftPinkOpacity: 0.18,
                leftPurpleOpacity: 0.16,
                rightBlueOpacity: 0.14,
                rightVioletOpacity: 0.12
            )
        }
    }

    func edgeLitField(
        topBase: Color,
        bottomBase: Color,
        leftPinkOpacity: Double,
        leftPurpleOpacity: Double,
        rightBlueOpacity: Double,
        rightVioletOpacity: Double
    ) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    topBase,
                    Color(red: 0.015, green: 0.016, blue: 0.032),
                    bottomBase
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color(red: 1.00, green: 0.82, blue: 0.86).opacity(leftPinkOpacity * 0.95),
                    Color(red: 0.95, green: 0.42, blue: 0.74).opacity(leftPinkOpacity * 0.68),
                    .clear
                ],
                center: UnitPoint(x: -0.08, y: 1.04),
                startRadius: 10,
                endRadius: 300
            )

            RadialGradient(
                colors: [
                    Color(red: 0.78, green: 0.22, blue: 0.88).opacity(leftPurpleOpacity * 0.86),
                    Color(red: 0.34, green: 0.08, blue: 0.76).opacity(leftPurpleOpacity * 0.58),
                    .clear
                ],
                center: UnitPoint(x: -0.05, y: 0.78),
                startRadius: 30,
                endRadius: 260
            )

            RadialGradient(
                colors: [
                    Color(red: 0.20, green: 0.66, blue: 1.00).opacity(rightBlueOpacity),
                    Color(red: 0.10, green: 0.20, blue: 0.76).opacity(rightBlueOpacity * 0.62),
                    .clear
                ],
                center: UnitPoint(x: 1.05, y: -0.02),
                startRadius: 30,
                endRadius: 280
            )

            RadialGradient(
                colors: [
                    Color(red: 0.42, green: 0.28, blue: 0.96).opacity(rightVioletOpacity * 0.90),
                    Color(red: 0.20, green: 0.08, blue: 0.44).opacity(rightVioletOpacity * 0.56),
                    .clear
                ],
                center: UnitPoint(x: 1.06, y: 0.96),
                startRadius: 30,
                endRadius: 240
            )

            LinearGradient(
                colors: [
                    Color.black.opacity(0.14),
                    .clear,
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

/// The shared light-mode field: a dense cool grey settles at the base and opens
/// to warm light toward the top — a clean dark→light vertical transition. Used by
/// every light-mode surface so the whole app reads consistently. All static
/// gradients: no timeline, no blur → effectively free on the GPU, zero CPU.
struct PremiumLightField: View {
    private let baseGrey = Color(red: 0.588, green: 0.596, blue: 0.620)

    var body: some View {
        ZStack {
            // Light at top → a plain, recognizable grey at the very bottom.
            LinearGradient(
                colors: [
                    Color(red: 0.982, green: 0.974, blue: 0.958),
                    Color(red: 0.905, green: 0.902, blue: 0.900),
                    Color(red: 0.735, green: 0.740, blue: 0.758),
                    baseGrey
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Cloudy transition — soft grey puffs billow up from the base so the
            // boundary reads as clouds, not a straight line.
            RadialGradient(
                colors: [Color(red: 0.560, green: 0.570, blue: 0.598).opacity(0.55), .clear],
                center: UnitPoint(x: 0.28, y: 1.02), startRadius: 20, endRadius: 430
            )
            RadialGradient(
                colors: [Color(red: 0.575, green: 0.585, blue: 0.612).opacity(0.50), .clear],
                center: UnitPoint(x: 0.80, y: 1.05), startRadius: 20, endRadius: 450
            )
            RadialGradient(
                colors: [Color(red: 0.600, green: 0.610, blue: 0.636).opacity(0.42), .clear],
                center: UnitPoint(x: 0.52, y: 0.90), startRadius: 30, endRadius: 400
            )

            // Light puffs drifting down into the transition to feather it further.
            RadialGradient(
                colors: [Color.white.opacity(0.42), .clear],
                center: UnitPoint(x: 0.64, y: 0.62), startRadius: 20, endRadius: 360
            )
            RadialGradient(
                colors: [Color.white.opacity(0.34), .clear],
                center: UnitPoint(x: 0.20, y: 0.56), startRadius: 20, endRadius: 330
            )

            // Solid grey anchor so the known grey shows directly at the very bottom.
            LinearGradient(
                colors: [baseGrey.opacity(0.85), .clear],
                startPoint: .bottom,
                endPoint: UnitPoint(x: 0.5, y: 0.55)
            )

            // Top sheen keeps the upper third crisp and bright.
            LinearGradient(
                colors: [Color.white.opacity(0.38), .clear, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
