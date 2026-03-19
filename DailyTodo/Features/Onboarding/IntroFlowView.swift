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
            subtitle: "See your progress, focus status, next class and today’s tasks in one clean screen.",
            accent: .blue,
            style: .homeNextClass
        ),
        IntroPage(
            title: "Live across the system",
            subtitle: "Your week can stay visible from widgets and live activities while you keep going.",
            accent: .cyan,
            style: .liveWidget
        ),
        IntroPage(
            title: "Own your week",
            subtitle: "Use Week to see your schedule, daily summary and your full weekly structure.",
            accent: .purple,
            style: .week
        ),
        IntroPage(
            title: "Switch to Crew week",
            subtitle: "Tap the Week title area to move from your personal week into shared crew planning.",
            accent: .indigo,
            style: .weekCrew
        ),
        IntroPage(
            title: "Build and focus together",
            subtitle: "Create a crew, assign shared tasks and start focus sessions together.",
            accent: .green,
            style: .crew
        ),
        IntroPage(
            title: "Stay connected",
            subtitle: "In Friends, you can check a friend’s week and talk with them directly.",
            accent: .blue,
            style: .friends
        ),
        IntroPage(
            title: "Track your progress",
            subtitle: "Insights helps you understand your stats, streaks and weekly momentum.",
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

    private var topBar: some View {
        HStack {
            Spacer()

            Button {
                didFinishIntroFlow = true
            } label: {
                Text("Skip")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var bottomControls: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? Color.white : Color.white.opacity(0.18))
                        .frame(width: index == currentPage ? 28 : 8, height: 8)
                        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: currentPage)
                }
            }

            Button {
                if currentPage < pages.count - 1 {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        currentPage += 1
                    }
                } else {
                    didFinishIntroFlow = true
                }
            } label: {
                HStack(spacing: 10) {
                    Text(currentPage == pages.count - 1 ? "Let’s Go" : "Continue")
                    Image(systemName: currentPage == pages.count - 1 ? "checkmark.circle.fill" : "arrow.right")
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: currentPage == pages.count - 1
                                ? [Color.green, Color.blue]
                                : [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 34)
    }

    private var introBackground: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            RadialGradient(
                colors: [Color.purple.opacity(0.24), Color.clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 340
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.blue.opacity(0.22), Color.clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 380
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [Color.white.opacity(0.02), Color.clear, Color.white.opacity(0.01)],
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
    case homeNextClass
    case liveWidget
    case week
    case weekCrew
    case crew
    case friends
    case insights
}
