//
//  WeekAmbientBackground.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI

struct WeekAmbientBackground: View {
    var body: some View {
        ZStack {

            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.blue.opacity(0.14),
                    Color.indigo.opacity(0.10),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            // MOR GLOW (Week yazısı arkası)
            RadialGradient(
                colors: [
                    Color.purple.opacity(0.10),
                    Color.clear
                ],
                center: UnitPoint(x: 0.20, y: 0.05),
                startRadius: 10,
                endRadius: 220
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.cyan.opacity(0.04),
                    Color.clear
                ],
                center: UnitPoint(x: 0.82, y: 0.15),
                startRadius: 10,
                endRadius: 180
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.purple.opacity(0.08),
                    Color.blue.opacity(0.02)
                ],
                startPoint: .center,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}
