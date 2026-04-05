//
//  StudyInsightsQuickActionsRow.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 4.04.2026.
//

import SwiftUI

struct StudyInsightsQuickActionsRow: View {
    let actions: [StudyQuickActionData]
    let onTap: (SmartSuggestionAction) -> Void

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    var body: some View {
        HStack(spacing: 10) {
            ForEach(actions.prefix(3)) { action in
                Button {
                    onTap(action.action)
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            iconTile(for: action)

                            Spacer(minLength: 0)

                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(action.tint.opacity(0.70))
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(Color.white.opacity(0.03))
                                )
                        }

                        Spacer(minLength: 0)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(action.title)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(palette.primaryText)
                                .lineLimit(2)
                                .minimumScaleFactor(0.82)

                            Text(subtitle(for: action))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(palette.secondaryText)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
                    .padding(14)
                    .background(cardBackground(for: action))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(action.tint.opacity(0.09), lineWidth: 1)
                    )
                    .shadow(color: action.tint.opacity(0.05), radius: 10, y: 5)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func iconTile(for action: StudyQuickActionData) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            action.tint.opacity(0.16),
                            action.tint.opacity(0.07)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 46, height: 46)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(action.tint.opacity(0.12), lineWidth: 1)
                )

            Image(systemName: action.icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(action.tint)
        }
    }

    private func cardBackground(for action: StudyQuickActionData) -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                action.tint.opacity(0.05),
                                Color.clear,
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
    }

    private func subtitle(for action: StudyQuickActionData) -> String {
        switch action.action {
        case .openWeek:
            return "programı aç"
        case .openFocus:
            return "odak başlat"
        case .openTasks:
            return "görevleri gör"
        case .none:
            return "hızlı geçiş"
        }
    }
}
