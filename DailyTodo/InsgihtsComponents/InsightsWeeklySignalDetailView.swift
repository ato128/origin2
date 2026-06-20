//
//  InsightsWeeklySignalDetailView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//

import SwiftUI

struct InsightsWeeklySignalDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let data: InsightsWeeklySignalDetailData
    let onOpenWeek: () -> Void
    let onOpenFocus: () -> Void

    @State private var animateBars = false
    @State private var animateLine = false

    private var accent: Color {
        Color(arenaHex: AppArenaPalette.cyan)
    }

    private var secondaryAccent: Color {
        Color(arenaHex: AppArenaPalette.blue)
    }

    private var warmAccent: Color {
        Color(arenaHex: AppArenaPalette.gold)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ArenaBackground(
                primaryGlow: accent,
                secondaryGlow: Color(arenaHex: AppArenaPalette.purple),
                warmGlow: warmAccent,
                intensity: 0.92
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    heroCard
                    weeklyChartCard
                    dailyBreakdownCard
                    actionCard
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 26)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.spring(response: 0.72, dampingFraction: 0.84)) {
                animateBars = true
            }

            withAnimation(.easeOut(duration: 0.8).delay(0.08)) {
                animateLine = true
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(accent)
                        .frame(width: 20, height: 1)

                    Text("WEEKLY SIGNAL")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(2.3)
                        .foregroundStyle(accent)
                        .lineLimit(1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("Weekly")
                        .font(.system(size: 38, weight: .black))
                        .foregroundStyle(.white)

                    Text("signal")
                        .font(.system(size: 35, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    accent,
                                    secondaryAccent
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .lineLimit(1)
                .minimumScaleFactor(0.72)

                Text("Premium weekly rhythm analysis.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.095),
                                        Color.white.opacity(0.045)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.11), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.24), radius: 12, y: 6)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var heroCard: some View {
        premiumSurface(tint: accent) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(accent)
                                .frame(width: 18, height: 1)

                            Text("SIGNAL OVERVIEW")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .tracking(1.7)
                                .foregroundStyle(accent)
                        }

                        Text(data.trendSummary)
                            .font(.system(size: 26, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                    }

                    Spacer()

                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(accent)
                        .frame(width: 48, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill(accent.opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .stroke(accent.opacity(0.16), lineWidth: 1)
                                )
                        )
                }

                HStack(spacing: 8) {
                    statChip(data.completionTotalText, tint: accent)
                    statChip(data.focusTotalText, tint: secondaryAccent)
                    statChip(data.streakText, tint: warmAccent)
                }
            }
        }
    }

    private var weeklyChartCard: some View {
        premiumSurface(tint: Color(arenaHex: AppArenaPalette.blue)) {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(
                    eyebrow: "7-DAY CHART",
                    title: "7-Day Rhythm",
                    icon: "chart.bar.fill",
                    tint: Color(arenaHex: AppArenaPalette.blue)
                )

                ZStack(alignment: .bottomLeading) {
                    gridBackground

                    HStack(alignment: .bottom, spacing: 12) {
                        ForEach(data.days) { day in
                            VStack(spacing: 8) {
                                ZStack(alignment: .bottom) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.060))
                                        .frame(width: day.isHighlight ? 40 : 28, height: 122)

                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: day.isHighlight
                                                ? [
                                                    Color(arenaHex: AppArenaPalette.gold).opacity(0.98),
                                                    accent.opacity(0.86)
                                                ]
                                                : [
                                                    Color(arenaHex: AppArenaPalette.blue).opacity(0.88),
                                                    Color(arenaHex: AppArenaPalette.cyan).opacity(0.72)
                                                ],
                                                startPoint: .bottom,
                                                endPoint: .top
                                            )
                                        )
                                        .frame(
                                            width: day.isHighlight ? 40 : 28,
                                            height: animateBars ? max(14, day.value * 122) : 10
                                        )
                                        .shadow(
                                            color: day.isHighlight
                                            ? Color(arenaHex: AppArenaPalette.gold).opacity(0.20)
                                            : Color(arenaHex: AppArenaPalette.blue).opacity(0.18),
                                            radius: 10,
                                            y: 4
                                        )
                                }

                                Text(day.label)
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white.opacity(day.isHighlight ? 0.92 : 0.56))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 156)
                }

                HStack(spacing: 8) {
                    miniLegend(color: Color(arenaHex: AppArenaPalette.gold), text: "Peak")
                    miniLegend(color: Color.white.opacity(0.22), text: "Base")
                }
            }
        }
    }

    private var dailyBreakdownCard: some View {
        premiumSurface(tint: Color(arenaHex: AppArenaPalette.purple)) {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    eyebrow: "DAILY DETAILS",
                    title: "Daily Breakdown",
                    icon: "list.bullet.rectangle",
                    tint: Color(arenaHex: AppArenaPalette.purple)
                )

                ForEach(data.days) { day in
                    HStack(spacing: 12) {
                        Text(day.label)
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(day.isHighlight ? 0.92 : 0.58))
                            .frame(width: 28, alignment: .leading)

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.060))
                                    .frame(height: 8)

                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: day.isHighlight
                                            ? [
                                                Color(arenaHex: AppArenaPalette.gold).opacity(0.96),
                                                accent.opacity(0.82)
                                            ]
                                            : [
                                                Color(arenaHex: AppArenaPalette.purple).opacity(0.86),
                                                Color(arenaHex: AppArenaPalette.cyan).opacity(0.70)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width: animateLine ? max(8, proxy.size.width * day.value) : 12,
                                        height: 8
                                    )
                            }
                        }
                        .frame(height: 8)

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(tr("rel_task_count", day.completedCount))
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(.white.opacity(0.82))

                            Text("\(day.focusMinutes) dk")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.42))
                        }
                        .frame(width: 58, alignment: .trailing)
                    }
                }

                HStack(spacing: 8) {
                    summaryTag("Strongest \(data.strongestDay)", tint: Color(arenaHex: AppArenaPalette.green))
                    summaryTag("Weakest \(data.weakestDay)", tint: Color(arenaHex: AppArenaPalette.gold))
                }
            }
        }
    }

    private var actionCard: some View {
        premiumSurface(tint: Color(arenaHex: AppArenaPalette.gold)) {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    eyebrow: "NEXT MOVE",
                    title: "Next Move",
                    icon: "arrow.up.forward",
                    tint: Color(arenaHex: AppArenaPalette.gold)
                )

                Text("Use your strongest day as a template and reinforce your weakest one with a short block.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.56))
                    .lineLimit(3)

                HStack(spacing: 10) {
                    Button {
                        dismiss()
                        onOpenFocus()
                    } label: {
                        Text(tr("iws_start_focus_caps"))
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(
                                Capsule()
                                    .fill(Color(arenaHex: AppArenaPalette.gold))
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        dismiss()
                        onOpenWeek()
                    } label: {
                        Text(tr("iws_open_week_caps"))
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(.white.opacity(0.84))
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.070))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
        }
    }

    private var gridBackground: some View {
        VStack(spacing: 22) {
            ForEach(0..<4, id: \.self) { _ in
                Rectangle()
                    .fill(Color.white.opacity(0.045))
                    .frame(height: 1)
            }
        }
        .padding(.bottom, 26)
    }

    private func sectionHeader(
        eyebrow: String,
        title: String,
        icon: String,
        tint: Color
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(tint)
                        .frame(width: 18, height: 1)

                    Text(eyebrow)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(tint)
                }

                Text(title)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
            }

            Spacer()

            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint.opacity(0.12))
                )
        }
    }

    private func statChip(_ text: String, tint: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .tracking(0.7)
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.70)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.16), lineWidth: 1)
                    )
            )
    }

    private func miniLegend(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(text.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(.white.opacity(0.46))
        }
    }

    private func summaryTag(_ text: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)

            Text(text)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            Capsule()
                .fill(tint.opacity(0.12))
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(0.16), lineWidth: 1)
                )
        )
    }

    private func premiumSurface<Content: View>(
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.085),
                            Color(arenaHex: AppArenaPalette.purple).opacity(0.040),
                            Color(arenaHex: AppArenaPalette.surface).opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    tint.opacity(0.145),
                                    Color.clear
                                ],
                                center: .topLeading,
                                startRadius: 4,
                                endRadius: 170
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(arenaHex: AppArenaPalette.blue).opacity(0.075),
                                    Color.clear
                                ],
                                center: .bottomTrailing,
                                startRadius: 8,
                                endRadius: 190
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(tint.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.22), radius: 16, y: 9)

            content()
                .padding(18)
        }
    }
}
