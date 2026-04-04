//
//  CourseBalanceCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 4.04.2026.
//

import SwiftUI

struct CourseBalanceCard: View {
    let data: CourseBalanceData

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(data.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text(data.subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if data.rows.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(data.emptyTitle)
                        .font(.system(size: 18, weight: .bold))
                    Text("Görev ve çalışma verisi geldikçe burada hangi derse az ya da çok yüklendiğin netleşecek.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(data.rows) { row in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(row.courseName)
                                    .font(.system(size: 17, weight: .bold))

                                Spacer()

                                Text(row.statusText)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(row.accent)
                            }

                            ProgressView(value: row.progress)
                                .tint(row.accent)

                            HStack {
                                Text(row.taskText)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Text(row.minutesText)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                                )
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}
