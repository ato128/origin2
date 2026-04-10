//
//  FocusModeSwitcherV3.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 9.04.2026.
//

import SwiftUI

struct FocusModeSwitcherV3: View {
    @Binding var selectedMode: FocusMode
    @Namespace private var namespace

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    var body: some View {
        HStack(spacing: 8) {
            ForEach(FocusMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                        selectedMode = mode
                    }
                } label: {
                    ZStack {
                        if selectedMode == mode {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.11),
                                            Color.white.opacity(0.045)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .matchedGeometryEffect(id: "focus_mode_bg", in: namespace)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.10),
                                                    Color.white.opacity(0.035)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                        }

                        Text(mode.title)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                selectedMode == mode
                                ? palette.primaryText.opacity(0.98)
                                : palette.secondaryText.opacity(0.82)
                            )
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.025),
                            Color.white.opacity(0.01),
                            Color.black.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.16))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.045), lineWidth: 1)
                )
        )
    }
}
