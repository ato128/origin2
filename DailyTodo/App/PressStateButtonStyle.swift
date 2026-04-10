//
//  FocusShowcaseView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 9.04.2026.
//

import SwiftUI

struct PressStateButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.015 : 0)
    }
}
