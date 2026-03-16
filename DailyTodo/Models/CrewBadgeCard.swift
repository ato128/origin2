//
//  CrewBadgeCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI
import UIKit

struct CrewBadgeCard: View {
    let crew: Crew
    let palette: ThemePalette

    @State private var badgeGlow = false
    @State private var previousBadgeTitle: String = ""
    @State private var showBadgeUnlocked = false

    private var focusBadgeTitle: String {
        CrewBadgeHelper.title(for: crew.totalFocusMinutes)
    }

    private var focusBadgeColor: Color {
        CrewBadgeHelper.color(for: crew.totalFocusMinutes)
    }

    private var nextTarget: Int? {
        CrewBadgeHelper.nextTarget(for: crew.totalFocusMinutes)
    }

    private var badgeProgress: Double {
        CrewBadgeHelper.progress(for: crew.totalFocusMinutes)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Crew Badge")
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)

                    Text("Unlocked by total focus time")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer()

                if showBadgeUnlocked {
                    Text("Unlocked!")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(focusBadgeColor)
                        )
                        .transition(.scale.combined(with: .opacity))
                }

                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(focusBadgeColor)
                    .shadow(
                        color: focusBadgeColor.opacity(badgeGlow ? 0.22 : 0.10),
                        radius: 6
                    )
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: showBadgeUnlocked)

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(focusBadgeColor.opacity(badgeGlow ? 0.20 : 0.10))
                        .frame(width: 56, height: 56)

                    Circle()
                        .stroke(focusBadgeColor.opacity(0.22), lineWidth: 1)
                        .frame(width: 56, height: 56)

                    Image(systemName: "medal.fill")
                        .font(.title3)
                        .foregroundStyle(focusBadgeColor)
                        .shadow(
                            color: focusBadgeColor.opacity(badgeGlow ? 0.18 : 0.08),
                            radius: 6
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(focusBadgeTitle)

                        if crew.totalFocusMinutes >= 15 {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(focusBadgeColor)
                                .font(.caption)
                        }
                    }
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)

                    Text(focusTimeText(crew.totalFocusMinutes))
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer()
            }
            .padding(14)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(focusBadgeColor.opacity(0.08))

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(focusBadgeColor.opacity(0.24), lineWidth: 1)

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    focusBadgeColor.opacity(badgeGlow ? 0.18 : 0.08),
                                    Color.clear
                                ],
                                center: .topLeading,
                                startRadius: 10,
                                endRadius: 180
                            )
                        )
                        .blur(radius: 8)
                }
            )
            .scaleEffect(badgeGlow ? 1.0 : 0.985)
            .animation(.easeInOut(duration: 0.25), value: focusBadgeTitle)

            if let nextTarget {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Next badge")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.secondaryText)

                        Spacer()

                        Text("\(focusTimeText(nextTarget - crew.totalFocusMinutes)) left")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(palette.secondaryText)
                    }

                    ProgressView(value: badgeProgress)
                        .tint(focusBadgeColor)
                        .scaleEffect(y: 1.5)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)

                Text("Streak: \(crew.currentStreak)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
            }
            .padding(.top, 2)
        }
        .padding(18)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(palette.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(palette.cardStroke, lineWidth: 1)
                    )

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                focusBadgeColor.opacity(showBadgeUnlocked ? 0.22 : (badgeGlow ? 0.12 : 0.06)),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 10,
                            endRadius: 220
                        )
                    )
                    .blur(radius: 8)
            }
        )
        .shadow(
            color: focusBadgeColor.opacity(showBadgeUnlocked ? 0.16 : (badgeGlow ? 0.10 : 0.04)),
            radius: showBadgeUnlocked ? 10 : 6,
            y: 4
        )
        .onAppear {
            previousBadgeTitle = focusBadgeTitle

            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                badgeGlow = true
            }
        }
        .onChange(of: crew.totalFocusMinutes) { _, _ in
            let newBadgeTitle = focusBadgeTitle

            guard newBadgeTitle != previousBadgeTitle else { return }
            guard newBadgeTitle != "No Badge" else {
                previousBadgeTitle = newBadgeTitle
                return
            }

            previousBadgeTitle = newBadgeTitle
            showBadgeUnlocked = true

            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.prepare()
            gen.impactOccurred()

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showBadgeUnlocked = false
                }
            }
            
        }
        .compositingGroup()
    }
}
