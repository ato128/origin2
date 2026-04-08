//
//  HomeOverviewCards.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 8.04.2026.
//

import SwiftUI

extension HomeDashboardView {

    var todayOverviewTopCards: some View {
        HStack(alignment: .top, spacing: 14) {
            overviewMainMetricCard

            VStack(spacing: 14) {
                overviewStreakMetricCard
                overviewContextMetricCard
            }
        }
    }

    var overviewMainMetricCard: some View {
        Button {
            showTasksShortcut = true
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 10) {
                    Text("Bugünkü İlerleme")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .shadow(color: .white.opacity(0.05), radius: 3, y: 1)

                    Spacer(minLength: 8)

                    premiumHeroCornerIcon(
                        systemName: safeTodayCompletionRatio >= 1 ? "checkmark.circle.fill" : "checkmark.circle",
                        tint: safeTodayCompletionRatio >= 1 ? Color.green.opacity(0.98) : .white.opacity(0.88),
                        glowColor: safeTodayCompletionRatio >= 1 ? Color.green.opacity(0.30) : .white.opacity(0.10)
                    )
                }

                Spacer(minLength: 14)

                ZStack {
                    Circle()
                        .stroke(
                            safeTodayCompletionRatio >= 1
                            ? Color.green.opacity(0.20)
                            : Color.white.opacity(0.10),
                            lineWidth: 9
                        )

                    Circle()
                        .trim(from: 0, to: safeTodayCompletionRatio)
                        .stroke(
                            AngularGradient(
                                colors: safeTodayCompletionRatio >= 1
                                ? [
                                    Color.green.opacity(0.95),
                                    Color.green.opacity(0.78),
                                    Color.green.opacity(0.98)
                                ]
                                : [
                                    .white.opacity(0.98),
                                    .white.opacity(0.82),
                                    .white.opacity(0.96)
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 9, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .shadow(
                            color: safeTodayCompletionRatio >= 1
                            ? Color.green.opacity(0.22)
                            : Color.white.opacity(0.08),
                            radius: 8
                        )

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    (safeTodayCompletionRatio >= 1 ? Color.green : Color.white).opacity(0.07),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 8,
                                endRadius: 52
                            )
                        )
                        .padding(18)

                    VStack(spacing: 2) {
                        Text(todayCompletionPercentageText)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .minimumScaleFactor(0.8)
                            .shadow(color: .white.opacity(0.05), radius: 3, y: 1)

                        Text("tamamlandı")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                .frame(width: 108, height: 108)

                Spacer(minLength: 16)

                VStack(alignment: .leading, spacing: 4) {
                    Text(todayCompletionSummaryText)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.96))
                        .lineLimit(2)
                        .minimumScaleFactor(0.84)
                        .shadow(color: .white.opacity(0.04), radius: 2, y: 1)

                    Text(todayCompletionFootnoteText)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.70))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 10)

