//
//  CountUpText.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI

struct CountUpText: View {
    let value: Double
    let duration: Double
    let trigger: Bool
    let formatter: (Double) -> String

    @State private var displayedValue: Double = 0

    var body: some View {
        Text(formatter(displayedValue))
            .monospacedDigit()
            .onAppear {
                if trigger {
                    runAnimation()
                }
            }
            .onChange(of: trigger) { _, newValue in
                guard newValue else { return }
                runAnimation()
            }
    }

    private func runAnimation() {
        displayedValue = 0
        withAnimation(.easeOut(duration: duration)) {
            displayedValue = value
        }
    }
}
