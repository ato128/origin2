//
//  OverViewCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI

struct OverviewCard: View {
    let data: OverviewData

    @State private var isVisible = false
    @State private var animatedProgress: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            HStack {
                Text("Overview")
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                Text(data.statusText)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.15))
                    .foregroundStyle(Color.orange)
                    .clipShape(Capsule())
            }

            HStack(alignment: .lastTextBaseline, spacing: 8) {

                CountUpText(
                    value: data.progress * 100,
                    duration: 0.9,
                    trigger: isVisible,
                    formatter: { "%\(Int($0))" }
                )
                .font(.system(size: 36, weight: .bold, design: .rounded))

                Text("tamamlanma")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {

                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.95),
                                    Color.accentColor
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(20, geo.size.width * animatedProgress), height: 8)
                        .shadow(color: Color.accentColor.opacity(0.20), radius: 8)
                        .overlay(alignment: .trailing) {
                            Circle()
                                .fill(Color.white.opacity(0.22))
                                .frame(width: 10, height: 10)
                                .blur(radius: 2)
                                .opacity(animatedProgress > 0.02 ? 1 : 0)
                        }
                }
            }
            .frame(height: 8)

            HStack(spacing: 10) {

                pill(text: data.streakText, icon: "flame.fill")

                pill(text: data.completedText, icon: "checkmark.circle.fill")
            }

            Text(data.subtitle)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(cardBackground)
        .animateWhenVisible($isVisible)
        .onChange(of: isVisible) { _, newValue in
            guard newValue else { return }

            withAnimation(.spring(response: 0.9, dampingFraction: 0.85)) {
                animatedProgress = data.progress
            }
        }
    }

    func pill(text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 12, weight: .semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.08))
            )
    }
}
