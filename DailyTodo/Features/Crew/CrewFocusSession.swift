//
//  CrewFocusSession.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 15.03.2026.
//

import Foundation
import SwiftData

@Model
final class CrewFocusSession {
    var id: UUID
    var crewID: UUID
    var title: String
    var durationMinutes: Int
    var startedAt: Date
    var isActive: Bool
    var hostName: String
    var participantNames: [String]
    var isPaused: Bool
    var pausedRemainingSeconds: Int?

    init(
        id: UUID = UUID(),
        crewID: UUID,
        title: String = "Focus Session",
        durationMinutes: Int = 25,
        startedAt: Date = Date(),
        isActive: Bool = true,
        hostName: String,
        participantNames: [String] = [],
        isPaused: Bool = false,
        pausedRemainingSeconds: Int? = nil
    ) {
        self.id = id
        self.crewID = crewID
        self.title = title
        self.durationMinutes = durationMinutes
        self.startedAt = startedAt
        self.isActive = isActive
        self.hostName = hostName
        self.participantNames = participantNames
        self.isPaused = isPaused
        self.pausedRemainingSeconds = pausedRemainingSeconds
    }

    var endDate: Date {
        Calendar.current.date(byAdding: .minute, value: durationMinutes, to: startedAt) ?? startedAt
    }
}
