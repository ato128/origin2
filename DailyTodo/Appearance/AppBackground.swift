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
            Color(.systemGray6)
                .ignoresSafeArea()

        case AppTheme.amoled.rawValue:
            Color.black
                .ignoresSafeArea()

        case AppTheme.light.rawValue:
            Color.white
                .ignoresSafeArea()

        default:
            ZStack {

                Color.black
                    .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        Color.purple.opacity(0.30),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 320
                )

                RadialGradient(
                    colors: [
                        Color.blue.opacity(0.24),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: 380
                )

                RadialGradient(
                    colors: [
                        Color.blue.opacity(0.08),
                        Color.clear
                    ],
                    center: .bottomLeading,
                    startRadius: 80,
                    endRadius: 280
                )

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.015),
                        Color.clear,
                        Color.white.opacity(0.01)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.screen)

            }
            .ignoresSafeArea()
        }
    }
}
