//
//  DTTaskItem.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 6.03.2026.
//

import Foundation
import SwiftData

@Model
final class DTTaskItem {
    var taskUUID: String

    var ownerUserID: String?   // 🔥 EKLENDİ

    var title: String
    var isDone: Bool
    var dueDate: Date?
    var createdAt: Date
    var completedAt: Date?

    var notes: String
    var taskType: String

    var workoutDay: String?
    var workoutDurationMinutes: Int?

    var scheduledWeekDate: Date?
    var scheduledWeekDurationMinutes: Int?
    
    var workoutExercises: [WorkoutExerciseItem]? = nil
    
  

    init(
        taskUUID: String = UUID().uuidString,
        ownerUserID: String? = nil,   // 🔥 EKLENDİ
        title: String,
        isDone: Bool = false,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        notes: String = "",
        taskType: String = "standard",
        workoutDay: String? = nil,
        workoutDurationMinutes: Int? = nil,
        scheduledWeekDate: Date? = nil,
        scheduledWeekDurationMinutes: Int? = nil
    ) {
        self.taskUUID = taskUUID
        self.ownerUserID = ownerUserID   // 🔥 EKLENDİ
        self.title = title
        self.isDone = isDone
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.notes = notes
        self.taskType = taskType
        self.workoutDay = workoutDay
        self.workoutDurationMinutes = workoutDurationMinutes
        self.scheduledWeekDate = scheduledWeekDate
        self.scheduledWeekDurationMinutes = scheduledWeekDurationMinutes
    }
}
