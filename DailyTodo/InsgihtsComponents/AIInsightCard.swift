//
//  AIInsightCard.swift
//  DailyTodo
//

import SwiftUI

struct AIInsightCard: View {
    let item: AIInsightItem

    @State private var appeared = false
    @State private var expanded = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                expanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Always-visible header row
                HStack(alignment: .center, spacing: 14) {
                    iconView
                    Text(item.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                .padding(16)

                // Expandable body
                if expanded {
                    Text(item.body)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(.spring(response: 0.44, dampingFraction: 0.82), value: appeared)
        .onAppear { appeared = true }
    }

    private var accentColor: Color {
        Color(arenaHex: item.accent)
    }

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(0.15))
                .frame(width: 40, height: 40)
            Image(systemName: item.icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(accentColor)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(accentColor.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(accentColor.opacity(0.18), lineWidth: 1)
            )
    }
}
