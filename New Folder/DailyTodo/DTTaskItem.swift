//
//  DTTaskItem.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 6.03.2026.
//

import Foundation
import SwiftData

@Model
final class DTTaskItem {
    var title: String
    var isDone: Bool
    var dueDate: Date?
    var createdAt: Date
    var completedAt: Date?

    init(
        title: String,
        isDone: Bool = false,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.title = title
        self.isDone = isDone
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}
