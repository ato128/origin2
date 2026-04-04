//
//  StudyInsightsHeroCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 4.04.2026.
//

import SwiftUI

struct StudyInsightsHeroCard: View {
    let data: StudyHeroData
    let onTap: (SmartSuggestionAction) -> Void

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    private var tint: Color { softenedTint }

    private var heroTag: String {
        switch data.mode {
        case .exams: return "EN KRİTİK SINAV"
        case .courses: return "DERS DENGESİ"
        case .rhythm: return "ÇALIŞMA RİTMİ"
        case .empty: return "STUDY INSIGHTS"
        }
    }

    private var iconName: String {
        switch data.mode {
        case .exams: return "graduationcap.fill"
        case .courses: return "books.vertical.fill"
        case .rhythm: return "waveform.path.ecg"
        case .empty: return "sparkles"
        }
    }

    private var progressValue: Double {
        let raw = Double(data.primaryValue.filter(\.isNumber)) ?? 0
        if data.primaryLabel.localizedCaseInsensitiveContains("hazırlık")
            || data.primaryLabel.localizedCaseInsensitiveContains("readiness")
            || data.primaryLabel.localizedCaseInsensitiveContains("ritim")
            || data.primaryLabel.localizedCaseInsensitiveContains("rhythm") {
            return min(max(raw / 100, 0.06), 1)
        }
        return min(max(raw / 180, 0.06), 1)
    }

    private var sideMetricTitle: String {
        switch data.mode {
        case .exams: return "Bugün"
        case .courses: return "Denge"
        case .rhythm: return "Akış"
        case .empty: return "Başlangıç"
        }
    }

    private var helperText: String {
        switch data.mode {
        case .exams: return "Kısa bir blok hazırlığı yükseltir."
        case .courses: return "Zayıf dersi öne çek, görünüm açılsın."
        case .rhythm: return "Bir focus daha ritmi netleştirir."
        case .empty: return "Bir veri ekle, alan canlansın."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            topRow

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(data.title)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.84)

                    Text(data.subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(2)

                    chipsRow
                }

                Spacer(minLength: 8)

                compactRingMetric
            }

            bottomStatus

            primaryCTA
        }
        .padding(18)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(tint.opacity(0.08), lineWidth: 1)
        )
    }

    private var topRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(tint)
                    .frame(width: 7, height: 7)

                Text(heroTag)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                    .tracking(0.35)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(tint.opacity(0.09))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.12), lineWidth: 1)
            )

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .frame(width: 42, height: 42)

                Image(systemName: iconName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(tint)
            }
        }
    }

    private var chipsRow: some View {
        HStack(spacing: 8) {
            chip(text: data.chip1, tint: softPink)
            chip(text: data.chip2, tint: softBlue)
            chip(text: data.chip3, tint: softAmber)
        }
    }

    private var compactRingMetric: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 7)
                    .frame(width: 70, height: 70)

                Circle()
                    .trim(from: 0, to: progressValue)
                    .stroke(
                        LinearGradient(
                            colors: [tint.opacity(0.72), tint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 70, height: 70)

                VStack(spacing: 1) {
                    Text("%\(Int((Double(data.primaryValue.filter(\.isNumber)) ?? 0)))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Text("hazır")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(palette.secondaryText)
                }
            }

            Text("\(sideMetricTitle): \(data.primaryValue) \(metricSuffix)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(width: 112)
    }

    private var metricSuffix: String {
        switch data.mode {
        case .exams: return "dk çalışıldı"
        case .courses: return "aktif ders"
        case .rhythm: return "puan"
        case .empty: return ""
        }
    }

    private var bottomStatus: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(helperText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.secondaryText)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 7)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.88), tint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(16, geo.size.width * max(progressValue, 0.06)), height: 7)
                }
            }
            .frame(height: 7)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.white.opacity(0.028))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(palette.cardStroke.opacity(0.85), lineWidth: 1)
                )
        )
    }

    private var primaryCTA: some View {
        Button {
            onTap(data.action)
        } label: {
            HStack {
                Text(data.actionTitle)
                    .font(.system(size: 15, weight: .bold, design: .rounded))

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 42, height: 42)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.88), tint.opacity(0.78)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: tint.opacity(0.10), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }

    private func chip(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(tint.opacity(0.09))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.10), lineWidth: 1)
            )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.cardStroke.opacity(0.88), lineWidth: 1)
            )
    }

    private var softenedTint: Color {
        switch data.mode {
        case .exams: return softAmber
        case .courses: return softBlue
        case .rhythm: return softGreen
        case .empty: return Color.accentColor.opacity(0.82)
        }
    }

    private var softPink: Color { Color.pink.opacity(0.80) }
    private var softBlue: Color { Color.blue.opacity(0.80) }
    private var softAmber: Color { Color.orange.opacity(0.80) }
    private var softGreen: Color { Color.green.opacity(0.78) }
}
