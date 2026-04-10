//
//  FloatingFocusBubble.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 10.04.2026.
//

import SwiftUI

struct FloatingFocusBubble: View {
    @EnvironmentObject var focusSession: FocusSessionManager

    @State private var topOffset: CGFloat = 0

    var body: some View {
        Group {
            if focusSession.isSessionActive && focusSession.isMinimized {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.14), lineWidth: 3.5)

                        Circle()
                            .trim(from: 0, to: max(0.02, focusSession.progress))
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.96),
                                        bubbleTint.opacity(0.92)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 22, height: 22)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(focusSession.bubbleTitle)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.95))
                            .lineLimit(1)

                        Text(focusSession.bubbleSubtitle)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.68))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 40)
                .background(
                    ZStack {
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.58))

                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial.opacity(0.35))
                    }
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
                .padding(.trailing, 16)
                .padding(.top, 56 + topOffset)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        topOffset = 0
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .transition(.move(edge: .top).combined(with: .opacity))
                .offset(y: focusSession.isPaused ? 0 : -2)
                .animation(
                    .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                    value: focusSession.isPaused
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        focusSession.expandSession()
                    }
                }
            }
        }
    }

    private var bubbleTint: Color {
        switch focusSession.selectedMode {
        case .personal:
            return Color(red: 0.74, green: 0.86, blue: 1.0)
        case .crew:
            return Color(red: 1.0, green: 0.80, blue: 0.82)
        case .friend:
            return Color(red: 0.92, green: 0.84, blue: 1.0)
        }
    }
}
