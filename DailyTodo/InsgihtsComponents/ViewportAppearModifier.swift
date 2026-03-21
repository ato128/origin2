//
//  ViewportAppearModifier.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI
import UIKit

struct ViewportAppearModifier: ViewModifier {
    @Binding var hasEnteredViewport: Bool
    var triggerOnce: Bool = true

    @State private var hasTriggered = false

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            check(frame: geo.frame(in: .global))
                        }
                        .onChange(of: geo.frame(in: .global)) { _, newFrame in
                            check(frame: newFrame)
                        }
                }
            )
    }

    private func check(frame: CGRect) {
        guard !(triggerOnce && hasTriggered) else { return }

      
        let activationZone = CGRect(
            x: frame.minX,
            y: frame.minY - 120,
            width: frame.width,
            height: frame.height + 240
        )

        if activationZone.intersects(frame) {
            hasEnteredViewport = true
            hasTriggered = true
        }
    }
}

extension View {
    func animateWhenVisible(_ hasEnteredViewport: Binding<Bool>, triggerOnce: Bool = true) -> some View {
        modifier(
            ViewportAppearModifier(
                hasEnteredViewport: hasEnteredViewport,
                triggerOnce: triggerOnce
            )
        )
    }
}
