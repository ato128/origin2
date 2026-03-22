//
//  WeekView+CrewHelpers.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 11.03.2026.
//

import SwiftUI

extension WeekView {
    
    func crewTasks(for day: Int) -> [WeekCrewTaskItem] {
        let calendar = Calendar.current
        let targetDate = targetDateFor(day: day)

        return allCrewTasks
            .filter { task in
                guard task.showOnWeek else { return false }
                guard let selectedCrewID else { return false }
                guard task.crewID == selectedCrewID else { return false }

                if let scheduledDate = task.scheduledDate {
                    return calendar.isDate(scheduledDate, inSameDayAs: targetDate)
                } else {
                    return task.scheduledWeekday == day
                }
            }
            .sorted {
                ($0.scheduledStartMinute ?? 0) < ($1.scheduledStartMinute ?? 0)
            }
    }
    
    func commentsForTask(_ task: WeekCrewTaskItem) -> [WeekCrewCommentItem] {
        allCrewComments
            .filter { $0.taskID == task.id }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    func previewCommentsForTask(_ task: WeekCrewTaskItem) -> [WeekCrewCommentItem] {
        Array(commentsForTask(task).prefix(2))
    }
    
    func initialLetter(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(1)).uppercased()
    }
    
    func hasComments(_ task: WeekCrewTaskItem) -> Bool {
        !commentsForTask(task).isEmpty
    }
    
    func hasCrewTasks(on day: Int) -> Bool {
        !crewTasks(for: day).isEmpty
    }
    
    func hasActiveCrewTask(on day: Int) -> Bool {
        guard day == weekdayIndexToday() else { return false }
        return crewTasks(for: day).contains { isTaskActive($0) }
    }
    
    func hasUpcomingCrewTaskSoon(on day: Int) -> Bool {
        guard day == weekdayIndexToday() else { return false }
        return crewTasks(for: day).contains { isTaskStartingSoon($0) }
    }
    
    func shouldGlowDay(_ day: Int) -> Bool {
        hasActiveCrewTask(on: day) || hasUpcomingCrewTaskSoon(on: day)
    }
    
    func toggleCrewTaskDone(_ task: WeekCrewTaskItem) {
        guard let dto = crewStore.crewTasks.first(where: { $0.id == task.id }) else { return }

        let willBeDone = !dto.is_done

        Task {
            await crewStore.toggleTask(dto)

            await MainActor.run {
                if willBeDone {
                    Haptics.notify(.success)
                } else {
                    Haptics.impact(.light)
                }
            }
        }
    }

    func deleteCrewTask(_ task: WeekCrewTaskItem) {
        Task {
            do {
                try await crewStore.deleteTask(
                    taskID: task.id,
                    crewID: task.crewID,
                    title: task.title
                )

                await MainActor.run {
                    Haptics.impact(.heavy)
                }
            } catch {
                print("DELETE CREW TASK ERROR:", error.localizedDescription)
            }
        }
    }
    
    func dayIndicatorColor(for day: Int) -> Color {
        if hasActiveCrewTask(on: day) {
            return .green
        }
        
        if hasUpcomingCrewTaskSoon(on: day) {
            return .orange
        }
        
        if hasUrgentCrewTask(on: day) {
            return .red
        }
        
        if hasCrewTasks(on: day) {
            return .blue
        }
        
        return .secondary
    }
    
    func dayIndicatorSize(for day: Int) -> CGFloat {
        if hasActiveCrewTask(on: day) {
            return 12
        }
        
        if hasUpcomingCrewTaskSoon(on: day) {
            return 10
        }
        
        return hasCrewTasks(on: day) ? 8 : 6
    }
    
    func dayPulseScale(for day: Int) -> CGFloat {
        if hasActiveCrewTask(on: day) {
            return 1.18
        }
        
        if hasUpcomingCrewTaskSoon(on: day) {
            return 1.08
        }
        
        return 1.0
    }
    
    func fullDateTextForSelectedDay() -> String {
        let targetDate = targetDateFor(day: selectedDay)
        return targetDate.formatted(date: .complete, time: .omitted)
    }
    
    func premiumPriorityColor(_ priority: String) -> Color {
        switch priority {
        case "urgent":
            return Color(red: 1.00, green: 0.24, blue: 0.36)
        case "high":
            return Color(red: 1.00, green: 0.58, blue: 0.18)
        case "medium":
            return Color(red: 0.18, green: 0.56, blue: 1.00)
        case "low":
            return Color(red: 0.42, green: 0.78, blue: 0.67)
        default:
            return .secondary
        }
    }
    
