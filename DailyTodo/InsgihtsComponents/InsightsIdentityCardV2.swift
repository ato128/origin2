//
//  InsightsIdentityCardV2.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//

import SwiftUI

struct InsightsIdentityCardV2: View {
    let data: InsightsIdentityData
    let stats: [InsightsMiniStatData]
    let streakCount: Int
    let isExpanded: Bool
    let onTap: () -> Void

    private var archetypeIcon: String {
        switch data.title.lowercased() {
        case let t where t.contains("deep"):
            return "circle.hexagongrid.fill"
        case let t where t.contains("consistency"):
            return "leaf.fill"
        case let t where t.contains("night"):
            return "moon.stars.fill"
        default:
            return "bolt.fill"
        }
    }

    private var streakGlowOpacity: Double {
        min(0.30, 0.08 + (Double(streakCount) * 0.025))
    }

    private var streakScale: CGFloat {
        min(1.18, 1.0 + (CGFloat(streakCount) * 0.025))
    }

    var body: some View {
        Button(action: onTap) {
            InsightsGlassCard(
                cornerRadius: 30,
                tint: data.accent,
                glowOpacity: 0.15,
                fillOpacity: 0.12,
                strokeOpacity: 0.09
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    headerRow

                    Text(data.subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(2)

                    streakBeam

                    HStack(spacing: 8) {
                        ForEach(data.traits.prefix(3), id: \.self) { trait in
                            Text(trait)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.84))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.white.opacity(0.08), in: Capsule())
                        }

                        Spacer(minLength: 0)

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.58))
                            .frame(width: 26, height: 26)
                            .background(Color.white.opacity(0.05), in: Circle())
                    }

                    if isExpanded {
                        expandedStats
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var headerRow: some View {
        HStack(alignment: .top) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(data.accent.opacity(0.16))
                        .frame(width: 42, height: 42)

                    if streakCount > 0 {
                        Circle()
                            .fill(data.accent.opacity(streakGlowOpacity))
                            .frame(width: 42, height: 42)
                            .blur(radius: 8)
                            .scaleEffect(streakScale)
                    }

                    Image(systemName: archetypeIcon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Identity")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.56))

                    Text(data.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 50, height: 50)

                VStack(spacing: 1) {
                    Text("Lv")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.50))

                    Text("\(data.level)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private var streakBeam: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 8)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                data.accent.opacity(0.98),
                                Color.white.opacity(0.92)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(14, width * data.progress), height: 8)

                if streakCount > 0 {
                    Circle()
                        .fill(data.accent.opacity(0.55))
                        .frame(width: 14, height: 14)
                        .blur(radius: 5)
                        .offset(x: max(0, width * data.progress - 7))
                }
            }
        }
        .frame(height: 8)
    }

    private var expandedStats: some View {
        VStack(spacing: 10) {
            Divider()
                .overlay(Color.white.opacity(0.06))

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(Array(stats.enumerated()), id: \.offset) { index, item in
                    statTile(item: item, index: index)
                }
            }
        }
    }

    private func statTile(item: InsightsMiniStatData, index: Int) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(item.accent.opacity(0.14))
                    .frame(width: 34, height: 34)

                Image(systemName: icon(for: index))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(shortLabel(item.label))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.56))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        )
    }

    private func icon(for index: Int) -> String {
        switch index {
        case 0: return "flame.fill"
        case 1: return "timer"
        case 2: return "checkmark.circle.fill"
        default: return "waveform.path"
        }
    }

    private func shortLabel(_ label: String) -> String {
        let lowered = label.lowercased()

        if lowered.contains("seri") || lowered.contains("streak") {
            return "Streak"
        } else if lowered.contains("focus") {
            return "Focus"
        } else if lowered.contains("tamam") || lowered.contains("done") || lowered.contains("completed") {
            return "Done"
        } else {
            return "Best Day"
        }
    }
}
