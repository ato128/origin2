//
//  AppBackground.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 14.03.2026.
//
import SwiftUI

struct AppBackground: View {
    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue

    var body: some View {
        switch appTheme {
        case AppTheme.dark.rawValue:
            darkBackground

        case AppTheme.amoled.rawValue:
            amoledBackground

        case AppTheme.light.rawValue:
            lightBackground

        default:
            gradientBackground
        }
    }
}

private extension AppBackground {

    var darkBackground: some View {
        ZStack {
            Color(red: 0.030, green: 0.032, blue: 0.050)
                .ignoresSafeArea()

            edgeLitField(
                topBase: Color(red: 0.024, green: 0.020, blue: 0.050),
                bottomBase: Color(red: 0.010, green: 0.012, blue: 0.022),
                leftPinkOpacity: 0.12,
                leftPurpleOpacity: 0.10,
                rightBlueOpacity: 0.09,
                rightVioletOpacity: 0.08
            )
        }
        .ignoresSafeArea()
    }

    var amoledBackground: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            edgeLitField(
                topBase: Color(red: 0.018, green: 0.016, blue: 0.038),
                bottomBase: Color(red: 0.004, green: 0.006, blue: 0.014),
                leftPinkOpacity: 0.10,
                leftPurpleOpacity: 0.09,
                rightBlueOpacity: 0.08,
                rightVioletOpacity: 0.07
            )
        }
        .ignoresSafeArea()
    }

    var lightBackground: some View {
        LinearGradient(
            colors: [
                Color.white,
                Color(.systemGray6)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    var gradientBackground: some View {
        ZStack {
            Color(red: 0.008, green: 0.010, blue: 0.020)
                .ignoresSafeArea()

            edgeLitField(
                topBase: Color(red: 0.030, green: 0.020, blue: 0.070),
                bottomBase: Color(red: 0.008, green: 0.010, blue: 0.020),
                leftPinkOpacity: 0.18,
                leftPurpleOpacity: 0.16,
                rightBlueOpacity: 0.14,
                rightVioletOpacity: 0.12
            )
        }
        .ignoresSafeArea()
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
            .ignoresSafeArea()

            // Sol alt peach/pink edge glow
            RadialGradient(
                colors: [
                    Color(red: 1.00, green: 0.82, blue: 0.86).opacity(leftPinkOpacity * 0.95),
                    Color(red: 0.95, green: 0.42, blue: 0.74).opacity(leftPinkOpacity * 0.68),
                    Color.clear
                ],
                center: UnitPoint(x: -0.08, y: 1.04),
                startRadius: 10,
                endRadius: 300
            )
            .ignoresSafeArea()

            // Sol orta/alt violet lift
            RadialGradient(
                colors: [
                    Color(red: 0.78, green: 0.22, blue: 0.88).opacity(leftPurpleOpacity * 0.86),
                    Color(red: 0.34, green: 0.08, blue: 0.76).opacity(leftPurpleOpacity * 0.58),
                    Color.clear
                ],
                center: UnitPoint(x: -0.05, y: 0.78),
                startRadius: 30,
                endRadius: 260
            )
            .ignoresSafeArea()

            // Sağ üst blue edge glow
            RadialGradient(
                colors: [
                    Color(red: 0.20, green: 0.66, blue: 1.00).opacity(rightBlueOpacity),
                    Color(red: 0.10, green: 0.20, blue: 0.76).opacity(rightBlueOpacity * 0.62),
                    Color.clear
                ],
                center: UnitPoint(x: 1.05, y: -0.02),
                startRadius: 30,
                endRadius: 280
            )
            .ignoresSafeArea()

            // Sağ alt indigo/violet edge glow
            RadialGradient(
                colors: [
                    Color(red: 0.42, green: 0.28, blue: 0.96).opacity(rightVioletOpacity * 0.90),
                    Color(red: 0.20, green: 0.08, blue: 0.44).opacity(rightVioletOpacity * 0.56),
                    Color.clear
                ],
                center: UnitPoint(x: 1.06, y: 0.96),
                startRadius: 30,
                endRadius: 240
            )
            .ignoresSafeArea()

            // Üstte hafif koyu perde, header rahat okusun
            LinearGradient(
                colors: [
                    Color.black.opacity(0.14),
                    Color.clear,
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Alt derinlik
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Çok hafif genel polish
            LinearGradient(
                colors: [
                    Color.white.opacity(0.010),
                    Color.clear,
                    Color.black.opacity(0.018)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}
