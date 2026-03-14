//
//  CrewDetailView+ActivitySection.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 14.03.2026.
//

import SwiftUI
import SwiftData

extension CrewDetailView {
    func activityIcon(for text: String) -> String {
        let lower = text.lowercased()

        if lower.contains("comment") {
            return "text.bubble.fill"
        } else if lower.contains("vote") {
            return "hand.thumbsup.fill"
        } else if lower.contains("complete") || lower.contains("done") {
            return "checkmark.circle.fill"
        } else if lower.contains("status") {
            return "arrow.triangle.2.circlepath.circle.fill"
        } else if lower.contains("create") {
            return "plus.circle.fill"
        } else if lower.contains("reaction") {
            return "face.smiling.fill"
        } else {
            return "bolt.fill"
        }
    }

    func activityRow(_ item: CrewActivity, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(hexColor(crew.colorHex).opacity(0.16))
                        .frame(width: 34, height: 34)

                    Image(systemName: activityIcon(for: item.actionText))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(hexColor(crew.colorHex))
                }

                if !isLast {
                    Rectangle()
                        .fill(palette.secondaryCardFill)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 6)
                }
            }
            .frame(width: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.memberName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(item.actionText)
                    .font(.caption)
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(2)

                Text(item.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    func activitySection(_ crewActivities: [CrewActivity]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Activity")
                    .font(.headline)

                Text("Recent team updates")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(crewActivities.count)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.12))
                    )
                    .foregroundStyle(.secondary)
            }

            if crewActivities.isEmpty {
                emptyMiniState(text: "No activity yet")
            } else {
                let topActivities = Array(crewActivities.prefix(5))
                ForEach(Array(topActivities.enumerated()), id: \.element.id) { index, item in
                    activityRow(item, isLast: index == topActivities.count - 1)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }
}
