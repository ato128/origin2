//
//  CrewTask.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 9.03.2026.
//

import Foundation
import SwiftData

@Model
final class CrewTask {
    var id: UUID
    var crewID: UUID
    var title: String
    var assignedTo: String
    var isDone: Bool
    var createdAt: Date
    var dueDate: Date?

    init(
        id: UUID = UUID(),
        crewID: UUID,
        title: String,
        assignedTo: String = "",
        isDone: Bool = false,
        createdAt: Date = Date(),
        dueDate: Date? = nil
    ) {
        self.id = id
        self.crewID = crewID
        self.title = title
        self.assignedTo = assignedTo
        self.isDone = isDone
        self.createdAt = createdAt
        self.dueDate = dueDate
    }
}
