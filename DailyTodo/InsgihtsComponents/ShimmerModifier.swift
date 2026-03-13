//
//  ShimmerModifier.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI

struct ShimmerModifier: ViewModifier {
    var isActive: Bool

    @State private var move = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.0),
                                Color.white.opacity(0.10),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .rotationEffect(.degrees(22))
                        .offset(x: move ? geo.size.width * 1.4 : -geo.size.width * 1.4)
                        .onAppear {
                            move = false
                            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                move = true
                            }
                        }
                    }
                    .clipped()
                    .blendMode(.plusLighter)
                }
            }
    }
}

extension View {
    func shimmer(_ active: Bool) -> some View {
        modifier(ShimmerModifier(isActive: active))
    }
}
