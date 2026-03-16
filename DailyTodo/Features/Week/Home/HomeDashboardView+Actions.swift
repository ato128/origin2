//
//  HomeDashboardView+Actions.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI
import SwiftData
import Combine

extension HomeDashboardView {
    var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quick Actions")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(palette.primaryText)

            HStack(spacing: 12) {
                quickActionButton(
                    title: "Add Task",
                    systemImage: "plus.circle.fill",
                    action: onAddTask
                )

                quickActionButton(
                    title: "Week",
                    systemImage: "calendar",
                    action: onOpenWeek
                )

                quickActionButton(
                    title: "Insights",
                    systemImage: "chart.bar.fill",
                    action: onOpenInsights
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(secondaryCardBackground)
    }

    func quickActionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(palette.secondaryCardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
