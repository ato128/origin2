//
//  InsightsPlusWeekSignalCardV2.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//

import SwiftUI

struct InsightsPlusWeeklySignalCardV2: View {
    let data: InsightsPlusWeeklySignalCardData
    let action: (SmartSuggestionAction) -> Void
    let onTap: () -> Void

    private let labels = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]

    private var secondaryAccent: Color {
        Color(red: 0.03, green: 0.18, blue: 0.36)
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                header
                signalBars
                statRow
                actionRow
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

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Weekly Signal")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(data.tint.opacity(0.98))
                    .tracking(0.7)

                Text(data.trendText)
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.055))
                    .frame(width: 42, height: 42)

                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white.opacity(0.86))
                    .shadow(color: data.tint.opacity(0.24), radius: 6)
            }
        }
    }

    private var signalBars: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(0..<min(data.values.count, labels.count), id: \.self) { index in
                let isHighlighted = index == data.highlightIndex
                let value = max(0.12, min(data.values[index], 1.0))

                VStack(spacing: 8) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: isHighlighted
                                ? [Color.white.opacity(0.96), data.tint.opacity(0.95)]
                                : [Color.white.opacity(0.22), data.tint.opacity(0.22)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(
                            width: isHighlighted ? 38 : 28,
                            height: max(12, value * 58)
                        )
                        .shadow(
                            color: isHighlighted ? data.tint.opacity(0.18) : .clear,
                            radius: isHighlighted ? 9 : 0,
                            y: isHighlighted ? 3 : 0
                        )

                    Text(labels[index])
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(isHighlighted ? .white.opacity(0.86) : .white.opacity(0.56))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 104)
    }

    private var statRow: some View {
        HStack(spacing: 8) {
            statPill("Strongest \(data.strongestDay)")
            statPill("Weakest \(data.weakestDay)")
        }
    }

    private var actionRow: some View {
        HStack {
            Button {
                action(data.action)
            } label: {
                Text(data.actionTitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.52))
        }
    }

    private func statPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.82))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.08), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
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
