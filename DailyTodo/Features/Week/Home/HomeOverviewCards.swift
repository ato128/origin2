//
//  HomeOverviewCards.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 8.04.2026.
//

import SwiftUI

extension HomeDashboardView {

    var todayOverviewTopCards: some View {
        HStack(alignment: .top, spacing: 12) {
            overviewMainMetricCard
                .frame(maxWidth: .infinity)

            VStack(spacing: 12) {
                overviewFocusMetricCard
                overviewCourseMetricCard
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Main Plan Card

    var overviewMainMetricCard: some View {
        Button {
            handleMainMetricTap()
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(tr("oc_todays_plan_caps"))
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.6)
                            .foregroundStyle(todayProgressAccent.opacity(0.95))

                        Text(mainMetricCardTitle)
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: mainMetricIcon)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(todayProgressAccent.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .stroke(todayProgressAccent.opacity(0.18), lineWidth: 1)
                                )
                        )
                }

                Spacer(minLength: 4)

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 10)
                        .frame(width: 112, height: 112)

                    Circle()
                        .trim(from: 0, to: max(safeTodayCompletionRatio, 0.025))
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(arenaHex: AppArenaPalette.cyan),
                                    todayProgressAccent,
                                    Color(arenaHex: AppArenaPalette.purple)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 112, height: 112)

                    VStack(spacing: 2) {
                        Text(todayCompletionPercentageText)
                            .font(.system(size: 31, weight: .black))
                            .foregroundStyle(.white)
                            .monospacedDigit()

                        Text("TAMAM")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(1.1)
                            .foregroundStyle(.white.opacity(0.42))
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 2)

                VStack(alignment: .leading, spacing: 5) {
                    Text(todayCompletionSummaryText)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(todayCompletionFootnoteText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(2)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
            .background(
                homeArenaCardBackground(
                    accent: todayProgressAccent,
                    cornerRadius: 30,
                    intensity: safeTodayCompletionRatio >= 1 ? 1.15 : 0.90
                )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Focus Card

    var overviewFocusMetricCard: some View {
        Button {
            onOpenFocus()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(focusMetricEyebrowText.uppercased())
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.6)
                            .foregroundStyle(focusMetricAccent.opacity(0.95))

                        Text(focusMetricMainText)
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: focusMetricIconName)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(focusMetricAccent.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .stroke(focusMetricAccent.opacity(0.18), lineWidth: 1)
                                )
                        )
                }

                Spacer(minLength: 0)

                Text(focusMetricSubtitleText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.54))
                    .lineLimit(2)

                HStack(spacing: 5) {
                    Circle()
                        .fill(isFocusCurrentlyActive ? Color(arenaHex: AppArenaPalette.green) : focusMetricAccent)
                        .frame(width: 6, height: 6)

                    Text(isFocusCurrentlyActive ? "LIVE" : "READY")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(isFocusCurrentlyActive ? Color(arenaHex: AppArenaPalette.green) : focusMetricAccent)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
            .background(
                homeArenaCardBackground(
                    accent: focusMetricAccent,
                    cornerRadius: 28,
                    intensity: isFocusCurrentlyActive ? 1.18 : 0.86
                )
            )
        }
        .buttonStyle(.plain)
    }
    // MARK: - Course Card

    var overviewCourseMetricCard: some View {
        Button {
            handleCourseMetricTap()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(courseMetricEyebrowText.uppercased())
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.6)
                            .foregroundStyle(courseMetricAccent.opacity(0.95))

                        Text(courseMetricTitle)
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: courseMetricIconName)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(courseMetricAccent.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .stroke(courseMetricAccent.opacity(0.18), lineWidth: 1)
                                )
                        )
                }

                Spacer(minLength: 0)

                Text(courseMetricSubtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.54))
                    .lineLimit(2)

                HStack(spacing: 5) {
                    Circle()
                        .fill(courseMetricAccent)
                        .frame(width: 6, height: 6)

                    Text(hasStudentCourses ? "COURSES" : "SETUP")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(courseMetricAccent)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
            .background(
                homeArenaCardBackground(
                    accent: courseMetricAccent,
                    cornerRadius: 28,
                    intensity: nextEvent != nil ? 1.08 : 0.84
                )
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
            return tr("oc_start")
        }

        if totalTodayTaskCount == 0 {
            return tr("oc_todays_plan")
        }

        if completedTodayCount >= totalTodayTaskCount {
            return tr("oc_today_done")
        }

        return tr("oc_todays_progress")
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
            return tr("oc_pick_class_study")
        }

        if completedTodayCount >= totalTodayTaskCount {
            return tr("hd_today_done")
        }

        return tr("hd_tasks_done_of", completedTodayCount, totalTodayTaskCount)
    }

    var todayCompletionFootnoteText: String {
        if !hasStudentCourses {
            return tr("oc_plan_smartens")
        }

        if totalTodayTaskCount == 0 {
            return tr("oc_lets_make_plan")
        }

        let remaining = max(totalTodayTaskCount - completedTodayCount, 0)

        if remaining == 0 {
            return tr("oc_clean_close")
        }

        return tr("oc_tasks_left", remaining)
    }

    var todayProgressAccent: Color {
        if !hasStudentCourses {
            return Color(arenaHex: AppArenaPalette.cyan)
        }

        if safeTodayCompletionRatio >= 1 {
            return Color(arenaHex: AppArenaPalette.green)
        }

        if safeTodayCompletionRatio >= 0.66 {
            return Color(arenaHex: AppArenaPalette.blue)
        }

        if safeTodayCompletionRatio > 0 {
            return Color(arenaHex: AppArenaPalette.purple)
        }

        return Color(arenaHex: AppArenaPalette.cyan)
    }

    var todayProgressSecondaryAccent: Color {
        Color(arenaHex: AppArenaPalette.purple)
    }

    var focusMetricAccent: Color {
        if isFocusCurrentlyActive {
            return Color(arenaHex: AppArenaPalette.green)
        }

        if hasFocusedTodayForHome {
            return Color(arenaHex: AppArenaPalette.gold)
        }

        return Color(arenaHex: AppArenaPalette.purple)
    }

    var focusMetricSecondaryAccent: Color {
        Color(arenaHex: AppArenaPalette.blue)
    }

    var courseMetricAccent: Color {
        if let nextEvent {
            let hex = nextEvent.colorHex.trimmingCharacters(in: .whitespacesAndNewlines)
            if let color = colorFromHex(hex), !hex.isEmpty {
                return color
            }

            return Color(arenaHex: AppArenaPalette.blue)
        }

        if hasStudentCourses {
            return Color(arenaHex: AppArenaPalette.blue)
        }

        return Color(arenaHex: AppArenaPalette.cyan)
    }

    var courseMetricSecondaryAccent: Color {
        Color(arenaHex: AppArenaPalette.purple)
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
            return tr("oc_fire_caps")
        }

        return "🔥 FOCUS"
    }

    var focusMetricMainText: String {
        if isFocusCurrentlyActive {
            return "Aktif"
        }

        if hasFocusedTodayForHome {
            return tr("oc_burning")
        }

        return tr("hd_start")
    }

    var focusMetricSubtitleText: String {
        if isFocusCurrentlyActive {
            return "oturum devam ediyor"
        }

        if hasFocusedTodayForHome {
            return streakCount > 0 ? tr("oc_day_streak", streakCount) : tr("oc_focused_today")
        }

        return tr("oc_start_first_session")
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

   

    var focusMetricGlowStrength: Double {
        if isFocusCurrentlyActive { return 0.94 }
        if hasFocusedTodayForHome { return 0.86 }
        return 0.62
    }

    // MARK: - Course Metric State

    var courseMetricEyebrowText: String {
        if nextEvent != nil {
            return tr("oc_next_caps")
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

            return tr("oc_pick_classes_week")
        }

        let diff = max(nextEvent.startMinute - currentMinuteOfDay(), 0)
        let end = nextEvent.startMinute + nextEvent.durationMinute
        let now = currentMinuteOfDay()

        if now >= nextEvent.startMinute && now < end {
            return tr("hd_active_now_label")
        }

        if diff <= 0 {
            return tr("oc_about_to_start")
        }

        if diff < 60 {
            return tr("hd_starts_in_min", diff)
        }

        let hours = diff / 60
        let minutes = diff % 60

        if minutes == 0 {
            return "\(hours) saat sonra"
        }

        return "\(hours) sa \(minutes) dk sonra"
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
        case "prep": return tr("grade_prep")
        case "1": return tr("grade_uni_1")
        case "2": return tr("grade_uni_2")
        case "3": return tr("grade_uni_3")
        case "4": return tr("grade_uni_4")
        case "5": return tr("grade_uni_5")
        case "6": return tr("grade_uni_6")
        default: return tr("grade_year_fmt", value)
        }
    }
    
    func homeArenaCardBackground(
        accent: Color,
        cornerRadius: CGFloat,
        intensity: Double
    ) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.105 * intensity),
                        Color(arenaHex: AppArenaPalette.purple).opacity(0.075 * intensity),
                        Color(arenaHex: AppArenaPalette.surface).opacity(0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(0.18 * intensity),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 6,
                            endRadius: 210
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(arenaHex: AppArenaPalette.blue).opacity(0.08 * intensity),
                                Color.clear
                            ],
                            center: .bottomTrailing,
                            startRadius: 8,
                            endRadius: 220
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(accent.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 16, y: 9)
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
