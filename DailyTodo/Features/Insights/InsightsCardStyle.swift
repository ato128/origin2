//
//  InsightsCardStyle.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 4.04.2026.
//

import SwiftUI

struct InsightsPremiumCardModifier: ViewModifier {
    let accent: Color
    let cornerRadius: CGFloat
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.035))
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.07),
                                        Color.clear,
                                        accent.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.14),
                                        accent.opacity(0.10),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: .black.opacity(0.14), radius: 20, y: 10)
    }
}

struct InsightsInnerGlassModifier: ViewModifier {
    let accent: Color

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.05),
                                        Color.clear,
                                        accent.opacity(0.06)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }
}

extension View {
    func insightsPremiumCardStyle(
        accent: Color,
        cornerRadius: CGFloat = 30,
        padding: CGFloat = 22
    ) -> some View {
        modifier(
            InsightsPremiumCardModifier(
                accent: accent,
                cornerRadius: cornerRadius,
                padding: padding
            )
        )
    }

    func insightsInnerGlass(accent: Color) -> some View {
        modifier(InsightsInnerGlassModifier(accent: accent))
    }
}
