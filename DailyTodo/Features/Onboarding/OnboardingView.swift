//
//  OnboardingView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//
import SwiftUI

struct OnboardingView: View {
    @AppStorage("didFinishOnboarding") private var didFinishOnboarding = false

    @State private var currentPage = 0
    @State private var showFinishBurst = false
    @State private var animateFinalButton = false

    var body: some View {
        ZStack {
            onboardingBackground

            VStack(spacing: 0) {
                topBar

                TabView(selection: $currentPage) {
                    OnboardingPageView(
                        title: "Welcome to DailyTodo",
                        subtitle: "Plan your day, stay focused and build momentum with a beautiful productivity system.",
                        icon: "checklist",
                        accent: .blue,
                        isFinalPage: false,
                        features: [
                            ("sparkles", "Beautiful planning"),
                            ("timer", "Focus sessions"),
                            ("person.3.fill", "Crew productivity")
                        ]
                    )
                    .scaleEffect(currentPage == 0 ? 1.0 : 0.96)
                    .opacity(currentPage == 0 ? 1 : 0.72)
                    .animation(.easeInOut(duration: 0.35), value: currentPage)
                    .tag(0)

                    OnboardingPageView(
                        title: "Stay Focused",
                        subtitle: "Start focus sessions, track progress and turn your tasks into real deep work.",
                        icon: "timer",
                        accent: .orange,
                        isFinalPage: false,
                        features: [
                            ("timer", "Timed sessions"),
                            ("chart.line.uptrend.xyaxis", "Track progress"),
                            ("dumbbell.fill", "Workout focus")
                        ]
                    )
                    .scaleEffect(currentPage == 1 ? 1.0 : 0.96)
                    .opacity(currentPage == 1 ? 1 : 0.72)
                    .animation(.easeInOut(duration: 0.35), value: currentPage)
                    .tag(1)

                    OnboardingPageView(
                        title: "How DailyTodo Works",
                        subtitle: "Create tasks, plan them in your week, then use focus sessions to get them done.",
                        icon: "arrow.triangle.branch",
                        accent: .green,
                        isFinalPage: false,
                        features: [
                            ("checkmark.circle", "Add tasks"),
                            ("calendar", "Plan your week"),
                            ("timer", "Complete with focus")
                        ]
                    )
                    .scaleEffect(currentPage == 2 ? 1.0 : 0.96)
                    .opacity(currentPage == 2 ? 1 : 0.72)
                    .animation(.easeInOut(duration: 0.35), value: currentPage)
                    .tag(2)

                    OnboardingPageView(
                        title: "Work Together",
                        subtitle: "Create crews, share tasks and stay productive with your friends or team.",
                        icon: "person.3.fill",
                        accent: .purple,
                        isFinalPage: true,
                        features: [
                            ("person.2.wave.2.fill", "Shared focus"),
                            ("bubble.left.and.bubble.right.fill", "Friend chat"),
                            ("person.3.fill", "Crew productivity")
                        ]
                    )
                    .scaleEffect(currentPage == 3 ? 1.0 : 0.96)
                    .opacity(currentPage == 3 ? 1 : 0.72)
                    .animation(.easeInOut(duration: 0.35), value: currentPage)
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                bottomControls
            }
        }
        .onChange(of: currentPage) { _, newValue in
            showFinishBurst = false
            animateFinalButton = (newValue == 3)
        }
        .onAppear {
            animateFinalButton = (currentPage == 3)
        }
    }

    private var topBar: some View {
        HStack {
            Spacer()

            if currentPage < 3 {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        didFinishOnboarding = true
                    }
                } label: {
                    Text("Skip")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var bottomControls: some View {
        VStack(spacing: 22) {
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? Color.white : Color.white.opacity(0.18))
                        .frame(width: index == currentPage ? 28 : 8, height: 8)
                        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: currentPage)
                }
            }

            Button {
                if currentPage < 3 {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        currentPage += 1
                    }
                } else {
                    showFinishBurst = true

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            didFinishOnboarding = true
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Text(currentPage == 3 ? "Start Using DailyTodo" : "Continue")

                    Image(systemName: currentPage == 3
                          ? "checkmark.circle.fill"
                          : "arrow.right")
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue,
                                    Color.purple
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .scaleEffect(currentPage == 3 && animateFinalButton ? 1.05 : 1.0)
                .shadow(
                    color: currentPage == 3
                    ? Color.purple.opacity(0.35)
                    : Color.blue.opacity(0.24),
                    radius: 18,
                    y: 6
                )
                .overlay {
                    if currentPage == 3 && showFinishBurst {
                        SparkleBurstOverlay()
                            .clipShape(Capsule())
                    }
                }
            }
            .buttonStyle(.plain)
            .animation(
                currentPage == 3
                ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                : .easeOut(duration: 0.2),
                value: animateFinalButton
            )
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 34)
    }

    private var onboardingBackground: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.purple.opacity(0.32),
                    Color.clear
                ],
                center: currentPage == 0 ? .topLeading : (currentPage == 1 ? .top : .leading),
                startRadius: 0,
                endRadius: 320
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.6), value: currentPage)

            RadialGradient(
                colors: [
                    Color.blue.opacity(0.26),
                    Color.clear
                ],
                center: currentPage == 3 ? .topTrailing : .trailing,
                startRadius: 20,
                endRadius: 380
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.6), value: currentPage)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.018),
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

private struct SparkleBurstOverlay: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 2) ? Color.white : Color.blue)
                    .frame(width: 6, height: 6)
                    .offset(y: animate ? -36 : 0)
                    .rotationEffect(.degrees(Double(index) * 36))
                    .scaleEffect(animate ? 1 : 0.2)
                    .opacity(animate ? 0 : 1)
                    .animation(
                        .easeOut(duration: 0.55)
                            .delay(Double(index) * 0.015),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }
}
