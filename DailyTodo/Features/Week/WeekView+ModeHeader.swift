//
//  WeekView+ModeHeader.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 11.03.2026.
//

import SwiftUI

extension WeekView {
    var modeTitleSwitcher: some View {
        let activeOffset = weekMode == .crew ? crewScrollOffset : personalScrollOffset
        let collapseProgress = min(max(activeOffset / 80, 0), 1)

        let bigFont: CGFloat = 44 - (10 * collapseProgress)
        let backFont: CGFloat = 34 - (6 * collapseProgress)
        let topY: CGFloat = 18 - (12 * collapseProgress)
        let backY: CGFloat = 2 - (6 * collapseProgress)
        let blurOpacity = 0.0 + (0.95 * collapseProgress)

        return ZStack(alignment: .topLeading) {
            if weekMode == .personal {
                Text("Crew")
                    .font(.system(size: backFont, weight: .bold, design: .default))
                    .foregroundStyle(.primary.opacity(0.10))
                    .offset(x: 10, y: backY)
                    .allowsHitTesting(false)

                Text("Week")
                    .font(.system(size: bigFont, weight: .bold, design: .default))
                    .foregroundStyle(.primary)
                    .offset(x: 0, y: topY)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.84)) {
                            weekMode = .crew
                        }
                    }
            } else {
                Text("Week")
                    .font(.system(size: backFont, weight: .bold, design: .default))
                    .foregroundStyle(.primary.opacity(0.10))
                    .offset(x: 10, y: backY)
                    .allowsHitTesting(false)

                Text("Crew")
                    .font(.system(size: bigFont, weight: .bold, design: .default))
                    .foregroundStyle(.primary)
                    .offset(x: 0, y: topY)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.84)) {
                            weekMode = .personal
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 86 - (18 * collapseProgress), alignment: .topLeading)
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background(
            .ultraThinMaterial.opacity(blurOpacity)
        )
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.05 * blurOpacity))
                .frame(height: 0.5),
            alignment: .bottom
        )
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.86), value: weekMode)
        .animation(.easeInOut(duration: 0.18), value: collapseProgress)
    }
}
