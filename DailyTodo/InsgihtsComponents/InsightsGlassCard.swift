//
//  InsightsGlassCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//


import SwiftUI

struct InsightsGlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = 30
    var tint: Color = .white
    var glowOpacity: Double = 0.16
    var fillOpacity: Double = 0.12
    var strokeOpacity: Double = 0.10

    init(
        cornerRadius: CGFloat = 30,
        tint: Color = .white,
        glowOpacity: Double = 0.16,
        fillOpacity: Double = 0.12,
        strokeOpacity: Double = 0.10,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.glowOpacity = glowOpacity
        self.fillOpacity = fillOpacity
        self.strokeOpacity = strokeOpacity
        self.content = content()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(fillOpacity * 0.95),
                            Color.white.opacity(0.028),
                            Color.black.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.025))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(strokeOpacity + 0.02),
                                    tint.opacity(strokeOpacity * 0.55),
                                    Color.white.opacity(0.025)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(tint.opacity(glowOpacity))
                        .frame(width: 150, height: 150)
                        .blur(radius: 40)
                        .offset(x: -24, y: -28)
                        .allowsHitTesting(false)
                }
                .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 12)

            content
                .padding(18)
        }
        .compositingGroup()
    }
}
