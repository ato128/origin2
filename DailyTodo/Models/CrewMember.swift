//
//  CrewMember.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 9.03.2026.
//
import Foundation
import SwiftData

@Model
final class CrewMember {
    var id: UUID
    var crewID: UUID
    var name: String
    var role: String
    var isOnline: Bool
    var avatarSymbol: String
    var joinedAt: Date
    var presence: String = "online"

    init(
        id: UUID = UUID(),
        crewID: UUID,
        name: String,
        role: String = "Member",
        isOnline: Bool = false,
        avatarSymbol: String = "person.fill",
        joinedAt: Date = Date()
    ) {
        self.id = id
        self.crewID = crewID
        self.name = name
        self.role = role
        self.isOnline = isOnline
        self.avatarSymbol = avatarSymbol
        self.joinedAt = joinedAt
    }
}
