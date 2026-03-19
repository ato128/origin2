//
//  WeekCrewModels.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import Foundation

struct WeekCrewItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let icon: String
    let colorHex: String
}

struct WeekCrewTaskItem: Identifiable, Hashable {
    let id: UUID
    let crewID: UUID
    let title: String
    let details: String
    let assignedTo: String
    let createdBy: String
    let priority: String
    let status: String
    let showOnWeek: Bool
    let scheduledWeekday: Int?
    let scheduledStartMinute: Int?
    let scheduledDurationMinute: Int?
    let scheduledDate: Date?
    let isDone: Bool
    let createdAt: Date
}

struct WeekCrewActivityItem: Identifiable, Hashable {
    let id: UUID
    let crewID: UUID
    let memberName: String
    let actionText: String
    let createdAt: Date
}

struct WeekCrewCommentItem: Identifiable, Hashable {
    let id: UUID
    let taskID: UUID
    let authorName: String
    let message: String
    let createdAt: Date
}
