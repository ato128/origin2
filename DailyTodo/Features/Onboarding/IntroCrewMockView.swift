//
//  IntroCrewMockView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 23.03.2026.
//

import SwiftUI

struct IntroCrewMockView: View {
    let accent: Color
    let highlightStep: Int

    private var showingFriendsTab: Bool {
        highlightStep >= 3
    }

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        topHeader
                            .id(0)

                        segmentedToggle
                            .id(1)

                        if !showingFriendsTab {
                            overviewCard
                                .id(2)

                            crewCard
                                .id(3)
                        } else {
                            friendsSummaryCard
                                .id(4)

                            emptyFriendsCard
                                .id(5)
                        }

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
        default: target = 5
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

private extension IntroCrewMockView {
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
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Crew")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Your Crew Space")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(
                    showingFriendsTab
                    ? "Arkadaşlar, istekler ve ortak plan akışı burada."
                    : "Build together, focus together,\nfinish together."
                )
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.70))
            }

            Spacer()

            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 58, height: 58)
                .overlay(
                    Image(systemName: showingFriendsTab ? "person.badge.plus" : "person.3.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.blue)
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        }
    }

    var segmentedToggle: some View {
        spotlight(active: highlightStep == 0, radius: 24) {
            HStack(spacing: 10) {
                segment(title: "Crews", selected: !showingFriendsTab)
                segment(title: "Friends", selected: showingFriendsTab)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
    }

    func segment(title: String, selected: Bool) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(selected ? Color.blue.opacity(0.18) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(selected ? Color.blue.opacity(0.32) : Color.white.opacity(0.03), lineWidth: 1)
            )
    }

    var overviewCard: some View {
        spotlight(active: highlightStep == 1, radius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Overview")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Your team productivity at a glance")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.66))
                    }

                    Spacer()

                    Image(systemName: "person.3.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.blue)
                }

                HStack(spacing: 10) {
                    overviewMini(value: "5", label: "Crews")
                    overviewMini(value: "12", label: "Members")
                    overviewMini(value: "8", label: "Tasks")
                }

                Text("Aktif ekipler, görev yükü ve toplam ekip temposu tek bakışta.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.66))
            }
            .padding(16)
            .background(cardBG(radius: 28))
        }
    }

    func overviewMini(value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.035))
        )
    }

    var crewCard: some View {
        spotlight(active: highlightStep == 2, radius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Your Crews")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                HStack(alignment: .top, spacing: 14) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.red.opacity(0.22))
                        .frame(width: 68, height: 68)
                        .overlay(
                            Image(systemName: "scope")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(.red.opacity(0.92))
                        )

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Çizim")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text("4 members • 5 tasks")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.68))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("%64")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("tamam")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.68))
                    }
                }

                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 8)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.red.opacity(0.9))
                            .frame(width: 170, height: 8)
                    }

                HStack(spacing: 10) {
                    badge(text: "2 live focus", tint: .green)
                    badge(text: "1 request", tint: .blue)
                    badge(text: "5 tasks", tint: .red)
                }

                Text("Crew sayfası ekipleri, durumları ve ortak üretim akışını gösterir.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.66))
            }
            .padding(16)
            .background(cardBG(radius: 28))
        }
    }

    var friendsSummaryCard: some View {
        spotlight(active: highlightStep == 3, radius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Friends")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Shared schedules and direct collaboration")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.66))
                    }

                    Spacer()

                    Image(systemName: "person.2.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.blue)
                }

                HStack(spacing: 10) {
                    overviewMini(value: "8", label: "Friends")
                    overviewMini(value: "2", label: "Requests")
                    overviewMini(value: "3", label: "In Focus")
                }

                Text("Week paylaşımı, sohbet ve ortak odak görünümü burada toplanır.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.66))
            }
            .padding(16)
            .background(cardBG(radius: 28))
        }
    }

    var emptyFriendsCard: some View {
        spotlight(active: highlightStep >= 4, radius: 28) {
            VStack(spacing: 16) {
                Circle()
                    .fill(Color.blue.opacity(0.16))
                    .frame(width: 88, height: 88)
                    .overlay(
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.blue)
                    )

                VStack(spacing: 8) {
                    Text("Find your people")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Arkadaşlarını ekleyip haftanı paylaş, direkt mesajlaş ve focus başlat.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.74))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    badge(text: "Week share", tint: .blue)
                    badge(text: "Chat", tint: .green)
                    badge(text: "Presence", tint: .orange)
                }

                Text("Add Your First Friend")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.95))
                    )
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(cardBG(radius: 28))
        }
    }

    func badge(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(tint.opacity(0.16)))
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
