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
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hızlı İşlemler")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                Text("Öğrenci akışın için kısa yollar")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
            }

            HStack(spacing: 10) {
                quickActionButton(
                    title: "Görev",
                    subtitle: "Yeni görev",
                    systemImage: "checklist",
                    tint: .blue,
                    isHighlighted: true
                ) {
                    onAddTask()
                }

                quickActionButton(
                    title: "Sınav",
                    subtitle: "Planla",
                    systemImage: "doc.text.fill",
                    tint: .orange
                ) {
                    onAddTask()
                }

                quickActionButton(
                    title: "Hafta",
                    subtitle: "Ekle",
                    systemImage: "calendar.badge.plus",
                    tint: .purple
                ) {
                    onOpenWeek()
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(secondaryCardBackground)
    }

    func quickActionButton(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        isHighlighted: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint.opacity(isHighlighted ? 0.18 : 0.14))
                        .frame(width: 40, height: 40)

                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        isHighlighted
                        ? tint.opacity(0.08)
                        : palette.secondaryCardFill
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isHighlighted
                        ? tint.opacity(0.26)
                        : palette.cardStroke,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isHighlighted ? tint.opacity(0.08) : .clear,
                radius: isHighlighted ? 8 : 0,
                y: isHighlighted ? 3 : 0
            )
        }
        .buttonStyle(.plain)
    }
}
