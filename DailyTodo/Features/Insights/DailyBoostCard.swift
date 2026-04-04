//
//  DailyBoostCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//


import SwiftUI

struct DailyBoostCard: View {
    let data: DailyBoostData

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    @State private var isVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(data.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.secondaryText)

            Text(data.message)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.primaryText)
                .multilineTextAlignment(.leading)

            if let buttonTitle = data.buttonTitle {
                Button(buttonTitle) { }
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(Color.accentColor)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            appTheme == AppTheme.light.rawValue
                                                ? Color.black.opacity(0.06)
                                                : Color.white.opacity(0.14)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    )
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.accentColor.opacity(0.20), radius: 8)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.985)
        .offset(y: isVisible ? 0 : 12)
        .animation(.spring(response: 0.48, dampingFraction: 0.86), value: isVisible)
        .animateWhenVisible($isVisible)
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
