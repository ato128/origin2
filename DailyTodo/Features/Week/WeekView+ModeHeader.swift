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

        let collapseProgress = min(max(activeOffset / 80, 0), 1)

        let titleFont: CGFloat = 32 - (5 * collapseProgress)
        let subtitleOpacity: CGFloat = 1 - (collapseProgress * 1.35)
        let topPadding: CGFloat = 6 - (2 * collapseProgress)
        let blurOpacity: CGFloat = 0.10 + (0.82 * collapseProgress)

        let activeTitle = weekMode == .personal ? "Week" : "Crew"
        let subtitle = weekMode == .personal
            ? "Kişisel planını ve gün akışını yönet"
            : "Ekip akışını ve ortak görevleri takip et"

        return VStack(spacing: 8) {
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea(edges: .top)
                    .opacity(blurOpacity)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activeTitle)
                            .font(.system(size: titleFont, weight: .black, design: .rounded))
                            .foregroundStyle(palette.primaryText)
                            .shadow(
                                color: Color.black.opacity(0.05),
                                radius: 4,
                                y: 1
                            )

                        if subtitleOpacity > 0.08 {
                            Text(subtitle)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(palette.secondaryText)
                                .lineLimit(1)
                                .opacity(subtitleOpacity)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, topPadding)
            }
            .frame(height: subtitleOpacity > 0.08 ? 68 : 54)

            modeSegmentedControl
                .padding(.horizontal, 20)
        }
        .padding(.bottom, 2)
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.035 * blurOpacity))
                .frame(height: 0.5),
            alignment: .bottom
        )
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: activeOffset)
        .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.88), value: weekMode)
    }

    var modeSegmentedControl: some View {
        HStack(spacing: 8) {
            modeSegmentButton(
                title: "Personal",
                icon: "calendar",
                isSelected: weekMode == .personal
            ) {
                withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.88)) {
                    weekMode = .personal
                }
            }

            modeSegmentButton(
                title: "Crew",
                icon: "person.3.fill",
                isSelected: weekMode == .crew
            ) {
                withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.88)) {
                    weekMode = .crew
                }
            }
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
    }

    func modeSegmentButton(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))

                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(isSelected ? palette.primaryText : palette.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        isSelected
                        ? Color.accentColor.opacity(0.15)
                        : Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(
                        isSelected
                        ? Color.accentColor.opacity(0.24)
                        : Color.clear,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isSelected ? Color.accentColor.opacity(0.06) : .clear,
                radius: isSelected ? 6 : 0,
                y: isSelected ? 2 : 0
            )
        }
        .buttonStyle(.plain)
    }
}
