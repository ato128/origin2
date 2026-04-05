//
//  StudyInsightsPagerCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 4.04.2026.
//

import SwiftUI

struct StudyInsightsPagerCard: View {
    let data: StudyInsightsDeckData
    let onTap: (SmartSuggestionAction) -> Void

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(data.pages) { page in
                    pageSurface(page)
                        .frame(width: 306)
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollTargetBehavior(.viewAligned)
    }

    @ViewBuilder
    private func pageSurface(_ page: StudyInsightsDeckPageData) -> some View {
        switch page.page {
        case .exams:
            if page.isEmpty {
                examsEmptyPage(page)
            } else {
                examsFilledPage(page)
            }

        case .courses:
            if page.isEmpty {
                coursesEmptyPage(page)
            } else {
                coursesFilledPage(page)
            }

        case .rhythm:
            if page.isEmpty {
                rhythmEmptyPage(page)
            } else {
                rhythmFilledPage(page)
            }
        }
    }

    // MARK: - Exams

    private func examsFilledPage(_ page: StudyInsightsDeckPageData) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            topLabel(title: "Sınavlar", tint: softAmber)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(page.subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)

                    Text("En yakın sınav")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                }

                Spacer()

                softBadge(text: page.statusText, tint: softAmber)
            }

            HStack(spacing: 10) {
                compactMetricCard(
                    value: page.primaryValue,
                    label: "kalan süre",
                    tint: softRed
                )

                compactMetricCard(
                    value: page.secondaryValue,
                    label: "hazırlık",
                    tint: softAmber
                )
            }

            compactProgressPanel(
                title: "Hazırlık çizgisi",
                trailing: "Bu hafta",
                tint: softPink,
                progress: page.progress,
                stripValues: [
                    max(page.progress * 0.32, 0.10),
                    max(page.progress * 0.48, 0.10),
                    max(page.progress * 0.44, 0.10),
                    max(page.progress * 0.50, 0.10),
                    max(page.progress * 0.56, 0.10),
                    max(page.progress * 0.60, 0.10),
                    max(page.progress * 0.36, 0.10)
                ]
            )

            chipsRow(page.chips)

            compactCTA(title: page.ctaTitle, tint: softPink) {
                onTap(page.action)
            }
        }
        .padding(16)
        .background(softSurface(stroke: softPink.opacity(0.08)))
    }

    private func examsEmptyPage(_ page: StudyInsightsDeckPageData) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            topLabel(title: "Sınavlar", tint: softAmber)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Henüz sınav görünümü yok")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Text(page.emptySubtitle ?? "")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(3)
                }

                Spacer()

                iconBadge(systemName: "graduationcap.fill", tint: softAmber)
            }

            HStack(spacing: 10) {
                placeholderMetric(title: "Kalan gün")
                placeholderMetric(title: "Hazırlık")
            }

            HStack(spacing: 8) {
                chipPill("İlk sınav", tint: softAmber)
                chipPill("Plan aç", tint: softBlue)
            }

            compactCTA(title: page.emptyButtonTitle ?? page.ctaTitle, tint: softAmber) {
                onTap(page.action)
            }
        }
        .padding(16)
        .background(softSurface(stroke: softAmber.opacity(0.08)))
    }

    // MARK: - Courses

    private func coursesFilledPage(_ page: StudyInsightsDeckPageData) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            topLabel(title: "Dersler", tint: softBlue)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ders yükü görünümü")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.secondaryText)

                    Text("Ders dengesi")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                }

                Spacer()

                iconBadge(systemName: "books.vertical.fill", tint: softBlue)
            }

            HStack(spacing: 10) {
                compactMetricCard(
                    value: page.primaryValue,
                    label: "ilgisi azalan",
                    tint: softBlue
                )

                compactMetricCard(
                    value: page.secondaryValue,
                    label: "öne çıkan",
                    tint: softGreen
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Ders dağılımı")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.secondaryText)

                VStack(spacing: 9) {
                    courseBar(label: "Öncelik", value: max(page.progress, 0.16), tint: softBlue)
                    courseBar(label: "Denge", value: max(page.progress * 0.82, 0.12), tint: softCyan)
                    courseBar(label: "Derinlik", value: max(page.progress * 0.58, 0.10), tint: softAmber)
                }
            }
            .padding(13)
            .background(innerPanel)

            chipsRow(page.chips)

            compactCTA(title: page.ctaTitle, tint: softBlue) {
                onTap(page.action)
            }
        }
        .padding(16)
        .background(softSurface(stroke: softBlue.opacity(0.08)))
    }

    private func coursesEmptyPage(_ page: StudyInsightsDeckPageData) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            topLabel(title: "Dersler", tint: softBlue)

            HStack(alignment: .top) {
                Text("Henüz ders dengesi oluşmadı")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                Spacer()

                iconBadge(systemName: "books.vertical.fill", tint: softBlue)
            }

            Text(page.emptySubtitle ?? "")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(3)

            HStack(spacing: 8) {
                chipPill("Ders etiketi", tint: softBlue)
                chipPill("Görev oluştur", tint: softAmber)
            }

            HStack(spacing: 8) {
                ghostCourseCard(label: "Mat", tint: softBlue)
                ghostCourseCard(label: "Fiz", tint: softPurple)
                ghostCourseCard(label: "Kim", tint: softGreen)
                ghostCourseCard(label: "Calc", tint: softAmber)
            }

            compactCTA(title: page.emptyButtonTitle ?? page.ctaTitle, tint: softBlue, icon: "plus") {
                onTap(page.action)
            }
        }
        .padding(16)
        .background(softSurface(stroke: softBlue.opacity(0.08)))
    }

    // MARK: - Rhythm

    private func rhythmFilledPage(_ page: StudyInsightsDeckPageData) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            topLabel(title: "Ritim", tint: softGreen)

            HStack(alignment: .top) {
                HStack(spacing: 7) {
                    Text("Ritim")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Circle()
                        .fill(softGreen)
                        .frame(width: 8, height: 8)
                        .shadow(color: softGreen.opacity(0.24), radius: 5)
                }

                Spacer()

                softBadge(text: "Aktif", tint: softGreen)
            }

            Text("Gün içi çalışma akışı")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.secondaryText)

            HStack(spacing: 10) {
                compactMetricCard(
                    value: page.primaryValue,
                    label: "en iyi zaman",
                    tint: softGreen
                )

                compactMetricCard(
                    value: page.secondaryValue,
                    label: "en iyi gün",
                    tint: softBlue
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Haftalık aktivite")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.secondaryText)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 6), spacing: 7) {
                    ForEach(0..<18, id: \.self) { idx in
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(idx == 8 ? softGreen.opacity(0.14) : palette.secondaryCardFill.opacity(0.85))
                            .overlay(
                                Text("\(idx + 6)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(idx == 8 ? softGreen : palette.secondaryText)
                            )
                            .frame(height: 38)
                    }
                }
            }
            .padding(13)
            .background(innerPanel)

            HStack(spacing: 8) {
                chipPill(page.chips.first?.text ?? "İlk focus", tint: softBlue)
                chipPill(page.chips.dropFirst().first?.text ?? "Görev bitir", tint: softGreen)
            }
            compactCTA(title: page.ctaTitle, tint: softGreen, icon: "plus") {
                onTap(page.action)
            }
        }
        .padding(16)
        .background(softSurface(stroke: softGreen.opacity(0.08)))
    }

    private func rhythmEmptyPage(_ page: StudyInsightsDeckPageData) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            topLabel(title: "Ritim", tint: softGreen)

            HStack(alignment: .top) {
                Text("Ritmin henüz oluşmadı")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                Spacer()

                iconBadge(systemName: "waveform.path.ecg", tint: softGreen)
            }

            Text(page.emptySubtitle ?? "")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(3)

            HStack(spacing: 8) {
                chipPill("İlk focus", tint: softBlue)
                chipPill("Görev bitir", tint: softGreen)
            }

            compactCTA(title: page.emptyButtonTitle ?? page.ctaTitle, tint: softGreen, icon: "plus") {
                onTap(page.action)
            }
        }
        .padding(16)
        .background(softSurface(stroke: softGreen.opacity(0.08)))
    }

    // MARK: - Shared UI

    private func topLabel(title: String, tint: Color) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(tint.opacity(0.10))
                )

            Spacer()
        }
    }

    private func compactMetricCard(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)
                .minimumScaleFactor(0.78)
                .lineLimit(2)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.white.opacity(0.026))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(tint.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func placeholderMetric(title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(palette.secondaryCardFill)
                .frame(width: 64, height: 14)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.white.opacity(0.026))
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(palette.cardStroke.opacity(0.84), lineWidth: 1)
                )
        )
    }

    private func compactProgressPanel(
        title: String,
        trailing: String,
        tint: Color,
        progress: Double,
        stripValues: [Double]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)

                Spacer()

                Text(trailing)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.secondaryText)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 6)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.95), tint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(14, geo.size.width * max(progress, 0.06)), height: 6)
                }
            }
            .frame(height: 6)

            HStack(spacing: 7) {
                ForEach(Array(stripValues.enumerated()), id: \.offset) { index, value in
                    weekStripCell(
                        label: dayLabel(index),
                        value: value,
                        tint: tint
                    )
                }
            }
        }
        .padding(13)
        .background(innerPanel)
    }

    private func dayLabel(_ index: Int) -> String {
        let labels = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
        return labels[index]
    }

    private func weekStripCell(label: String, value: Double, tint: Color) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint)
                .frame(height: max(7, value * 28))

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
    }

    private func courseBar(label: String, value: Double, tint: Color) -> some View {
        HStack(spacing: 9) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .frame(width: 50, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 6)

                    Capsule()
                        .fill(tint)
                        .frame(width: max(12, geo.size.width * value), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private func ghostCourseCard(label: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(palette.secondaryText)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(palette.secondaryCardFill.opacity(0.88))
                .frame(height: 32)

            Capsule()
                .fill(tint)
                .frame(width: 14, height: 3)
        }
        .frame(maxWidth: .infinity)
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(0.022))
        )
    }

    private func chipsRow(_ chips: [StudyDeckChip]) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(chips.prefix(3).enumerated()), id: \.offset) { _, chip in
                chipPill(chip.text, tint: chip.tint)
            }
        }
    }

    private func chipPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(tint.opacity(0.10))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.08), lineWidth: 1)
            )
    }

    private func compactCTA(title: String, tint: Color, icon: String = "arrow.right", action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 42, height: 42)

                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
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

    private func softBadge(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(tint.opacity(0.10))
            )
    }

    private func iconBadge(systemName: String, tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.10))
                .frame(width: 36, height: 36)

            Image(systemName: systemName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tint)
        }
    }

    private func softSurface(stroke: Color) -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
    }

    private var innerPanel: some View {
        RoundedRectangle(cornerRadius: 17, style: .continuous)
            .fill(Color.white.opacity(0.024))
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(palette.cardStroke.opacity(0.80), lineWidth: 1)
            )
    }

    private var softRed: Color { Color.red.opacity(0.78) }
    private var softPink: Color { Color.pink.opacity(0.84) }
    private var softAmber: Color { Color.orange.opacity(0.82) }
    private var softBlue: Color { Color.blue.opacity(0.82) }
    private var softCyan: Color { Color.cyan.opacity(0.78) }
    private var softGreen: Color { Color.green.opacity(0.80) }
    private var softPurple: Color { Color.purple.opacity(0.78) }
}
