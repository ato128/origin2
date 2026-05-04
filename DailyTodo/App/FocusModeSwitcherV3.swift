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

    var body: some View {
        HStack(spacing: 7) {
            ForEach(FocusMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                        selectedMode = mode
                    }
                } label: {
                    ZStack {
                        if selectedMode == mode {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            accent(for: mode),
                                            secondaryAccent(for: mode)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .matchedGeometryEffect(id: "focus_mode_bg", in: namespace)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color.white.opacity(0.13), lineWidth: 1)
                                )
                                .shadow(
                                    color: accent(for: mode).opacity(0.22),
                                    radius: 14,
                                    y: 7
                                )
                        }

                        HStack(spacing: 7) {
                            Image(systemName: icon(for: mode))
                                .font(.system(size: 13, weight: .black))

                            Text(mode.title)
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .tracking(selectedMode == mode ? 0.2 : 0)
                                .lineLimit(1)
                        }
                        .foregroundStyle(selectedMode == mode ? .black : .white.opacity(0.48))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(arenaHex: AppArenaPalette.blue).opacity(0.055),
                            Color(arenaHex: AppArenaPalette.purple).opacity(0.040),
                            Color.white.opacity(0.030)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.080), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.22), radius: 14, y: 7)
        )
    }

    private func icon(for mode: FocusMode) -> String {
        switch mode {
        case .personal:
            return "person.fill"
        case .crew:
            return "person.3.fill"
        case .friend:
            return "person.2.fill"
        }
    }

    private func accent(for mode: FocusMode) -> Color {
        switch mode {
        case .personal:
            return Color(arenaHex: AppArenaPalette.cyan)
        case .crew:
            return Color(arenaHex: AppArenaPalette.coral)
        case .friend:
            return Color(arenaHex: AppArenaPalette.purple)
        }
    }

    private func secondaryAccent(for mode: FocusMode) -> Color {
        switch mode {
        case .personal:
            return Color(arenaHex: AppArenaPalette.purple)
        case .crew:
            return Color(arenaHex: AppArenaPalette.gold)
        case .friend:
            return Color(arenaHex: AppArenaPalette.blue)
        }
    }
}
