//
//  InsightsPlusCoachCardV2.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//

import SwiftUI

struct InsightsPlusCoachCardV2: View {
    let data: InsightsPlusCoachCardData
    let action: (SmartSuggestionAction) -> Void
    let onTap: () -> Void

    private var secondaryAccent: Color {
        Color(red: 0.03, green: 0.18, blue: 0.36)
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 14) {
                premiumIcon

                VStack(alignment: .leading, spacing: 6) {
                    Text("Insights+ Coach")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(data.tint.opacity(0.98))
                        .tracking(0.7)

                    Text(data.title)
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(data.subtitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.70))
                        .lineLimit(2)

                    progressHint
                }

                Spacer()

                Button {
                    action(data.action)
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.08), in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.07), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(premiumBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var premiumIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .frame(width: 66, height: 66)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            data.tint.opacity(0.42),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 42
                    )
                )
                .frame(width: 58, height: 58)

            Image(systemName: data.symbol)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))
                .shadow(color: data.tint.opacity(0.24), radius: 8)
        }
    }

    private var progressHint: some View {
        HStack(spacing: 5) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index < 4 ? data.tint.opacity(0.95) : Color.white.opacity(0.18))
                    .frame(width: 5, height: 5)
            }

            Text(data.hint)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.56))
                .padding(.leading, 4)
        }
    }

    private var premiumBackground: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        data.tint.opacity(0.34),
                        data.tint.opacity(0.16),
                        secondaryAccent.opacity(0.62),
                        Color(red: 0.035, green: 0.035, blue: 0.070)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                data.tint.opacity(0.24),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: 150
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.075),
                                Color.clear,
                                Color.black.opacity(0.18)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
    }
}
