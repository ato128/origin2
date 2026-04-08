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
            Color(red: 0.038, green: 0.042, blue: 0.058)
                .ignoresSafeArea()

            stableAmbientBackground(
                magentaOpacity: 0.14,
                blueOpacity: 0.12,
                tealOpacity: 0.04,
                violetOpacity: 0.05,
                amberOpacity: 0.025
            )
        }
        .ignoresSafeArea()
    }

    var amoledBackground: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            stableAmbientBackground(
                magentaOpacity: 0.12,
                blueOpacity: 0.10,
                tealOpacity: 0.035,
                violetOpacity: 0.045,
                amberOpacity: 0.02
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
            Color(red: 0.010, green: 0.012, blue: 0.022)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(red: 0.020, green: 0.018, blue: 0.040),
                    Color(red: 0.014, green: 0.016, blue: 0.030),
                    Color(red: 0.010, green: 0.012, blue: 0.024)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            stableAmbientBackground(
                magentaOpacity: 0.18,
                blueOpacity: 0.16,
                tealOpacity: 0.055,
                violetOpacity: 0.07,
                amberOpacity: 0.03
            )
        }
        .ignoresSafeArea()
    }

    func stableAmbientBackground(
        magentaOpacity: Double,
        blueOpacity: Double,
        tealOpacity: Double,
        violetOpacity: Double,
        amberOpacity: Double
    ) -> some View {
        ZStack {
            // sol üst magenta
            RadialGradient(
                colors: [
                    Color(red: 0.96, green: 0.34, blue: 0.80).opacity(magentaOpacity),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 260
            )
            .ignoresSafeArea()

            // sağ üst blue/cyan
            RadialGradient(
                colors: [
                    Color(red: 0.20, green: 0.66, blue: 1.00).opacity(blueOpacity),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 290
            )
            .ignoresSafeArea()

            // orta hafif violet bağlayıcı
            RadialGradient(
                colors: [
                    Color(red: 0.46, green: 0.32, blue: 0.96).opacity(violetOpacity),
                    Color.clear
                ],
                center: .center,
                startRadius: 60,
                endRadius: 240
            )
            .ignoresSafeArea()

            // alt sol teal
            RadialGradient(
                colors: [
                    Color(red: 0.20, green: 0.84, blue: 0.70).opacity(tealOpacity),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 40,
                endRadius: 220
            )
            .ignoresSafeArea()

            // alt sağ violet
            RadialGradient(
                colors: [
                    Color(red: 0.36, green: 0.28, blue: 0.96).opacity(violetOpacity * 0.9),
                    Color.clear
                ],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 220
            )
            .ignoresSafeArea()

            // hafif sıcak amber
            RadialGradient(
                colors: [
                    Color(red: 1.00, green: 0.58, blue: 0.26).opacity(amberOpacity),
                    Color.clear
                ],
                center: .top,
                startRadius: 20,
                endRadius: 150
            )
            .ignoresSafeArea()

            // üstten çok hafif ışık
            LinearGradient(
                colors: [
                    Color.white.opacity(0.018),
                    Color.clear,
                    Color.black.opacity(0.025)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}
