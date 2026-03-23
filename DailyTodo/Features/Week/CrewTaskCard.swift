//
//  CrewTaskCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 11.03.2026.
//

import SwiftUI

struct CrewTaskCard: View {
    let title: String
    let crewName: String?
    let timeText: String?
    let priorityTitle: String
    let statusTitle: String
    let tint: Color
    let active: Bool
    let done: Bool
    let soon: Bool
    let isLate: Bool
    let lateText: String?
    let crewPulse: Bool
    let minutesLeft: Int
    let progress: Double
    let parallaxOffset: CGFloat
    let timelineParallaxOffset: CGFloat

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    @State private var latePulse = false

    private let palette = ThemePalette()

    private var effectiveTint: Color {
        isLate ? .red : tint
    }

    private var isLightTheme: Bool {
        palette.primaryText == .black
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(done ? Color.green : (active ? effectiveTint : effectiveTint.opacity(0.85)))
                        .frame(width: active ? 16 : 13, height: active ? 16 : 13)
                        .scaleEffect(active && crewPulse ? 1.12 : 1.0)
                        .shadow(
                            color: active ? effectiveTint.opacity(0.40) : (soon ? effectiveTint.opacity(0.18) : .clear),
                            radius: active ? 14 : (soon ? 8 : 0)
                        )

                    if active {
                        Circle()
                            .stroke(effectiveTint.opacity(0.24), lineWidth: 6)
                            .frame(width: 16, height: 16)
                            .scaleEffect(crewPulse ? 1.55 : 1.15)
                            .opacity(crewPulse ? 0.35 : 0.12)
                    }
                }
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: crewPulse)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                active ? effectiveTint.opacity(0.85) : effectiveTint.opacity(0.35),
                                effectiveTint.opacity(0.15),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 6)
                    .opacity(0.9)
            }
            .offset(y: timelineParallaxOffset)
            .frame(width: 20)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 10) {
                    Text(title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(done ? palette.secondaryText : palette.primaryText)
                        .strikethrough(done, color: palette.secondaryText)
                        .lineLimit(2)

                    Spacer()

                    if active {
                        ZStack {
                            Circle()
                                .stroke(effectiveTint.opacity(0.18), lineWidth: 4)
                                .frame(width: 30, height: 30)

                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(
                                    effectiveTint,
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 30, height: 30)
                                .animation(.easeInOut(duration: 0.35), value: progress)

                            Text("\(minutesLeft)")
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundStyle(effectiveTint)
                        }
                    } else if let timeText {
                        Text(timeText)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.secondaryText)
                            .monospacedDigit()
                    }
                }

                if let crewName {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(effectiveTint)
                            .frame(width: 8, height: 8)
                            .shadow(color: effectiveTint.opacity(0.35), radius: 4)

                        Text(crewName)
                            .font(.caption2.weight(.bold))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(effectiveTint.opacity(0.12))
                    .foregroundStyle(effectiveTint)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(effectiveTint.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: effectiveTint.opacity(0.25), radius: 6)
                }

                HStack(spacing: 8) {
                    Text(priorityTitle)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(effectiveTint.opacity(0.14))
                        .foregroundStyle(effectiveTint)
                        .clipShape(Capsule())

                    Text(statusTitle)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(palette.secondaryCardFill)
                        .foregroundStyle(palette.secondaryText)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(palette.cardStroke, lineWidth: 1)
                        )

                    Spacer()

                    if isLate {
                        HStack(spacing: 6) {
                            Text("LATE")
                                .font(.caption2.weight(.black))

                            if let lateText {
                                Text(lateText)
                                    .font(.caption2.weight(.bold))
                                    .monospacedDigit()
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.16))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                    } else if active {
                        HStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.18))
                                    .frame(width: 16, height: 16)
                                    .scaleEffect(crewPulse ? 1.15 : 0.95)

                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                    .shadow(color: Color.green.opacity(0.35), radius: 6)
                            }
                            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: crewPulse)

                            Text("LIVE")
                                .font(.caption2.weight(.black))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.green.opacity(0.16))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                    } else if soon {
                        Text("SOON")
                            .font(.caption2.weight(.black))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(effectiveTint.opacity(0.14))
                            .foregroundStyle(effectiveTint)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(palette.cardFill)
                    .shadow(
                        color: active
                            ? effectiveTint.opacity(0.25)
                            : (isLightTheme ? Color.black.opacity(0.06) : .black.opacity(0.08)),
                        radius: active ? 10 : 4,
                        y: active ? 4 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(active ? effectiveTint.opacity(0.28) : palette.cardStroke, lineWidth: 1)
            )
        }
        .offset(y: parallaxOffset)
        .opacity(done ? 0.82 : 1.0)
        .shadow(
            color: isLate ? Color.red.opacity(latePulse ? 0.26 : 0.12) : .clear,
            radius: isLate ? (latePulse ? 16 : 8) : 0
        )
        .scaleEffect(
            isLate
                ? (latePulse ? 1.01 : 1.0)
                : (active && crewPulse ? 1.008 : 1.0)
        )
        .animation(active ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : .default, value: crewPulse)
        .animation(isLate ? .easeInOut(duration: 1.4).repeatForever(autoreverses: true) : .default, value: latePulse)
        .animation(.easeInOut(duration: 0.2), value: done)
        .onAppear {
            latePulse = isLate
        }
        .onChange(of: isLate) { _, newValue in
            latePulse = newValue
        }
    }
}
