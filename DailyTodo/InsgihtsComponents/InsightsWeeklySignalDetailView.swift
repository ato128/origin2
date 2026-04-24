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

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    heroCard
                    weeklyChartCard
                    dailyBreakdownCard
                    actionCard
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Weekly Signal")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Premium weekly rhythm analysis")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.60))
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var heroCard: some View {
        premiumSurface(tint: .blue) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Signal Overview")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.56))

                        Text(data.trendSummary)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white.opacity(0.78))
                }

                HStack(spacing: 8) {
                    statChip(data.completionTotalText)
                    statChip(data.focusTotalText)
                    statChip(data.streakText)
                }
            }
        }
    }

    private var weeklyChartCard: some View {
        premiumSurface(tint: .cyan) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("7-Day Rhythm")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    HStack(spacing: 8) {
                        miniLegend(color: .white.opacity(0.88), text: "Peak")
                        miniLegend(color: .white.opacity(0.22), text: "Base")
                    }
                }

                ZStack(alignment: .bottomLeading) {
                    gridBackground

                    HStack(alignment: .bottom, spacing: 12) {
                        ForEach(data.days) { day in
                            VStack(spacing: 8) {
                                ZStack(alignment: .bottom) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.06))
                                        .frame(width: day.isHighlight ? 40 : 28, height: 122)

                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: day.isHighlight
                                                    ? [.white.opacity(0.98), .white.opacity(0.84)]
                                                    : [.blue.opacity(0.85), .white.opacity(0.72)],
                                                startPoint: .bottom,
                                                endPoint: .top
                                            )
                                        )
                                        .frame(
                                            width: day.isHighlight ? 40 : 28,
                                            height: animateBars ? max(14, day.value * 122) : 10
                                        )
                                        .shadow(
                                            color: day.isHighlight ? .white.opacity(0.16) : .blue.opacity(0.18),
                                            radius: 10,
                                            y: 4
                                        )
                                }

                                Text(day.label)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white.opacity(day.isHighlight ? 0.92 : 0.56))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 156)
                }
            }
        }
    }

    private var dailyBreakdownCard: some View {
        premiumSurface(tint: .purple) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Daily Breakdown")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                ForEach(data.days) { day in
                    HStack(spacing: 12) {
                        Text(day.label)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(day.isHighlight ? 0.92 : 0.58))
                            .frame(width: 28, alignment: .leading)

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 8)

                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: day.isHighlight
                                                ? [.white.opacity(0.96), .white.opacity(0.82)]
                                                : [.purple.opacity(0.85), .white.opacity(0.72)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width: animateLine ? proxy.size.width * day.value : 12,
                                        height: 8
                                    )
                            }
                        }
                        .frame(height: 8)

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(day.completedCount) görev")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.82))

                            Text("\(day.focusMinutes) dk")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.46))
                        }
                        .frame(width: 54, alignment: .trailing)
                    }
                }

                HStack(spacing: 8) {
                    summaryTag("Strongest \(data.strongestDay)", tint: .green)
                    summaryTag("Weakest \(data.weakestDay)", tint: .orange)
                }
            }
        }
    }

    private var actionCard: some View {
        premiumSurface(tint: .orange) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Next Move")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Use your strongest day as a template and reinforce your weakest one with a short block.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(3)

                HStack(spacing: 10) {
                    Button {
                        dismiss()
                        onOpenFocus()
                    } label: {
                        Text("Focus Başlat")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .background(Color.white, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        dismiss()
                        onOpenWeek()
                    } label: {
                        Text("Haftayı Aç")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var gridBackground: some View {
        VStack(spacing: 22) {
            ForEach(0..<4, id: \.self) { _ in
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 1)
            }
        }
        .padding(.bottom, 26)
    }

    private func statChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.82))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.08), in: Capsule())
    }

    private func miniLegend(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.46))
        }
    }

    private func summaryTag(_ text: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)

            Text(text)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.86))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08), in: Capsule())
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
                            tint.opacity(0.34),
                            tint.opacity(0.16),
                            Color(red: 0.03, green: 0.18, blue: 0.36).opacity(0.62),
                            Color(red: 0.035, green: 0.035, blue: 0.070)
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
                                    tint.opacity(0.24),
                                    Color.clear
                                ],
                                center: .topLeading,
                                startRadius: 4,
                                endRadius: 150
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
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
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )

            content()
                .padding(18)
        }
    }
}
