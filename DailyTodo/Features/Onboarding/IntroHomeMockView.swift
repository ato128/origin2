//
//  IntroMockHomeView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 22.03.2026.
//

import SwiftUI

struct IntroHomeMockView: View {
    let accent: Color
    let highlightStep: Int

    private let dayTitles = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
    private let selectedDay = 6

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        headerCard
                            .id(100)

                        miniWeekCard
                            .id(101)

                        progressCard
                            .id(0)

                        focusCard
                            .id(1)

                        nextClassCard
                            .id(2)

                        todayTasksCard
                            .id(102)

                        rhythmCard
                            .id(103)

                        quickActionsCard
                            .id(3)

                        Spacer(minLength: 110)
                    }
                    .padding(16)
                    .frame(minHeight: geo.size.height, alignment: .top)
                }
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                .background(deviceShell)
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .onAppear {
                    scrollToStep(proxy: proxy, animated: false)
                }
                .onChange(of: highlightStep) { _, _ in
                    scrollToStep(proxy: proxy, animated: true)
                }
            }
        }
        .frame(maxWidth: 390)
    }

    private func scrollToStep(proxy: ScrollViewProxy, animated: Bool) {
        let target = highlightStep

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

// MARK: - Main Sections
private extension IntroHomeMockView {
    var deviceShell: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.06),
                            Color.white.opacity(0.025)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.035),
                            Color.clear,
                            Color.black.opacity(0.08)
                        ],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
        }
        .shadow(color: accent.opacity(0.14), radius: 20, y: 12)
        .shadow(color: .black.opacity(0.22), radius: 16, y: 10)
    }

    var headerCard: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Good evening")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("22 Mart, Pazar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.60))

                Text("Stay productive today 🚀")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.74))
            }

            Spacer(minLength: 12)

            HStack(spacing: 7) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("Friends")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.07))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroCardBackground(cornerRadius: 28))
    }

    var miniWeekCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("This Week")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.76))

                Spacer()

                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "calendar")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }

            HStack(spacing: 8) {
                ForEach(Array(dayTitles.enumerated()), id: \.offset) { index, day in
                    dayCell(index: index, day: day)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(secondaryCardBackground(cornerRadius: 24))
    }

    var progressCard: some View {
        spotlight(isActive: highlightStep == 0, cornerRadius: 26) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Today Progress")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer()

                    Text("0/0")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }

                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 10)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(accent)
                            .frame(width: 0, height: 10)
                    }

                HStack(spacing: 8) {
                    miniBadge(icon: "flame.fill", text: "0 gün seri", tint: .orange)
                    miniBadge(icon: "checkmark.circle.fill", text: "0 bugün tamamlandı", tint: .green)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(heroCardBackground(cornerRadius: 26))
        }
    }

    var focusCard: some View {
        spotlight(isActive: highlightStep == 1, cornerRadius: 26) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(accent)
                            .frame(width: 8, height: 8)

                        Text("Focus Running")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Text("24:52")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }

                Text("Çizim Focus")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 10)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(accent)
                            .frame(width: 44, height: 10)
                    }

                HStack(spacing: 8) {
                    miniBadge(icon: "timer", text: "Odak aktif", tint: accent)
                    miniBadge(icon: "scope", text: "Devam", tint: .green)
                }

                HStack(spacing: 12) {
                    largeActionButton(
                        title: "Open Focus",
                        fill: accent.opacity(0.96),
                        textColor: .white
                    )

                    largeActionButton(
                        title: "Pause",
                        fill: Color.orange.opacity(0.16),
                        textColor: .orange
                    )
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(focusBackground)
        }
    }

    var nextClassCard: some View {
        spotlight(isActive: highlightStep == 2, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Next Class")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.red.opacity(0.92))

                    Spacer()

                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 38, height: 38)
                        .overlay(
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        )
                }

                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(Color.red.opacity(0.92))
                        .frame(width: 12, height: 12)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Fizik")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(Color.red.opacity(0.92))

                        Text("18:00 – 23:00")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.70))

                        HStack(spacing: 8) {
                            Text("LIVE")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.green.opacity(0.18))
                                )
                                .foregroundStyle(.green)

                            Text("Şu an aktif • 122 dk kaldı")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.70))
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(nextClassBackground)
        }
    }

    var todayTasksCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Today Tasks")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                Text("0 gösteriliyor")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.64))
            }

            Text("Bugün için aktif task yok.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.72))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(secondaryCardBackground(cornerRadius: 24))
    }

    var rhythmCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ritim korunabilir")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)

            Text("Küçük bir görevi tamamlayarak güne akış kazandırabilirsin.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(secondaryCardBackground(cornerRadius: 24))
    }

    var quickActionsCard: some View {
        spotlight(isActive: highlightStep == 3, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Quick Actions")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    quickActionButton(title: "Add Task", systemImage: "plus.circle.fill")
                    quickActionButton(title: "Week", systemImage: "calendar")
                    quickActionButton(title: "Insights", systemImage: "chart.bar.fill")
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(secondaryCardBackground(cornerRadius: 24))
        }
    }
}

// MARK: - Helpers
private extension IntroHomeMockView {
    @ViewBuilder
    func spotlight<Content: View>(
        isActive: Bool,
        cornerRadius: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if isActive {
            content()
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(accent.opacity(0.88), lineWidth: 1.3)
                )
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(accent.opacity(0.06))
                )
                .shadow(color: accent.opacity(0.22), radius: 12, y: 6)
                .scaleEffect(1.01)
                .animation(.spring(response: 0.36, dampingFraction: 0.86), value: isActive)
        } else {
            content()
                .scaleEffect(1.0)
                .animation(.spring(response: 0.36, dampingFraction: 0.86), value: isActive)
        }
    }

    func dayCell(index: Int, day: String) -> some View {
        let isSelected = index == selectedDay

        return VStack(spacing: 5) {
            Text(day)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isSelected ? .white : Color.white.opacity(0.66))

            Text(isSelected ? "22" : "\(16 + index)")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Circle()
                .fill(isSelected ? accent : Color.white.opacity(0.12))
                .frame(width: 6, height: 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? accent.opacity(0.18) : Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isSelected ? accent.opacity(0.30) : Color.white.opacity(0.05),
                    lineWidth: 1
                )
        )
    }

    func quickActionButton(title: String, systemImage: String) -> some View {
        VStack(spacing: 10) {
            Circle()
                .fill(accent.opacity(0.16))
                .frame(width: 42, height: 42)
                .overlay(
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(accent)
                )

            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    func largeActionButton(title: String, fill: Color, textColor: Color) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(fill)
            )
            .foregroundStyle(textColor)
    }

    func miniBadge(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))

            Text(text)
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(tint.opacity(0.15))
        )
        .foregroundStyle(tint)
    }

    func heroCardBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.055))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
    }

    func secondaryCardBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.038))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
    }

    var focusBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(Color.white.opacity(0.048))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(accent.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(accent.opacity(0.18), lineWidth: 1)
            )
    }

    var nextClassBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white.opacity(0.048))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.red.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.red.opacity(0.16), lineWidth: 1)
            )
    }
}
