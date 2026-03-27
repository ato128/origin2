//
//  WeeklyProgressCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI

struct WeeklyProgressCard: View {
    let data: WeeklyProgressData

    @Environment(\.locale) private var locale
    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    @State private var isVisible = false
    @State private var isExpanded = false

    private var totalCount: Int { data.values.reduce(0, +) }

    private var bestDayLabel: String {
        guard let index = data.highlightIndex, index >= 0, index < data.labels.count else { return "-" }
        return data.labels[index]
    }

    private var bestDayValue: Int {
        guard let index = data.highlightIndex, index >= 0, index < data.values.count else { return 0 }
        return data.values[index]
    }

    private var hasAnyProgress: Bool { totalCount > 0 }
    private var maxValue: Int { max(data.values.max() ?? 0, 1) }

    private var headerSubtitle: String {
        hasAnyProgress
        ? tr("insights_weekly_progress_subtitle_active")
        : tr("insights_weekly_progress_subtitle_empty")
    }

    private var daysLabel: String { tr("insights_weekly_progress_days_label") }

    private var totalPillText: String {
        tr("insights_weekly_progress_total_format ")
            .replacingOccurrences(of: "%lld", with: "\(totalCount)")
    }

    private var bestDayPillText: String {
        tr("insights_weekly_progress_best_day_format ")
            .replacingOccurrences(of: "%@", with: bestDayLabel)
            .replacingOccurrences(of: "%lld", with: "\(bestDayValue)")
    }

    private var repeatBestDayHint: String { tr("insights_weekly_progress_repeat_hint") }
    private var firstTasksHint: String { tr("insights_weekly_progress_first_tasks_hint") }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                isExpanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                chartSection

                if isExpanded {
                    expandedSection
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.985)
        .offset(y: isVisible ? 0 : 12)
        .animation(.spring(response: 0.48, dampingFraction: 0.86), value: isVisible)
        .animateWhenVisible($isVisible)
    }

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("insights_weekly_progress_title"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(headerSubtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Text(daysLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(palette.secondaryText)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
        }
    }

    private var chartSection: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(data.values.enumerated()), id: \.offset) { index, value in
                VStack(spacing: 6) {
                    Spacer(minLength: 0)

                    CountUpText(
                        value: Double(value),
                        duration: 0.7,
                        trigger: isVisible,
                        formatter: { "\(Int($0))" }
                    )
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(index == data.highlightIndex ? Color.accentColor : palette.secondaryCardFill)
                        .frame(height: barHeight(for: value))
                        .scaleEffect(y: isVisible ? 1 : 0.88, anchor: .bottom)
                        .shadow(
                            color: index == data.highlightIndex
                                ? Color.accentColor.opacity(isVisible ? 0.18 : 0) : .clear,
                            radius: 6
                        )
                        .animation(
                            .spring(response: 0.55, dampingFraction: 0.82).delay(Double(index) * 0.04),
                            value: isVisible
                        )

                    Text(data.labels[index])
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 126, alignment: .bottom)
    }

    private var expandedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .vertical) {
                HStack(spacing: 10) {
                    miniInfoPill(icon: "chart.bar.fill", text: totalPillText)
                    miniInfoPill(icon: "star.fill", text: bestDayPillText)
                }
                VStack(alignment: .leading, spacing: 8) {
                    miniInfoPill(icon: "chart.bar.fill", text: totalPillText)
                    miniInfoPill(icon: "star.fill", text: bestDayPillText)
                }
            }

            Text(data.summaryText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 1)
                Text(hasAnyProgress ? repeatBestDayHint : firstTasksHint)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func barHeight(for value: Int) -> CGFloat {
        let minHeight: CGFloat = 16
        let maxHeight: CGFloat = 62
        let normalized = CGFloat(value) / CGFloat(maxValue)
        let height = minHeight + ((maxHeight - minHeight) * normalized)
        return isVisible ? height : 10
    }

    private func miniInfoPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text).lineLimit(1).minimumScaleFactor(0.75)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(palette.secondaryText)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(palette.secondaryCardFill))
        .overlay(Capsule().stroke(palette.cardStroke, lineWidth: 1))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(palette.cardFill)
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(palette.cardStroke, lineWidth: 1))
    }
}
