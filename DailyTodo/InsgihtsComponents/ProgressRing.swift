//
//  ProgressRing.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI

struct ProgressRing: View {
    var progress: Double
    var color: Color = .blue
    var lineWidth: CGFloat = 10
    var trigger: Bool = true

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0, min(1, animatedProgress)))
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.16), radius: 8)
        }
        .onAppear {
            if trigger {
                animateRing()
            }
        }
        .onChange(of: trigger) { _, newValue in
            guard newValue else { return }
            animateRing()
        }
        .onChange(of: progress) { _, newValue in
            guard trigger else { return }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.84)) {
                animatedProgress = newValue
            }
        }
    }

    private func animateRing() {
        animatedProgress = 0
        withAnimation(.spring(response: 0.9, dampingFraction: 0.84).delay(0.05)) {
            animatedProgress = progress
        }
    }
}
