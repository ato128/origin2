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

        let titleFont: CGFloat = 34 - (4 * collapseProgress)
        let subtitleOpacity: CGFloat = 1 - (collapseProgress * 1.2)
        let topPadding: CGFloat = 4 - (1.5 * collapseProgress)
        let blurOpacity: CGFloat = 0.08 + (0.72 * collapseProgress)

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
                    VStack(alignment: .leading, spacing: 3) {
                        Text(activeTitle)
                            .font(.system(size: titleFont, weight: .black, design: .rounded))
                            .foregroundStyle(palette.primaryText)

                        if subtitleOpacity > 0.08 {
                            Text(subtitle)
                                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
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
            .frame(height: subtitleOpacity > 0.08 ? 62 : 48)

            modeSegmentedControl
                .padding(.horizontal, 20)
        }
        .padding(.bottom, 2)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.035 * blurOpacity))
                .frame(height: 0.5),
            alignment: .bottom
        )
        .animation(.spring(response: 0.30, dampingFraction: 0.86), value: activeOffset)
        .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.88), value: weekMode)
    }

    var modeSegmentedControl: some View {
        HStack(spacing: 8) {
            modeSegmentButton(
                title: "Personal",
                icon: "calendar",
                isSelected: weekMode == .personal,
                accent: Color(red: 0.24, green: 0.56, blue: 1.00)
            ) {
                withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.88)) {
                    weekMode = .personal
                }
            }

            modeSegmentButton(
                title: "Crew",
                icon: "person.3.fill",
                isSelected: weekMode == .crew,
                accent: Color(red: 0.62, green: 0.44, blue: 0.96)
            ) {
                withAnimation(.interactiveSpring(response: 0.26, dampingFraction: 0.88)) {
                    weekMode = .crew
                }
            }
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            palette.cardFill,
                            palette.cardFill.opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    func modeSegmentButton(
        title: String,
        icon: String,
        isSelected: Bool,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(accent.opacity(0.16))
                            .frame(width: 20, height: 20)
                    }

                    Image(systemName: icon)
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(isSelected ? accent : palette.secondaryText)
                }

                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? palette.primaryText : palette.secondaryText)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isSelected
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [
                                    accent.opacity(0.16),
                                    accent.opacity(0.09),
                                    Color.white.opacity(0.015)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        : AnyShapeStyle(Color.white.opacity(0.01))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected
                        ? accent.opacity(0.18)
                        : Color.white.opacity(0.04),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isSelected ? accent.opacity(0.05) : .clear,
                radius: isSelected ? 5 : 0,
                y: isSelected ? 2 : 0
            )
        }
        .buttonStyle(.plain)
    }
}
