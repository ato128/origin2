//
//  CrewChatView+Models.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import SwiftUI

struct TypingDotsView: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 4) {
            dot(delay: 0.0)
            dot(delay: 0.18)
            dot(delay: 0.36)
        }
        .onAppear {
            animate = true
        }
        .onDisappear {
            animate = false
        }
    }

    private func dot(delay: Double) -> some View {
        Circle()
            .fill(Color.secondary)
            .frame(width: 5, height: 5)
            .scaleEffect(animate ? 1.0 : 0.7)
            .opacity(animate ? 1.0 : 0.45)
            .animation(
                .easeInOut(duration: 0.75)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: animate
            )
    }
}

