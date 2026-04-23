//
//  StudentStore.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 23.04.2026.
//

import Foundation
import SwiftData
import SwiftUI
import Combine
import Supabase

private struct StudentProfileRow: Codable {
    let user_id: UUID
    let education_level: String
    let grade_level: String
    let high_school_track: String?
    let institution_name: String?
    let institution_country: String?
    let major_name: String?
    let daily_study_goal_minutes: Int
    let weekly_study_goal_minutes: Int
    let onboarding_completed: Bool
    let academic_year_start: Int?
    let last_promoted_at: String?
    let created_at: String?
    let updated_at: String?
}

private struct StudentCourseRow: Codable {
    let id: UUID
    let user_id: UUID
    let course_code: String
    let course_name: String
    let institution_name: String?
    let major_name: String?
    let grade_level: String?
    let year_number: Int?
    let term_number: Int?
    let source_type: String
    let is_archived: Bool
    let created_at: String?
    let updated_at: String?
}

@MainActor
final class StudentStore: ObservableObject {
    private let context: ModelContext

    @Published private(set) var currentUserID: String?
    @Published private(set) var profile: StudentProfile?
    @Published private(set) var courses: [Course] = []

    @Published var isLoading: Bool = false
    @Published var didResolveRemoteProfile: Bool = false

    init(context: ModelContext, currentUserID: String? = nil) {
        self.context = context
        self.currentUserID = currentUserID
        reload()
    }

    var hasCompletedStudentProfile: Bool {
        profile?.onboardingCompleted == true
    }

    func setCurrentUserID(_ userID: String?) {
        currentUserID = userID
        didResolveRemoteProfile = false

        if userID == nil {
            profile = nil
            courses = []
            reload()
            return
        }

        reload()

        Task {
            await loadFromRemote()
        }
    }

    func reload() {
        guard let currentUserID else {
            profile = nil
            courses = []
            return
        }

        do {
            let profileDescriptor = FetchDescriptor<StudentProfile>()
            let allProfiles = try context.fetch(profileDescriptor)
            profile = allProfiles.first(where: { $0.ownerUserID == currentUserID })

            let courseDescriptor = FetchDescriptor<Course>(
                sortBy: [SortDescriptor(\Course.createdAt, order: .forward)]
            )
            let allCourses = try context.fetch(courseDescriptor)
            courses = allCourses.filter {
                $0.ownerUserID == currentUserID && !$0.isArchived
            }
        } catch {
            print("❌ StudentStore.reload error:", error)
            profile = nil
            courses = []
        }
    }

    // MARK: - Public Remote API

    func loadFromRemote() async {
        guard let currentUserID else {
            didResolveRemoteProfile = true
            return
        }

        guard let userUUID = UUID(uuidString: currentUserID) else {
            didResolveRemoteProfile = true
            return
        }

        isLoading = true
        defer {
            isLoading = false
            didResolveRemoteProfile = true
        }

        do {
            let profileResponse = try await SupabaseManager.shared.client
                .from("student_profiles")
                .select()
                .eq("user_id", value: userUUID.uuidString)
                .limit(1)
                .execute()

            if let rows = try? JSONDecoder().decode([StudentProfileRow].self, from: profileResponse.data),
               let profileRow = rows.first {
                upsertLocalProfile(from: profileRow)
            }

            let coursesResponse = try await SupabaseManager.shared.client
                .from("student_courses")
                .select()
                .eq("user_id", value: userUUID.uuidString)
                .eq("is_archived", value: false)
                .order("created_at", ascending: true)
                .execute()

            if let rows = try? JSONDecoder().decode([StudentCourseRow].self, from: coursesResponse.data) {
                replaceLocalCourses(from: rows)
            }

            reload()
        } catch {
            print("❌ StudentStore.loadFromRemote error:", error)
            reload()
        }
    }

