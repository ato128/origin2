//
//  IntroInsightsMockView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 23.03.2026.
//

import SwiftUI

struct IntroInsightsMockView: View {
    let accent: Color
    let highlightStep: Int

    private let weekDays = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        topHeader
                            .id(0)

                        heroCard
                            .id(1)

                        gettingStartedCard
                            .id(2)

                        weeklyProgressCard
                            .id(3)

                        focusInsightsCard
                            .id(4)

                        scoresCard
                            .id(5)

                        coachCard
                            .id(6)

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                    .frame(minHeight: geo.size.height, alignment: .top)
                }
                .background(deviceShell)
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .onAppear {
                    scrollToCurrentStep(proxy: proxy, animated: false)
                }
                .onChange(of: highlightStep) { _, _ in
                    scrollToCurrentStep(proxy: proxy, animated: true)
                }
            }
        }
        .frame(height: 490)
    }

    private func scrollToCurrentStep(proxy: ScrollViewProxy, animated: Bool) {
        let target: Int

        switch highlightStep {
        case 0: target = 1
        case 1: target = 2
        case 2: target = 3
        case 3: target = 4
        default: target = 6
        }

        if animated {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                proxy.scrollTo(target, anchor: .center)
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                proxy.scrollTo(target, anchor: .center)
            }
        }
    }
}

private extension IntroInsightsMockView {
    var deviceShell: some View {
        ZStack {
            Color.black.opacity(0.95)

            LinearGradient(
                colors: [
                    Color.purple.opacity(0.12),
                    Color.blue.opacity(0.12),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.white.opacity(0.025))
        }
        .shadow(color: accent.opacity(0.14), radius: 18, y: 10)
    }

    var topHeader: some View {
        HStack {
            Text("Insights")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
        }
    }

    var heroCard: some View {
        spotlight(active: highlightStep == 0, radius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text("🔥")
                    Text("Great Job")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.76))
                }

                Text("Ana hedeflerin bitti. İstersen kısa bir ekstra focus açıp ritmi koru.")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text("New Focus")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.95))
                    )
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.16),
                                Color.blue.opacity(0.14)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
    }

    var gettingStartedCard: some View {
        spotlight(active: highlightStep == 1, radius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Getting Started")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Start your streak")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.68))
                    }

                    Spacer()

                    Text("Start your\nmomentum")
                        .font(.system(size: 11, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.white.opacity(0.07)))
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("%32")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("tamamlanma")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white.opacity(0.84))
                }

                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 10)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.blue)
                            .frame(width: 110, height: 10)
                    }

                HStack(spacing: 10) {
                    smallBadge(text: "3 gün seri", tint: .orange, bg: Color.orange.opacity(0.16))
                    smallBadge(text: "8 tamamlandı", tint: .green, bg: Color.green.opacity(0.15))
                }

                Text("Bu hafta ritmi başlattın. Küçük ama istikrarlı ilerleme güçlü bir temel oluşturuyor.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .background(cardBG(radius: 28))
        }
    }

    var weeklyProgressCard: some View {
        spotlight(active: highlightStep == 2, radius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weekly Progress")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Haftalık ritmin burada görünür")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.66))
                    }

                    Spacer()

                    Text("7 gün")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(weekDays.enumerated()), id: \.offset) { index, day in
                        VStack(spacing: 8) {
                            Capsule()
                                .fill(index == 0 ? Color.blue : (index == 2 ? Color.purple.opacity(0.85) : Color.white.opacity(0.08)))
                                .frame(height: 12)

                            Text(day)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.70))

                            Text(index == 0 ? "4" : index == 2 ? "2" : "0")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.56))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.purple.opacity(0.12),
                                    Color.blue.opacity(0.10)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .padding(18)
            .background(cardBG(radius: 28))
        }
    }

    var focusInsightsCard: some View {
        spotlight(active: highlightStep == 3, radius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Focus Insights")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.orange.opacity(0.20))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: "flame.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.orange)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("3 Günlük Focus Serisi")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Ritmi başlatabildiğin bir akış var")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.68))
                    }

                    Spacer()
                }

                HStack(spacing: 10) {
                    focusMini(title: "Today Focus", value: "92 dk", subtitle: "2 session")
                    focusMini(title: "Best Session", value: "48 dk", subtitle: "Deep work")
                }
            }
            .padding(18)
            .background(cardBG(radius: 28))
        }
    }

    func focusMini(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.68))

            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.66))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.blue.opacity(0.10))
        )
    }

    var scoresCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                scoreCard(title: "Productivity", value: "76", subtitle: "Güçlü tempo")
                scoreCard(title: "Consistency", value: "81", subtitle: "İyi düzen")
            }

            HStack(spacing: 12) {
                scoreCard(title: "Most Busy Day", value: "Pzt", subtitle: "4 sa 20 dk")
                scoreCard(title: "Completion", value: "%78", subtitle: "Bu hafta")
            }
        }
    }

    func scoreCard(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.72))

            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.66))
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .padding(14)
        .background(cardBG(radius: 24))
    }

    var coachCard: some View {
        spotlight(active: highlightStep >= 4, radius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.blue.opacity(0.16))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.blue)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Behavior Analysis")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.62))
                        Text("AI Productivity Coach")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }

                Text("Pzt ve Çar günleri daha verimli görünüyorsun. Zor görevleri bu günlere koymak tamamlanma oranını artırabilir.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.80))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    smallBadge(text: "Best day: Pzt", tint: .orange, bg: Color.orange.opacity(0.16))
                    smallBadge(text: "Focus peak: 20:00", tint: .blue, bg: Color.blue.opacity(0.16))
                }

                Text("View Week")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.95))
                    )
            }
            .padding(18)
            .background(cardBG(radius: 28))
        }
    }

    func smallBadge(text: String, tint: Color, bg: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(bg))
    }

    @ViewBuilder
    func spotlight<Content: View>(
        active: Bool,
        radius: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if active {
            content()
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(accent.opacity(0.82), lineWidth: 1.3)
                )
                .shadow(color: accent.opacity(0.18), radius: 10, y: 6)
        } else {
            content()
        }
    }

    func cardBG(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Color.white.opacity(0.045))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
    }
}
