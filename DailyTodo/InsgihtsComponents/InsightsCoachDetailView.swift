//
//  SwiftUIView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//

import SwiftUI

struct InsightsCoachDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let data: InsightsCoachDetailData
    let onAction: (SmartSuggestionAction) -> Void

    @State private var animateConfidence = false
    @State private var animateSignalBars = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    heroCard
                    directionCard
                    readingCard
                    nextMovesSection
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
                animateConfidence = true
            }
            withAnimation(.easeOut(duration: 0.65).delay(0.08)) {
                animateSignalBars = true
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Coach")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Premium daily decision support")
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
        premiumSurface(tint: .cyan) {
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Insights+ Coach")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.56))

                    Text(data.headline)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(3)

                    Text(data.summary)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(3)
                }

                Spacer()

                confidenceOrb
            }
        }
    }

    private var confidenceOrb: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .frame(width: 98, height: 98)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.cyan.opacity(0.42),
                            Color.cyan.opacity(0.12),
                            .clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 32
                    )
                )
                .frame(width: 70, height: 70)

            VStack(spacing: 6) {
                HStack(spacing: 5) {
                    ForEach(0..<5, id: \.self) { index in
                        Circle()
                            .fill(index < (animateConfidence ? data.confidenceLevel : 0) ? .white.opacity(0.92) : .white.opacity(0.18))
                            .frame(width: 6, height: 6)
                    }
                }

                Text(data.confidenceText)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
            }
        }
    }

    private var directionCard: some View {
        premiumSurface(tint: .purple) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today Direction")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.56))

                        Text(data.todayDirectionTitle)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white.opacity(0.72))
                }

                HStack(spacing: 8) {
                    directionChip("Short")
                    directionChip("Clear")
                    directionChip("Actionable")
                }
            }
        }
    }

    private var readingCard: some View {
        premiumSurface(tint: .orange) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Smart Reading")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.62))
                }

                signalMeter(
                    title: "Strongest",
                    value: data.strongestSignal,
                    tint: .green,
                    level: 0.86
                )

                signalMeter(
                    title: "Blocking",
                    value: data.blockingSignal,
                    tint: .orange,
                    level: 0.58
                )

                Text(data.recommendationReason)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(3)
            }
        }
    }

    private var nextMovesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Next Moves")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(data.actionRows) { row in
                    moveTile(row)
                }
            }
        }
    }

    private func moveTile(_ row: InsightsCoachActionRow) -> some View {
        Button {
            dismiss()
            onAction(row.action)
        } label: {
            premiumSurface(tint: row.tint) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(row.tint.opacity(0.16))
                                .frame(width: 50, height: 50)

                            Image(systemName: row.symbol)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white.opacity(0.90))
                        }

                        Spacer()

                        Text(row.intensity)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.84))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }

                    Text(row.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(row.subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.70))
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
    }

    private func signalMeter(
        title: String,
        value: String,
        tint: Color,
        level: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(tint)
                        .frame(width: 8, height: 8)

                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.54))
                }

                Spacer()

                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 8)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint.opacity(0.95),
                                    .white.opacity(0.90)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: animateSignalBars ? proxy.size.width * level : 12,
                            height: 8
                        )
                }
            }
            .frame(height: 8)
        }
    }

    private func directionChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.82))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
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
                            tint.opacity(0.14),
                            Color.white.opacity(0.03),
                            Color.black.opacity(0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
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
