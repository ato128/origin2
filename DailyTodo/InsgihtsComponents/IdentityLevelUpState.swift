//
//  IdentityLevelUpState.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 27.04.2026.
//

import Foundation
import SwiftData

@Model
final class IdentityLevelUpState {
    var id: UUID
    var ownerUserID: String?

    var pendingLevel: Int
    var pendingTitle: String

    var isPending: Bool
    var createdAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        ownerUserID: String?,
        pendingLevel: Int,
        pendingTitle: String,
        isPending: Bool = true,
        createdAt: Date = .now,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.ownerUserID = ownerUserID
        self.pendingLevel = pendingLevel
        self.pendingTitle = pendingTitle
        self.isPending = isPending
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}
