//
//  AICoachCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 14.03.2026.
//

import SwiftUI

struct AICoachCard: View {
    let data: AICoachData
    let onTapAction: ((SmartSuggestionAction) -> Void)?

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    @State private var isVisible = false
    @State private var pressed = false
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 40, height: 40)
                        .scaleEffect(pulse ? 1.05 : 0.96)

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Behavior Analysis")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.secondaryText)

                    Text(data.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Text(data.message)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)

            if   !data.buttonTitle.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.72)) {
                        pressed = true
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            pressed = false
                        }
                        onTapAction?(data.action)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: buttonIcon(for: data.action))
                            .font(.system(size: 14, weight: .bold))

                        Text(data.buttonTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(
                        Capsule()
                            .fill(Color.accentColor)
                    )
                    .foregroundStyle(.white)
                    .scaleEffect(pressed ? 0.97 : 1.0)
                    .shadow(color: Color.accentColor.opacity(0.18), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.985)
        .offset(y: isVisible ? 0 : 12)
        .animation(.spring(response: 0.48, dampingFraction: 0.86), value: isVisible)
        .animateWhenVisible($isVisible)
        .onChange(of: isVisible) { _, newValue in
            guard newValue else { return }
            pulse = false
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private func buttonIcon(for action: SmartSuggestionAction) -> String {
        switch action {
        case .openTasks: return "checklist"
        case .openFocus: return "timer"
        case .openWeek: return "calendar"
        case .none: return "sparkles"
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }
}
