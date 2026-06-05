//
//  InsightsJourneyCard.swift
//  DailyTodo
//
//  Telemetri stili kart — son 4 haftanın focus telemetrisi.
//  - Sol üst: "FOCUS DAKİKA" + büyük % (+18%) + ↑ ok
//  - Sağ üst: en iyi haftanın dakikası
//  - Orta: SVG line chart (4 hafta, gradient line + area fill)
//  - Alt: insight tag ("Pazartesi en verimli günün")
//

import SwiftUI

struct InsightsJourneyCard: View {
    let focusSessions: [FocusSessionRecord]
    let isTurkish: Bool

    private let calendar = Calendar.current

    private var primaryAccent: Color { Color(arenaHex: AppArenaPalette.cyan) }
    private var secondaryAccent: Color { Color(arenaHex: AppArenaPalette.purple) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            topRow

            chartArea

            if let insight = bestDayInsight {
                insightChip(text: insight)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(cardBackground)
    }

    // MARK: Top — Eyebrow + Title

    private var eyebrowSection: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(arenaHex: AppArenaPalette.green), primaryAccent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 16, height: 1)

            Text(isTurkish ? "JOURNEY · SON 4 HAFTA" : "JOURNEY · LAST 4 WEEKS")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(arenaHex: AppArenaPalette.green), primaryAccent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineLimit(1)
        }
    }

    private var topRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            eyebrowSection

            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(isTurkish ? "FOCUS DAKİKA" : "FOCUS MINUTES")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.42))

                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(trendText)
                            .font(.system(size: 26, weight: .black))
                            .foregroundStyle(.white)
                            .monospacedDigit()

                        if trendDelta != 0 {
                            Image(systemName: trendDelta > 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(trendColor)
                        }
                    }

                    Text(isTurkish ? "geçen haftaya göre" : "vs. last week")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.42))
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(isTurkish ? "EN İYİ HAFTA" : "BEST WEEK")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.42))

                    Text("\(bestWeekMinutes) \(isTurkish ? "dk" : "min")")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundStyle(primaryAccent)
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: Chart

    private var chartArea: some View {
        GeometryReader { geo in
            let weekValues = focusMinutesPerWeek  // [w-3, w-2, w-1, w]
            let maxValue = max(weekValues.max() ?? 1, 1)

            ZStack(alignment: .bottomLeading) {
                // Area + Line
                if weekValues.contains(where: { $0 > 0 }) {
                    journeyLinePath(values: weekValues, maxValue: maxValue, geo: geo)

                    // Dots
                    ForEach(0..<weekValues.count, id: \.self) { idx in
                        let point = chartPoint(idx: idx, value: weekValues[idx], maxValue: maxValue, geo: geo)
                        let isCurrent = idx == weekValues.count - 1

                        Circle()
                            .fill(isCurrent ? primaryAccent : secondaryAccent)
                            .frame(width: isCurrent ? 9 : 6, height: isCurrent ? 9 : 6)
                            .overlay(
                                Circle()
                                    .stroke(isCurrent ? .white : .black, lineWidth: isCurrent ? 1.8 : 1.2)
                            )
                            .shadow(
                                color: isCurrent ? primaryAccent.opacity(0.55) : .clear,
                                radius: isCurrent ? 7 : 0
                            )
                            .position(x: point.x, y: point.y)

                        if isCurrent {
                            Circle()
                                .fill(primaryAccent.opacity(0.30))
                                .frame(width: 18, height: 18)
                                .blur(radius: 4)
                                .position(x: point.x, y: point.y)
                        }
                    }
                } else {
                    // Empty state
                    Text(isTurkish ? "Henüz yolculuk verisi yok" : "No journey data yet")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }

                // X axis labels
                HStack {
                    ForEach(weekLabels, id: \.self) { label in
                        Text(label)
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundStyle(label == weekLabels.last ? primaryAccent : .white.opacity(0.35))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, geo.size.height - 16)
            }
        }
        .frame(height: 80)
    }

    @ViewBuilder
    private func journeyLinePath(values: [Int], maxValue: Int, geo: GeometryProxy) -> some View {
        let points = (0..<values.count).map { idx in
            chartPoint(idx: idx, value: values[idx], maxValue: maxValue, geo: geo)
        }

        // Filled area
        Path { path in
            guard let first = points.first else { return }
            path.move(to: CGPoint(x: first.x, y: geo.size.height - 14))
            path.addLine(to: first)

            for i in 1..<points.count {
                path.addLine(to: points[i])
            }

            if let last = points.last {
                path.addLine(to: CGPoint(x: last.x, y: geo.size.height - 14))
            }
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: [
                    primaryAccent.opacity(0.35),
                    primaryAccent.opacity(0.02)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )

        // Line
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for i in 1..<points.count {
                path.addLine(to: points[i])
            }
        }
        .stroke(
            LinearGradient(
                colors: [secondaryAccent, Color(arenaHex: AppArenaPalette.blue), primaryAccent],
                startPoint: .leading,
                endPoint: .trailing
            ),
            style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
        )
    }

    private func chartPoint(idx: Int, value: Int, maxValue: Int, geo: GeometryProxy) -> CGPoint {
        let count = focusMinutesPerWeek.count
        let availableWidth = geo.size.width - 20
        let xStep = count > 1 ? availableWidth / CGFloat(count - 1) : 0
        let x = 10 + CGFloat(idx) * xStep

        let chartHeight = geo.size.height - 24
        let yFraction = maxValue > 0 ? CGFloat(value) / CGFloat(maxValue) : 0
        let y = 6 + (chartHeight * (1 - yFraction))

        return CGPoint(x: x, y: y)
    }

    // MARK: Insight chip

    private func insightChip(text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(primaryAccent)

            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(primaryAccent.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(primaryAccent.opacity(0.14), lineWidth: 1)
                )
        )
    }

    // MARK: Computed

    /// Son 4 haftanın focus dakikaları: [w-3, w-2, w-1, current_week]
    private var focusMinutesPerWeek: [Int] {
        let now = Date()
        let calendar = self.calendar

        return (0..<4).reversed().map { weeksAgo -> Int in
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: now),
                  let weekStartOfWeek = calendar.dateInterval(of: .weekOfYear, for: weekStart)?.start,
                  let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStartOfWeek)
            else { return 0 }

            return focusSessions
                .filter { $0.startedAt >= weekStartOfWeek && $0.startedAt < weekEnd }
                .reduce(0) { $0 + ($1.completedSeconds / 60) }
        }
    }

    private var bestWeekMinutes: Int {
        focusMinutesPerWeek.max() ?? 0
    }

    private var weekLabels: [String] {
        isTurkish ? ["H-3", "H-2", "H-1", "BU"] : ["W-3", "W-2", "W-1", "NOW"]
    }

    /// Bu haftanın geçen haftaya göre yüzde değişimi
    private var trendDelta: Int {
        let values = focusMinutesPerWeek
        guard values.count >= 2 else { return 0 }
        let current = values.last ?? 0
        let previous = values[values.count - 2]

        guard previous > 0 else {
            return current > 0 ? 100 : 0
        }

        let delta = Double(current - previous) / Double(previous) * 100
        return Int(delta.rounded())
    }

    private var trendText: String {
        if trendDelta > 0 { return "+\(trendDelta)%" }
        if trendDelta < 0 { return "\(trendDelta)%" }
        return "0%"
    }

    private var trendColor: Color {
        if trendDelta > 0 { return Color(arenaHex: AppArenaPalette.green) }
        if trendDelta < 0 { return Color(arenaHex: AppArenaPalette.coral) }
        return .white.opacity(0.42)
    }

    /// Hangi gün en verimli? (haftanın en çok focus alan günü)
    private var bestDayInsight: String? {
        guard !focusSessions.isEmpty else { return nil }

        let now = Date()
        guard let monthAgo = calendar.date(byAdding: .day, value: -28, to: now) else { return nil }

        let recent = focusSessions.filter { $0.startedAt >= monthAgo }
        guard !recent.isEmpty else { return nil }

        // Pzt=0..Paz=6
        var dayTotals = Array(repeating: 0, count: 7)
        var dayCounts = Array(repeating: 0, count: 7)

        for session in recent {
            let weekday = (calendar.component(.weekday, from: session.startedAt) + 5) % 7
            dayTotals[weekday] += session.completedSeconds / 60
            dayCounts[weekday] += 1
        }

        // Ortalama dakika hesabı
        let averages: [(idx: Int, avg: Double)] = (0..<7).map { idx in
            let count = dayCounts[idx]
            let avg = count > 0 ? Double(dayTotals[idx]) / Double(count) : 0
            return (idx, avg)
        }

        guard let best = averages.max(by: { $0.avg < $1.avg }), best.avg > 0 else { return nil }

        let dayName = dayName(for: best.idx)
        let avgMinutes = Int(best.avg.rounded())

        if avgMinutes < 10 { return nil }

        let hours = avgMinutes / 60
        let mins = avgMinutes % 60

        let durationText: String
        if hours > 0 && mins > 0 {
            durationText = isTurkish ? "\(hours)sa \(mins)dk" : "\(hours)h \(mins)m"
        } else if hours > 0 {
            durationText = isTurkish ? "\(hours) saat" : "\(hours)h"
        } else {
            durationText = isTurkish ? "\(mins) dk" : "\(mins) min"
        }

        if isTurkish {
            return "\(dayName) en verimli günün — ortalama \(durationText)"
        } else {
            return "\(dayName) is your best day — average \(durationText)"
        }
    }

    private func dayName(for index: Int) -> String {
        let tr = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"]
        let en = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let safe = max(0, min(6, index))
        return isTurkish ? tr[safe] : en[safe]
    }

    // MARK: Background

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        primaryAccent.opacity(0.075),
                        secondaryAccent.opacity(0.045),
                        Color(arenaHex: AppArenaPalette.surface).opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                primaryAccent.opacity(0.13),
                                Color.clear
                            ],
                            center: .topTrailing,
                            startRadius: 5,
                            endRadius: 170
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(primaryAccent.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 14, y: 8)
    }
}
