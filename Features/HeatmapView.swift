//
//  HeatmapView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 7.03.2026.
//

import SwiftUI

struct HeatmapView: View {

    let data = [
        1, 2, 0, 3, 1, 0, 2,
        2, 1, 0, 0, 3, 2, 1,
        0, 1, 2, 3, 2, 1, 0,
        3, 2, 1, 0, 2, 3, 1
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Last 4 Weeks")
                .font(.headline)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 7),
                spacing: 6
            ) {
                ForEach(0..<data.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(color(for: data[i]))
                        .frame(height: 14)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func color(for value: Int) -> Color {
        switch value {
        case 0:
            return Color.gray.opacity(0.18)
        case 1:
            return Color.blue.opacity(0.35)
        case 2...3:
            return Color.blue.opacity(0.65)
        default:
            return Color.blue
        }
    }
}

#Preview {
    HeatmapView()
        .padding()
        .background(Color.black)
}
