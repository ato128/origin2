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

    var ownerUserID: String?

    var title: String
    var isDone: Bool
    var dueDate: Date?
    var createdAt: Date
    var completedAt: Date?

    var notes: String
    var taskType: String

    var colorName: String
    var courseName: String

    var workoutDay: String?
    var workoutDurationMinutes: Int?

    var scheduledWeekDate: Date?
    var scheduledWeekDurationMinutes: Int?

    var workoutExercises: [WorkoutExerciseItem]? = nil

    init(
        taskUUID: String = UUID().uuidString,
        ownerUserID: String? = nil,
        title: String,
        isDone: Bool = false,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        notes: String = "",
        taskType: String = "standard",
        colorName: String = "blue",
        courseName: String = "",
        workoutDay: String? = nil,
        workoutDurationMinutes: Int? = nil,
        scheduledWeekDate: Date? = nil,
        scheduledWeekDurationMinutes: Int? = nil
    ) {
        self.taskUUID = taskUUID
        self.ownerUserID = ownerUserID
        self.title = title
        self.isDone = isDone
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.notes = notes
        self.taskType = taskType
        self.colorName = colorName
        self.courseName = courseName
        self.workoutDay = workoutDay
        self.workoutDurationMinutes = workoutDurationMinutes
        self.scheduledWeekDate = scheduledWeekDate
        self.scheduledWeekDurationMinutes = scheduledWeekDurationMinutes
    }
}
