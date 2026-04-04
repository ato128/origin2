//
//  StudyInsightsUnlockedCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 4.04.2026.
//

import SwiftUI

struct StudyInsightsUnlockCard: View {
    let data: StudyUnlockPromptData
    let onTap: (SmartSuggestionAction) -> Void

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(data.title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            Text(data.subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)

            HStack {
                Text(data.progressText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.accentColor)

                Spacer()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(palette.secondaryCardFill)
                        .frame(height: 6)

                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: max(14, geo.size.width * max(data.progress, 0.08)), height: 6)
                }
            }
            .frame(height: 6)

            Button {
                onTap(data.action)
            } label: {
                HStack {
                    Text(data.actionTitle)
                        .font(.system(size: 14, weight: .bold, design: .rounded))

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.accentColor)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(palette.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(palette.cardStroke)
                )
        )
    }
}
