//
//  StudentCatalogService.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 23.04.2026.
//

import Foundation
import Supabase

struct CatalogUniversity: Identifiable, Hashable, Decodable {
    let id: UUID
    let name: String
    let country_code: String
    let sort_name: String
    let is_active: Bool?
}

struct CatalogMajor: Identifiable, Hashable, Decodable {
    let id: UUID
    let university_id: UUID
    let name: String
    let faculty_name: String?
    let is_active: Bool?
}

struct CatalogCurriculumCourse: Identifiable, Hashable, Decodable {
    let id: UUID
    let major_id: UUID
    let year_number: Int
    let term_number: Int?
    let course_code: String
    let course_name: String
    let is_required: Bool
    let source_url: String?
    let is_active: Bool?
}

enum StudentCatalogService {
    static func fetchUniversities(
        countryCode: String,
        query: String = ""
    ) async throws -> [CatalogUniversity] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        var request = SupabaseManager.shared.client
            .from("universities")
            .select()
            .eq("country_code", value: countryCode)
            .eq("is_active", value: true)

        if !trimmed.isEmpty {
            request = request.ilike("name", value: "%\(trimmed)%")
        }

        let response = try await request
            .order("sort_name", ascending: true)
            .execute()

        return try JSONDecoder().decode([CatalogUniversity].self, from: response.data)
    }

    static func fetchMajors(
        universityID: UUID,
        query: String = ""
    ) async throws -> [CatalogMajor] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        var request = SupabaseManager.shared.client
            .from("majors")
            .select()
            .eq("university_id", value: universityID)
            .eq("is_active", value: true)

        if !trimmed.isEmpty {
            request = request.ilike("name", value: "%\(trimmed)%")
        }

        let response = try await request
            .order("name", ascending: true)
            .execute()

        return try JSONDecoder().decode([CatalogMajor].self, from: response.data)
    }

    static func fetchCurriculumCourses(
        majorID: UUID,
        gradeLevel: String
    ) async throws -> [CatalogCurriculumCourse] {
        guard let yearNumber = normalizedYearNumber(from: gradeLevel) else {
            return []
        }

        let response = try await SupabaseManager.shared.client
            .from("curriculum_courses")
            .select()
            .eq("major_id", value: majorID)
            .eq("year_number", value: yearNumber)
            .eq("is_active", value: true)
            .order("term_number", ascending: true)
            .order("course_code", ascending: true)
            .execute()

        return try JSONDecoder().decode([CatalogCurriculumCourse].self, from: response.data)
    }
    
    static func fetchAllCurriculumCourses(
        majorID: UUID
    ) async throws -> [CatalogCurriculumCourse] {
        let response = try await SupabaseManager.shared.client
            .from("curriculum_courses")
            .select()
            .eq("major_id", value: majorID)
            .eq("is_active", value: true)
            .order("year_number", ascending: true)
            .order("term_number", ascending: true)
            .order("course_code", ascending: true)
            .execute()

        return try JSONDecoder().decode([CatalogCurriculumCourse].self, from: response.data)
    }

    private static func normalizedYearNumber(from gradeLevel: String) -> Int? {
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
}
