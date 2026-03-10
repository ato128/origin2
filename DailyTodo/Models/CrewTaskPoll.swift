//
//  CrewTaskPoll.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 10.03.2026.
//

import Foundation
import SwiftData

@Model
final class CrewTaskPoll {
    var id: UUID
    var taskID: UUID

    var question: String
    var yesVotes: Int
    var noVotes: Int
    var isOpen: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        taskID: UUID,
        question: String,
        yesVotes: Int = 0,
        noVotes: Int = 0,
        isOpen: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.taskID = taskID
        self.question = question
        self.yesVotes = yesVotes
        self.noVotes = noVotes
        self.isOpen = isOpen
        self.createdAt = createdAt
    }
}
