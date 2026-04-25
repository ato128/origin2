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
        Color(red: 0.20, green: 0.58, blue: 1.00)
    }

    private var secondaryTint: Color {
        Color(red: 0.04, green: 0.12, blue: 0.30)
    }

    var body: some View {
        Button {
            action(data.action)
        } label: {
            VStack(alignment: .leading, spacing: 22) {
                topRow
                weeklyMetricsRow
                divider
                quoteRow
                bottomActionRow
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, minHeight: 232, alignment: .topLeading)
            .background(cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var topRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("BU HAFTA")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(heroTint.opacity(0.98))
                    .tracking(3.4)

                Text("Haftanın ritmi")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.98))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 54, height: 54)

                Circle()
                    .fill(heroTint.opacity(0.20))
                    .frame(width: 54, height: 54)
                    .blur(radius: 9)

                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
    }

    private var weeklyMetricsRow: some View {
        HStack(spacing: 0) {
            weeklyMetric(value: data.primaryValue, label: data.primaryLabel)

            metricDivider

            weeklyMetric(
                value: cleanedMetricValue(data.chip1),
                label: cleanedMetricLabel(data.chip1, fallback: "görev")
            )

            metricDivider

            weeklyMetric(
                value: cleanedMetricValue(data.chip2),
                label: cleanedMetricLabel(data.chip2, fallback: "aktif gün")
            )
        }
    }

    private func weeklyMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.98))
                .lineLimit(1)
                .minimumScaleFactor(0.60)

            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.54))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 58)
            .padding(.horizontal, 14)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.075))
            .frame(height: 1)
    }

    private var quoteRow: some View {
        Text(weeklyQuote)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.82))
            .lineLimit(2)
    }

    private var bottomActionRow: some View {
        HStack(spacing: 10) {
            Button {
                action(data.action)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12, weight: .bold))

                    Text(data.actionTitle)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.white.opacity(0.98)))
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 5) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index == 0 ? Color.white.opacity(0.86) : Color.white.opacity(0.22))
                        .frame(width: 7, height: 7)
                }
            }
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
        RoundedRectangle(cornerRadius: 34, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        heroTint.opacity(0.40),
                        heroTint.opacity(0.20),
                        secondaryTint.opacity(0.82),
                        Color(red: 0.025, green: 0.030, blue: 0.055)
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            )
            .overlay(
                RadialGradient(
                    colors: [
                        heroTint.opacity(0.26),
                        .clear
                    ],
                    center: .topTrailing,
                    startRadius: 4,
                    endRadius: 220
                )
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            )
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.15),
                        .clear,
                        Color.black.opacity(0.22)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            )
    }
}
