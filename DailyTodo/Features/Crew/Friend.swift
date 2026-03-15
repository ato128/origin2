//
//  Friend.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import Foundation
import SwiftData

@Model
final class Friend {
    var id: UUID
    var name: String
    var subtitle: String
    var avatarSymbol: String
    var colorHex: String
    var isOnline: Bool
    var createdAt: Date
    var isMuted: Bool

    init(
        id: UUID = UUID(),
        name: String,
        subtitle: String = "",
        avatarSymbol: String = "person.fill",
        colorHex: String = "#3B82F6",
        isOnline: Bool = false,
        createdAt: Date = Date(),
        isMuted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.avatarSymbol = avatarSymbol
        self.colorHex = colorHex
        self.isOnline = isOnline
        self.createdAt = createdAt
        self.isMuted = isMuted
        
    }
}
