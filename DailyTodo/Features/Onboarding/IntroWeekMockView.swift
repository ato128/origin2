//
//  IntroMockWeekView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 23.03.2026.
//

import SwiftUI

struct IntroWeekMockView: View {
    let accent: Color
    let highlightStep: Int

    private let days = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
    private let selectedDay = 0

    private var isShowingCrewStyleArea: Bool {
        highlightStep >= 3
    }

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        topHeader
                            .id(0)

                        weekSwitcherCard
                            .id(1)

                        if !isShowingCrewStyleArea {
                            daySelector
                                .id(2)

                            todaySummaryCard
                                .id(3)

                            nowCard
                                .id(4)
                        } else {
                            crewWeekPreviewCard
                                .id(5)

                            sharedDayStrip
                                .id(6)

                            sharedPlanCard
                                .id(7)
                        }

                        Spacer(minLength: 50)
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
        case 3: target = 5
        default: target = 7
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

private extension IntroWeekMockView {
    var deviceShell: some View {
        ZStack {
            Color.black.opacity(0.95)

            LinearGradient(
                colors: [
                    Color.purple.opacity(0.12),
                    Color.blue.opacity(0.10),
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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Week")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(
                    isShowingCrewStyleArea
                    ? "Kendi haftan ve paylaşılan plan tek akışta."
                    : "Planını gün gün takip et, canlı dersi kaçırma."
                )
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            HStack(spacing: 10) {
                topCapsuleIcon("square.and.arrow.up")
                topCapsuleIcon("calendar")
                topCapsuleIcon("plus")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(0.14))
            )
            .overlay(
                Capsule()
                    .stroke(Color.blue.opacity(0.24), lineWidth: 1)
            )
        }
    }

    func topCapsuleIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
    }

    var weekSwitcherCard: some View {
        spotlight(active: highlightStep == 0, radius: 26) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Week View")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    Text(isShowingCrewStyleArea ? "Shared" : "Personal")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.07)))
                }

                HStack(spacing: 10) {
                    switchPill(
                        title: "My Week",
                        subtitle: "Derslerim",
                        selected: !isShowingCrewStyleArea,
                        tint: .blue
                    )

                    switchPill(
                        title: "Crew Week",
                        subtitle: "Paylaşılan akış",
                        selected: isShowingCrewStyleArea,
                        tint: .purple
                    )
                }

