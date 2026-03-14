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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 36, height: 36)
                        .scaleEffect(pulse ? 1.08 : 0.96)

                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Behavior Analysis")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.secondaryText)

                    Text(data.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                }

                Spacer()
            }

            Text(data.message)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let buttonTitle = data.buttonTitle {
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

                        Text(buttonTitle)
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(
                        Capsule()
                            .fill(Color.accentColor)
                    )
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .scaleEffect(pressed ? 0.96 : 1.0)
                    .shadow(color: Color.accentColor.opacity(0.20), radius: 10, y: 5)
                }
                .buttonStyle(.plain)
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
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
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
