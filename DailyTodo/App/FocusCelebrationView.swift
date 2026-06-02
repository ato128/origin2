//
//  FocusCelebrationView.swift
//  DailyTodo
//
//  Focus bitince gösterilen tebrikler ekranı.
//

import SwiftUI

struct FocusCelebrationView: View {
    let summary: FocusCompletionSummary
    let onClose: () -> Void

    @State private var pulse = false
    @State private var iconBounce = false
    @State private var showStats = false

    private var modeAccent: Color {
        switch summary.mode {
        case .personal: return Color(arenaHex: AppArenaPalette.cyan)
        case .crew:     return Color(arenaHex: AppArenaPalette.coral)
        case .friend:   return Color(arenaHex: AppArenaPalette.purple)
        }
    }

    private var modeSecondaryAccent: Color {
        switch summary.mode {
        case .personal: return Color(arenaHex: AppArenaPalette.purple)
        case .crew:     return Color(arenaHex: AppArenaPalette.gold)
        case .friend:   return Color(arenaHex: AppArenaPalette.blue)
        }
    }

    private var headerEyebrow: String {
        switch summary.mode {
        case .personal: return "PERSONAL FOCUS · TAMAMLANDI"
        case .crew:     return "CREW FOCUS · TAMAMLANDI"
        case .friend:   return "FRIEND FOCUS · TAMAMLANDI"
        }
    }

    private var modeIcon: String {
        switch summary.mode {
        case .personal: return "person.fill"
        case .crew:     return "person.3.fill"
        case .friend:   return "person.2.fill"
        }
    }

    private var deltaInfo: (text: String, color: Color, icon: String)? {
        guard let previous = summary.previousMinutes, previous > 0 else { return nil }

        let delta = summary.durationMinutes - previous

        if delta > 0 {
            return ("+\(delta) dk", Color(arenaHex: AppArenaPalette.green), "arrow.up")
        }

        if delta < 0 {
            return ("\(delta) dk", Color(arenaHex: AppArenaPalette.coral), "arrow.down")
        }

        return ("Aynı", .white.opacity(0.6), "equal")
    }

    private var encouragementText: String {
        guard let previous = summary.previousMinutes, previous > 0 else {
            return "İlk focus oturumun tamamlandı!"
        }

        let delta = summary.durationMinutes - previous

        if delta > 0 {
            return "Geçen seferden \(delta) dakika daha iyi 🚀"
        }

        if delta < 0 {
            return "Bir sonraki seferde daha uzun odaklanabilirsin 💪"
        }

        return "Geçen seferki süreyi tutturdun 👏"
    }

    var body: some View {
        ZStack {
            backgroundLayer.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Color.clear.frame(height: 12)

                    headerSection
                    medalSection
                    durationSection

                    if summary.previousMinutes != nil {
                        comparisonSection
                    }

                    statsGrid
                    encouragementCard

                    Color.clear.frame(height: 12)

                    closeButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55).delay(0.1)) {
                iconBounce = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.84).delay(0.35)) {
                showStats = true
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(modeAccent)
                    .frame(width: 22, height: 1)

                Text(headerEyebrow)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(modeAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Tebrikler")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(.white)

                Text("🎉")
                    .font(.system(size: 36))
                    .scaleEffect(iconBounce ? 1.0 : 0.6)
                    .rotationEffect(.degrees(iconBounce ? 0 : -20))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var medalSection: some View {
        ZStack {
            Circle()
                .fill(modeAccent.opacity(pulse ? 0.22 : 0.10))
                .frame(width: 200, height: 200)
                .blur(radius: 40)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            modeAccent.opacity(0.95),
                            modeSecondaryAccent.opacity(0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 130, height: 130)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 3)
                )
                .shadow(color: modeAccent.opacity(0.5), radius: 24, y: 12)

            Image(systemName: "trophy.fill")
                .font(.system(size: 50, weight: .black))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                .scaleEffect(iconBounce ? 1.0 : 0.5)
                .opacity(iconBounce ? 1.0 : 0.0)
        }
        .frame(height: 200)
    }

    private var durationSection: some View {
        VStack(spacing: 8) {
            Text("\(summary.durationMinutes)")
                .font(.system(size: 96, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .contentTransition(.numericText())

            Text("dakika focus tamamladın")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
        }
        .opacity(showStats ? 1.0 : 0.0)
        .offset(y: showStats ? 0 : 8)
    }

    private var comparisonSection: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("GEÇEN SEFER")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.42))

                Text("\(summary.previousMinutes ?? 0) dk")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let delta = deltaInfo {
                HStack(spacing: 6) {
                    Image(systemName: delta.icon)
                        .font(.system(size: 14, weight: .black))

                    Text(delta.text)
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                }
                .foregroundStyle(delta.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(delta.color.opacity(0.14))
                        .overlay(
                            Capsule()
                                .stroke(delta.color.opacity(0.28), lineWidth: 1)
                        )
                )
            }

            VStack(alignment: .trailing, spacing: 6) {
                Text("BU SEFER")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(modeAccent.opacity(0.85))

                Text("\(summary.durationMinutes) dk")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            modeAccent.opacity(0.07),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(modeAccent.opacity(0.15), lineWidth: 1)
                )
        )
        .opacity(showStats ? 1.0 : 0.0)
        .offset(y: showStats ? 0 : 12)
    }

    private var statsGrid: some View {
        HStack(spacing: 10) {
            statCard(
                title: "BUGÜN",
                value: "\(summary.totalTodayMinutes)",
                subtitle: "dk toplam",
                icon: "calendar"
            )

            statCard(
                title: "SERİ",
                value: "\(summary.streakDays)",
                subtitle: "gün üst üste",
                icon: "flame.fill"
            )

            statCard(
                title: summary.mode == .personal ? "MOD" : "KİŞİ",
                value: summary.mode == .personal ? summary.goal.title : "\(summary.participantCount)",
                subtitle: summary.mode == .personal ? summary.goal.subtitle : "katılımcı",
                icon: modeIcon
            )
        }
        .opacity(showStats ? 1.0 : 0.0)
        .offset(y: showStats ? 0 : 14)
    }

    private func statCard(
        title: String,
        value: String,
        subtitle: String,
        icon: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(modeAccent)

                Text(title)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(modeAccent)
                    .lineLimit(1)
            }

            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(subtitle)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .frame(height: 100)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var encouragementCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(modeAccent)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(modeAccent.opacity(0.14))
                )

            Text(encouragementText)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
        .opacity(showStats ? 1.0 : 0.0)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            HStack(spacing: 8) {
                Text("Tamam")
                    .font(.system(size: 17, weight: .black, design: .rounded))

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .black))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [modeAccent, modeSecondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: modeAccent.opacity(0.4), radius: 18, y: 10)
        }
        .buttonStyle(.plain)
    }

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(arenaHex: "#0A0612"),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(modeAccent.opacity(0.18))
                .frame(width: 380, height: 380)
                .blur(radius: 100)
                .offset(x: 140, y: -200)

            Circle()
                .fill(modeSecondaryAccent.opacity(0.12))
                .frame(width: 320, height: 320)
                .blur(radius: 95)
                .offset(x: -130, y: 300)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.30),
                    Color.clear,
                    Color.black.opacity(0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
