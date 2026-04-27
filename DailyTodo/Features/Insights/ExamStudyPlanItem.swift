//
//  ExamStudyPlanItem.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 27.04.2026.
//

import Foundation
import SwiftData

enum ExamPlannerType: String, Codable, CaseIterable, Identifiable {
    case quiz
    case midterm
    case final

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quiz: return "Quiz"
        case .midterm: return "Vize"
        case .final: return "Final"
        }
    }
}

@Model
final class ExamStudyPlanItem {
    var id: UUID
    var ownerUserID: String?

    var courseID: UUID?
    var courseName: String
    var courseCode: String

    var examTypeRaw: String
    var examDate: Date

    var studyDate: Date
    var minutes: Int
    var topic: String

    var isCompleted: Bool
    var isRevisionDay: Bool
    var isWeakTopicBoost: Bool

    var createdAt: Date
    var completedAt: Date?
    
    var examGroupID: UUID?

    init(
        id: UUID = UUID(),
        ownerUserID: String?,
        courseID: UUID?,
        courseName: String,
        courseCode: String,
        examType: ExamPlannerType,
        examDate: Date,
        studyDate: Date,
        minutes: Int,
        topic: String,
        isCompleted: Bool = false,
        isRevisionDay: Bool = false,
        isWeakTopicBoost: Bool = false,
        createdAt: Date = .now,
        examGroupID: UUID? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.ownerUserID = ownerUserID
        self.courseID = courseID
        self.courseName = courseName
        self.courseCode = courseCode
        self.examTypeRaw = examType.rawValue
        self.examDate = examDate
        self.studyDate = studyDate
        self.minutes = minutes
        self.topic = topic
        self.isCompleted = isCompleted
        self.isRevisionDay = isRevisionDay
        self.isWeakTopicBoost = isWeakTopicBoost
        self.createdAt = createdAt
        self.examGroupID = examGroupID
        self.completedAt = completedAt
    }

    var examType: ExamPlannerType {
        ExamPlannerType(rawValue: examTypeRaw) ?? .midterm
    }
}