    func hasUrgentCrewTask(on day: Int) -> Bool {
        crewTasks(for: day).contains { $0.priority == "urgent" }
    }
    
    func taskProgress(_ task: WeekCrewTaskItem) -> Double {
        guard isTaskActive(task),
              let start = task.scheduledStartMinute,
              let duration = task.scheduledDurationMinute,
              duration > 0
        else { return 0 }
        
        let now = currentMinuteOfDay()
        let elapsed = max(0, now - start)
        return min(1, Double(elapsed) / Double(duration))
    }
    
    func taskMinutesLeft(_ task: WeekCrewTaskItem) -> Int {
        guard let start = task.scheduledStartMinute,
              let duration = task.scheduledDurationMinute
        else { return 0 }
        
        let now = currentMinuteOfDay()
        let end = start + duration
        return max(0, end - now)
    }
    
    func isTaskActive(_ task: WeekCrewTaskItem) -> Bool {
        let calendar = Calendar.current
        
        if let scheduledDate = task.scheduledDate {
            guard calendar.isDateInToday(scheduledDate) else { return false }
        } else {
            guard task.scheduledWeekday == weekdayIndexToday() else { return false }
        }
        
        let now = currentMinuteOfDay()
        guard let start = task.scheduledStartMinute,
              let duration = task.scheduledDurationMinute
        else { return false }
        
        let end = start + duration
        return now >= start && now < end
    }
    
    func isTaskStartingSoon(_ task: WeekCrewTaskItem) -> Bool {
        let calendar = Calendar.current
        
        if let scheduledDate = task.scheduledDate {
            guard calendar.isDateInToday(scheduledDate) else { return false }
        } else {
            guard task.scheduledWeekday == weekdayIndexToday() else { return false }
        }
        
        let now = currentMinuteOfDay()
        guard let start = task.scheduledStartMinute else { return false }
        
        let diff = start - now
        return diff >= 0 && diff <= 30
    }
    
    func activeCrewTasksToday() -> [WeekCrewTaskItem] {
        allCrewTasksForSelectedDay.filter { isTaskActive($0) && !$0.isDone }
    }

    func upcomingCrewTasksToday() -> [WeekCrewTaskItem] {
        allCrewTasksForSelectedDay.filter { isTaskStartingSoon($0) && !isTaskActive($0) && !$0.isDone }
    }

    func laterCrewTasksToday() -> [WeekCrewTaskItem] {
        if selectedDay != weekdayIndexToday() {
            return allCrewTasksForSelectedDay.filter { !$0.isDone }
        }

        let now = currentMinuteOfDay()

        return allCrewTasksForSelectedDay.filter { task in
            guard !task.isDone else { return false }
            guard let start = task.scheduledStartMinute else { return false }
            return start > now + 30
        }
    }

    func completedCrewTasksToday() -> [WeekCrewTaskItem] {
        allCrewTasksForSelectedDay.filter { $0.isDone }
    }

    func lateCrewTasksToday() -> [WeekCrewTaskItem] {
        guard selectedDay == weekdayIndexToday() else { return [] }

        let now = currentMinuteOfDay()

        return allCrewTasksForSelectedDay.filter { task in
            guard !task.isDone else { return false }
            guard let start = task.scheduledStartMinute else { return false }
            return start < now && !isTaskActive(task)
        }
    }

    func lateDurationText(for task: WeekCrewTaskItem) -> String? {
        guard selectedDay == weekdayIndexToday() else { return nil }
        guard !task.isDone else { return nil }
        guard let start = task.scheduledStartMinute else { return nil }

        let now = currentMinuteOfDay()
        guard start < now, !isTaskActive(task) else { return nil }

        let diff = now - start
        let hours = diff / 60
        let minutes = diff % 60

        if hours == 0 {
            return "Late by \(minutes)m"
        }

        if minutes == 0 {
            return "Late by \(hours)h"
        }

        return "Late by \(hours)h \(minutes)m"
    }
    
    func targetDateFor(day: Int) -> Date {
        let calendar = Calendar.current
        let mondayStart = mondayStartOfCurrentWeek()
        let safeDay = max(0, min(6, day))

        return calendar.date(byAdding: .day, value: safeDay, to: mondayStart) ?? mondayStart
    }
}
