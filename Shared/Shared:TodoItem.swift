//
//  Shared:.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import Foundation
import SwiftData

enum RepeatRule: String, CaseIterable, Codable, Hashable {
    case none = "Yok"
    case daily = "Her gün"
    case weekly = "Her hafta"
    case monthly = "Her ay"
}

@Model
final class DTTaskItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var isDone: Bool
    var dueDate: Date?
    var createdAt: Date
    var repeatRuleRaw: String
    var reminderEnabled: Bool
    var reminderTime: Date?

    init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        repeatRule: RepeatRule = .none,
        reminderEnabled: Bool = false,
        reminderTime: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.repeatRuleRaw = repeatRule.rawValue
        self.reminderEnabled = reminderEnabled
        self.reminderTime = reminderTime
    }

    var repeatRule: RepeatRule {
        get { RepeatRule(rawValue: repeatRuleRaw) ?? .none }
        set { repeatRuleRaw = newValue.rawValue }
    }
}
