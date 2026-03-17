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
    var weight: Double
    var notes: String
    var isSuperset: Bool

    init(
        taskUUID: String,
        name: String,
        sets: Int,
        reps: Int,
        durationSeconds: Int,
        restSeconds: Int,
        orderIndex: Int,
        createdAt: Date = Date(),
        weight: Double = 0,
        notes: String = "",
        isSuperset: Bool = false
    ) {
        self.taskUUID = taskUUID
        self.name = name
        self.sets = sets
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.restSeconds = restSeconds
        self.orderIndex = orderIndex
        self.createdAt = createdAt
        self.weight = weight
        self.notes = notes
        self.isSuperset = isSuperset
    }
}
