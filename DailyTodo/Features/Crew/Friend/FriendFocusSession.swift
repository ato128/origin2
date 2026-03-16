//
//  FriendFocusSession.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import Foundation
import SwiftData

@Model
final class FriendFocusSession {
    var id: UUID
    var friendID: UUID
    var title: String
    var startedAt: Date
    var durationMinute: Int
    var isActive: Bool

    init(
        id: UUID = UUID(),
        friendID: UUID,
        title: String,
        startedAt: Date = Date(),
        durationMinute: Int = 25,
        isActive: Bool = true
    ) {
        self.id = id
        self.friendID = friendID
        self.title = title
        self.startedAt = startedAt
        self.durationMinute = durationMinute
        self.isActive = isActive
    }
}
