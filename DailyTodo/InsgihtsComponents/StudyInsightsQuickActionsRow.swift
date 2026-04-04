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
        HStack(spacing: 12) {
            ForEach(actions.prefix(3)) { action in
                Button {
                    onTap(action.action)
                } label: {
                    VStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(action.tint.opacity(0.10))
                                .frame(width: 46, height: 46)

                            Image(systemName: action.icon)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(action.tint)
                        }

                        Text(action.title)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(action.tint)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 98)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(palette.cardFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(action.tint.opacity(0.10), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
