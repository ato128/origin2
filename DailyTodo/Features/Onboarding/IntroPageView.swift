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
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            mockPreview
                .scaleEffect(animateCard ? 1 : 0.96)
                .opacity(animateCard ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.86), value: animateCard)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                Text(page.subtitle)
                    .font(.system(size: 16, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.horizontal, 24)
            }
            .rotation3DEffect(.degrees(Double(tilt.height / 10)), axis: (x: 1, y: 0, z: 0))
            .rotation3DEffect(.degrees(Double(-tilt.width / 10)), axis: (x: 0, y: 1, z: 0))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        tilt = value.translation
                    }
                    .onEnded { _ in
                        withAnimation(.spring()) {
                            tilt = .zero
                        }
                    }
            )

            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear {
            animateCard = true
        }
    }

    @ViewBuilder
    private var mockPreview: some View {
        switch page.style {
        case .homeNextClass:
            mockHomeNextClassCard
        case .liveWidget:
            mockLiveWidgetCard
        case .week:
            mockWeekCard
        case .weekCrew:
            mockWeekCrewCard
        case .crew:
            mockCrewCard
        case .friends:
            mockFriendsCard
        case .insights:
            mockInsightsCard
        }
    }

    private var shell: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }

    private var mockHomeNextClassCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Home")
                .font(.title.bold())
                .foregroundStyle(.white)

            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.08))
                .frame(height: 110)
                .overlay(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Today Progress")
                            .font(.headline.bold())

                        Capsule()
                            .fill(Color.white.opacity(0.14))
                            .frame(height: 8)

                        HStack(spacing: 8) {
                            badge("0 gün seri")
                            badge("0 bugün tamamlandı")
                        }
                    }
                    .foregroundStyle(.white)
                    .padding()
                }

            RoundedRectangle(cornerRadius: 24)
                .fill(page.accent.opacity(0.16))
                .frame(height: 132)
                .overlay(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Next Class")
                                .font(.headline.bold())

                            Spacer()

                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title3)
                        }

                        Text("Fizik")
                            .font(.system(size: 28, weight: .black, design: .rounded))

                        Text("20:11 – 21:11")
                            .foregroundStyle(.white.opacity(0.78))

                        HStack(spacing: 8) {
                            badge("LIVE")
                            Text("Şu an aktif • 59 dk kaldı")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding()
                }

            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.06))
                .frame(height: 82)
                .overlay(alignment: .leading) {
                    HStack {
                        Text("Quick Actions")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                        Spacer()
                        HStack(spacing: 8) {
                            quickBubble(icon: "plus")
                            quickBubble(icon: "calendar")
                            quickBubble(icon: "chart.bar.fill")
                        }
                    }
                    .padding()
                }
        }
        .padding(20)
        .background(shell)
    }
    
    private var mockLiveWidgetCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Live + Widget")
                .font(.title.bold())
                .foregroundStyle(.white)

            VStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 86)
                    .overlay(alignment: .leading) {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Bugün")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.72))

                                Text("5")
                                    .font(.system(size: 26, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                            }

                            Spacer()

                            VStack(alignment: .leading, spacing: 6) {
                                Text("İlk")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.72))

                                Text("08:30")
                                    .font(.headline.bold())
                                    .foregroundStyle(.white)
                            }

                            Spacer()

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Son")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.72))

                                Text("16:20")
                                    .font(.headline.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                RoundedRectangle(cornerRadius: 24)
                    .fill(page.accent.opacity(0.16))
                    .frame(height: 112)
                    .overlay(alignment: .leading) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("CMPE201")
                                    .font(.headline.bold())

                                Spacer()

                                Text("12:30 – 14:20")
                                    .font(.subheadline.weight(.bold))
                            }

                            Text("Şu an aktif")
                                .foregroundStyle(.white.opacity(0.78))

                            Capsule()
                                .fill(Color.white.opacity(0.14))
                                .frame(height: 8)
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(page.accent)
                                        .frame(width: 170, height: 8)
                                }

                            HStack(spacing: 8) {
                                badge("LIVE")
                                Text("59 dk kaldı")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.78))
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(16)
                    }
            }
        }
        .padding(20)
        .background(shell)
    }

    private var mockWeekCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Week")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .overlay(
                    Text("Week")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(page.accent)
                        .opacity(0.6)
                        .blur(radius: 12)
                )
                .scaleEffect(pulse ? 1.05 : 1.0)
                .animation(
                    .easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true),
                    value: pulse
                )
                .onAppear {
                    pulse = true
                }
            HStack(spacing: 8) {
                Image(systemName: "hand.point.up.left.fill")
                    .foregroundStyle(page.accent)

                Text("Tap here to switch to Crew")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(page.accent)
            }
            .padding(.top, 2)

            HStack(spacing: 10) {
                ForEach(["Pzt", "Sal", "Çar", "Per", "Cum"], id: \.self) { day in
                    VStack(spacing: 8) {
                        Text(day)
                            .font(.caption.bold())
                        Text(day == "Çar" ? "18" : "17")
                            .font(.headline.bold())
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(day == "Çar" ? 0.14 : 0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }

            RoundedRectangle(cornerRadius: 22)
                .fill(page.accent.opacity(0.18))
                .frame(height: 112)
                .overlay(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("Çar")
                                .font(.headline.bold())
                            Text("Bugün")
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.blue.opacity(0.2)))
                        }
                        Text("5 ders • 7 sa 45 dk")
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .foregroundStyle(.white)
                    .padding()
                }
        }
        .padding(20)
        .background(shell)
    }

    private var mockWeekCrewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text("Week")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Image(systemName: "arrow.right")
                    .foregroundStyle(page.accent)

                Text("Crew")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(page.accent)
            }

            Text("Tap the title area to switch views")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))

            HStack(spacing: 10) {
                tabPill("Personal", selected: false)
                tabPill("Crew", selected: true)
            }

            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.08))
                .frame(height: 132)
                .overlay(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Crew Week")
                            .font(.headline.bold())

                        Text("Shared schedule, crew tasks and common planning in one place.")
                            .foregroundStyle(.white.opacity(0.72))

                        HStack(spacing: 8) {
                            badge("3 shared tasks")
                            badge("2 active")
                            badge("1 focus room")
                        }
                    }
                    .foregroundStyle(.white)
                    .padding()
                }
        }
        .padding(20)
        .background(shell)
    }

    private var mockCrewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Crew")
                .font(.title.bold())
                .foregroundStyle(.white)

            RoundedRectangle(cornerRadius: 22)
                .fill(page.accent.opacity(0.18))
                .frame(height: 110)
                .overlay(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Design Crew")
                            .font(.headline.bold())
                        Text("Create crews, assign work and start shared focus.")
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .foregroundStyle(.white)
                    .padding()
                }

            HStack(spacing: 12) {
                actionBox("Shared Task")
                actionBox("Focus Together")
            }
        }
        .padding(20)
        .background(shell)
    }

    private var mockFriendsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Friends")
                .font(.title.bold())
                .foregroundStyle(.white)

            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.08))
                .frame(height: 95)
                .overlay(alignment: .leading) {
                    HStack {
                        Circle()
                            .fill(page.accent.opacity(0.22))
                            .frame(width: 46, height: 46)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(page.accent)
                            }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Atakan")
                                .font(.headline.bold())
                            Text("This week: 8 items")
                                .foregroundStyle(.white.opacity(0.72))
                        }

                        Spacer()

                        Image(systemName: "message.fill")
                            .foregroundStyle(page.accent)
                    }
                    .padding()
                }

            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.06))
                .frame(height: 88)
                .overlay(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Shared schedules and direct chat")
                            .font(.headline.bold())
                        Text("Check their week and talk instantly.")
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .foregroundStyle(.white)
                    .padding()
                }
        }
        .padding(20)
        .background(shell)
    }

    private var mockInsightsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Insights")
                .font(.title.bold())
                .foregroundStyle(.white)

            RoundedRectangle(cornerRadius: 22)
                .fill(page.accent.opacity(0.18))
                .frame(height: 118)
                .overlay(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("%78 completion")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                        Text("Weekly Progress")
                            .font(.headline.bold())
                        Text("See streaks, completed work and momentum.")
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .foregroundStyle(.white)
                    .padding()
                }

            HStack(spacing: 10) {
                miniStat("7 gün", subtitle: "streak")
                miniStat("24", subtitle: "done")
                miniStat("4.8h", subtitle: "focus")
            }
        }
        .padding(20)
        .background(shell)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
    }

    private func tabPill(_ text: String, selected: Bool) -> some View {
        Text(text)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(selected ? page.accent.opacity(0.22) : Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func actionBox(_ title: String) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.white.opacity(0.06))
            .frame(height: 80)
            .overlay {
                Text(title)
                    .font(.headline.bold())
                    .foregroundStyle(.white)
            }
    }

    private func miniStat(_ value: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.headline.bold())
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func quickBubble(icon: String) -> some View {
        Circle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 34, height: 34)
            .overlay {
                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }
    }
}
