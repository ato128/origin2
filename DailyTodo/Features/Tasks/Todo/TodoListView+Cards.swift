//
//  TodoListView+Cards.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI

extension TodoListView {
    func previewStatCard(value: String, title: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(palette.primaryText)

            Text(title)
                .font(.caption)
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.secondaryCardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardStroke.opacity(0.7), lineWidth: 1)
                )
        )
    }
    
   func rankBadge(for crew: Crew) -> some View {
        let sorted = crews.sorted { $0.totalFocusMinutes > $1.totalFocusMinutes }
        let rank = (sorted.firstIndex(where: { $0.id == crew.id }) ?? 999) + 1

        let color: Color = {
            switch rank {
            case 1: return .yellow
            case 2: return .gray
            case 3: return .orange
            default: return .secondary
            }
        }()

        return ZStack {
            Circle()
                .fill(color.opacity(0.16))
                .frame(width: 34, height: 34)

            Text("\(rank)")
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
        }
    }

    func socialActionRow(title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .frame(width: 26)
                .foregroundStyle(palette.primaryText)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.primaryText)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryText)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.secondaryCardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardStroke.opacity(0.7), lineWidth: 1)
                )
        )
    }

     var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }

}
