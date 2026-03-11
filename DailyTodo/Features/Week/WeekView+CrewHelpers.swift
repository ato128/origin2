//
//  WeekView+CrewHelpers.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 11.03.2026.
//

import SwiftUI
import SwiftData

extension WeekView {
    
    func crewTasks(for day: Int) -> [CrewTask] {
        allCrewTasks
            .filter { $0.showOnWeek && $0.scheduledWeekday == day }
            .sorted {
                ($0.scheduledStartMinute ?? 0) < ($1.scheduledStartMinute ?? 0)
            }
    }
    
    func commentsForTask(_ task: CrewTask) -> [CrewTaskComment] {
        allCrewComments
            .filter { $0.taskID == task.id }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    
    
    func previewCommentsForTask(_ task: CrewTask) -> [CrewTaskComment] {
        Array(commentsForTask(task).prefix(2))
    }
    
    func initialLetter(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(1)).uppercased()
    }
    
    func hasComments(_ task: CrewTask) -> Bool {
        !commentsForTask(task).isEmpty
    }
    
    
    
    func hasCrewTasks(on day: Int) -> Bool {
        !crewTasks(for: day).isEmpty
    }
    
    
    func hasActiveCrewTask(on day: Int) -> Bool {
        guard day == weekdayIndexToday() else { return false }
        
        let now = currentMinuteOfDay()
        
        return crewTasks(for: day).contains { task in
            guard let start = task.scheduledStartMinute,
                  let duration = task.scheduledDurationMinute else { return false }
            let end = start + duration
            return now >= start && now < end
        }
    }
    
    func hasUpcomingCrewTaskSoon(on day: Int) -> Bool {
        guard day == weekdayIndexToday() else { return false }
        
        let now = currentMinuteOfDay()
        
        return crewTasks(for: day).contains { task in
            guard let start = task.scheduledStartMinute else { return false }
            let diff = start - now
            return diff >= 0 && diff <= 30
        }
    }
    
    func shouldGlowDay(_ day: Int) -> Bool {
        hasActiveCrewTask(on: day) || hasUpcomingCrewTaskSoon(on: day)
    }
    
    func toggleCrewTaskDone(_ task: CrewTask) {
        task.isDone.toggle()
        
        if task.isDone {
            task.status = "done"
            Haptics.notify(.success)
        } else {
            if task.status == "done" {
                task.status = "todo"
            }
            Haptics.impact(.light)
        }
        
        try? context.save()
    }
    
    func deleteCrewTask(_ task: CrewTask) {
        context.delete(task)
        Haptics.impact(.heavy)
        try? context.save()
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
        let calendar = Calendar.current
        let today = Date()
        
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let targetDate = calendar.date(byAdding: .day, value: selectedDay, to: startOfWeek) else {
            return "Date unavailable"
        }
        
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
    func taskProgress(_ task: CrewTask) -> Double {
        guard isTaskActive(task),
              let start = task.scheduledStartMinute,
              let duration = task.scheduledDurationMinute,
              duration > 0
        else { return 0 }
        
        let now = currentMinuteOfDay()
        let elapsed = max(0, now - start)
        return min(1, Double(elapsed) / Double(duration))
    }
    
    func taskMinutesLeft(_ task: CrewTask) -> Int {
        guard let start = task.scheduledStartMinute,
              let duration = task.scheduledDurationMinute
        else { return 0 }
        
        let now = currentMinuteOfDay()
        let end = start + duration
        return max(0, end - now)
    }
    
    func isTaskActive(_ task: CrewTask) -> Bool {
        guard task.scheduledWeekday == weekdayIndexToday() else { return false }
        
        let now = currentMinuteOfDay()
        guard let start = task.scheduledStartMinute,
              let duration = task.scheduledDurationMinute else { return false }
        
        let end = start + duration
        return now >= start && now < end
    }
    
    func isTaskStartingSoon(_ task: CrewTask) -> Bool {
        guard task.scheduledWeekday == weekdayIndexToday() else { return false }
        
        let now = currentMinuteOfDay()
        guard let start = task.scheduledStartMinute else { return false }
        
        let diff = start - now
        return diff >= 0 && diff <= 30
    }
    func activeCrewTasksToday() -> [CrewTask] {
        allCrewTasksForSelectedDay.filter { isTaskActive($0) && !$0.isDone }
    }

    func upcomingCrewTasksToday() -> [CrewTask] {
        allCrewTasksForSelectedDay.filter { isTaskStartingSoon($0) && !isTaskActive($0) && !$0.isDone }
    }

    func laterCrewTasksToday() -> [CrewTask] {
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

    func completedCrewTasksToday() -> [CrewTask] {
        allCrewTasksForSelectedDay.filter { $0.isDone }
    }
    func lateCrewTasksToday() -> [CrewTask] {
        guard selectedDay == weekdayIndexToday() else { return [] }

        let now = currentMinuteOfDay()

        return allCrewTasksForSelectedDay.filter { task in
            guard !task.isDone else { return false }
            guard let start = task.scheduledStartMinute else { return false }
            return start < now && !isTaskActive(task)
        }
    }
    func lateDurationText(for task: CrewTask) -> String? {
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
}