    func saveStudentProfile(
        educationLevel: String,
        gradeLevel: String,
        highSchoolTrack: String?,
        institutionName: String?,
        institutionCountry: String?,
        majorName: String?,
        dailyStudyGoalMinutes: Int,
        weeklyStudyGoalMinutes: Int
    ) {
        guard let currentUserID else { return }

        if let profile {
            profile.educationLevel = educationLevel
            profile.gradeLevel = gradeLevel
            profile.highSchoolTrack = highSchoolTrack
            profile.institutionName = institutionName
            profile.institutionCountry = institutionCountry
            profile.majorName = majorName
            profile.dailyStudyGoalMinutes = dailyStudyGoalMinutes
            profile.weeklyStudyGoalMinutes = weeklyStudyGoalMinutes
            profile.onboardingCompleted = true
            profile.updatedAt = Date()
        } else {
            let newProfile = StudentProfile(
                ownerUserID: currentUserID,
                educationLevel: educationLevel,
                gradeLevel: gradeLevel,
                highSchoolTrack: highSchoolTrack,
                institutionName: institutionName,
                institutionCountry: institutionCountry,
                majorName: majorName,
                onboardingCompleted: true,
                dailyStudyGoalMinutes: dailyStudyGoalMinutes,
                weeklyStudyGoalMinutes: weeklyStudyGoalMinutes
            )
            context.insert(newProfile)
        }

        saveAndReload()
    }

    func completeOnboardingAndSync(
        educationLevel: String,
        gradeLevel: String,
        highSchoolTrack: String?,
        institutionName: String?,
        institutionCountry: String?,
        majorName: String?,
        dailyStudyGoalMinutes: Int,
        weeklyStudyGoalMinutes: Int,
        courseDrafts: [OnboardingCourseDraft]
    ) async {
        guard let currentUserID else { return }
        guard let userUUID = UUID(uuidString: currentUserID) else { return }

        isLoading = true
        defer { isLoading = false }

        // 1) local profile
        saveStudentProfile(
            educationLevel: educationLevel,
            gradeLevel: gradeLevel,
            highSchoolTrack: highSchoolTrack,
            institutionName: institutionName,
            institutionCountry: institutionCountry,
            majorName: majorName,
            dailyStudyGoalMinutes: dailyStudyGoalMinutes,
            weeklyStudyGoalMinutes: weeklyStudyGoalMinutes
        )

        // 2) local courses reset + replace
        clearLocalCoursesForCurrentUser()
        for draft in courseDrafts {
            do {
                let payload = StudentCourseInsertPayload(
                    user_id: userUUID,
                    course_code: draft.code,
                    course_name: draft.name,
                    institution_name: institutionName,
                    major_name: majorName,
                    grade_level: gradeLevel,
                    year_number: normalizedYearNumber(from: gradeLevel),
                    term_number: nil,
                    source_type: "manual",
                    is_archived: false
                )

                try await SupabaseManager.shared.client
                    .from("student_courses")
                    .insert(payload)
                    .execute()
            } catch {
                print("❌ StudentStore.insert remote course error:", error)
            }
        }

        // 4) remote courses replace
        do {
            try await SupabaseManager.shared.client
                .from("student_courses")
                .delete()
                .eq("user_id", value: userUUID.uuidString)
                .execute()
        } catch {
            print("❌ StudentStore.delete remote courses error:", error)
        }

        for draft in courseDrafts {
            do {
                let payload = StudentProfileUpsertPayload(
                    user_id: userUUID,
                    education_level: educationLevel,
                    grade_level: gradeLevel,
                    high_school_track: highSchoolTrack,
                    institution_name: institutionName,
                    institution_country: institutionCountry,
                    major_name: majorName,
                    daily_study_goal_minutes: dailyStudyGoalMinutes,
                    weekly_study_goal_minutes: weeklyStudyGoalMinutes,
                    onboarding_completed: true
                )

                try await SupabaseManager.shared.client
                    .from("student_profiles")
                    .upsert(payload, onConflict: "user_id")
                    .execute()
            } catch {
                print("❌ StudentStore.upsert profile error:", error)
            }
        }

        await loadFromRemote()
    }
    
    private struct StudentProfileUpsertPayload: Encodable {
        let user_id: UUID
        let education_level: String
        let grade_level: String
        let high_school_track: String?
        let institution_name: String?
        let institution_country: String?
        let major_name: String?
        let daily_study_goal_minutes: Int
        let weekly_study_goal_minutes: Int
        let onboarding_completed: Bool
    }

    private struct StudentCourseInsertPayload: Encodable {
        let user_id: UUID
        let course_code: String
        let course_name: String
        let institution_name: String?
        let major_name: String?
        let grade_level: String?
        let year_number: Int?
        let term_number: Int?
        let source_type: String
        let is_archived: Bool
    }

