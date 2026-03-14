//
//  SmartTaskSuggestionCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 14.03.2026.
//

import SwiftUI

struct SmartTaskSuggestionCard: View {
    let suggestion: SmartTaskSuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(suggestion.title)
                .font(.headline)

            Text(suggestion.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}
