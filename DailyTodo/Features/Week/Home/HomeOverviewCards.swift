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
                overviewFocusMetricCard
                overviewCourseMetricCard
            }
        }
    }

    // MARK: - Main Plan Card

    var overviewMainMetricCard: some View {
        Button {
            handleMainMetricTap()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 10) {
                    Text(mainMetricCardTitle)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.96))
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Spacer(minLength: 8)

                    premiumHeroCornerIcon(
                        systemName: mainMetricIcon,
                        tint: .white.opacity(0.9),
                        glowColor: todayProgressAccent.opacity(0.28)
                    )
                }

                Spacer(minLength: 14)

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 9)

                    Circle()
                        .trim(from: 0, to: safeTodayCompletionRatio)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color.white.opacity(0.96),
                                    todayProgressAccent.opacity(0.95),
                                    Color.white.opacity(0.88)
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 9, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .shadow(color: todayProgressAccent.opacity(0.18), radius: 8)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    todayProgressAccent.opacity(0.10),
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

                        Text("tamamlandı")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.74))
                    }
                }
                .frame(width: 108, height: 108)

                Spacer(minLength: 16)

                VStack(alignment: .leading, spacing: 4) {
                    Text(todayCompletionSummaryText)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.97))
                        .lineLimit(2)
                        .minimumScaleFactor(0.84)

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
                    secondaryAccent: todayProgressSecondaryAccent,
                    strength: todayCardGlowStrength,
                    cornerRadius: 34,
                    emphasizeBottomGlow: safeTodayCompletionRatio >= 1 || !hasStudentCourses
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Focus Card

    var overviewFocusMetricCard: some View {
        Button {
            onOpenFocus()
        } label: {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(focusMetricEyebrowText)
                            .font(.system(size: 10.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(focusMetricAccent.opacity(0.98))
                            .tracking(1.1)

                        Spacer(minLength: 8)

                        premiumHeroCornerIcon(
                            systemName: focusMetricIconName,
                            tint: .white.opacity(0.9),
                            glowColor: focusMetricAccent.opacity(0.32)
                        )
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(focusMetricMainText)
                            .font(.system(size: hasFocusedTodayForHome && !isFocusCurrentlyActive ? 28 : 32,
                                          weight: .heavy,
                                          design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Text(focusMetricSubtitleText)
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.76))
                            .lineLimit(2)
                            .minimumScaleFactor(0.84)
                    }

                    Spacer(minLength: 8)

                    premiumOrbitDecorationCompact
                }

                if hasFocusedTodayForHome && !isFocusCurrentlyActive {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 58, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.95),
                                    Color(red: 1.00, green: 0.72, blue: 0.22),
                                    Color(red: 1.00, green: 0.30, blue: 0.10)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.orange.opacity(0.55), radius: 18)
                        .shadow(color: Color.red.opacity(0.20), radius: 28)
                        .opacity(0.32)
                        .offset(x: 4, y: 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            .background(
                premiumOverviewCardBackground(
                    accent: focusMetricAccent,
                    secondaryAccent: focusMetricSecondaryAccent,
                    strength: focusMetricGlowStrength,
                    cornerRadius: 28,
                    emphasizeBottomGlow: isFocusCurrentlyActive || hasFocusedTodayForHome
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.065), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Course Card

    var overviewCourseMetricCard: some View {
        Button {
            handleCourseMetricTap()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    Text(courseMetricEyebrowText)
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(courseMetricAccent.opacity(0.98))
                        .tracking(0.9)

                    Spacer(minLength: 8)

                    premiumHeroCornerIcon(
                        systemName: courseMetricIconName,
                        tint: .white.opacity(0.9),
                        glowColor: courseMetricAccent.opacity(0.26)
                    )
                }

                Spacer(minLength: 14)

                VStack(alignment: .leading, spacing: 3) {
                    Text(courseMetricTitle)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.98))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(courseMetricSubtitle)
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.74))
                        .lineLimit(2)
                        .minimumScaleFactor(0.84)
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
                    accent: courseMetricAccent,
                    secondaryAccent: courseMetricSecondaryAccent,
                    strength: courseMetricGlowStrength,
                    cornerRadius: 28,
                    emphasizeBottomGlow: nextEvent != nil || hasStudentCourses
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.065), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    func handleMainMetricTap() {
        if !hasStudentCourses {
            onOpenWeek()
            return
        }

        showTasksShortcut = true
    }

    func handleCourseMetricTap() {
        onOpenWeek()
    }

    // MARK: - Main Metric State

    var mainMetricCardTitle: String {
        if !hasStudentCourses {
            return "Başlangıç"
        }

        if totalTodayTaskCount == 0 {
            return "Bugünkü Plan"
        }

        if completedTodayCount >= totalTodayTaskCount {
            return "Bugün Tamam"
        }

        return "Bugünkü İlerleme"
    }

    var mainMetricIcon: String {
        if !hasStudentCourses {
            return "graduationcap.fill"
        }

        if totalTodayTaskCount == 0 {
            return "sparkles"
        }

        if completedTodayCount >= totalTodayTaskCount {
            return "checkmark.circle.fill"
        }

        return "checkmark.circle"
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
        if !hasStudentCourses {
            return "Derslerini ekle"
        }

        if totalTodayTaskCount == 0 {
            return "Bir ders seç ve çalış"
        }

        if completedTodayCount >= totalTodayTaskCount {
            return "Bugün tamam"
        }

        return "\(completedTodayCount)/\(totalTodayTaskCount) görev bitti"
    }

    var todayCompletionFootnoteText: String {
        if !hasStudentCourses {
            return "Planın buna göre akıllanır"
        }

        if totalTodayTaskCount == 0 {
            return "Sana çalışma planı oluşturalım"
        }

        let remaining = max(totalTodayTaskCount - completedTodayCount, 0)

        if remaining == 0 {
            return "Bugünü temiz kapattın"
        }

        return "\(remaining) görev daha kaldı"
    }

    var todayProgressAccent: Color {
        if !hasStudentCourses {
            return Color(red: 0.44, green: 0.58, blue: 1.00)
        }

        if safeTodayCompletionRatio >= 1 {
            return Color(red: 0.20, green: 0.78, blue: 0.44)
        }

        if safeTodayCompletionRatio >= 0.66 {
            return Color(red: 0.35, green: 0.67, blue: 1.00)
        }

        if safeTodayCompletionRatio > 0 {
            return Color(red: 0.55, green: 0.44, blue: 1.00)
        }

        return Color(red: 0.48, green: 0.35, blue: 0.98)
    }

    var todayProgressSecondaryAccent: Color {
        if !hasStudentCourses {
            return Color(red: 0.08, green: 0.18, blue: 0.36)
        }

        if safeTodayCompletionRatio >= 1 {
            return Color(red: 0.04, green: 0.30, blue: 0.20)
        }

        return Color(red: 0.12, green: 0.06, blue: 0.28)
    }

    var todayCardGlowStrength: Double {
        if !hasStudentCourses { return 0.74 }
        return 0.34 + (Double(safeTodayCompletionRatio) * 0.66)
    }

    // MARK: - Focus Metric State

    var isFocusCurrentlyActive: Bool {
        focusSession.isSessionActive || hasAnyActiveFocusSession
    }

    var hasFocusedTodayForHome: Bool {
        if isFocusCurrentlyActive { return true }
        return streakCount > 0
    }

    var focusMetricEyebrowText: String {
        if isFocusCurrentlyActive {
            return "🔥 ODAK"
        }

        if hasFocusedTodayForHome {
            return "🔥 ATEŞ"
        }

        return "🔥 FOCUS"
    }

    var focusMetricMainText: String {
        if isFocusCurrentlyActive {
            return "Aktif"
        }

        if hasFocusedTodayForHome {
            return "Yandı"
        }

        return "Başla"
    }

    var focusMetricSubtitleText: String {
        if isFocusCurrentlyActive {
            return "oturum devam ediyor"
        }

        if hasFocusedTodayForHome {
            return streakCount > 0 ? "\(streakCount) gün seri" : "bugün odaklandın"
        }

        return "ilk oturumu başlat"
    }

    var focusMetricIconName: String {
        if isFocusCurrentlyActive {
            return "timer"
        }

        if hasFocusedTodayForHome {
            return "flame.fill"
        }

        return "play.fill"
    }

    var focusMetricAccent: Color {
        if isFocusCurrentlyActive {
            return Color(red: 0.16, green: 0.56, blue: 1.00)
        }

        if hasFocusedTodayForHome {
            return Color(red: 1.00, green: 0.52, blue: 0.16)
        }

        return Color(red: 0.56, green: 0.36, blue: 1.00)
    }

    var focusMetricSecondaryAccent: Color {
        if isFocusCurrentlyActive {
            return Color(red: 0.03, green: 0.18, blue: 0.36)
        }

        if hasFocusedTodayForHome {
            return Color(red: 0.36, green: 0.10, blue: 0.04)
        }

        return Color(red: 0.16, green: 0.07, blue: 0.32)
    }

    var focusMetricGlowStrength: Double {
        if isFocusCurrentlyActive { return 0.94 }
        if hasFocusedTodayForHome { return 0.86 }
        return 0.62
    }

    // MARK: - Course Metric State

    var courseMetricEyebrowText: String {
        if nextEvent != nil {
            return "✨ SIRADAKİ"
        }

        return "✨ DERS"
    }

    var courseMetricIconName: String {
        if nextEvent != nil {
            return "calendar.badge.clock"
        }

        if hasStudentCourses {
            return "books.vertical.fill"
        }

        return "calendar.badge.plus"
    }

    var courseMetricTitle: String {
        if let nextEvent {
            return nextEvent.title
        }

        if hasStudentCourses {
            return "\(studentCourseCount) aktif ders"
        }

        return "Ders ekle"
    }

    var courseMetricSubtitle: String {
        guard let nextEvent else {
            if hasStudentCourses {
                return coursePreviewText
            }

            return "Derslerini seç, haftanı ona göre kuralım"
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

    var courseMetricAccent: Color {
        if let nextEvent {
            let hex = nextEvent.colorHex.trimmingCharacters(in: .whitespacesAndNewlines)
            if let color = colorFromHex(hex), !hex.isEmpty {
                return color
            }

            return Color(red: 0.18, green: 0.62, blue: 1.00)
        }

        if hasStudentCourses {
            return primaryCourseAccent
        }

        return Color(red: 0.55, green: 0.60, blue: 0.72)
    }

    var courseMetricSecondaryAccent: Color {
        if nextEvent != nil {
            return Color(red: 0.03, green: 0.18, blue: 0.34)
        }

        if hasStudentCourses {
            return Color(red: 0.10, green: 0.08, blue: 0.28)
        }

        return Color(red: 0.16, green: 0.16, blue: 0.22)
    }

    var courseMetricGlowStrength: Double {
        if nextEvent != nil { return 0.92 }
        if hasStudentCourses { return 0.72 }
        return 0.42
    }

    var primaryCourseAccent: Color {
        guard let first = studentActiveCourses.first else {
            return Color(red: 0.50, green: 0.56, blue: 0.72)
        }

        let hex = first.colorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if let color = colorFromHex(hex), !hex.isEmpty {
            return color
        }

        return Color(red: 0.28, green: 0.56, blue: 1.00)
    }

    // MARK: - Student Data

    var studentActiveCourses: [Course] {
        studentStore.courses.filter { !$0.isArchived }
    }

    var studentCourseCount: Int {
        studentActiveCourses.count
    }

    var hasStudentCourses: Bool {
        studentCourseCount > 0
    }

    var coursePreviewText: String {
        let previews = studentActiveCourses
            .prefix(2)
            .map { course in
                let code = course.code.trimmingCharacters(in: .whitespacesAndNewlines)
                return code.isEmpty ? course.name : code
            }

        if previews.isEmpty {
            return "Derslerini ekle"
        }

        return previews.joined(separator: ", ")
    }

    func studentGradeLabel(_ value: String) -> String {
        switch value {
        case "prep": return "Hazırlık"
        case "1": return "1. sınıf"
        case "2": return "2. sınıf"
        case "3": return "3. sınıf"
        case "4": return "4. sınıf"
        case "5": return "5. sınıf"
        case "6": return "6. sınıf"
        default: return "\(value). sınıf"
        }
    }

    // MARK: - Shared UI

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
                            glowColor.opacity(0.24),
                            Color.white.opacity(0.035),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 22
                    )
                )
                .frame(width: 34, height: 34)

            Circle()
                .fill(Color.white.opacity(0.055))
                .frame(width: 28, height: 28)

            Circle()
                .stroke(Color.white.opacity(0.075), lineWidth: 1)
                .frame(width: 28, height: 28)

            Image(systemName: systemName)
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(tint)
                .shadow(color: glowColor.opacity(0.24), radius: 4)
        }
    }

    func premiumOverviewCardBackground(
        accent: Color,
        secondaryAccent: Color,
        strength: Double,
        cornerRadius: CGFloat,
        emphasizeBottomGlow: Bool
    ) -> some View {
        let topGlow = 0.12 + (strength * 0.08)
        let leadingGlow = 0.16 + (strength * 0.10)
        let bottomGlow = emphasizeBottomGlow ? (0.16 + strength * 0.18) : (0.08 + strength * 0.08)

        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.82),
                        accent.opacity(0.46),
                        secondaryAccent.opacity(0.78),
                        Color(red: 0.035, green: 0.035, blue: 0.070)
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
                                Color.black.opacity(0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
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
                            endRadius: 170
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
                            endRadius: 170
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
                                Color.black.opacity(0.20)
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
            opacityScale: 0.72
        )
    }

    var premiumOrbitDecorationCompact: some View {
        premiumOrbitDecoration(
            height: 30,
            circleSize: 28,
            pointScale: 0.72,
            opacityScale: 0.62
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
