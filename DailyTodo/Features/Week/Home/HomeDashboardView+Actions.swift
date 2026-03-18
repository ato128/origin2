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

                // ADD TASK
                quickActionButton(
                    title: "Add Task",
                    systemImage: "plus.circle.fill",
                    isHighlighted: guide.currentStep == .homeTasksPrompt
                ) {
                    onAddTask()
                }

                // WEEK
                quickActionButton(
                    title: "Week",
                    systemImage: "calendar",
                    isHighlighted: guide.currentStep == .weekPrompt
                ) {
                    onOpenWeek()

                    if guide.currentStep == .weekPrompt {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            guide.next()
                        }
                    }
                }

                // INSIGHTS
                quickActionButton(
                    title: "Insights",
                    systemImage: "chart.bar.fill",
                    isHighlighted: false
                ) {
                    onOpenInsights()
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(secondaryCardBackground)
    }

    func quickActionButton(
        title: String,
        systemImage: String,
        isHighlighted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {
            VStack(spacing: 12) {

                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(isHighlighted ? .white : Color.accentColor)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.primaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        isHighlighted
                        ? Color.accentColor.opacity(0.22)
                        : palette.secondaryCardFill
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isHighlighted
                        ? Color.accentColor.opacity(0.95)
                        : palette.cardStroke,
                        lineWidth: isHighlighted ? 2 : 1
                    )
            )
            .shadow(
                color: isHighlighted ? Color.accentColor.opacity(0.28) : .clear,
                radius: isHighlighted ? 14 : 0
            )
            .scaleEffect(isHighlighted ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

