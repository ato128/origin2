//
//  OnboardingView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("didFinishOnboarding") private var didFinishOnboarding: Bool = false
    @State private var page: Int = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                TabView(selection: $page) {
                    OnboardingPage(
                        symbol: "checklist",
                        title: "Gününü sadeleştir",
                        subtitle: "Görevlerini ekle, önceliklendir, bitirdikçe rahatla.",
                        tint: .blue
                    )
                    .tag(0)

                    OnboardingPage(
                        symbol: "hand.tap",
                        title: "Swipe + Haptic",
                        subtitle: "Sil, tamamla, düzenle. Hepsi iOS gibi akıcı ve hissiyatlı.",
                        tint: .purple
                    )
                    .tag(1)

                    OnboardingPage(
                        symbol: "rectangle.3.group.bubble.left",
                        title: "Widget ile hızlı kontrol",
                        subtitle: "Ana ekrandan görevleri gör, tek dokunuşla aç.",
                        tint: .green
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: page)

                footer
            }
            .padding(.top, 8)
        }
    }

    private var header: some View {
        HStack {
            Text("DailyTodo")
                .font(.system(size: 22, weight: .semibold, design: .rounded))

            Spacer()

            Button {
                hapticImpact(.light)
                finish()
            } label: {
                Text("Atla")
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                hapticImpact(.medium)
                if page < 2 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        page += 1
                    }
                } else {
                    finish()
                }
            } label: {
                HStack {
                    Text(page < 2 ? "Devam" : "Başla")
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Image(systemName: page < 2 ? "chevron.right" : "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .padding(.horizontal, 20)

            Text("Devam ederek gizlilik politikasını kabul etmiş olursun.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.bottom, 14)
        }
        .padding(.top, 6)
    }

    private func finish() {
        hapticNotify(.success)
        withAnimation(.easeInOut(duration: 0.25)) {
            didFinishOnboarding = true
        }
    }

    // MARK: - Haptics
    private func hapticImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let g = UIImpactFeedbackGenerator(style: style)
        g.prepare()
        g.impactOccurred()
    }

    private func hapticNotify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let g = UINotificationFeedbackGenerator()
        g.prepare()
        g.notificationOccurred(type)
    }
}

private struct OnboardingPage: View {
    let symbol: String
    let title: String
    let subtitle: String
    let tint: Color

    @State private var appear = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 24)

            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 150, height: 150)

                Image(systemName: symbol)
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(tint)
                    .scaleEffect(appear ? 1 : 0.92)
                    .opacity(appear ? 1 : 0.5)
            }
            .padding(.top, 18)
            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: appear)

            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .offset(y: appear ? 0 : 8)
            .opacity(appear ? 1 : 0)
            .animation(.easeOut(duration: 0.35), value: appear)

            Spacer()
        }
        .onAppear { appear = true }
        .onDisappear { appear = false }
        .padding(.bottom, 10)
    }
}
