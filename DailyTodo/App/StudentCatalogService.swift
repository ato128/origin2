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

    let city: String?
    let university_type: String?
    let source: String?
    let source_url: String?
}

struct CatalogMajor: Identifiable, Hashable, Decodable {
    let id: UUID
    let university_id: UUID
    let name: String
    let normalized_name: String?
    let faculty_name: String?
    let degree_level: String?
    let language: String?
    let duration_years: Int?
    let source_url: String?
    let is_active: Bool?
}

struct CatalogCurriculumCourse: Identifiable, Hashable, Decodable {
    let id: UUID
    let university_id: UUID?
    let major_id: UUID
    let year_number: Int
    let term_number: Int?
    let course_code: String
    let course_name: String

    let ects: String?
    let credit: String?

    let is_required: Bool
    let is_elective: Bool?
    let category: String?
    let source_url: String?
    let last_verified_at: String?
    let is_active: Bool?
}

private struct CatalogUniversitiesResponse: Decodable {
    let ok: Bool
    let universities: [CatalogUniversity]
    let error: String?
}

private struct CatalogMajorsResponse: Decodable {
    let ok: Bool
    let majors: [CatalogMajor]
    let error: String?
}

private struct CatalogCurriculumResponse: Decodable {
    let ok: Bool
    let courses: [CatalogCurriculumCourse]
    let error: String?
}

enum StudentCatalogService {
    private static var baseURL: String {
        ChatBackendEnvironment.httpBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    static func fetchUniversities(
        countryCode: String,
        query: String = ""
    ) async throws -> [CatalogUniversity] {
        var components = URLComponents(string: "\(baseURL)/v1/catalog/universities")!
        components.queryItems = [
            URLQueryItem(name: "countryCode", value: countryCode),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: "300")
        ]

        let response: CatalogUniversitiesResponse = try await sendRequest(
            url: components.url!,
            method: "GET"
        )

        guard response.ok else {
            throw CatalogServiceError.backend(response.error ?? "University catalog failed")
        }

        return response.universities
    }

    static func fetchMajors(
        universityID: UUID,
        query: String = ""
    ) async throws -> [CatalogMajor] {
        var components = URLComponents(
            string: "\(baseURL)/v1/catalog/universities/\(universityID.uuidString)/majors"
        )!

        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: "300")
        ]

        let response: CatalogMajorsResponse = try await sendRequest(
            url: components.url!,
            method: "GET"
        )

        guard response.ok else {
            throw CatalogServiceError.backend(response.error ?? "Major catalog failed")
        }

        return response.majors
    }

    static func fetchCurriculumCourses(
        majorID: UUID,
        gradeLevel: String
    ) async throws -> [CatalogCurriculumCourse] {
        var components = URLComponents(
            string: "\(baseURL)/v1/catalog/majors/\(majorID.uuidString)/curriculum"
        )!

        components.queryItems = [
            URLQueryItem(name: "gradeLevel", value: gradeLevel)
        ]

        let response: CatalogCurriculumResponse = try await sendRequest(
            url: components.url!,
            method: "GET"
        )

        guard response.ok else {
            throw CatalogServiceError.backend(response.error ?? "Curriculum catalog failed")
        }

        return response.courses
    }

    static func fetchAllCurriculumCourses(
        majorID: UUID
    ) async throws -> [CatalogCurriculumCourse] {
        let url = URL(
            string: "\(baseURL)/v1/catalog/majors/\(majorID.uuidString)/curriculum/all"
        )!

        let response: CatalogCurriculumResponse = try await sendRequest(
            url: url,
            method: "GET"
        )

        guard response.ok else {
            throw CatalogServiceError.backend(response.error ?? "All curriculum catalog failed")
        }

        return response.courses
    }

    private static func sendRequest<T: Decodable>(
        url: URL,
        method: String
    ) async throws -> T {
        guard let accessToken = SupabaseManager.shared.client.auth.currentSession?.accessToken,
              !accessToken.isEmpty else {
            throw CatalogServiceError.missingAccessToken
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw CatalogServiceError.invalidResponse
        }

        if !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "no-body"
            throw CatalogServiceError.backend("Catalog request failed: \(http.statusCode) \(body)")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? "no-body"
            print("❌ Catalog decode failed:", error)
            print("❌ Catalog response body:", body)
            throw error
        }
    }
}

enum CatalogServiceError: LocalizedError {
    case missingAccessToken
    case invalidResponse
    case backend(String)

    var errorDescription: String? {
        switch self {
        case .missingAccessToken:
            return "Oturum tokenı bulunamadı."
        case .invalidResponse:
            return "Katalog yanıtı geçersiz."
        case .backend(let message):
            return message
        }
    }
}