                Text(
                    isShowingCrewStyleArea
                    ? "Week alanı içinden ekip gününe geçiyormuş gibi gösteriliyor."
                    : "Kişisel haftandan ekibin gün akışına tek dokunuş hissi."
                )
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.64))
            }
            .padding(16)
            .background(cardBG(radius: 26))
        }
    }

    func switchPill(title: String, subtitle: String, selected: Bool, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.68))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(selected ? tint.opacity(0.18) : Color.white.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(selected ? tint.opacity(0.34) : Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    var daySelector: some View {
        spotlight(active: highlightStep == 1, radius: 24) {
            HStack(spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    VStack(spacing: 7) {
                        Text(day)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(index == selectedDay ? .white : .white.opacity(0.72))

                        Circle()
                            .fill(index == selectedDay ? .blue : .clear)
                            .frame(width: 7, height: 7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(index == selectedDay ? Color.white.opacity(0.11) : Color.white.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                index == selectedDay ? Color.white.opacity(0.10) : Color.white.opacity(0.04),
                                lineWidth: 1
                            )
                    )
                }
            }
            .padding(10)
            .background(cardBG(radius: 24))
        }
    }

    var todaySummaryCard: some View {
        spotlight(active: highlightStep == 2, radius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("Pzt")
                                .font(.system(size: 19, weight: .black, design: .rounded))
                                .foregroundStyle(.white)

                            miniPill("Bugün", tint: .blue)
                            miniPill("LIVE", tint: .green)
                        }

                        Text("Ders şu an aktif")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.70))
                    }

                    Spacer()

                    Text("1 sa")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }

                HStack(spacing: 10) {
                    summaryMiniCard(icon: "book.closed", title: "Ders", value: "1")
                    summaryMiniCard(icon: "sun.max", title: "İlk", value: "20:41")
                    summaryMiniCard(icon: "moon.stars", title: "Son", value: "21:41")
                }

                HStack {
                    Label {
                        Text("Math aktif")
                    } icon: {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)

                    Spacer()

                    Text("20:41 – 21:41")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.78))
                }
            }
            .padding(16)
            .background(cardBG(radius: 28))
        }
    }

    func summaryMiniCard(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.66))

            Text(value)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    var nowCard: some View {
        spotlight(active: highlightStep == 3, radius: 28) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Now")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.72))
                }

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.purple.opacity(0.24),
                                    Color.blue.opacity(0.16)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    HStack(alignment: .top, spacing: 12) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.purple.opacity(0.9))
                            .frame(width: 10)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Math")
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)

                                Text("Şu an")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(Color.purple.opacity(0.30)))
                                    .foregroundStyle(.purple.opacity(0.95))

                                Spacer()

                                Text("20:41 – 21:41")
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color.white.opacity(0.10)))
                                    .foregroundStyle(.white.opacity(0.95))
                            }

                            HStack {
                                Text("60 dk")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.72))
                                Spacer()
                            }

                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: 8)

                            HStack {
                                Text("%0")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.72))
                                Spacer()
                                Text("60 dk kaldı")
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(14)
                }
                .frame(height: 126)
            }
            .padding(16)
            .background(cardBG(radius: 28))
        }
    }

    var crewWeekPreviewCard: some View {
        spotlight(active: highlightStep == 3, radius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Crew Week")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Çizim ekibinin ortak planı")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.68))
                    }

                    Spacer()

                    Image(systemName: "person.3.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.green)
                }

                HStack(spacing: 10) {
                    crewMiniStat(title: "3", subtitle: "Task")
                    crewMiniStat(title: "2", subtitle: "Live")
                    crewMiniStat(title: "4h", subtitle: "Plan")
                }

                Text("Week alanından çıkmadan ekip akışına geçiş hissi.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(16)
            .background(cardBG(radius: 28))
        }
    }

    func crewMiniStat(title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.035))
        )
    }

    var sharedDayStrip: some View {
        spotlight(active: highlightStep == 4, radius: 24) {
            HStack(spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    VStack(spacing: 7) {
                        Text(day)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)

                        Circle()
                            .fill(index == 1 ? .green : Color.white.opacity(0.12))
                            .frame(width: 7, height: 7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(index == 1 ? Color.green.opacity(0.16) : Color.white.opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(index == 1 ? Color.green.opacity(0.28) : Color.white.opacity(0.04), lineWidth: 1)
                    )
                }
            }
            .padding(10)
            .background(cardBG(radius: 24))
        }
    }

    var sharedPlanCard: some View {
        spotlight(active: highlightStep >= 5, radius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Today in Çizim")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    Text("2 aktif")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.green.opacity(0.18)))
                }

                VStack(spacing: 10) {
                    sharedRow(
                        title: "Moodboard review",
                        time: "09:00 – 10:00",
                        status: "Done",
                        tint: .blue
                    )

                    sharedRow(
                        title: "Poster fixes",
                        time: "13:00 – 14:30",
                        status: "Live",
                        tint: .green
                    )

                    sharedRow(
                        title: "Asset export",
                        time: "18:00 – 19:00",
                        status: "Next",
                        tint: .orange
                    )
                }

                Text("Kişisel hafta görünümünden ekip gününe doğal geçiş.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.66))
            }
            .padding(16)
            .background(cardBG(radius: 28))
        }
    }

    func sharedRow(title: String, time: String, status: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)

                Text(time)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.66))
            }

            Spacer()

            Text(status)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(tint.opacity(0.16)))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
    }

    func miniPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(tint.opacity(0.18)))
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
                        .stroke(accent.opacity(0.85), lineWidth: 1.4)
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
