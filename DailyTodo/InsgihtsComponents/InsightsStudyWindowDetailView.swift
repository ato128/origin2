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

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    heroCard
                    courseBreakdownCard
                    smartReadingCard
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
            withAnimation(.easeOut(duration: 0.75)) {
                animateRing = true
            }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82).delay(0.08)) {
                animateBars = true
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Study Window")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Premium course-level focus insight")
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
        premiumSurface(tint: .purple) {
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Best Window")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.56))

                    Text(data.timeRangeText)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(data.confidenceText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.66))

                    HStack(spacing: 8) {
                        miniChip("Longer focus")
                        miniChip("Higher completion")
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
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .frame(width: 102, height: 102)

            Circle()
                .trim(from: 0.12, to: animateRing ? 0.84 : 0.12)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.purple.opacity(0.95),
                            Color.pink.opacity(0.88),
                            Color.white.opacity(0.92)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-110))
                .frame(width: 82, height: 82)

            VStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.88))

                Text(data.timeRangeText)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
        }
    }

    private var courseBreakdownCard: some View {
        premiumSurface(tint: .blue) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Course Breakdown")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.60))
                }

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
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 38, height: 104)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            row.accent.opacity(0.98),
                                            .white.opacity(0.88)
                                        ],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(
                                    width: 38,
                                    height: animateBars ? max(18, row.progress * 104) : 12
                                )
                                .shadow(color: row.accent.opacity(0.25), radius: 10, y: 4)
                        }

                        Text(shortCourse(row.courseName))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.70))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text("\(row.minutes) dk")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.46))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 148)

            HStack(spacing: 8) {
                visualTag(title: "Top", value: data.strongestCourse, tint: .green)
                visualTag(title: "Low", value: data.neglectedCourse, tint: .orange)
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
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.56))
        }
    }

    private var smartReadingCard: some View {
        premiumSurface(tint: .orange) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Smart Reading")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.64))
                }

                insightLine(
                    icon: "checkmark.circle.fill",
                    tint: .green,
                    label: "Strongest",
                    value: data.strongestCourse
                )

                insightLine(
                    icon: "exclamationmark.circle.fill",
                    tint: .orange,
                    label: "Needs more",
                    value: data.neglectedCourse
                )

                insightLine(
                    icon: "arrow.triangle.branch",
                    tint: .purple,
                    label: "Recommended",
                    value: data.recommendedCourse
                )

                Text(data.recommendationReason)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(3)
            }
        }
    }

    private var actionCard: some View {
        premiumSurface(tint: .pink) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Next Move")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

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

    private func insightLine(
        icon: String,
        tint: Color,
        label: String,
        value: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)

            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.56))

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
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

            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.48))

            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08), in: Capsule())
    }

    private func miniChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.82))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.08), in: Capsule())
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
