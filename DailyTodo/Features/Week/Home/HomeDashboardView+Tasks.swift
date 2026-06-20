//
//  HomeDashboardView+Tasks.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 30.03.2026.
//

import SwiftUI
import SwiftData
import Combine

extension HomeDashboardView {

    // MARK: - Today Task Data

    var todayBoardTasks: [DTTaskItem] {
        let calendar = Calendar.current

        return userScopedTasks
            .filter { task in
                if let due = task.dueDate, calendar.isDateInToday(due) { return true }
                if let completedAt = task.completedAt, calendar.isDateInToday(completedAt) { return true }
                if let weekDate = task.scheduledWeekDate, calendar.isDateInToday(weekDate) { return true }
                return false
            }
            .sorted { lhs, rhs in
                let lhsDoneRank = lhs.isDone ? 1 : 0
                let rhsDoneRank = rhs.isDone ? 1 : 0
                if lhsDoneRank != rhsDoneRank { return lhsDoneRank < rhsDoneRank }

                let lhsUrgency = todayTaskUrgencyScore(lhs)
                let rhsUrgency = todayTaskUrgencyScore(rhs)
                if lhsUrgency != rhsUrgency { return lhsUrgency > rhsUrgency }

                let lhsDate = lhs.dueDate ?? lhs.scheduledWeekDate ?? lhs.completedAt ?? .distantFuture
                let rhsDate = rhs.dueDate ?? rhs.scheduledWeekDate ?? rhs.completedAt ?? .distantFuture
                return lhsDate < rhsDate
            }
    }

    var todayPendingTasks: [DTTaskItem] {
        todayBoardTasks.filter { !$0.isDone }
    }

    var todayCompletedTasks: [DTTaskItem] {
        todayBoardTasks.filter(\.isDone)
    }

    var completedTodayBoardCount: Int {
        todayCompletedTasks.count
    }

    var todayPendingBoardCount: Int {
        todayPendingTasks.count
    }

    var taskCardIsCompactMode: Bool {
        switch homeLayoutMode {
        case .focusActive:
            return true
        default:
            return false
        }
    }

    var taskCardPendingLimit: Int {
        switch homeLayoutMode {
        case .focusActive:
            return 3
        case .crewFollowUp:
            return 4
        case .insightsFollowUp, .completionWrapUp:
            return 3
        case .defaultFlow:
            return 4
        }
    }

    var taskCardCompletedLimit: Int {
        switch homeLayoutMode {
        case .focusActive:
            return 1
        case .crewFollowUp:
            return 2
        case .insightsFollowUp, .completionWrapUp:
            return 2
        case .defaultFlow:
            return 2
        }
    }

    var shouldEmphasizeCompletedSection: Bool {
        switch homeLayoutMode {
        case .insightsFollowUp, .completionWrapUp:
            return true
        default:
            return false
        }
    }

    // MARK: - Arena State

    var todayCardAccentColor: Color {
        if todayBoardTasks.isEmpty {
            return Color(arenaHex: AppArenaPalette.cyan)
        }

        if todayPendingBoardCount == 0 {
            return Color(arenaHex: AppArenaPalette.green)
        }

        if todayPendingTasks.contains(where: { store.isOverdue($0) }) {
            return Color(arenaHex: AppArenaPalette.gold)
        }

        if boardTodayProgressValue > 0.55 {
            return Color(arenaHex: AppArenaPalette.green)
        }

        return Color(arenaHex: AppArenaPalette.blue)
    }

    var todayOpenBadgeColor: Color {
        if todayPendingBoardCount == 0 {
            return Color(arenaHex: AppArenaPalette.green)
        }

        if todayPendingTasks.contains(where: { store.isOverdue($0) }) {
            return Color(arenaHex: AppArenaPalette.gold)
        }

        return Color(arenaHex: AppArenaPalette.blue)
    }

