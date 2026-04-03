//
//  ExamItem.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 3.04.2026.
//

import Foundation
import SwiftData

@Model
final class ExamItem {
    var id: UUID
    var title: String
    var courseName: String
    var examType: String
    var examDate: Date
    var notes: String
    var colorHex: String
    var preferredStudyMinutes: Int
    var isCompleted: Bool
    var createdAt: Date
    var ownerUserID: String?

    init(
        id: UUID = UUID(),
        title: String,
        courseName: String,
        examType: String = "Vize",
        examDate: Date,
        notes: String = "",
        colorHex: String = "#3B82F6",
        preferredStudyMinutes: Int = 40,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        ownerUserID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.courseName = courseName
        self.examType = examType
        self.examDate = examDate
        self.notes = notes
        self.colorHex = colorHex
        self.preferredStudyMinutes = preferredStudyMinutes
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.ownerUserID = ownerUserID
    }
}
