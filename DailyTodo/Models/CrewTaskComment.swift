//
//  CrewTaskComment.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 10.03.2026.
//

import Foundation
import SwiftData

@Model
final class CrewTaskComment {
    var id: UUID
    var taskID: UUID

    var authorName: String
    var message: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        taskID: UUID,
        authorName: String,
        message: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.taskID = taskID
        self.authorName = authorName
        self.message = message
        self.createdAt = createdAt
    }
}
