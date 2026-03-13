//
//  SmartSuggestionCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI

struct SmartSuggestionCard: View {

    let data: SmartSuggestionData

    @State private var isVisible = false
    @State private var pressed = false

    var body: some View {

        VStack(alignment: .leading, spacing: 12) {

            Text(data.title)
                .font(.system(size: 16, weight: .semibold))

            Text(data.message)
                .font(.system(size: 16, weight: .semibold))

            if let buttonTitle = data.buttonTitle {

                Button {

                    withAnimation(.spring(response: 0.25)) {
                        pressed = true
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(.spring(response: 0.3)) {
                            pressed = false
                        }
                    }

                } label: {

                    Text(buttonTitle)
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
                                                Color.white.opacity(0.16),
                                                Color.clear
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            }
                        )
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .scaleEffect(pressed ? 0.96 : 1)
                        .shadow(color: Color.accentColor.opacity(0.25), radius: 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(cardBackground)
        .animateWhenVisible($isVisible)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.08))
            )
    }
}
