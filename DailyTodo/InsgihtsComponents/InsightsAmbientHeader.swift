//
//  InsightsAmbientHeader.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI

struct InsightsAmbientHeader: View {

    @State private var animate = false

    var body: some View {

        ZStack {

            LinearGradient(
                colors: [
                    Color.blue.opacity(0.25),
                    Color.purple.opacity(0.18),
                    Color.clear
                ],
                startPoint: animate ? .topLeading : .topTrailing,
                endPoint: animate ? .bottomTrailing : .bottomLeading
            )
            .blur(radius: 80)

            Circle()
                .fill(Color.blue.opacity(0.25))
                .frame(width: 260)
                .blur(radius: 90)
                .offset(x: animate ? -120 : 120, y: -40)

            Circle()
                .fill(Color.purple.opacity(0.22))
                .frame(width: 220)
                .blur(radius: 80)
                .offset(x: animate ? 120 : -120, y: -20)

        }
        .onAppear {

            withAnimation(
                .easeInOut(duration: 10)
                .repeatForever(autoreverses: true)
            ) {
                animate.toggle()
            }

        }
    }
}
