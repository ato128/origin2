//
//  InsightsPremiumLabCard.swift
//  DailyTodo
//
//  Premium Lab — 3 araç:
//  1. AI Sınav Planlayıcı (aktif, mevcut ExamPlannerSheet'i açar)
//  2. AI Çalışma Koçu (Yakında — ComingSoonSheet)
//  3. Smart Insights (Yakında — ComingSoonSheet)
//
//  Free state'te: Üstte 3 kart + altta büyük Pro CTA ("3 gün bedava")
//  Premium state'te: Sadece 3 kart, CTA yok
//

import SwiftUI

// MARK: - PremiumLabTool (parametreli model)

enum PremiumLabTool {
    case examPlanner    // Aktif — ExamPlannerSheet açar
    case aiCoach        // Yakında — ComingSoonSheet
    case smartInsights  // Yakında — ComingSoonSheet
}

// MARK: - Main Card

struct InsightsPremiumLabCard: View {
    let isPremium: Bool

    /// AI Sınav Planlayıcı'ya tıklayınca
    let onExamPlanner: () -> Void

    /// "Yakında" sheet açmak için (AI Coach / Smart Insights)
    let onComingSoon: (PremiumLabTool) -> Void

    /// Pro CTA'ya tıklayınca (free → showPremium)
    let onUpgrade: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            eyebrowRow

            VStack(spacing: 10) {
                toolCard(
                    tool: .examPlanner,
                    title: "AI Sınav Planlayıcı",
                    subtitle: "\"Final 15 gün sonra\" — kalan günleri konu konu otomatik dağıt",
                    icon: "calendar.badge.clock",
                    primaryTint: Color(arenaHex: AppArenaPalette.gold),
                    secondaryTint: Color(arenaHex: AppArenaPalette.coral),
                    examplePrompt: "Calculus II finali — 7 günlük plan oluştur",
                    promptIcon: "bolt.fill",
                    isComingSoon: false,
                    onTap: onExamPlanner
                )

                toolCard(
                    tool: .aiCoach,
                    title: "AI Çalışma Koçu",
                    subtitle: "Hedefini söyle, takvimini doldursun — günlük rutin önerisi",
                    icon: "brain.head.profile",
                    primaryTint: Color(arenaHex: AppArenaPalette.purple),
                    secondaryTint: Color(arenaHex: AppArenaPalette.cyan),
                    examplePrompt: "Bu hafta hangi konuya öncelik vermeliyim?",
                    promptIcon: "bubble.left.fill",
                    isComingSoon: true,
                    onTap: { onComingSoon(.aiCoach) }
                )

                toolCard(
                    tool: .smartInsights,
                    title: "Smart Insights",
                    subtitle: "Verilerini analiz et — verimli saatler, en iyi konular, trendler",
                    icon: "chart.line.uptrend.xyaxis",
                    primaryTint: Color(arenaHex: AppArenaPalette.cyan),
                    secondaryTint: Color(arenaHex: AppArenaPalette.blue),
                    examplePrompt: "Matematik için en verimli saatlerin 09:00–11:00",
                    promptIcon: "lightbulb.fill",
                    isComingSoon: true,
                    onTap: { onComingSoon(.smartInsights) }
                )
            }

            if !isPremium {
                upgradeCTA
                    .padding(.top, 4)
            }
        }
    }

    // MARK: Eyebrow

    private var eyebrowRow: some View {
        HStack(spacing: 7) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(arenaHex: AppArenaPalette.gold),
                            Color(arenaHex: AppArenaPalette.purple)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 16, height: 1)

            Text("PREMIUM LAB · 3 ARAÇ")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(arenaHex: AppArenaPalette.gold),
                            Color(arenaHex: AppArenaPalette.purple)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Spacer()

            if isPremium {
                HStack(spacing: 3) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .black))

                    Text("PRO")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(0.6)
                }
                .foregroundStyle(Color(arenaHex: AppArenaPalette.gold))
                .padding(.horizontal, 7)
                .frame(height: 20)
                .background(
                    Capsule()
                        .fill(Color(arenaHex: AppArenaPalette.gold).opacity(0.15))
                        .overlay(
                            Capsule()
                                .stroke(Color(arenaHex: AppArenaPalette.gold).opacity(0.30), lineWidth: 1)
                        )
                )
            }
        }
    }

    // MARK: Tool card

    private func toolCard(
        tool: PremiumLabTool,
        title: String,
        subtitle: String,
        icon: String,
        primaryTint: Color,
        secondaryTint: Color,
        examplePrompt: String,
        promptIcon: String,
        isComingSoon: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [primaryTint, secondaryTint],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .shadow(color: primaryTint.opacity(0.30), radius: 8, y: 4)

                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text(subtitle)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.52))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 4)

                    // PRO or YAKINDA badge
                    badge(isComingSoon: isComingSoon, tint: primaryTint)
                }

                // Example prompt
                HStack(spacing: 7) {
                    Image(systemName: promptIcon)
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(primaryTint.opacity(0.85))

                    Text(examplePrompt)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Spacer(minLength: 4)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.035))
                )
            }
            .padding(13)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                primaryTint.opacity(0.080),
                                secondaryTint.opacity(0.040),
                                Color(arenaHex: AppArenaPalette.surface).opacity(0.94)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(primaryTint.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 10, y: 5)
            )
        }
        .buttonStyle(.plain)
    }

    private func badge(isComingSoon: Bool, tint: Color) -> some View {
        HStack(spacing: 3) {
            if isComingSoon {
                Image(systemName: "clock.fill")
                    .font(.system(size: 7, weight: .black))

                Text("YAKINDA")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(0.4)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 7, weight: .black))

                Text("PRO")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(0.4)
            }
        }
        .foregroundStyle(isComingSoon ? .white.opacity(0.55) : tint)
        .padding(.horizontal, 7)
        .frame(height: 19)
        .background(
            Capsule()
                .fill(isComingSoon ? Color.white.opacity(0.05) : tint.opacity(0.16))
                .overlay(
                    Capsule()
                        .stroke(
                            isComingSoon ? Color.white.opacity(0.08) : tint.opacity(0.30),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: Pro CTA (free only)

    private var upgradeCTA: some View {
        Button(action: onUpgrade) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9, weight: .black))

                        Text("UPDO PRO")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(1.2)
                    }
                    .foregroundStyle(.black.opacity(0.62))

                    Text("Tüm araçlar — 3 gün bedava")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text("sonra ₺49/ay")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black.opacity(0.62))
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.08))
                    )
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(arenaHex: AppArenaPalette.gold),
                                Color(arenaHex: AppArenaPalette.coral),
                                Color(arenaHex: AppArenaPalette.purple)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.22),
                                        Color.clear
                                    ],
                                    center: .topTrailing,
                                    startRadius: 4,
                                    endRadius: 160
                                )
                            )
                    )
                    .shadow(color: Color(arenaHex: AppArenaPalette.gold).opacity(0.25), radius: 14, y: 7)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Coming Soon Sheet (yakında)

