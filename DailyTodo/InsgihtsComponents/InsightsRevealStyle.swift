//
//  InsightsRevealStyle.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI

struct InsightsRevealStyle: ViewModifier {
    @Binding var isVisible: Bool
    var delay: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.985)
            .offset(y: isVisible ? 0 : 14)
            .blur(radius: isVisible ? 0 : 6)
            .animation(
                .spring(response: 0.52, dampingFraction: 0.86)
                .delay(delay),
                value: isVisible
            )
    }
}

extension View {
    func insightsReveal(isVisible: Binding<Bool>, delay: Double = 0) -> some View {
        modifier(InsightsRevealStyle(isVisible: isVisible, delay: delay))
    }
}
