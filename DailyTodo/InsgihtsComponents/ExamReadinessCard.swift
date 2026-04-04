//
//  ExamReadinessCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 4.04.2026.
//

import SwiftUI

struct ExamReadinessCard: View {
    let data: ExamReadinessData
    let onTap: (SmartSuggestionAction) -> Void

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
                        .font(.system(size: 17, weight: .bold))

                    Text(data.emptySubtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            } else {
                VStack(spacing: 12) {
                    ForEach(data.rows) { row in
                        Button {
                            onTap(row.action)
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(row.examTitle)
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(.primary)
                                            .multilineTextAlignment(.leading)

                                        Text(row.countdownText)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(row.accent)
                                    }

                                    Spacer()

                                    Text(row.readinessText)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(row.accent)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(row.accent.opacity(0.12))
                                        )
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    ProgressView(value: row.readinessProgress)
                                        .tint(row.accent)

                                    HStack {
                                        Text(row.studyMinutesText)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(.secondary)

                                        Spacer()

                                        Text("%\(Int(row.readinessProgress * 100))")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                    }
                                }

                                HStack(spacing: 8) {
                                    miniPill(
                                        text: row.countdownText,
                                        tint: row.accent
                                    )

                                    miniPill(
                                        text: row.studyMinutesText,
                                        tint: .blue
                                    )
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.white.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .stroke(row.accent.opacity(0.14), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private func miniPill(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
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
