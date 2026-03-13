//
//  WeekView+ModeHeader.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 11.03.2026.
//

import SwiftUI

extension WeekView {
    var modeTitleSwitcher: some View {
        let activeOffset = weekMode == .personal
            ? personalScrollOffset
            : crewScrollOffset

        let collapseProgress = min(max(activeOffset / 90, 0), 1)

        let frontFont: CGFloat = 44 - (10 * collapseProgress)
        let backFont: CGFloat = 30 - (4 * collapseProgress)

        let frontTopOffset: CGFloat = 18 - (10 * collapseProgress)
        let backTopOffset: CGFloat = 8 - (4 * collapseProgress)

        let frontLeadingOffset: CGFloat = 0 + (72 * collapseProgress)
        let blurOpacity: CGFloat = 0.0 + (0.94 * collapseProgress)

        let activeTitle = weekMode == .personal ? "Week" : "Crew"
        let backgroundTitle = weekMode == .personal ? "Crew" : "Week"

        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)
                .opacity(blurOpacity)

            Text(backgroundTitle)
                .font(.system(size: backFont, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.18),
                            Color.blue.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 2)
                .opacity(0.6)
                .offset(x: 10, y: backTopOffset)
                .allowsHitTesting(false)

            HStack {
                Text(activeTitle)
                    .font(.system(size: frontFont, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: Color.white.opacity(0.15), radius: 6, y: 2)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.86)) {
                            weekMode = weekMode == .personal ? .crew : .personal
                        }
                    }

                Spacer()
            }
            .offset(x: frontLeadingOffset, y: frontTopOffset)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 88 - (14 * collapseProgress), alignment: .topLeading)
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.04 * blurOpacity))
                .frame(height: 0.5),
            alignment: .bottom
        )
        .animation(.spring(response: 0.34, dampingFraction: 0.84), value: activeOffset)
        .animation(.interactiveSpring(response: 0.26, dampingFraction: 0.88), value: weekMode)
    }
}
