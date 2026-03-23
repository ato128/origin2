//
//  IntroFlowView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.03.2026.
//

import SwiftUI

struct IntroFlowView: View {
    @AppStorage("didFinishIntroFlow") private var didFinishIntroFlow = false
    @State private var currentPage = 0

    private let pages: [IntroPage] = [
        IntroPage(
            title: "Your daily overview",
            subtitle: "See progress, focus, next class and quick actions from one premium home screen.",
            accent: .blue,
            style: .home
        ),
        IntroPage(
            title: "Own your week",
            subtitle: "Follow your daily schedule, live lesson flow and weekly structure clearly.",
            accent: .purple,
            style: .week
        ),
        IntroPage(
            title: "Build and focus together",
            subtitle: "Manage crews, shared tasks, members and group focus in one place.",
            accent: .green,
            style: .crew
        ),
        IntroPage(
            title: "Track your momentum",
            subtitle: "Understand your streak, weekly progress and overall rhythm with Insights.",
            accent: .orange,
            style: .insights
        )
    ]

    var body: some View {
        ZStack {
            introBackground

            VStack(spacing: 0) {
                topBar

                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        IntroPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                bottomControls
            }
        }
    }
}

// MARK: - Sections
private extension IntroFlowView {
    var topBar: some View {
        HStack {
            pageCounter

            Spacer()

            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    didFinishIntroFlow = true
                }
            } label: {
                HStack(spacing: 6) {
                    Text("Skip")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.84))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
    }

    var pageCounter: some View {
        HStack(spacing: 6) {
            Text("\(currentPage + 1)")
                .foregroundStyle(.white)

            Text("of")
                .foregroundStyle(Color.white.opacity(0.48))

            Text("\(pages.count)")
                .foregroundStyle(Color.white.opacity(0.72))
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    var bottomControls: some View {
        VStack(spacing: 18) {
            pageIndicator

            Button {
                if currentPage < pages.count - 1 {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                        currentPage += 1
                    }
                } else {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                        didFinishIntroFlow = true
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Text(currentPage == pages.count - 1 ? "Get Started" : "Continue")

                    Image(systemName: currentPage == pages.count - 1 ? "checkmark.circle.fill" : "arrow.right")
                        .font(.system(size: 18, weight: .bold))
                }
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 19)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: currentPage == pages.count - 1
                                ? [
                                    Color.green.opacity(0.95),
                                    Color.blue.opacity(0.95)
                                ]
                                : [
                                    Color.blue.opacity(0.97),
                                    Color.purple.opacity(0.97)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(
                    color: (currentPage == pages.count - 1 ? Color.green : Color.blue).opacity(0.22),
                    radius: 18,
                    y: 10
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 30)
        .background(bottomPanelBackground)
    }

    var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { index in
                Capsule()
                    .fill(
                        index == currentPage
                        ? AnyShapeStyle(.white)
                        : AnyShapeStyle(Color.white.opacity(0.16))
                    )
                    .frame(width: index == currentPage ? 32 : 8, height: 8)
                    .animation(.spring(response: 0.30, dampingFraction: 0.86), value: currentPage)
            }
        }
        .padding(.vertical, 2)
    }

    var bottomPanelBackground: some View {
        LinearGradient(
            colors: [
                Color.clear,
                Color.black.opacity(0.18),
                Color.black.opacity(0.34)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea(edges: .bottom)
    }

    var introBackground: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.purple.opacity(0.28),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 360
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.blue.opacity(0.24),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.white.opacity(0.04),
                    Color.clear
                ],
                center: .center,
                startRadius: 40,
                endRadius: 500
            )
            .blendMode(.screen)
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.white.opacity(0.015),
                    Color.clear,
                    Color.white.opacity(0.01)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.screen)
            .ignoresSafeArea()
        }
    }
}

struct IntroPage {
    let title: String
    let subtitle: String
    let accent: Color
    let style: IntroMockStyle
}

enum IntroMockStyle {
    case home
    case week
    case crew
    case insights
}
