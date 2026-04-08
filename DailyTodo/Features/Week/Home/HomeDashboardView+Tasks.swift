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

    var todayCardAccentColor: Color {
        if todayBoardTasks.isEmpty { return .blue }
        if todayPendingBoardCount == 0 { return .green }
        if todayPendingTasks.contains(where: { store.isOverdue($0) }) { return .orange }
        if boardTodayProgressValue > 0.55 { return .green }
        return .blue
    }

    var adaptiveTasksBackground: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        palette.cardFill,
                        palette.cardFill.opacity(0.96)
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
                                todayCardAccentColor.opacity(0.10),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 12,
                            endRadius: 220
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                shouldEmphasizeCompletedSection
                                ? Color.green.opacity(0.06)
                                : Color.clear,
                                Color.clear
                            ],
                            center: .bottomTrailing,
                            startRadius: 10,
                            endRadius: 220
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(
                        shouldEmphasizeCompletedSection
                        ? Color.green.opacity(0.12)
                        : todayCardAccentColor.opacity(0.10),
                        lineWidth: 1
                    )
            )
    }

    var todayTasksCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Bugün")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Text(todayTaskHeaderText)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(2)
                }

                Spacer()

                if !todayBoardTasks.isEmpty {
                    Text(todayOpenBadgeText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(todayOpenBadgeColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(todayOpenBadgeColor.opacity(0.13))
                        )
                        .overlay(
                            Capsule()
                                .stroke(todayOpenBadgeColor.opacity(0.14), lineWidth: 1)
                        )
                }
            }

            if !todayBoardTasks.isEmpty {
                HStack(spacing: 12) {
                    todayMiniMetricPill(
                        title: "Tamamlanan",
                        value: "\(completedTodayBoardCount)",
                        tint: .green
                    )

                    todayMiniMetricPill(
                        title: "Kalan",
                        value: "\(todayPendingBoardCount)",
                        tint: todayPendingTasks.contains(where: { store.isOverdue($0) }) ? .orange : .blue
                    )

                    todayMiniMetricPill(
                        title: "İlerleme",
                        value: "\(Int((boardTodayProgressValue * 100).rounded()))%",
                        tint: todayCardAccentColor
                    )
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(palette.secondaryCardFill.opacity(0.95))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        todayCardAccentColor.opacity(0.92),
                                        todayCardAccentColor.opacity(0.76)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(10, geo.size.width * boardTodayProgressValue))
                    }
                }
                .frame(height: 10)
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
                            tint: todayPendingTasks.contains(where: { store.isOverdue($0) }) ? .orange : .blue
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
                            tint: .green
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
                    smallStatsChip(title: "Seri", value: "\(streakCount)", tint: .orange)
                    smallStatsChip(title: "Biten", value: "\(completedTodayBoardCount)", tint: .green)
                    smallStatsChip(title: "Kalan", value: "\(todayPendingBoardCount)", tint: todayPendingTasks.contains(where: { store.isOverdue($0) }) ? .orange : .blue)
                }
                .padding(.top, 2)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(adaptiveTasksBackground)
    }

    var emptyTodayTasksState: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.14))
                        .frame(width: 38, height: 38)

                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.green)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Bugün temiz görünüyor")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Text(
                        homeLayoutMode == .completionWrapUp || homeLayoutMode == .insightsFollowUp
                        ? "Bugün için kalan görev görünmüyor."
                        : "Şimdilik sakin. İstersen küçük bir görev ekleyebilirsin."
                    )
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.secondaryText)
                }
            }

            HStack(spacing: 8) {
                smallStatsChip(title: "Seri", value: "\(streakCount)", tint: .orange)
                smallStatsChip(title: "Biten", value: "0", tint: .green)
                smallStatsChip(title: "Kalan", value: "0", tint: .blue)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(palette.secondaryCardFill.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(palette.cardStroke.opacity(0.84), lineWidth: 1)
        )
    }

    var todayTaskHeaderText: String {
        if todayBoardTasks.isEmpty {
            return "Bugün sakin görünüyor"
        }

        switch homeLayoutMode {
        case .insightsFollowUp, .completionWrapUp:
            if todayPendingBoardCount == 0 {
                return "Bugünün tüm görevleri tamamlandı"
            }
            return "\(todayPendingBoardCount) görev kaldı • \(completedTodayBoardCount) tamamlandı"

        case .crewFollowUp:
            return "\(todayPendingBoardCount) kişisel görev kaldı"

        case .focusActive:
            return "\(todayPendingBoardCount) görev kaldı • odak sürüyor"

        case .defaultFlow:
            if todayPendingBoardCount == 0 {
                return "Bugünün tüm görevleri tamamlandı"
            }
            return "\(todayPendingBoardCount) görev kaldı • \(completedTodayBoardCount) tamamlandı"
        }
    }

    var todayOpenBadgeText: String {
        todayPendingBoardCount == 0 ? "Temiz" : "\(todayPendingBoardCount) açık"
    }

    var todayOpenBadgeColor: Color {
        if todayPendingBoardCount == 0 { return .green }
        if todayPendingTasks.contains(where: { store.isOverdue($0) }) { return .orange }
        return .blue
    }

    var taskCardPendingSectionTitle: String {
        switch homeLayoutMode {
        case .focusActive:
            return "Kalan görevler"
        case .crewFollowUp:
            return "Kişisel taraf"
        case .insightsFollowUp, .completionWrapUp:
            return "Açık kalanlar"
        case .defaultFlow:
            return "Sıradaki işler"
        }
    }

    func sectionEyebrow(title: String, count: String?, tint: Color) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(tint)

            Spacer()

            if let count {
                Text(count)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(tint.opacity(0.12))
                    )
            }
        }
    }

    func todayMiniMetricPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.secondaryText)

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.10), lineWidth: 1)
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
                        .stroke(task.isDone ? Color.green.opacity(0.24) : accent.opacity(0.95), lineWidth: 2.2)
                        .frame(width: compact ? 26 : 30, height: compact ? 26 : 30)

                    if task.isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: compact ? 10 : 11, weight: .bold))
                            .foregroundStyle(.green)
                    } else if isFocused {
                        Image(systemName: "scope")
                            .font(.system(size: compact ? 9 : 10, weight: .bold))
                            .foregroundStyle(accent)
                    }
                }

                VStack(alignment: .leading, spacing: compact ? 3 : 5) {
                    HStack(spacing: 6) {
                        Text(task.title)
                            .font(.system(size: compact ? 15 : 16, weight: .bold, design: .rounded))
                            .foregroundStyle(task.isDone ? palette.secondaryText : palette.primaryText)
                            .strikethrough(task.isDone, color: palette.secondaryText.opacity(0.72))
                            .lineLimit(1)

                        if isFocused && !task.isDone {
                            Text("Odakta")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(accent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(accent.opacity(0.12))
                                )
                        }
                    }

                    if !compact || !task.isDone {
                        Text(taskRowSubtitle(for: task))
                            .font(.system(size: compact ? 11.5 : 12.5, weight: .medium, design: .rounded))
                            .foregroundStyle(palette.secondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if task.isDone {
                    miniBadge(
                        icon: "checkmark.circle.fill",
                        text: compact ? "Bitti" : "Tamamlandı",
                        tint: .green
                    )
                } else if isOverdue {
                    miniBadge(
                        icon: "exclamationmark.triangle.fill",
                        text: dueText,
                        tint: .red
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
                    .fill(palette.secondaryCardFill.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        isOverdue
                        ? Color.red.opacity(0.14)
                        : (task.isDone ? Color.green.opacity(0.10) : palette.cardStroke.opacity(0.82)),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    func toggleTodayBoardTask(_ task: DTTaskItem) {
        withAnimation(.easeOut(duration: 0.18)) {
            task.isDone.toggle()
            task.completedAt = task.isDone ? Date() : nil

            do {
                try modelContext.save()
            } catch {
                print("❌ today board task toggle error:", error)
            }

            if task.isDone {
                completeLinkedWeekEvent(for: task)
            }
        }
    }

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
        if store.isOverdue(task) && !task.isDone { return .red }

        switch task.colorName.lowercased() {
        case "green": return .green
        case "orange": return .orange
        case "pink": return .pink
        case "purple": return .purple
        default: return .blue
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
        if task.isDone { return "Tamamlandı" }

        let type = task.taskType.lowercased()

        if store.isOverdue(task) {
            if type == "exam" { return "Sınav geçti" }
            return "Gecikmiş"
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
            if days >= 1 { return "\(days) gün kaldı" }
            if hours >= 1 { return "\(hours) sa kaldı" }
            return "\(minutes) dk kaldı"
        }

        if type == "homework" {
            if Calendar.current.isDateInToday(target) { return "Bugün teslim" }
            if Calendar.current.isDateInTomorrow(target) { return "Yarın teslim" }
        }

        if type == "study", let duration = task.workoutDurationMinutes {
            return "\(duration) dk"
        }

        if Calendar.current.isDateInToday(target) {
            if hours >= 1 { return "\(hours) sa sonra" }
            return "\(minutes) dk sonra"
        }

        if Calendar.current.isDateInTomorrow(target) { return "Yarın" }

        return target.formatted(date: .abbreviated, time: .shortened)
    }

    func todayTaskLabel(for task: DTTaskItem) -> String {
        switch task.taskType.lowercased() {
        case "exam": return "Sınav"
        case "project": return "Proje"
        case "workout": return "Antrenman"
        case "study": return "Çalışma"
        case "homework": return "Ödev"
        default: return "Bugün"
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
        return task.taskType.isEmpty ? "Görev" : task.taskType.capitalized
    }

    func miniBadge(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(tint.opacity(0.14))
        )
        .foregroundStyle(tint)
    }

    func smallStatsChip(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)

            Text("\(title) \(value)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(tint.opacity(0.12))
        )
    }
}
