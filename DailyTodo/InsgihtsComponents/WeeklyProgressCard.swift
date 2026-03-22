//
//  WeeklyProgressCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI

struct WeeklyProgressCard: View {
    let data: WeeklyProgressData

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    @State private var isVisible = false
    @State private var isExpanded = false

    private var totalCount: Int {
        data.values.reduce(0, +)
    }

    private var bestDayLabel: String {
        guard let index = data.highlightIndex,
              index >= 0,
              index < data.labels.count else {
            return "-"
        }
        return data.labels[index]
    }

    private var bestDayValue: Int {
        guard let index = data.highlightIndex,
              index >= 0,
              index < data.values.count else {
            return 0
        }
        return data.values[index]
    }

    private var hasAnyProgress: Bool {
        totalCount > 0
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                isExpanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weekly Progress")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.primaryText)

                        Text(hasAnyProgress ? "Son 7 gündeki üretim ritmin" : "Haftalık ritmin burada görünecek")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.secondaryText)
                    }

                    Spacer()

                    HStack(spacing: 10) {
                        Text("7 gün")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.secondaryText)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(palette.secondaryText)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                }

                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(Array(data.values.enumerated()), id: \.offset) { index, value in
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(
                                    index == data.highlightIndex
                                    ? Color.accentColor
                                    : palette.secondaryCardFill
                                )
                                .frame(height: isVisible ? max(14, CGFloat(value) * 30) : 10)
                                .scaleEffect(y: isVisible ? 1 : 0.88, anchor: .bottom)
                                .shadow(
                                    color: index == data.highlightIndex
                                    ? Color.accentColor.opacity(isVisible ? 0.18 : 0)
                                    : .clear,
                                    radius: 6
                                )
                                .animation(
                                    .spring(response: 0.55, dampingFraction: 0.82)
                                        .delay(Double(index) * 0.04),
                                    value: isVisible
                                )

                            Text(data.labels[index])
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(palette.secondaryText)

                            CountUpText(
                                value: Double(value),
                                duration: 0.7,
                                trigger: isVisible,
                                formatter: { "\(Int($0))" }
                            )
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(palette.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 118, alignment: .bottom)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            miniInfoPill(
                                icon: "chart.bar.fill",
                                text: "Toplam \(totalCount)"
                            )

                            miniInfoPill(
                                icon: "star.fill",
                                text: "\(bestDayLabel) • \(bestDayValue)"
                            )
                        }

                        Text(data.summaryText)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(palette.primaryText)

                        if hasAnyProgress {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(Color.accentColor)

                                Text("En iyi gününü tekrar etmek için benzer saatlerde görev planlayabilirsin")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(palette.secondaryText)
                            }
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(Color.accentColor)

                                Text("İlk tamamlanan görevlerin burada haftalık grafik olarak görünmeye başlayacak")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(palette.secondaryText)
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

    private func miniInfoPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(palette.secondaryText)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(palette.secondaryCardFill)
        )
        .overlay(
            Capsule()
                .stroke(palette.cardStroke, lineWidth: 1)
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }
}
