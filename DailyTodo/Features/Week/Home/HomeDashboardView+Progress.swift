//
//  HomeDashboardView+Progress.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI
import SwiftData
import Combine

extension HomeDashboardView {
    var todayProgressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Today Progress")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(palette.primaryText)

                Spacer()

                Text("\(completedTodayCount)/\(totalTodayTaskCount)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(palette.primaryText)
            }

            ProgressView(value: todayProgressValue)
                .tint(.accentColor)
                .scaleEffect(y: 1.7)

            HStack(spacing: 8) {
                miniBadge(
                    icon: "flame.fill",
                    text: "\(streakCount) gün seri",
                    tint: .orange
                )

                miniBadge(
                    icon: "checkmark.circle.fill",
                    text: "\(completedTodayCount) bugün tamamlandı",
                    tint: .green
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroCardBackground)
    }

    var todayTasksCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Today Tasks")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(palette.primaryText)

                Spacer()

                Text("\(todayTasks.prefix(3).count) gösteriliyor")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
            }

            if todayTasks.isEmpty {
                Text("Bugün için aktif task yok.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
            } else {
                ForEach(Array(todayTasks.prefix(3))) { task in
                    HStack(spacing: 10) {
                        Image(systemName: "circle")
                            .foregroundStyle(palette.secondaryText)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(palette.primaryText)
                                .lineLimit(1)

                            if let due = task.dueDate {
                                Text(due, style: .time)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(palette.secondaryText)
                            }
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(palette.secondaryCardFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(palette.cardStroke, lineWidth: 1)
                    )
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(secondaryCardBackground)
    }

    func miniBadge(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)

            Text(text)
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(tint.opacity(0.14))
        )
        .foregroundStyle(tint)
    }
}
