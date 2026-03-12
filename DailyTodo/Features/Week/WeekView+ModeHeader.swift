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

        let frontFont: CGFloat = 44 - (12 * collapseProgress)
        let backFont: CGFloat = 34 - (6 * collapseProgress)

        let frontTopOffset: CGFloat = 18 - (14 * collapseProgress)
        let backTopOffset: CGFloat = 2 - (4 * collapseProgress)

        let frontLeadingOffset: CGFloat = 0 + (110 * collapseProgress)
        let blurOpacity: CGFloat = 0.0 + (0.98 * collapseProgress)

        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)
                .opacity(blurOpacity)

            if weekMode == .personal {
                Text("Crew")
                    .font(.system(size: backFont, weight: .bold, design: .default))
                    .foregroundStyle(.primary.opacity(0.10))
                    .offset(x: 12, y: backTopOffset)
                    .allowsHitTesting(false)

                HStack {
                    Text("Week")
                        .font(.system(size: frontFont, weight: .bold, design: .default))
                        .foregroundStyle(.primary)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.84)) {
                                weekMode = .crew
                            }
                        }

                    Spacer()
                }
                .offset(x: frontLeadingOffset, y: frontTopOffset)

            } else {
                Text("Week")
                    .font(.system(size: backFont, weight: .bold, design: .default))
                    .foregroundStyle(.primary.opacity(0.10))
                    .offset(x: 12, y: backTopOffset)
                    .allowsHitTesting(false)

                HStack {
                    Text("Crew")
                        .font(.system(size: frontFont, weight: .bold, design: .default))
                        .foregroundStyle(.primary)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.interactiveSpring(response: 0.36, dampingFraction: 0.84)) {
                                weekMode = .personal
                            }
                        }
                   
                        
                    Spacer()
                }
                .offset(x: frontLeadingOffset, y: frontTopOffset)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 92 - (20 * collapseProgress), alignment: .topLeading)
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.05 * blurOpacity))
                .frame(height: 0.5),
            alignment: .bottom
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: activeOffset)
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.86), value: weekMode)
        .animation(.easeInOut(duration: 0.18), value: collapseProgress)
    }
}
