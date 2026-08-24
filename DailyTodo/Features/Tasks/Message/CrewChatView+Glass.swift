//
//  CrewChatView+Glass.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 29.03.2026.
//

import SwiftUI

extension CrewChatView {

    var glassCircleBackground: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        UpdoTheme.filmy(0.16),
                        UpdoTheme.filmy(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(Color(arenaHex: "#22232B"), in: Circle())
            .overlay(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                UpdoTheme.filmy(0.18),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Circle()
                    .stroke(UpdoTheme.filmy(0.16), lineWidth: 0.9)
            )
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                UpdoTheme.filmy(0.28),
                                Color.clear,
                                UpdoTheme.filmy(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
            )
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }

    var glassCapsuleBackground: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        UpdoTheme.filmy(0.15),
                        UpdoTheme.filmy(0.07)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(Color(arenaHex: "#22232B"), in: Capsule())
            .overlay(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                UpdoTheme.filmy(0.16),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Capsule()
                    .stroke(UpdoTheme.filmy(0.14), lineWidth: 0.9)
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                UpdoTheme.filmy(0.24),
                                Color.clear,
                                UpdoTheme.filmy(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
            )
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }

    func glassRoundedBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        UpdoTheme.filmy(0.14),
                        UpdoTheme.filmy(0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(
                Color(arenaHex: "#22232B"),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                UpdoTheme.filmy(0.16),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(UpdoTheme.filmy(0.14), lineWidth: 0.9)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                UpdoTheme.filmy(0.22),
                                Color.clear,
                                UpdoTheme.filmy(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
            )
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}
