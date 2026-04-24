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

    private var accent: Color { data.accent }

    private var secondaryAccent: Color {
        Color(red: 0.22, green: 0.08, blue: 0.20)
    }

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

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                headerRow

                Text(data.subtitle)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)

                streakBeam

                HStack(spacing: 8) {
                    ForEach(data.traits.prefix(3), id: \.self) { trait in
                        Text(trait)
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.84))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.62))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.055), in: Circle())
                }

                if isExpanded {
                    expandedStats
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                premiumInsightsBackground(
                    accent: accent,
                    secondaryAccent: secondaryAccent,
                    strength: min(0.92, 0.54 + Double(streakCount) * 0.035),
                    cornerRadius: 30
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var headerRow: some View {
        HStack(alignment: .top) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    accent.opacity(0.30),
                                    Color.white.opacity(0.05),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 2,
                                endRadius: 26
                            )
                        )
                        .frame(width: 48, height: 48)

                    Circle()
                        .fill(Color.white.opacity(0.055))
                        .frame(width: 42, height: 42)

                    Image(systemName: archetypeIcon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white.opacity(0.94))
                        .shadow(color: accent.opacity(0.28), radius: 6)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Identity")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(accent.opacity(0.98))
                        .tracking(0.8)

                    Text(data.title)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 54, height: 54)

                VStack(spacing: 1) {
                    Text("Lv")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.52))

                    Text("\(data.level)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
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
                                accent.opacity(0.98),
                                Color.white.opacity(0.88)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(14, width * data.progress), height: 8)
                    .shadow(color: accent.opacity(0.18), radius: 8)
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
                    .fill(item.accent.opacity(0.16))
                    .frame(width: 34, height: 34)

                Image(systemName: icon(for: index))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.84))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(shortLabel(item.label))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.56))
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.045), lineWidth: 1)
                )
        )
    }

    private func premiumInsightsBackground(
        accent: Color,
        secondaryAccent: Color,
        strength: Double,
        cornerRadius: CGFloat
    ) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.32 + strength * 0.18),
                        accent.opacity(0.20),
                        secondaryAccent.opacity(0.70),
                        Color(red: 0.035, green: 0.035, blue: 0.070)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(0.20 + strength * 0.12),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: 170
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                secondaryAccent.opacity(0.18 + strength * 0.12),
                                Color.clear
                            ],
                            center: .bottomLeading,
                            startRadius: 10,
                            endRadius: 170
                        )
                    )
                    .blur(radius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.clear,
                                Color.black.opacity(0.18)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
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
