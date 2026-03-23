//
//  IntroPageView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.03.2026.
//

import SwiftUI

struct IntroPageView: View {
    let page: IntroPage

    @State private var animateCard = false
    @State private var tilt: CGSize = .zero
    @State private var highlightStep = 0
    @State private var highlightTimer: Timer?

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 6)

            mockStage
                .scaleEffect(animateCard ? 1 : 0.975)
                .opacity(animateCard ? 1 : 0)
                .rotation3DEffect(.degrees(Double(tilt.height / 24)), axis: (x: 1, y: 0, z: 0))
                .rotation3DEffect(.degrees(Double(-tilt.width / 24)), axis: (x: 0, y: 1, z: 0))
                .animation(.spring(response: 0.55, dampingFraction: 0.86), value: animateCard)
                .gesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { value in
                            tilt = CGSize(
                                width: value.translation.width * 0.24,
                                height: value.translation.height * 0.24
                            )
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                                tilt = .zero
                            }
                        }
                )

            copySection

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .onAppear {
            animateCard = true
            startHighlightLoop()
        }
        .onDisappear {
            highlightTimer?.invalidate()
            highlightTimer = nil
        }
        .onChange(of: page.style) { _, _ in
            startHighlightLoop()
        }
    }
}

// MARK: - Sections
private extension IntroPageView {
    var mockStage: some View {
        ZStack {
            stageGlow
            deviceFrame
        }
        .frame(maxWidth: .infinity)
    }

    var stageGlow: some View {
        ZStack {
            Circle()
                .fill(page.accent.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 34)
                .offset(y: 12)

            Circle()
                .fill(Color.white.opacity(0.03))
                .frame(width: 240, height: 240)
                .blur(radius: 20)
                .offset(y: 8)
        }
    }

    var deviceFrame: some View {
        premiumMockPreview
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.07),
                                Color.white.opacity(0.035)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 38, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .shadow(color: page.accent.opacity(0.16), radius: 24, y: 14)
            .shadow(color: .black.opacity(0.30), radius: 20, y: 12)
    }

    var copySection: some View {
        VStack(spacing: 12) {
            Text(page.title)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.9)

            Text(page.subtitle)
                .font(.system(size: 17, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.white.opacity(0.72))
                .padding(.horizontal, 14)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    var premiumMockPreview: some View {
        switch page.style {
        case .home:
            IntroHomeMockView(
                accent: page.accent,
                highlightStep: highlightStep
            )

        case .week:
            IntroWeekMockView(
                accent: page.accent,
                highlightStep: highlightStep
            )

        case .crew:
            IntroCrewMockView(
                accent: page.accent,
                highlightStep: highlightStep
            )

        case .insights:
            IntroInsightsMockView(
                accent: page.accent,
                highlightStep: highlightStep
            )
        }
    }
}

// MARK: - Timer
private extension IntroPageView {
    func startHighlightLoop() {
        highlightTimer?.invalidate()
        highlightTimer = nil
        highlightStep = 0

        let maxStep = maxHighlightStep(for: page.style)
        let interval = highlightInterval(for: page.style)

        highlightTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            withAnimation(.spring(response: 0.40, dampingFraction: 0.86)) {
                if highlightStep >= maxStep {
                    highlightStep = 0
                } else {
                    highlightStep += 1
                }
            }
        }
    }

    func maxHighlightStep(for style: IntroMockStyle) -> Int {
        switch style {
        case .home:
            return 3
        case .week:
            return 5
        case .crew:
            return 4
        case .insights:
            return 5
        }
    }

    func highlightInterval(for style: IntroMockStyle) -> Double {
        switch style {
        case .home:
            return 1.45
        case .week:
            return 1.55
        case .crew:
            return 1.55
        case .insights:
            return 1.6
        }
    }
}
