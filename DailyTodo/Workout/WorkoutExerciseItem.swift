//
//  WorkoutExerciseItem.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 17.03.2026.
//

import Foundation
import SwiftData

@Model
final class WorkoutExerciseItem {
    var taskUUID: String
    var name: String
    var sets: Int
    var reps: Int
    var durationSeconds: Int
    var restSeconds: Int
    var orderIndex: Int
    var createdAt: Date

    init(
        taskUUID: String,
        name: String,
        sets: Int = 3,
        reps: Int = 10,
        durationSeconds: Int = 0,
        restSeconds: Int = 60,
        orderIndex: Int = 0,
        createdAt: Date = Date()
    ) {
        self.taskUUID = taskUUID
        self.name = name
        self.sets = sets
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.restSeconds = restSeconds
        self.orderIndex = orderIndex
        self.createdAt = createdAt
    }
}
