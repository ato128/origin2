//
//  ParallaxCardModifier.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI

struct ParallaxCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .global).minY
            let screenMid = UIScreen.main.bounds.height * 0.5
            let distance = minY - screenMid
            let offset = max(-8, min(8, -distance * 0.02))

            content
                .offset(y: offset)
        }
    }
}

extension View {
    func subtleParallax() -> some View {
        modifier(ParallaxCardModifier())
    }
}
