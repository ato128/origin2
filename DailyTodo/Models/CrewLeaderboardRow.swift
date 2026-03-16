//
//  CrewLeaderboardView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI

struct CrewLeaderboardRow: View {
    let rank: Int
    let name: String
    let minutes: Int
    let palette: ThemePalette

    @State private var championPulse = false

    private var isChampion: Bool {
        rank == 1
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .secondary
        }
    }

    private func focusTimeText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60

        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(rankColor.opacity(isChampion ? 0.22 : 0.14))
                    .frame(width: 42, height: 42)
                    .shadow(
                        color: isChampion
                        ? rankColor.opacity(championPulse ? 0.16 : 0.06)
                        : .clear,
                        radius: isChampion ? (championPulse ? 8 : 4) : 0
                    )

                Text("\(rank)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(rankColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.primaryText)

                    if isChampion {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                            .scaleEffect(championPulse ? 1.03 : 1.0)
                    }
                }

                Text(focusTimeText(minutes))
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }

            Spacer()

            if isChampion {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .scaleEffect(championPulse ? 1.04 : 1.0)

                    Text("Crew Champion")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.yellow)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.yellow.opacity(0.14))
                )
            } else {
                Image(systemName: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.8))
            }
        }
        .padding(12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(palette.secondaryCardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                isChampion
                                ? Color.yellow.opacity(0.22)
                                : palette.cardStroke.opacity(0.7),
                                lineWidth: 1
                            )
                    )

                if isChampion {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.yellow.opacity(championPulse ? 0.14 : 0.06),
                                    Color.clear
                                ],
                                center: .leading,
                                startRadius: 10,
                                endRadius: 180
                            )
                        )
                        .blur(radius: 6)
                }
            }
        )
        .shadow(
            color: isChampion
            ? Color.yellow.opacity(championPulse ? 0.18 : 0.08)
            : .clear,
            radius: isChampion ? 10 : 0,
            y: 4
        )
        .onAppear {
            guard isChampion else { return }

            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                championPulse = true
            }
        }
        .compositingGroup()
    }
}