struct InsightsComingSoonSheet: View {
    let tool: PremiumLabTool

    @Environment(\.dismiss) private var dismiss

    private var toolInfo: (title: String, icon: String, primary: Color, secondary: Color, description: String, features: [String]) {
        switch tool {
        case .aiCoach:
            return (
                title: "AI Çalışma Koçu",
                icon: "brain.head.profile",
                primary: Color(arenaHex: AppArenaPalette.purple),
                secondary: Color(arenaHex: AppArenaPalette.cyan),
                description: "Kişisel hedeflerini söyle, AI sana özel günlük rutinler ve haftalık planlar önersin.",
                features: [
                    "Hedef bazlı çalışma planı",
                    "Günlük rutin önerisi",
                    "Zayıf konuları otomatik tespit",
                    "Motivasyon ve mola tavsiyeleri"
                ]
            )
        case .smartInsights:
            return (
                title: "Smart Insights",
                icon: "chart.line.uptrend.xyaxis",
                primary: Color(arenaHex: AppArenaPalette.cyan),
                secondary: Color(arenaHex: AppArenaPalette.blue),
                description: "Verilerini derinlemesine analiz et — en verimli saatlerin, konuların ve trendlerin.",
                features: [
                    "En verimli saat ve gün analizi",
                    "Konu bazlı performans takibi",
                    "Aylık ve dönemsel trendler",
                    "Akıllı bildirim önerileri"
                ]
            )
        case .examPlanner:
            // Bu enum sadece "coming soon" için, examPlanner gelmemeli
            return (
                title: "AI Sınav Planlayıcı",
                icon: "calendar.badge.clock",
                primary: Color(arenaHex: AppArenaPalette.gold),
                secondary: Color(arenaHex: AppArenaPalette.coral),
                description: "Sınav tarihini gir, AI çalışma planını oluştursun.",
                features: []
            )
        }
    }

    var body: some View {
        ZStack {
            ArenaBackground(
                primaryGlow: toolInfo.primary,
                secondaryGlow: toolInfo.secondary,
                warmGlow: Color(arenaHex: AppArenaPalette.gold),
                intensity: 0.90
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    heroSection

                    featuresSection

                    Spacer(minLength: 40)

                    notifyCTA
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10, weight: .black))

                    Text("YAKINDA")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.6)
                }
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 9)
                .frame(height: 26)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [toolInfo.primary, toolInfo.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .shadow(color: toolInfo.primary.opacity(0.40), radius: 14, y: 7)

                Image(systemName: toolInfo.icon)
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(.white)
            }

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(toolInfo.title)
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Text("yakında")
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [toolInfo.primary, toolInfo.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .lineLimit(1)
            }

            Text(toolInfo.description)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Rectangle()
                    .fill(toolInfo.primary)
                    .frame(width: 16, height: 1)

                Text("NELER GELECEK")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(toolInfo.primary)
            }

            VStack(spacing: 8) {
                ForEach(toolInfo.features, id: \.self) { feature in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(toolInfo.primary.opacity(0.16))
                                .frame(width: 26, height: 26)

                            Image(systemName: "sparkle")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(toolInfo.primary)
                        }

                        Text(feature)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(2)

                        Spacer(minLength: 4)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(toolInfo.primary.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(toolInfo.primary.opacity(0.12), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }

    private var notifyCTA: some View {
        Button {
            // Şimdilik sadece dismiss
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 14, weight: .black))

                Text("ÇIKTIĞINDA HABER VER")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(0.8)

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .black))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [toolInfo.primary, toolInfo.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: toolInfo.primary.opacity(0.30), radius: 12, y: 6)
            )
        }
        .buttonStyle(.plain)
    }
}
