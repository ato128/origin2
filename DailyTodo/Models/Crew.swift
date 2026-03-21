//
//  Crew.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 9.03.2026.
//

import Foundation
import SwiftData

@Model
final class Crew {
    var id: UUID
    var ownerUserID: UUID?
    var backendCrewID: UUID?
    var name: String
    var icon: String
    var colorHex: String
    var createdAt: Date
    var isMuted: Bool
    var totalFocusMinutes: Int
    var currentStreak: Int = 0
    var lastFocusDate: Date?

    init(
        id: UUID = UUID(),
        ownerUserID: UUID? = nil,
        backendCrewID: UUID? = nil,
        name: String,
        icon: String = "person.3.fill",
        colorHex: String = "#3B82F6",
        createdAt: Date = Date(),
        isMuted: Bool = false,
        totalFocusMinutes: Int = 0,
        currentStreak: Int = 0
    ) {
        self.id = id
        self.ownerUserID = ownerUserID
        self.backendCrewID = backendCrewID
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.isMuted = isMuted
        self.totalFocusMinutes = totalFocusMinutes
        self.currentStreak = currentStreak
    }
}
