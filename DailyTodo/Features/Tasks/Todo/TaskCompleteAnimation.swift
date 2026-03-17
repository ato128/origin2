//
//  TaskCompleteAnimation.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 17.03.2026.
//

import SwiftUI

struct TaskCompleteAnimation: View {

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {

            Circle()
                .fill(Color.green.opacity(0.15))
                .frame(width: 120, height: 120)
                .scaleEffect(scale)

            Image(systemName: "checkmark")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(.green)
                .scaleEffect(scale)
        }
        .onAppear {

            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1
            }

        }
    }
}
