//
//  CrewActivity.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 9.03.2026.
//

import Foundation
import SwiftData

@Model
final class CrewActivity {
    var id: UUID
    var crewID: UUID
    var memberName: String
    var actionText: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        crewID: UUID,
        memberName: String,
        actionText: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.crewID = crewID
        self.memberName = memberName
        self.actionText = actionText
        self.createdAt = createdAt
    }
}
