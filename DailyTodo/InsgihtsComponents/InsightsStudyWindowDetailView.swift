//
//  InsightsStudyWindowDetailView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//

import SwiftUI

struct InsightsStudyWindowDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let data: InsightsStudyWindowDetailData
    let onOpenWeek: () -> Void
    let onOpenFocus: () -> Void

    @State private var animateBars = false
    @State private var animateRing = false

    private var accent: Color {
        Color(arenaHex: AppArenaPalette.gold)
    }

    private var secondaryAccent: Color {
        Color(arenaHex: AppArenaPalette.coral)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ArenaBackground(
                primaryGlow: accent,
                secondaryGlow: Color(arenaHex: AppArenaPalette.purple),
                warmGlow: secondaryAccent,
                intensity: 0.92
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    heroCard
                    courseBreakdownCard
                    smartReadingCard
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
            withAnimation(.easeOut(duration: 0.75)) {
                animateRing = true
            }

            withAnimation(.spring(response: 0.7, dampingFraction: 0.82).delay(0.08)) {
                animateBars = true
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

                    Text("STUDY WINDOW")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(2.3)
                        .foregroundStyle(accent)
                        .lineLimit(1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("Study")
                        .font(.system(size: 38, weight: .black))
                        .foregroundStyle(.white)

                    Text("window")
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

                Text("Premium course-level focus insight.")
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
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(accent)
                            .frame(width: 18, height: 1)

                        Text("BEST WINDOW")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.7)
                            .foregroundStyle(accent)
                    }

                    Text(data.timeRangeText)
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(data.confidenceText)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(.white.opacity(0.52))

                    HStack(spacing: 8) {
                        miniChip("Longer focus", tint: accent)
                        miniChip("Higher completion", tint: secondaryAccent)
                    }
                }

                Spacer()

                progressRing
            }
        }
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.075), lineWidth: 8)
                .frame(width: 104, height: 104)

            Circle()
                .trim(from: 0.12, to: animateRing ? 0.84 : 0.12)
                .stroke(
                    AngularGradient(
                        colors: [
                            accent.opacity(0.98),
                            secondaryAccent.opacity(0.92),
                            Color(arenaHex: AppArenaPalette.purple).opacity(0.84),
                            accent.opacity(0.98)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-110))
                .frame(width: 86, height: 86)
                .shadow(color: accent.opacity(0.20), radius: 10, y: 3)

            VStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(accent)

                Text(data.timeRangeText)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }
        }
    }

    private var courseBreakdownCard: some View {
        premiumSurface(tint: Color(arenaHex: AppArenaPalette.blue)) {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    eyebrow: "COURSE CHART",
                    title: "Course Breakdown",
                    icon: "chart.bar.xaxis",
                    tint: Color(arenaHex: AppArenaPalette.blue)
                )

                if data.rows.isEmpty {
                    emptyGraphState
                } else {
                    animatedBarChart
                }
            }
        }
    }

    private var animatedBarChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(Array(data.rows.prefix(5).enumerated()), id: \.offset) { _, row in
                    VStack(spacing: 8) {
                        ZStack(alignment: .bottom) {
                            Capsule()
                                .fill(Color.white.opacity(0.060))
                                .frame(width: 38, height: 104)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            row.accent.opacity(0.98),
                                            Color(arenaHex: AppArenaPalette.cyan).opacity(0.82)
                                        ],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(
                                    width: 38,
                                    height: animateBars ? max(18, row.progress * 104) : 12
                                )
                                .shadow(color: row.accent.opacity(0.22), radius: 10, y: 4)
                        }

                        Text(shortCourse(row.courseName))
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.68))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)

                        Text("\(row.minutes) dk")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.40))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 148)

            HStack(spacing: 8) {
                visualTag(title: "Top", value: data.strongestCourse, tint: Color(arenaHex: AppArenaPalette.green))
                visualTag(title: "Low", value: data.neglectedCourse, tint: Color(arenaHex: AppArenaPalette.gold))
            }
        }
    }

    private var emptyGraphState: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(0..<5, id: \.self) { index in
                    VStack(spacing: 8) {
                        Capsule()
                            .fill(Color.white.opacity(index == 2 ? 0.10 : 0.06))
                            .frame(width: 38, height: [28, 54, 82, 46, 22][index])

                        Capsule()
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 22, height: 6)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120)

            Text("Add course tags to tasks to unlock this graph.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.50))
        }
    }

    private var smartReadingCard: some View {
        premiumSurface(tint: Color(arenaHex: AppArenaPalette.gold)) {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    eyebrow: "SMART READING",
                    title: "Smart Reading",
                    icon: "sparkles",
                    tint: Color(arenaHex: AppArenaPalette.gold)
                )

                insightLine(
                    icon: "checkmark.circle.fill",
                    tint: Color(arenaHex: AppArenaPalette.green),
                    label: "Strongest",
                    value: data.strongestCourse
                )

                insightLine(
                    icon: "exclamationmark.circle.fill",
                    tint: Color(arenaHex: AppArenaPalette.gold),
                    label: "Needs more",
                    value: data.neglectedCourse
                )

                insightLine(
                    icon: "arrow.triangle.branch",
                    tint: Color(arenaHex: AppArenaPalette.purple),
                    label: "Recommended",
                    value: data.recommendedCourse
                )

                Text(data.recommendationReason)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.56))
                    .lineLimit(3)
            }
        }
    }

    private var actionCard: some View {
        premiumSurface(tint: Color(arenaHex: AppArenaPalette.coral)) {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    eyebrow: "NEXT MOVE",
                    title: "Next Move",
                    icon: "arrow.up.forward",
                    tint: Color(arenaHex: AppArenaPalette.coral)
                )

                HStack(spacing: 10) {
                    Button {
                        dismiss()
                        onOpenFocus()
                    } label: {
                        Text("FOCUS BAŞLAT")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(
                                Capsule()
                                    .fill(Color(arenaHex: AppArenaPalette.coral))
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        dismiss()
                        onOpenWeek()
                    } label: {
                        Text("HAFTAYI AÇ")
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

    private func insightLine(
        icon: String,
        tint: Color,
        label: String,
        value: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 25, height: 25)
                .background(
                    Circle()
                        .fill(tint.opacity(0.12))
                )

            Text(label.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.42))

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func visualTag(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)

            Text(title.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(.white.opacity(0.42))

            Text(value)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(1)
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

    private func miniChip(_ text: String, tint: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .tracking(0.7)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.16), lineWidth: 1)
                    )
            )
    }

    private func shortCourse(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "—" }
        if trimmed.count <= 7 { return trimmed }
        return String(trimmed.prefix(7))
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
