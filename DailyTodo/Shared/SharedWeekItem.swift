//
//  SharedWeekItem.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import Foundation
import SwiftData

@Model
final class SharedWeekItem {
    var id: UUID
    var ownerUserID: UUID?
    var friendID: UUID
    var title: String
    var details: String
    var weekday: Int
    var startMinute: Int
    var durationMinute: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        ownerUserID: UUID? = nil,
        friendID: UUID,
        title: String,
        details: String = "",
        weekday: Int,
        startMinute: Int,
        durationMinute: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.ownerUserID = ownerUserID
        self.friendID = friendID
        self.title = title
        self.details = details
        self.weekday = weekday
        self.startMinute = startMinute
        self.durationMinute = durationMinute
        self.createdAt = createdAt
    }
}
