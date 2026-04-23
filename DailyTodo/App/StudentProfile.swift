//
//  StudentProfile.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 23.04.2026.
//

import Foundation
import SwiftData

@Model
final class StudentProfile {
    var id: UUID
    var ownerUserID: String?

    /// high_school / university
    var educationLevel: String

    /// 9 / 10 / 11 / 12 / prep / 1 / 2 / 3 / 4 / 5 / 6
    var gradeLevel: String

    /// sayisal / sozel / esit_agirlik / dil
    var highSchoolTrack: String?

    /// university only
    var institutionName: String?
    var institutionCountry: String?

    /// university only
    var majorName: String?

    var onboardingCompleted: Bool

    var dailyStudyGoalMinutes: Int
    var weeklyStudyGoalMinutes: Int

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        ownerUserID: String? = nil,
        educationLevel: String,
        gradeLevel: String,
        highSchoolTrack: String? = nil,
        institutionName: String? = nil,
        institutionCountry: String? = nil,
        majorName: String? = nil,
        onboardingCompleted: Bool = false,
        dailyStudyGoalMinutes: Int = 120,
        weeklyStudyGoalMinutes: Int = 840,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.ownerUserID = ownerUserID
        self.educationLevel = educationLevel
        self.gradeLevel = gradeLevel
        self.highSchoolTrack = highSchoolTrack
        self.institutionName = institutionName
        self.institutionCountry = institutionCountry
        self.majorName = majorName
        self.onboardingCompleted = onboardingCompleted
        self.dailyStudyGoalMinutes = dailyStudyGoalMinutes
        self.weeklyStudyGoalMinutes = weeklyStudyGoalMinutes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