    func addCourse(
        name: String,
        code: String = "",
        colorHex: String = "#3B82F6",
        sourceType: String = "user_created",
        yearNumber: Int? = nil,
        termNumber: Int? = nil
    ) {
        guard let currentUserID else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else { return }

        let course = Course(
            ownerUserID: currentUserID,
            name: trimmedName,
            code: trimmedCode,
            colorHex: colorHex,
            sourceType: sourceType,
            yearNumber: yearNumber,
            termNumber: termNumber
        )

        context.insert(course)
        saveAndReload()
    }

    func deleteCourse(_ course: Course) {
        guard course.ownerUserID == currentUserID else { return }
        context.delete(course)
        saveAndReload()
    }

    func clearForSignOut() {
        currentUserID = nil
        profile = nil
        courses = []
        didResolveRemoteProfile = false
    }

    // MARK: - Local Sync Helpers

    private func upsertLocalProfile(from row: StudentProfileRow) {
        let userID = row.user_id.uuidString

        let existing: StudentProfile?
        do {
            let descriptor = FetchDescriptor<StudentProfile>()
            let all = try context.fetch(descriptor)
            existing = all.first(where: { $0.ownerUserID == userID })
        } catch {
            print("❌ upsertLocalProfile fetch error:", error)
            return
        }

        if let existing {
            existing.educationLevel = row.education_level
            existing.gradeLevel = row.grade_level
            existing.highSchoolTrack = row.high_school_track
            existing.institutionName = row.institution_name
            existing.institutionCountry = row.institution_country
            existing.majorName = row.major_name
            existing.dailyStudyGoalMinutes = row.daily_study_goal_minutes
            existing.weeklyStudyGoalMinutes = row.weekly_study_goal_minutes
            existing.onboardingCompleted = row.onboarding_completed
            existing.updatedAt = Date()
        } else {
            let newProfile = StudentProfile(
                ownerUserID: userID,
                educationLevel: row.education_level,
                gradeLevel: row.grade_level,
                highSchoolTrack: row.high_school_track,
                institutionName: row.institution_name,
                institutionCountry: row.institution_country,
                majorName: row.major_name,
                onboardingCompleted: row.onboarding_completed,
                dailyStudyGoalMinutes: row.daily_study_goal_minutes,
                weeklyStudyGoalMinutes: row.weekly_study_goal_minutes
            )
            context.insert(newProfile)
        }

        saveContextOnly()
    }

    private func replaceLocalCourses(from rows: [StudentCourseRow]) {
        guard let currentUserID else { return }

        do {
            let descriptor = FetchDescriptor<Course>()
            let all = try context.fetch(descriptor)
            let mine = all.filter { $0.ownerUserID == currentUserID }
            for item in mine {
                context.delete(item)
            }

            for row in rows where row.user_id.uuidString == currentUserID {
                let course = Course(
                    ownerUserID: currentUserID,
                    name: row.course_name,
                    code: row.course_code,
                    colorHex: "#3B82F6",
                    sourceType: row.source_type,
                    yearNumber: row.year_number,
                    termNumber: row.term_number,
                    isArchived: row.is_archived
                )
                context.insert(course)
            }

            saveContextOnly()
        } catch {
            print("❌ replaceLocalCourses error:", error)
        }
    }

    private func clearLocalCoursesForCurrentUser() {
        guard let currentUserID else { return }

        do {
            let descriptor = FetchDescriptor<Course>()
            let all = try context.fetch(descriptor)
            let mine = all.filter { $0.ownerUserID == currentUserID }
            for item in mine {
                context.delete(item)
            }
            saveContextOnly()
            reload()
        } catch {
            print("❌ clearLocalCoursesForCurrentUser error:", error)
        }
    }

    private func normalizedYearNumber(from gradeLevel: String) -> Int? {
        switch gradeLevel {
        case "1": return 1
        case "2": return 2
        case "3": return 3
        case "4": return 4
        case "5": return 5
        case "6": return 6
        default: return nil
        }
    }

    private func saveAndReload() {
        saveContextOnly()
        reload()
        objectWillChange.send()
    }

    private func saveContextOnly() {
        do {
            try context.save()
        } catch {
            print("❌ StudentStore.save error:", error)
        }
    }
}
