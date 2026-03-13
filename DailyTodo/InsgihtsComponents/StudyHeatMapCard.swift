//
//  StudyHeatMapCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI

struct StudyHeatMapCard: View {
    let data: StudyHeatmapData

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    @State private var isVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(data.title)
                    .font(.system(size: 17, weight: .bold))

                Spacer()

                Text(data.subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 9) {
                ForEach(Array(data.cells.enumerated()), id: \.element.id) { index, cell in
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(fillColor(for: cell))
                        .overlay(
                            ZStack {
                                if cell.isSelected {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(Color.accentColor.opacity(0.18))
                                        .blur(radius: 8)
                                        .scaleEffect(isVisible ? 1.15 : 0.85)
                                }
                                
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(fillColor(for: cell))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .stroke(cell.isSelected ? Color.white.opacity(0.35) : .clear, lineWidth: 1)
                                    )
                            }
                                .frame(height: 20)
                                .opacity(isVisible ? 1 : 0)
                                .scaleEffect(isVisible ? (cell.isSelected ? 1.05 : 1.0) : 0.86)
                                .offset(y: isVisible ? 0 : 6)
                                .animation(
                                    .spring(response: 0.48, dampingFraction: 0.82)
                                        .delay(Double(index) * 0.012),
                                    value: isVisible
                                )
               ) }
            
            
            }

            HStack(spacing: 8) {
                Text("Az")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                ForEach(0..<4, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(legendColor(for: level))
                        .frame(width: 28, height: 14)
                }

                Text("Çok")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text(data.selectedDayText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(cardBackground)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.985)
        .offset(y: isVisible ? 0 : 12)
        .animation(.spring(response: 0.48, dampingFraction: 0.86), value: isVisible)
        .animateWhenVisible($isVisible)
    }

    func fillColor(for cell: InsightsHeatmapCell) -> Color {
        switch cell.level {
        case 0: return Color.white.opacity(0.06)
        case 1: return Color.accentColor.opacity(0.26)
        case 2: return Color.accentColor.opacity(0.50)
        default: return Color.accentColor
        }
    }

    func legendColor(for level: Int) -> Color {
        switch level {
        case 0: return Color.white.opacity(0.06)
        case 1: return Color.accentColor.opacity(0.26)
        case 2: return Color.accentColor.opacity(0.50)
        default: return Color.accentColor
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
    }
}
