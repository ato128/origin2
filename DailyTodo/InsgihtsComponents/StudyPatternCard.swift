//
//  StudyPatternCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 4.04.2026.
//

import SwiftUI

struct StudyPatternCard: View {
    let data: StudyPatternData

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerSection

            HStack(spacing: 12) {
                patternBox(title: "En iyi gün", value: data.bestDayText, accent: .blue)
                patternBox(title: "En iyi zaman", value: data.bestTimeText, accent: .purple)
                patternBox(title: "Ortalama", value: data.avgFocusText, accent: .orange)
            }

            insightStrip
        }
        .padding(18)
        .background(cardBackground)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(data.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            Text(data.subtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.secondaryText)
        }
    }

    private var insightStrip: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.14))
                    .frame(width: 30, height: 30)

                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }

            Text(data.patternInsightText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.accentColor.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.14), lineWidth: 1)
                )
        )
    }

    private func patternBox(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(palette.secondaryText)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Capsule()
                .fill(accent.opacity(0.85))
                .frame(width: 26, height: 4)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(palette.secondaryCardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(palette.cardStroke)
            )
    }
}
