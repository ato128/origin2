//
//  HomeDashboardView+Cards.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI

extension HomeDashboardView {
    var heroCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
            .shadow(color: palette.cardShadow, radius: 14, y: 8)
    }

    var secondaryCardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }

    var cardBackground: some View {
        secondaryCardBackground
    }

    var themedCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
            .shadow(color: palette.cardShadow, radius: 14, y: 8)
    }
}