                premiumOrbitDecorationLarge
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, minHeight: 228, alignment: .topLeading)
            .background(
                premiumOverviewCardBackground(
                    accent: todayProgressAccent,
                    secondaryAccent: safeTodayCompletionRatio >= 1 ? Color.green : Color(red: 0.45, green: 0.10, blue: 0.42),
                    strength: todayCardGlowStrength,
                    cornerRadius: 34,
                    emphasizeBottomGlow: safeTodayCompletionRatio >= 1
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    var overviewStreakMetricCard: some View {
        Button {
            onOpenInsights()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    Text("🔥 SERİ")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(streakAccent.opacity(0.97))
                        .tracking(0.9)
                        .shadow(color: streakAccent.opacity(0.18), radius: 4)

                    Spacer(minLength: 8)

                    premiumHeroCornerIcon(
                        systemName: "flame.fill",
                        tint: .white.opacity(0.88),
                        glowColor: streakAccent.opacity(0.32)
                    )
                }

                Spacer(minLength: 14)

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(streakCount)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .shadow(color: .white.opacity(0.05), radius: 3)

                    Text("gün üst üste")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.74))
                        .shadow(color: streakAccent.opacity(0.10), radius: 3)
                }

                Spacer(minLength: 8)

                premiumOrbitDecorationCompact
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            .background(
                premiumOverviewCardBackground(
                    accent: streakAccent,
                    secondaryAccent: Color(red: 0.38, green: 0.06, blue: 0.28),
                    strength: streakCardGlowStrength,
                    cornerRadius: 28,
                    emphasizeBottomGlow: streakCount >= 3
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.065), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    var overviewContextMetricCard: some View {
        Button {
            onOpenWeek()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    Text("✨ DERS")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(nextClassAccent.opacity(0.97))
                        .tracking(0.9)
                        .shadow(color: nextClassAccent.opacity(0.16), radius: 4)

                    Spacer(minLength: 8)

                    premiumHeroCornerIcon(
                        systemName: "calendar",
                        tint: .white.opacity(0.88),
                        glowColor: nextClassAccent.opacity(0.24)
                    )
                }

                Spacer(minLength: 14)

                VStack(alignment: .leading, spacing: 3) {
                    Text(nextClassCardTitle)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.98))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .shadow(color: .white.opacity(0.04), radius: 2, y: 1)

                    Text(nextClassCardSubtitle)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.74))
                        .lineLimit(2)
                        .minimumScaleFactor(0.84)
                        .shadow(color: nextClassAccent.opacity(0.10), radius: 3)
                }

                Spacer(minLength: 8)

                premiumOrbitDecorationCompact
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            .background(
                premiumOverviewCardBackground(
                    accent: nextClassAccent,
                    secondaryAccent: Color(red: 0.34, green: 0.05, blue: 0.34),
                    strength: nextClassGlowStrength,
                    cornerRadius: 28,
                    emphasizeBottomGlow: nextEvent != nil
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.065), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    var safeTodayCompletionRatio: CGFloat {
        guard totalTodayTaskCount > 0 else { return 0 }
        let value = Double(completedTodayCount) / Double(totalTodayTaskCount)
        return CGFloat(min(max(value, 0), 1))
    }

    var todayCompletionPercentageText: String {
        "\(Int((safeTodayCompletionRatio * 100).rounded()))%"
    }

    var todayCompletionSummaryText: String {
        if totalTodayTaskCount == 0 {
            return "Bugün boş görünüyor"
        }

        if completedTodayCount >= totalTodayTaskCount {
            return "Tüm görevler tamam"
        }

        return "\(completedTodayCount)/\(totalTodayTaskCount) görev bitti"
    }

    var todayCompletionFootnoteText: String {
        if totalTodayTaskCount == 0 {
            return "İstersen yeni bir görev ekleyebilirsin"
        }

        let remaining = max(totalTodayTaskCount - completedTodayCount, 0)

        if remaining == 0 {
            return "Bugünü temiz kapattın"
        }

        return "\(remaining) görev daha kaldı"
    }

    var todayProgressAccent: Color {
        if safeTodayCompletionRatio >= 1 {
            return Color(red: 0.22, green: 0.82, blue: 0.42)
        }
        if safeTodayCompletionRatio >= 0.66 {
            return Color(red: 0.66, green: 0.50, blue: 0.84)
        }
        return Color(red: 0.90, green: 0.47, blue: 0.80)
    }

    var todayCardGlowStrength: Double {
        0.32 + (Double(safeTodayCompletionRatio) * 0.68)
    }

    var streakAccent: Color {
        if streakCount >= 14 {
            return Color(red: 1.00, green: 0.55, blue: 0.16)
        }
        if streakCount >= 7 {
            return Color(red: 0.98, green: 0.50, blue: 0.18)
        }
        if streakCount >= 3 {
            return Color(red: 0.96, green: 0.46, blue: 0.20)
        }
        return Color(red: 0.90, green: 0.42, blue: 0.22)
    }

    var streakCardGlowStrength: Double {
        min(0.28 + (Double(streakCount) * 0.055), 1.0)
    }

    var nextClassGlowStrength: Double {
        guard let nextEvent else { return 0.26 }

        let diff = max(nextEvent.startMinute - currentMinuteOfDay(), 0)

        if diff <= 15 { return 1.0 }
        if diff <= 30 { return 0.86 }
        if diff <= 60 { return 0.70 }
        if diff <= 120 { return 0.52 }
        return 0.34
    }

    var nextClassAccent: Color {
        guard let nextEvent else {
            return Color.white.opacity(0.42)
        }

        let hex = nextEvent.colorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if let color = colorFromHex(hex), hex.isEmpty == false {
            return color
        }

        return Color(red: 0.20, green: 0.64, blue: 1.00)
    }

    var nextClassCardTitle: String {
        if let nextEvent {
            return nextEvent.title
        }
        return "Ders yok"
    }

    var nextClassCardSubtitle: String {
        guard let nextEvent else {
            return "Takviminde yakın ders görünmüyor"
        }

        let diff = max(nextEvent.startMinute - currentMinuteOfDay(), 0)
        let end = nextEvent.startMinute + nextEvent.durationMinute
        let now = currentMinuteOfDay()

        if now >= nextEvent.startMinute && now < end {
            return "Şu an aktif"
        }

        if diff <= 0 {
            return "Başlamak üzere"
        }

        if diff < 60 {
            return "\(diff) dk sonra başlıyor"
        }

        let hours = diff / 60
        let minutes = diff % 60

        if minutes == 0 {
            return "\(hours) saat sonra"
        }

        return "\(hours) sa \(minutes) dk sonra"
    }

    func premiumHeroCornerIcon(
        systemName: String,
        tint: Color,
        glowColor: Color
    ) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            glowColor.opacity(0.22),
                            Color.white.opacity(0.03),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 22
                    )
                )
                .frame(width: 34, height: 34)

            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 28, height: 28)

            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                .frame(width: 28, height: 28)

            Image(systemName: systemName)
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(tint)
                .shadow(color: glowColor.opacity(0.20), radius: 4)
        }
    }

    func premiumOverviewCardBackground(
        accent: Color,
        secondaryAccent: Color,
        strength: Double,
        cornerRadius: CGFloat,
        emphasizeBottomGlow: Bool
    ) -> some View {
        let topGlow = 0.14 + (strength * 0.08)
        let leadingGlow = 0.18 + (strength * 0.10)
        let bottomGlow = emphasizeBottomGlow ? (0.18 + strength * 0.18) : (0.10 + strength * 0.08)

        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.84),
                        accent.opacity(0.48),
                        secondaryAccent.opacity(0.76),
                        Color(red: 0.11, green: 0.03, blue: 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(topGlow),
                                Color.clear,
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .blendMode(.screen)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(leadingGlow),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: 160
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                secondaryAccent.opacity(bottomGlow),
                                Color.clear
                            ],
                            center: .bottomLeading,
                            startRadius: 10,
                            endRadius: 160
                        )
                    )
                    .blur(radius: 10)
                    .mask(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.00),
                                Color.black.opacity(0.08),
                                Color.black.opacity(0.18)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
    }

    var premiumOrbitDecorationLarge: some View {
        premiumOrbitDecoration(
            height: 66,
            circleSize: 62,
            pointScale: 0.95,
            opacityScale: 0.78
        )
    }

    var premiumOrbitDecorationCompact: some View {
        premiumOrbitDecoration(
            height: 30,
            circleSize: 28,
            pointScale: 0.72,
            opacityScale: 0.66
        )
    }

    func premiumOrbitDecoration(
        height: CGFloat,
        circleSize: CGFloat,
        pointScale: CGFloat,
        opacityScale: Double
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 120, style: .continuous)
                .strokeBorder(
                    Color.white.opacity(0.04 * opacityScale),
                    style: StrokeStyle(lineWidth: 0.8, dash: [3, 5])
                )
                .frame(height: height)

            GeometryReader { geo in
                let y = geo.size.height / 2

                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
                .stroke(
                    Color.white.opacity(0.03 * opacityScale),
                    style: StrokeStyle(lineWidth: 0.8, dash: [3, 5])
                )

                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .stroke(
                            Color.white.opacity(0.038 * opacityScale),
                            style: StrokeStyle(lineWidth: 0.8, dash: [3, 5])
                        )
                        .frame(width: circleSize, height: circleSize)
                        .position(
                            x: geo.size.width * (0.12 + (CGFloat(index) * 0.24)),
                            y: y
                        )
                }

                ForEach(overviewDecorationPoints.indices, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(index == 1 ? 0.70 * opacityScale : 0.50 * opacityScale))
                        .frame(
                            width: (index == 1 ? 7 : 5.5) * pointScale,
                            height: (index == 1 ? 7 : 5.5) * pointScale
                        )
                        .shadow(color: Color.white.opacity(0.08 * opacityScale), radius: 2)
                        .position(overviewDecorationPoints[index](geo.size))
                }
            }
            .frame(height: height)
        }
        .frame(height: height)
        .opacity(0.92)
    }

    var overviewDecorationPoints: [(CGSize) -> CGPoint] {
        [
            { size in CGPoint(x: size.width * 0.18, y: size.height * 0.70) },
            { size in CGPoint(x: size.width * 0.40, y: size.height * 0.28) },
            { size in CGPoint(x: size.width * 0.56, y: size.height * 0.52) },
            { size in CGPoint(x: size.width * 0.84, y: size.height * 0.72) }
        ]
    }

    func colorFromHex(_ hex: String) -> Color? {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "#", with: "")

        guard cleaned.count == 6 || cleaned.count == 8 else { return nil }

        var value: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&value) else { return nil }

        if cleaned.count == 6 {
            let r = Double((value >> 16) & 0xFF) / 255.0
            let g = Double((value >> 8) & 0xFF) / 255.0
            let b = Double(value & 0xFF) / 255.0
            return Color(red: r, green: g, blue: b)
        } else {
            let r = Double((value >> 24) & 0xFF) / 255.0
            let g = Double((value >> 16) & 0xFF) / 255.0
            let b = Double((value >> 8) & 0xFF) / 255.0
            let a = Double(value & 0xFF) / 255.0
            return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
        }
    }
}
