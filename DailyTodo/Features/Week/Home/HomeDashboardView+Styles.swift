//
//  HomeDashboardView+Styles.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 30.03.2026.
//

import SwiftUI

extension HomeDashboardView {
    var heroCardBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(appTheme == AppTheme.light.rawValue ? 0.10 : 0.06),
                                Color.clear,
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(appTheme == AppTheme.light.rawValue ? 0.18 : 0.10),
                                palette.cardStroke,
                                palette.cardStroke.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: palette.cardShadow.opacity(0.95), radius: 18, y: 10)
    }

    var secondaryCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(appTheme == AppTheme.light.rawValue ? 0.06 : 0.04),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        palette.cardStroke.opacity(appTheme == AppTheme.light.rawValue ? 1.0 : 0.92),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: palette.cardShadow.opacity(appTheme == AppTheme.light.rawValue ? 0.55 : 0.72),
                radius: 10,
                y: 5
            )
    }

    var themedCardBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.accentColor.opacity(appTheme == AppTheme.light.rawValue ? 0.08 : 0.10),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 10,
                            endRadius: 240
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(appTheme == AppTheme.light.rawValue ? 0.20 : 0.22),
                                palette.cardStroke,
                                palette.cardStroke.opacity(0.75)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: palette.cardShadow.opacity(0.92), radius: 16, y: 8)
    }
}
