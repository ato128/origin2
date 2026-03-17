//
//  WorkoutExerciseHistoryItem.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 17.03.2026.
//

import Foundation
import SwiftData

@Model
final class WorkoutExerciseHistoryItem {
    var taskUUID: String
    var exerciseName: String

    var sets: Int
    var reps: Int
    var weight: Double

    var durationSeconds: Int
    var restSeconds: Int

    var recordedAt: Date

    init(
        taskUUID: String,
        exerciseName: String,
        sets: Int,
        reps: Int,
        weight: Double,
        durationSeconds: Int = 0,
        restSeconds: Int = 0,
        recordedAt: Date = Date()
    ) {
        self.taskUUID = taskUUID
        self.exerciseName = exerciseName
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.durationSeconds = durationSeconds
        self.restSeconds = restSeconds
        self.recordedAt = recordedAt
    }
}
