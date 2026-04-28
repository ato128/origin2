//
//  AppBackground.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 14.03.2026.
//
import SwiftUI

struct AppBackground: View {
    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue

    private var theme: AppTheme {
        AppTheme(rawValue: appTheme) ?? .gradient
    }

    var body: some View {
        ZStack {
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
        .ignoresSafeArea()
    }
}

private extension AppBackground {

    var premiumCreamBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.996, green: 0.978, blue: 0.935),
                    Color(red: 0.978, green: 0.940, blue: 0.860),
                    Color(red: 0.950, green: 0.900, blue: 0.805)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color(red: 0.58, green: 0.38, blue: 1.00).opacity(0.34),
                    Color(red: 0.74, green: 0.56, blue: 1.00).opacity(0.16),
                    .clear
                ],
                center: UnitPoint(x: -0.18, y: 0.18),
                startRadius: 18,
                endRadius: 390
            )

            RadialGradient(
                colors: [
                    Color(red: 0.16, green: 0.62, blue: 1.00).opacity(0.30),
                    Color(red: 0.48, green: 0.78, blue: 1.00).opacity(0.14),
                    .clear
                ],
                center: UnitPoint(x: 1.20, y: 0.22),
                startRadius: 20,
                endRadius: 410
            )

            RadialGradient(
                colors: [
                    Color(red: 0.42, green: 0.26, blue: 1.00).opacity(0.30),
                    Color(red: 0.22, green: 0.54, blue: 1.00).opacity(0.16),
                    .clear
                ],
                center: UnitPoint(x: -0.16, y: 0.94),
                startRadius: 25,
                endRadius: 430
            )

            RadialGradient(
                colors: [
                    Color(red: 0.18, green: 0.58, blue: 1.00).opacity(0.28),
                    Color(red: 0.72, green: 0.36, blue: 1.00).opacity(0.16),
                    .clear
                ],
                center: UnitPoint(x: 1.18, y: 0.98),
                startRadius: 25,
                endRadius: 460
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.42),
                    Color.white.opacity(0.20),
                    .clear
                ],
                center: UnitPoint(x: 0.50, y: 0.42),
                startRadius: 40,
                endRadius: 420
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.48),
                    .clear,
                    Color(red: 0.66, green: 0.54, blue: 0.40).opacity(0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
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
