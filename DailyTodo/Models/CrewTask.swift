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
    var details: String

    var assignedTo: String
    var createdBy: String

    /// low, medium, high, urgent
    var priority: String

    /// todo, inProgress, review, done
    var status: String

    var showOnWeek: Bool

    /// Haftalık tekrar eden düzen için
    /// 0=Pzt ... 6=Paz
    var scheduledWeekday: Int?
    var scheduledStartMinute: Int?
    var scheduledDurationMinute: Int?

    /// Tek seferlik ileri tarihli görev için
    var scheduledDate: Date?

    var isDone: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        crewID: UUID,
        title: String,
        details: String = "",
        assignedTo: String = "",
        createdBy: String = "",
        priority: String = "medium",
        status: String = "todo",
        showOnWeek: Bool = false,
        scheduledWeekday: Int? = nil,
        scheduledStartMinute: Int? = nil,
        scheduledDurationMinute: Int? = nil,
        scheduledDate: Date? = nil,
        isDone: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.crewID = crewID
        self.title = title
        self.details = details
        self.assignedTo = assignedTo
        self.createdBy = createdBy
        self.priority = priority
        self.status = status
        self.showOnWeek = showOnWeek
        self.scheduledWeekday = scheduledWeekday
        self.scheduledStartMinute = scheduledStartMinute
        self.scheduledDurationMinute = scheduledDurationMinute
        self.scheduledDate = scheduledDate
        self.isDone = isDone
        self.createdAt = createdAt
    }
}
