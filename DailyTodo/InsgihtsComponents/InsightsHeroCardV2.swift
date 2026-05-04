//
//  InsightsHeroCardV2.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//

import SwiftUI

struct InsightsHeroCardV2: View {
    let data: StudyHeroData
    let isStudyMode: Bool
    let action: (SmartSuggestionAction) -> Void

    private var heroTint: Color {
        if isStudyMode {
            return Color(arenaHex: AppArenaPalette.gold)
        }

        switch data.mode {
        case .exams:
            return Color(arenaHex: AppArenaPalette.coral)
        case .courses:
            return Color(arenaHex: AppArenaPalette.blue)
        case .rhythm:
            return Color(arenaHex: AppArenaPalette.cyan)
        case .empty:
            return Color(arenaHex: AppArenaPalette.purple)
        }
    }

    private var secondaryTint: Color {
        if isStudyMode {
            return Color(arenaHex: AppArenaPalette.coral)
        }

        switch data.mode {
        case .exams:
            return Color(arenaHex: AppArenaPalette.gold)
        case .courses:
            return Color(arenaHex: AppArenaPalette.purple)
        case .rhythm:
            return Color(arenaHex: AppArenaPalette.blue)
        case .empty:
            return Color(arenaHex: AppArenaPalette.blue)
        }
    }

    private var heroIcon: String {
        if isStudyMode {
            return "graduationcap.fill"
        }

        switch data.mode {
        case .exams:
            return "calendar.badge.exclamationmark"
        case .courses:
            return "book.closed.fill"
        case .rhythm:
            return "waveform.path.ecg"
        case .empty:
            return "sparkles"
        }
    }

    private var heroEyebrow: String {
        if isStudyMode {
            return "STUDY SIGNAL"
        }

        switch data.mode {
        case .exams:
            return "EXAM SIGNAL"
        case .courses:
            return "COURSE FLOW"
        case .rhythm:
            return "WEEK RHYTHM"
        case .empty:
            return "START POINT"
        }
    }

    private var heroTitleMain: String {
        if isStudyMode {
            return "Study"
        }

        switch data.mode {
        case .exams:
            return "Exam"
        case .courses:
            return "Course"
        case .rhythm:
            return "Haftanın"
        case .empty:
            return "Yeni"
        }
    }

    private var heroTitleAccent: String {
        if isStudyMode {
            return "signal"
        }

        switch data.mode {
        case .exams:
            return "ready"
        case .courses:
            return "flow"
        case .rhythm:
            return "ritmi"
        case .empty:
            return "başla"
        }
    }

    var body: some View {
        Button {
            action(data.action)
        } label: {
            VStack(alignment: .leading, spacing: 18) {
                topRow
                metricsRow
                quoteRow
                bottomActionRow
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
    }

    private var topRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(heroTint)
                        .frame(width: 20, height: 1)

                    Text(heroEyebrow)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(2.1)
                        .foregroundStyle(heroTint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(heroTitleMain)
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(.white)

                    Text(heroTitleAccent)
                        .font(.system(size: 31, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    heroTint,
                                    secondaryTint
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 10)

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                heroTint.opacity(0.18),
                                secondaryTint.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(heroTint.opacity(0.18), lineWidth: 1)
                    )

                Image(systemName: heroIcon)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(heroTint)
            }
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 10) {
            metricCard(
                value: data.primaryValue,
                label: data.primaryLabel,
                tint: heroTint
            )

            metricCard(
                value: cleanedMetricValue(data.chip1),
                label: cleanedMetricLabel(data.chip1, fallback: "görev"),
                tint: secondaryTint
            )

            metricCard(
                value: cleanedMetricValue(data.chip2),
                label: cleanedMetricLabel(data.chip2, fallback: "aktif gün"),
                tint: Color(arenaHex: AppArenaPalette.cyan)
            )
        }
    }

    private func metricCard(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 27, weight: .black))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.58)

            Text(label.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.40))
                .lineLimit(1)
                .minimumScaleFactor(0.66)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(0.080))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(0.14), lineWidth: 1)
                )
        )
    }

    private var quoteRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "quote.opening")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(heroTint.opacity(0.90))
                .padding(.top, 2)

            Text(weeklyQuote)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 1)
    }

    private var bottomActionRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(heroTint)
                    .frame(width: 7, height: 7)
                    .shadow(color: heroTint.opacity(0.35), radius: 7)

                Text(data.actionTitle.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(heroTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                Capsule()
                    .fill(heroTint.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(heroTint.opacity(0.18), lineWidth: 1)
                    )
            )

            Spacer()

            Image(systemName: "arrow.right")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.black)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(heroTint)
                )
        }
    }

    private var weeklyQuote: String {
        if !data.chip3.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return data.chip3
        }

        switch data.mode {
        case .exams:
            return "Kısa bloklarla sınav ritmini güçlendir."
        case .courses:
            return "Ders dengeni korudukça haftan netleşir."
        case .rhythm:
            return "İyi bir ritim yakalıyorsun."
        case .empty:
            return "Kısa başla, ritim kendiliğinden kurulur."
        }
    }

    private func cleanedMetricValue(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "0" }
        return trimmed.split(separator: " ").first.map(String.init) ?? trimmed
    }

    private func cleanedMetricLabel(_ text: String, fallback: String) -> String {
        let parts = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
        guard parts.count > 1 else { return fallback }
        return parts.dropFirst().joined(separator: " ")
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        heroTint.opacity(0.090),
                        secondaryTint.opacity(0.055),
                        Color(arenaHex: AppArenaPalette.surface).opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                heroTint.opacity(0.18),
                                Color.clear
                            ],
                            center: .topTrailing,
                            startRadius: 8,
                            endRadius: 220
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                secondaryTint.opacity(0.12),
                                Color.clear
                            ],
                            center: .bottomLeading,
                            startRadius: 10,
                            endRadius: 230
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(heroTint.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 16, y: 9)
    }
}
