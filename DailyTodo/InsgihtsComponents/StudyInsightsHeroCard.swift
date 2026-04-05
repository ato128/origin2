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
        case .empty: return "İLK GÖRÜNÜM"
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

    private var helperText: String {
        switch data.mode {
        case .exams:
            return "Bugün kısa bir blok yeter."
        case .courses:
            return "Zayıf dersi biraz öne çek."
        case .rhythm:
            return "Bir focus daha ritmi netleştirir."
        case .empty:
            return "Bir sınav, ders etiketi ya da focus ile açılır."
        }
    }

    private var compactValueText: String {
        switch data.mode {
        case .exams, .rhythm:
            return "%\(Int((Double(data.primaryValue.filter(\.isNumber)) ?? 0)))"
        case .courses:
            return data.primaryValue
        case .empty:
            return "0"
        }
    }

    private var compactLabelText: String {
        switch data.mode {
        case .exams:
            return "hazırlık"
        case .courses:
            return "aktif ders"
        case .rhythm:
            return "ritim"
        case .empty:
            return "görünüm"
        }
    }

    private var displayTitle: String {
        if data.mode == .empty {
            return "İlk görünümünü aç"
        }
        return data.title
    }

    private var displaySubtitle: String {
        if data.mode == .empty {
            return "Bir sınav, ders etiketi veya focus ile bu alan kişiselleşir."
        }
        return data.subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            topRow

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(displayTitle)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.84)

                    Text(displaySubtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(2)

                    chipsRow
                }

                Spacer(minLength: 8)

                compactMetric
            }

            progressStrip

            compactCTA
        }
        .padding(16)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
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
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(tint.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.10), lineWidth: 1)
            )

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.024))
                    .frame(width: 38, height: 38)

                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .bold))
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

    private var compactMetric: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 5.5)
                    .frame(width: 62, height: 62)

                Circle()
                    .trim(from: 0, to: progressValue)
                    .stroke(
                        LinearGradient(
                            colors: [tint.opacity(0.70), tint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 5.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 62, height: 62)

                Text(compactValueText)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)
                    .minimumScaleFactor(0.75)
            }

            Text(compactLabelText)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(width: 86)
    }

    private var progressStrip: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(helperText)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(palette.secondaryText)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 6)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.84), tint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(16, geo.size.width * max(progressValue, 0.06)), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(0.022))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(palette.cardStroke.opacity(0.76), lineWidth: 1)
                )
        )
    }

    private var compactCTA: some View {
        Button {
            onTap(data.action)
        } label: {
            HStack {
                Text(data.actionTitle)
                    .font(.system(size: 15, weight: .bold, design: .rounded))

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 40, height: 40)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.86), tint.opacity(0.76)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: tint.opacity(0.08), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func chip(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(tint.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.08), lineWidth: 1)
            )
            .lineLimit(1)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(palette.cardStroke.opacity(0.84), lineWidth: 1)
            )
    }

    private var softenedTint: Color {
        switch data.mode {
        case .exams: return softAmber
        case .courses: return softBlue
        case .rhythm: return softGreen
        case .empty: return Color.accentColor.opacity(0.80)
        }
    }

    private var softPink: Color { Color.pink.opacity(0.78) }
    private var softBlue: Color { Color.blue.opacity(0.78) }
    private var softAmber: Color { Color.orange.opacity(0.78) }
    private var softGreen: Color { Color.green.opacity(0.76) }
}
