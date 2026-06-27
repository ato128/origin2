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
        HStack(spacing: 0) {
            ForEach(FocusMode.allCases) { mode in
                let isSelected = selectedMode == mode

                Button {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                        selectedMode = mode
                    }
                } label: {
                    VStack(spacing: 9) {
                        HStack(spacing: 6) {
                            Image(systemName: icon(for: mode))
                                .font(.system(size: 12, weight: .black))

                            Text(mode.title)
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .tracking(0.2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.38))

                        ZStack {
                            Capsule()
                                .fill(Color.white.opacity(0.05))
                                .frame(height: 2.5)

                            if isSelected {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [accent(for: mode), secondaryAccent(for: mode)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(height: 2.5)
                                    .matchedGeometryEffect(id: "focus_mode_underline", in: namespace)
                                    .shadow(color: accent(for: mode).opacity(0.5), radius: 5, y: 1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
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
