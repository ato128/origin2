//
//  EmptyStateView.swift
//  DailyTodo
//
//  Reusable empty-state for lists and dashboards.
//  Follows the Updo design system: deep navy surfaces, cyan/purple accents,
//  SF Rounded numerals, no emoji.
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var accent: Color = Color(arenaHex: "#22D3EE")
    var ctaTitle: String? = nil
    var ctaAction: (() -> Void)? = nil

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.10))
                    .frame(width: 84, height: 84)

                Image(systemName: icon)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(arenaHex: "#EEF4FF"))

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(arenaHex: "#64748B"))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)

            if let ctaTitle, let ctaAction {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    ctaAction()
                } label: {
                    Text(ctaTitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 11)
                        .background(accent, in: Capsule())
                }
                .buttonStyle(UpdoPressButtonStyle())
                .padding(.top, 4)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
        .onAppear {
            guard !appeared else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                appeared = true
            }
        }
    }
}

// MARK: - Press scale button style (0.96, spring back)

struct UpdoPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
