//
//  CrewFocusRecord.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import Foundation
import SwiftData

@Model
final class CrewFocusRecord {
    var id: UUID
    var crewID: UUID
    var memberName: String
    var minutes: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        crewID: UUID,
        memberName: String,
        minutes: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.crewID = crewID
        self.memberName = memberName
        self.minutes = minutes
        self.createdAt = createdAt
    }
}
