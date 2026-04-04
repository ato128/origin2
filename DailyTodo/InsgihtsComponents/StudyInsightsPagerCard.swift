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
            LazyHStack(spacing: 14) {
                ForEach(data.pages) { page in
                    pageSurface(page)
                        .frame(width: 318)
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
        VStack(alignment: .leading, spacing: 16) {
            topLabel(title: "Sınavlar", tint: softAmber)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(page.subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)

                    Text("En yakın sınav")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                }

                Spacer()

                softBadge(text: page.statusText, tint: softAmber)
            }

            HStack(spacing: 10) {
                infoMetricCard(
                    value: page.primaryValue,
                    label: "sınava kalan süre",
                    tint: softRed
                )

                infoMetricCard(
                    value: page.secondaryValue,
                    label: "hazırlık seviyesi",
                    tint: softAmber
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Hazırlık çizgisi")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(softRed)

                    Spacer()

                    Text("Bu hafta")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.secondaryText)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 7)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [softPink.opacity(0.95), softRed],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(16, geo.size.width * max(page.progress, 0.06)), height: 7)
                    }
                }
                .frame(height: 7)

                HStack(spacing: 8) {
                    weekStripCell(label: "Pzt", value: max(page.progress * 0.32, 0.10), tint: softPink)
                    weekStripCell(label: "Sal", value: max(page.progress * 0.48, 0.10), tint: softPink)
                    weekStripCell(label: "Çar", value: max(page.progress * 0.44, 0.10), tint: softPink)
                    weekStripCell(label: "Per", value: max(page.progress * 0.50, 0.10), tint: softPink)
                    weekStripCell(label: "Cum", value: max(page.progress * 0.56, 0.10), tint: softPink)
                    weekStripCell(label: "Cmt", value: max(page.progress * 0.60, 0.10), tint: softPink)
                    weekStripCell(label: "Paz", value: max(page.progress * 0.36, 0.10), tint: softPink)
                }
            }
            .padding(14)
            .background(innerPanel)

            chipsRow(page.chips)

            secondaryCTA(title: page.ctaTitle, tint: softPink) {
                onTap(page.action)
            }
        }
        .padding(16)
        .background(softSurface(stroke: softPink.opacity(0.08)))
    }

    private func examsEmptyPage(_ page: StudyInsightsDeckPageData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            topLabel(title: "Sınavlar", tint: softAmber)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Henüz sınav görünümü yok")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
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

            Spacer(minLength: 0)

            secondaryCTA(title: page.emptyButtonTitle ?? page.ctaTitle, tint: softAmber) {
                onTap(page.action)
            }
        }
        .padding(16)
        .background(softSurface(stroke: softAmber.opacity(0.08)))
    }

    // MARK: - Courses

    private func coursesFilledPage(_ page: StudyInsightsDeckPageData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            topLabel(title: "Dersler", tint: softBlue)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ders yükü görünümü")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.secondaryText)

                    Text("Ders dengesi")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                }

                Spacer()

                iconBadge(systemName: "books.vertical.fill", tint: softBlue)
            }

            HStack(spacing: 10) {
                infoMetricCard(
                    value: page.primaryValue,
                    label: "daha çok ilgi isteyen",
                    tint: softBlue
                )

                infoMetricCard(
                    value: page.secondaryValue,
                    label: "en güçlü ders",
                    tint: softGreen
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Ders dağılımı")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.secondaryText)

                VStack(spacing: 10) {
                    courseBar(label: "Öncelik", value: max(page.progress, 0.16), tint: softBlue)
                    courseBar(label: "Denge", value: max(page.progress * 0.82, 0.12), tint: softCyan)
                    courseBar(label: "Derinlik", value: max(page.progress * 0.58, 0.10), tint: softAmber)
                }
            }
            .padding(14)
            .background(innerPanel)

            chipsRow(page.chips)

            secondaryCTA(title: page.ctaTitle, tint: softBlue) {
                onTap(page.action)
            }
        }
        .padding(16)
        .background(softSurface(stroke: softBlue.opacity(0.08)))
    }

    private func coursesEmptyPage(_ page: StudyInsightsDeckPageData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            topLabel(title: "Dersler", tint: softBlue)

            HStack {
                Text("Henüz ders dengesi oluşmadı")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                Spacer()

                iconBadge(systemName: "books.vertical.fill", tint: softBlue)
            }

            Text(page.emptySubtitle ?? "")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(3)

            HStack(spacing: 8) {
                chipPill("Ders etiketi ekle", tint: softBlue)
                chipPill("Görev oluştur", tint: softAmber)
            }

            HStack(spacing: 8) {
                ghostCourseCard(label: "Mat", tint: softBlue)
                ghostCourseCard(label: "Fiz", tint: softPurple)
                ghostCourseCard(label: "Kim", tint: softGreen)
                ghostCourseCard(label: "Calc", tint: softAmber)
            }

            secondaryCTA(title: page.emptyButtonTitle ?? page.ctaTitle, tint: softBlue, icon: "plus") {
                onTap(page.action)
            }
        }
        .padding(16)
        .background(softSurface(stroke: softBlue.opacity(0.08)))
    }

    // MARK: - Rhythm

    private func rhythmFilledPage(_ page: StudyInsightsDeckPageData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            topLabel(title: "Ritim", tint: softGreen)

            HStack {
                HStack(spacing: 8) {
                    Text("Ritim")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Circle()
                        .fill(softGreen)
                        .frame(width: 8, height: 8)
                        .shadow(color: softGreen.opacity(0.28), radius: 6)
                }

                Spacer()

                softBadge(text: "Aktif", tint: softGreen)
            }

            Text("Çalışma ritminin gün içi akışı")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.secondaryText)

            HStack(spacing: 10) {
                infoMetricCard(
                    value: page.primaryValue,
                    label: "en iyi zaman",
                    tint: softGreen
                )

                infoMetricCard(
                    value: page.secondaryValue,
                    label: "en iyi gün",
                    tint: softBlue
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Haftalık aktivite haritası")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.secondaryText)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                    ForEach(0..<18, id: \.self) { idx in
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(idx == 8 ? softGreen.opacity(0.14) : palette.secondaryCardFill.opacity(0.85))
                            .overlay(
                                Text("\(idx + 6)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(idx == 8 ? softGreen : palette.secondaryText)
                            )
                            .frame(height: 42)
                    }
                }
            }
            .padding(14)
            .background(innerPanel)

            HStack(spacing: 8) {
                chipPill(page.chips.first?.text ?? "İlk focus", tint: softBlue)
                chipPill(page.chips.dropFirst().first?.text ?? "Görev bitir", tint: softGreen)
            }

            secondaryCTA(title: page.ctaTitle, tint: softGreen, icon: "plus") {
                onTap(page.action)
            }
        }
        .padding(16)
        .background(softSurface(stroke: softGreen.opacity(0.08)))
    }

    private func rhythmEmptyPage(_ page: StudyInsightsDeckPageData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            topLabel(title: "Ritim", tint: softGreen)

            HStack {
                Text("Ritmin henüz oluşmadı")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
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

            secondaryCTA(title: page.emptyButtonTitle ?? page.ctaTitle, tint: softGreen, icon: "plus") {
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

    private func infoMetricCard(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)
                .minimumScaleFactor(0.76)
                .lineLimit(2)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.028))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func placeholderMetric(title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(palette.secondaryCardFill)
                .frame(width: 70, height: 16)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.028))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.cardStroke.opacity(0.9), lineWidth: 1)
                )
        )
    }

    private func weekStripCell(label: String, value: Double, tint: Color) -> some View {
        VStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint)
                .frame(height: max(8, value * 34))

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
    }

    private func courseBar(label: String, value: Double, tint: Color) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .frame(width: 52, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 7)

                    Capsule()
                        .fill(tint)
                        .frame(width: max(12, geo.size.width * value), height: 7)
                }
            }
            .frame(height: 7)
        }
    }

    private func ghostCourseCard(label: String, tint: Color) -> some View {
        VStack(spacing: 9) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(palette.secondaryText)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(palette.secondaryCardFill.opacity(0.9))
                .frame(height: 38)

            Capsule()
                .fill(tint)
                .frame(width: 14, height: 3)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.024))
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
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(tint.opacity(0.10))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.08), lineWidth: 1)
            )
    }

    private func secondaryCTA(title: String, tint: Color, icon: String = "arrow.right", action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
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
                .frame(width: 38, height: 38)

            Image(systemName: systemName)
                .font(.system(size: 17, weight: .bold))
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
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.028))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(palette.cardStroke.opacity(0.85), lineWidth: 1)
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