    var adaptiveTasksBackground: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        todayCardAccentColor.opacity(0.070),
                        Color(arenaHex: AppArenaPalette.purple).opacity(0.045),
                        Color(arenaHex: AppArenaPalette.surface).opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                todayCardAccentColor.opacity(0.13),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 8,
                            endRadius: 210
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                shouldEmphasizeCompletedSection
                                ? Color(arenaHex: AppArenaPalette.green).opacity(0.10)
                                : Color(arenaHex: AppArenaPalette.blue).opacity(0.055),
                                Color.clear
                            ],
                            center: .bottomTrailing,
                            startRadius: 10,
                            endRadius: 230
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(
                        shouldEmphasizeCompletedSection
                        ? Color(arenaHex: AppArenaPalette.green).opacity(0.16)
                        : todayCardAccentColor.opacity(0.14),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.22), radius: 16, y: 9)
    }

    // MARK: - Card

    var todayTasksCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(todayCardAccentColor)
                            .frame(width: 18, height: 1)

                        Text("TODAY BOARD")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.7)
                            .foregroundStyle(todayCardAccentColor)
                    }

                    Text(tr("common_today"))
                        .font(.system(size: 25, weight: .black))
                        .foregroundStyle(.white)

                    Text(todayTaskHeaderText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                        .lineLimit(2)
                }

                Spacer(minLength: 10)

                if !todayBoardTasks.isEmpty {
                    Text(todayOpenBadgeText.uppercased())
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(todayOpenBadgeColor)
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background(
                            Capsule()
                                .fill(todayOpenBadgeColor.opacity(0.13))
                                .overlay(
                                    Capsule()
                                        .stroke(todayOpenBadgeColor.opacity(0.18), lineWidth: 1)
                                )
                        )
                }
            }

            if !todayBoardTasks.isEmpty {
                HStack(spacing: 10) {
                    todayMiniMetricPill(
                        title: "Tamamlanan",
                        value: "\(completedTodayBoardCount)",
                        tint: Color(arenaHex: AppArenaPalette.green)
                    )

                    todayMiniMetricPill(
                        title: "Kalan",
                        value: "\(todayPendingBoardCount)",
                        tint: todayPendingTasks.contains(where: { store.isOverdue($0) })
                        ? Color(arenaHex: AppArenaPalette.gold)
                        : Color(arenaHex: AppArenaPalette.blue)
                    )

                    todayMiniMetricPill(
                        title: tr("ha_progress"),
                        value: "\(Int((boardTodayProgressValue * 100).rounded()))%",
                        tint: todayCardAccentColor
                    )
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.075))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(arenaHex: AppArenaPalette.cyan),
                                        todayCardAccentColor,
                                        Color(arenaHex: AppArenaPalette.purple)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(10, geo.size.width * boardTodayProgressValue))
                            .shadow(color: todayCardAccentColor.opacity(0.18), radius: 8, y: 2)
                    }
                }
                .frame(height: 9)
            }

            if todayBoardTasks.isEmpty {
                emptyTodayTasksState
            } else {
                if !todayPendingTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionEyebrow(
                            title: taskCardPendingSectionTitle,
                            count: todayPendingTasks.count > taskCardPendingLimit
                            ? "+\(todayPendingTasks.count - taskCardPendingLimit)"
                            : nil,
                            tint: todayPendingTasks.contains(where: { store.isOverdue($0) })
                            ? Color(arenaHex: AppArenaPalette.gold)
                            : Color(arenaHex: AppArenaPalette.blue)
                        )

                        ForEach(Array(todayPendingTasks.prefix(taskCardPendingLimit)), id: \.taskUUID) { task in
                            todayTaskBoardRow(
                                task: task,
                                compact: taskCardIsCompactMode
                            )
                        }
                    }
                }

                if !todayCompletedTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionEyebrow(
                            title: "Tamamlananlar",
                            count: "\(todayCompletedTasks.count)",
                            tint: Color(arenaHex: AppArenaPalette.green)
                        )
                        .padding(.top, todayPendingTasks.isEmpty ? 0 : 2)

                        ForEach(Array(todayCompletedTasks.prefix(taskCardCompletedLimit)), id: \.taskUUID) { task in
                            todayTaskBoardRow(
                                task: task,
                                compact: true
                            )
                        }
                    }
                }

                HStack(spacing: 8) {
                    smallStatsChip(
                        title: "Seri",
                        value: "\(streakCount)",
                        tint: Color(arenaHex: AppArenaPalette.gold)
                    )

                    smallStatsChip(
                        title: "Biten",
                        value: "\(completedTodayBoardCount)",
                        tint: Color(arenaHex: AppArenaPalette.green)
                    )

                    smallStatsChip(
                        title: "Kalan",
                        value: "\(todayPendingBoardCount)",
                        tint: todayPendingTasks.contains(where: { store.isOverdue($0) })
                        ? Color(arenaHex: AppArenaPalette.gold)
                        : Color(arenaHex: AppArenaPalette.blue)
                    )
                }
                .padding(.top, 2)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(adaptiveTasksBackground)
    }

    // MARK: - Empty State

    var emptyTodayTasksState: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 11) {
                ZStack {
                    Circle()
                        .fill(Color(arenaHex: AppArenaPalette.green).opacity(0.13))
                        .frame(width: 40, height: 40)

                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(Color(arenaHex: AppArenaPalette.green))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("hdt_today_clean"))
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)

                    Text(
                        homeLayoutMode == .completionWrapUp || homeLayoutMode == .insightsFollowUp
                        ? tr("hdt_no_remaining")
                        : tr("hdt_calm_add")
                    )
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.50))
                    .lineLimit(2)
                }
            }

            HStack(spacing: 8) {
                smallStatsChip(
                    title: "Seri",
                    value: "\(streakCount)",
                    tint: Color(arenaHex: AppArenaPalette.gold)
                )

                smallStatsChip(
                    title: "Biten",
                    value: "0",
                    tint: Color(arenaHex: AppArenaPalette.green)
                )

                smallStatsChip(
                    title: "Kalan",
                    value: "0",
                    tint: Color(arenaHex: AppArenaPalette.blue)
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(arenaHex: AppArenaPalette.green).opacity(0.070),
                            Color.white.opacity(0.040)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(arenaHex: AppArenaPalette.green).opacity(0.13), lineWidth: 1)
        )
    }

    // MARK: - Header Text

    var todayTaskHeaderText: String {
        if todayBoardTasks.isEmpty {
            return tr("hh_today_calm")
        }

        switch homeLayoutMode {
        case .insightsFollowUp, .completionWrapUp:
            if todayPendingBoardCount == 0 {
                return tr("hdt_all_done")
            }
            return "\(tr("hdt_tasks_left", todayPendingBoardCount)) • \(tr("rel_done_count", completedTodayBoardCount))"

        case .crewFollowUp:
            return tr("hdt_personal_left", todayPendingBoardCount)

        case .focusActive:
            return "\(tr("hdt_tasks_left", todayPendingBoardCount)) • \(tr("hdt_focus_going"))"

        case .defaultFlow:
            if todayPendingBoardCount == 0 {
                return tr("hdt_all_done")
            }
            return "\(tr("hdt_tasks_left", todayPendingBoardCount)) • \(tr("rel_done_count", completedTodayBoardCount))"
        }
    }

    var todayOpenBadgeText: String {
        todayPendingBoardCount == 0 ? "Temiz" : tr("rel_open_count", todayPendingBoardCount)
    }

    var taskCardPendingSectionTitle: String {
        switch homeLayoutMode {
        case .focusActive:
            return tr("hdt_remaining_tasks")
        case .crewFollowUp:
            return tr("hdt_personal_side")
        case .insightsFollowUp, .completionWrapUp:
            return tr("hdt_open_ones")
        case .defaultFlow:
            return tr("hdt_next_tasks")
        }
    }

    // MARK: - UI Helpers

    func sectionEyebrow(title: String, count: String?, tint: Color) -> some View {
        HStack {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(tint.opacity(0.82))
                    .frame(width: 14, height: 1)

                Text(title.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(tint)
            }

            Spacer()

            if let count {
                Text(count)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(
                        Capsule()
                            .fill(tint.opacity(0.12))
                            .overlay(
                                Capsule()
                                    .stroke(tint.opacity(0.18), lineWidth: 1)
                            )
                    )
            }
        }
    }

    func todayMiniMetricPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(.white)
                .monospacedDigit()

            Text(title.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.38))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(0.080))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(0.14), lineWidth: 1)
                )
        )
    }

    func todayTaskBoardRow(task: DTTaskItem, compact: Bool = false) -> some View {
        let accent = todayTaskAccent(for: task)
        let isUpcoming = isUpcomingPriorityTask(task)
        let isOverdue = store.isOverdue(task) && !task.isDone
        let dueText = dueBadgeText(for: task)
        let isFocused = isCurrentFocusTask(task)

        return Button {
            toggleTodayBoardTask(task)
        } label: {
            HStack(spacing: compact ? 10 : 12) {
                ZStack {
                    Circle()
                        .stroke(
                            task.isDone
                            ? Color(arenaHex: AppArenaPalette.green).opacity(0.25)
                            : accent.opacity(0.95),
                            lineWidth: 2.2
                        )
                        .frame(width: compact ? 26 : 30, height: compact ? 26 : 30)

                    if task.isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: compact ? 10 : 11, weight: .black))
                            .foregroundStyle(Color(arenaHex: AppArenaPalette.green))
                    } else if isFocused {
                        Image(systemName: "scope")
                            .font(.system(size: compact ? 9 : 10, weight: .black))
                            .foregroundStyle(accent)
                    }
                }

                VStack(alignment: .leading, spacing: compact ? 3 : 5) {
                    HStack(spacing: 6) {
                        Text(task.title)
                            .font(.system(size: compact ? 15 : 16, weight: .black))
                            .foregroundStyle(task.isDone ? .white.opacity(0.42) : .white.opacity(0.94))
                            .strikethrough(task.isDone, color: .white.opacity(0.34))
                            .lineLimit(1)

                        if isFocused && !task.isDone {
                            Text("ODAKTA")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .tracking(0.7)
                                .foregroundStyle(accent)
                                .padding(.horizontal, 7)
                                .frame(height: 22)
                                .background(
                                    Capsule()
                                        .fill(accent.opacity(0.12))
                                )
                        }
                    }

                    if !compact || !task.isDone {
                        Text(taskRowSubtitle(for: task))
                            .font(.system(size: compact ? 11.5 : 12.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.44))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                if task.isDone {
                    miniBadge(
                        icon: "checkmark.circle.fill",
                        text: compact ? "Bitti" : tr("common_completed"),
                        tint: Color(arenaHex: AppArenaPalette.green)
                    )
                } else if isOverdue {
                    miniBadge(
                        icon: "exclamationmark.triangle.fill",
                        text: dueText,
                        tint: Color(arenaHex: AppArenaPalette.coral)
                    )
                } else if isFocused {
                    miniBadge(
                        icon: "scope",
                        text: "Odak aktif",
                        tint: accent
                    )
                } else if isUpcoming {
                    miniBadge(
                        icon: taskTypeBadgeIcon(for: task),
                        text: dueText,
                        tint: accent
                    )
                } else {
                    miniBadge(
                        icon: taskTypeBadgeIcon(for: task),
                        text: dueText,
                        tint: accent.opacity(0.92)
                    )
                }
            }
            .padding(compact ? 13 : 15)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(task.isDone ? 0.050 : 0.070),
                                Color.white.opacity(0.040)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        isOverdue
                        ? Color(arenaHex: AppArenaPalette.coral).opacity(0.20)
                        : (task.isDone ? Color(arenaHex: AppArenaPalette.green).opacity(0.13) : accent.opacity(0.12)),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    func miniBadge(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .black))

            Text(text.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.5)
        }
        .padding(.horizontal, 9)
        .frame(height: 26)
        .background(
            Capsule()
                .fill(tint.opacity(0.13))
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                )
        )
        .foregroundStyle(tint)
    }

    func smallStatsChip(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)

            Text("\(title.uppercased()) \(value)")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            Capsule()
                .fill(tint.opacity(0.12))
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                )
        )
    }

    // MARK: - Actions

    func toggleTodayBoardTask(_ task: DTTaskItem) {
        withAnimation(.easeOut(duration: 0.18)) {
            task.isDone.toggle()
            task.completedAt = task.isDone ? Date() : nil

            do {
                try modelContext.save()
            } catch {
                Log.debug("❌ today board task toggle error:", error)
            }

            if task.isDone {
                completeLinkedWeekEvent(for: task)
            }
        }
    }

    // MARK: - Task Logic

    func todayTaskUrgencyScore(_ task: DTTaskItem) -> Int {
        if task.isDone { return -1 }
        if store.isOverdue(task) { return 100 }

        if task.taskType.lowercased() == "exam",
           let due = task.dueDate {
            let minutes = Int(due.timeIntervalSinceNow / 60)
            if minutes <= 180 { return 95 }
            if minutes <= 1440 { return 85 }
        }

        guard let due = task.dueDate ?? task.scheduledWeekDate else { return 10 }
        let minutes = Int(due.timeIntervalSinceNow / 60)

        if minutes <= 30 { return 90 }
        if minutes <= 120 { return 70 }
        if Calendar.current.isDateInToday(due) { return 50 }
        return 20
    }

    func isUpcomingPriorityTask(_ task: DTTaskItem) -> Bool {
        guard !task.isDone else { return false }
        guard let due = task.dueDate ?? task.scheduledWeekDate else { return false }
        let minutes = Int(due.timeIntervalSinceNow / 60)
        return minutes >= 0 && minutes <= 90
    }

    func todayTaskAccent(for task: DTTaskItem) -> Color {
        if store.isOverdue(task) && !task.isDone {
            return Color(arenaHex: AppArenaPalette.coral)
        }

        switch task.colorName.lowercased() {
        case "green":
            return Color(arenaHex: AppArenaPalette.green)
        case "orange":
            return Color(arenaHex: AppArenaPalette.gold)
        case "pink":
            return Color(arenaHex: AppArenaPalette.coral)
        case "purple":
            return Color(arenaHex: AppArenaPalette.purple)
        default:
            return Color(arenaHex: AppArenaPalette.blue)
        }
    }

    func taskTypeBadgeIcon(for task: DTTaskItem) -> String {
        switch task.taskType.lowercased() {
        case "exam": return "doc.text.fill"
        case "homework": return "book.closed.fill"
        case "study": return "brain.head.profile"
        case "project": return "folder.fill"
        default: return "checklist"
        }
    }

    func dueBadgeText(for task: DTTaskItem) -> String {
        if task.isDone { return tr("common_completed") }

        let type = task.taskType.lowercased()

        if store.isOverdue(task) {
            if type == "exam" { return tr("hdt_exam_passed") }
            return tr("common_overdue")
        }

        guard let target = task.dueDate ?? task.scheduledWeekDate else {
            return todayTaskLabel(for: task)
        }

        let now = Date()
        let diff = Int(target.timeIntervalSince(now))
        let minutes = max(0, diff / 60)
        let hours = minutes / 60
        let days = minutes / 1440

        if type == "exam" {
            if days >= 1 { return tr("rel_days_left", days) }
            if hours >= 1 { return tr("rel_hours_left", hours) }
            return tr("rel_min_left", minutes)
        }

        if type == "homework" {
            if Calendar.current.isDateInToday(target) { return tr("due_today") }
            if Calendar.current.isDateInTomorrow(target) { return tr("due_tomorrow") }
        }

        if type == "study", let duration = task.workoutDurationMinutes {
            return "\(duration) dk"
        }

        if Calendar.current.isDateInToday(target) {
            if hours >= 1 { return "\(hours) sa sonra" }
            return "\(minutes) dk sonra"
        }

        if Calendar.current.isDateInTomorrow(target) { return tr("common_tomorrow") }

        return target.formatted(date: .abbreviated, time: .shortened)
    }

    func todayTaskLabel(for task: DTTaskItem) -> String {
        switch task.taskType.lowercased() {
        case "exam": return tr("at_kind_exam")
        case "project": return "Proje"
        case "workout": return "Antrenman"
        case "study": return tr("tt_study")
        case "homework": return tr("tt_homework")
        default: return tr("common_today")
        }
    }

    func taskRowSubtitle(for task: DTTaskItem) -> String {
        let course = task.courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = task.notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if !course.isEmpty, !note.isEmpty { return "\(course) • \(note)" }

        if !course.isEmpty {
            if let due = task.dueDate ?? task.scheduledWeekDate {
                return "\(course) • \(due.formatted(date: .omitted, time: .shortened))"
            }

            return course
        }

        if !note.isEmpty { return note }

        if let due = task.dueDate ?? task.scheduledWeekDate {
            return due.formatted(date: .omitted, time: .shortened)
        }

        return task.taskType.isEmpty ? tr("at_kind_task") : task.taskType.capitalized
    }
}
