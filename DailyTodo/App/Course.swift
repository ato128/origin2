//
//  Course.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 23.04.2026.
//

import Foundation
import SwiftData

@Model
final class Course {
    var id: UUID
    var ownerUserID: String?

    var name: String
    var code: String
    var colorHex: String

    /// user_created / catalog / imported
    var sourceType: String

    var yearNumber: Int?
    var termNumber: Int?

    var isArchived: Bool

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        ownerUserID: String? = nil,
        name: String,
        code: String = "",
        colorHex: String = "#3B82F6",
        sourceType: String = "user_created",
        yearNumber: Int? = nil,
        termNumber: Int? = nil,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.ownerUserID = ownerUserID
        self.name = name
        self.code = code
        self.colorHex = colorHex
        self.sourceType = sourceType
        self.yearNumber = yearNumber
        self.termNumber = termNumber
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
