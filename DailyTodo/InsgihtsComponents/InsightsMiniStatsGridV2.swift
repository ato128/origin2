//
//  InsightsMiniStatsGridV2.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//

import SwiftUI

struct InsightsMiniStatsGridV2: View {
    let items: [InsightsMiniStatData]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                compactTile(item, index: index)
            }
        }
    }

    private func compactTile(_ item: InsightsMiniStatData, index: Int) -> some View {
        InsightsGlassCard(
            cornerRadius: 24,
            tint: item.accent,
            glowOpacity: 0.10,
            fillOpacity: 0.08,
            strokeOpacity: 0.07
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: tileIcon(index: index))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.70))

                    Spacer()
                }

                Spacer(minLength: 0)

                Text(item.value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(shortLabel(for: item.label))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 76, alignment: .topLeading)
        }
    }

    private func tileIcon(index: Int) -> String {
        switch index {
        case 0: return "flame.fill"
        case 1: return "timer"
        case 2: return "checkmark.circle.fill"
        default: return "waveform.path"
        }
    }

    private func shortLabel(for label: String) -> String {
        let lowered = label.lowercased()

        if lowered.contains("seri") || lowered.contains("streak") {
            return "Streak"
        } else if lowered.contains("focus") {
            return "Focus"
        } else if lowered.contains("tamam") || lowered.contains("completed") {
            return "Done"
        } else if lowered.contains("gün") || lowered.contains("day") {
            return "Best Day"
        } else {
            return label
        }
    }
}
