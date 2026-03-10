//
//  CrewTaskReaction.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 10.03.2026.
//

import Foundation
import SwiftData

@Model
final class CrewTaskReaction {
    var id: UUID
    var taskID: UUID
    var emoji: String
    var count: Int

    init(
        id: UUID = UUID(),
        taskID: UUID,
        emoji: String,
        count: Int = 0
    ) {
        self.id = id
        self.taskID = taskID
        self.emoji = emoji
        self.count = count
    }
}
