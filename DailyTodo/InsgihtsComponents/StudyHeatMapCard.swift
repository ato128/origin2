//
//  StudyHeatMapCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI

struct StudyHeatMapCard: View {
    let data: StudyHeatmapData

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)

    @State private var isVisible = false
    @State private var isExpanded = false

    private var hasActivity: Bool {
        data.cells.contains { $0.level > 0 }
    }

    private var fallbackText: String {
        "Henüz tamamlanan görev görünmüyor. İlk tamamlanan görevlerin burada son 4 haftalık ritim olarak görünecek."
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                isExpanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(data.title)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.primaryText)

                        Text(hasActivity ? "Son 28 günde tamamlama yoğunluğu" : "Son 28 günlük aktivite burada görünecek")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.secondaryText)
                    }

                    Spacer()

                    HStack(spacing: 10) {
                        Text(data.subtitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.secondaryText)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(palette.secondaryText)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(data.cells.enumerated()), id: \.element.id) { index, cell in
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(fillColor(for: cell))
                            .frame(height: 18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(
                                        cell.isSelected
                                        ? Color.white.opacity(appTheme == AppTheme.light.rawValue ? 0.18 : 0.28)
                                        : .clear,
                                        lineWidth: 1
                                    )
                            )
                            .overlay {
                                if cell.isSelected {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.accentColor.opacity(0.16))
                                        .blur(radius: 8)
                                        .scaleEffect(isVisible ? 1.08 : 0.92)
                                }
                            }
                            .opacity(isVisible ? 1 : 0)
                            .scaleEffect(isVisible ? (cell.isSelected ? 1.03 : 1.0) : 0.90)
                            .offset(y: isVisible ? 0 : 8)
                            .animation(
                                .spring(response: 0.46, dampingFraction: 0.84)
                                    .delay(Double(index) * 0.01),
                                value: isVisible
                            )
                    }
                }

                if isExpanded {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Text("Az")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(palette.secondaryText)

                            ForEach(0..<4, id: \.self) { level in
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(legendColor(for: level))
                                    .frame(width: 30, height: 16)
                            }

                            Text("Çok")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(palette.secondaryText)
                        }

                        if hasActivity {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(data.selectedDayText)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(palette.primaryText)

                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(Color.accentColor)

                                    Text("Bu görünüm son 4 haftadaki tamamlanan görev yoğunluğunu gösterir")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(palette.secondaryText)
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(fallbackText)
                                    .font(.system(size: 14))
                                    .foregroundStyle(palette.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)

                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(Color.accentColor)

                                    Text("Görev tamamladıkça burası dolacak")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.accentColor)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(
                                    Capsule()
                                        .fill(Color.accentColor.opacity(0.14))
                                )
                            }
                        }
                    }
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
                }
            }
            .padding(18)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.985)
        .offset(y: isVisible ? 0 : 12)
        .animation(.spring(response: 0.48, dampingFraction: 0.86), value: isVisible)
        .animateWhenVisible($isVisible)
    }

    func fillColor(for cell: InsightsHeatmapCell) -> Color {
        switch cell.level {
        case 0:
            return palette.secondaryCardFill
        case 1:
            return Color.accentColor.opacity(appTheme == AppTheme.light.rawValue ? 0.20 : 0.28)
        case 2:
            return Color.accentColor.opacity(appTheme == AppTheme.light.rawValue ? 0.40 : 0.55)
        default:
            return Color.accentColor
        }
    }

    func legendColor(for level: Int) -> Color {
        switch level {
        case 0:
            return palette.secondaryCardFill
        case 1:
            return Color.accentColor.opacity(appTheme == AppTheme.light.rawValue ? 0.20 : 0.28)
        case 2:
            return Color.accentColor.opacity(appTheme == AppTheme.light.rawValue ? 0.40 : 0.55)
        default:
            return Color.accentColor
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }
}
