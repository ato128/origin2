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

    enum CodingKeys: String, CodingKey {
        case id
        case university_id
        case major_id
        case year_number
        case term_number
        case course_code
        case course_name
        case ects
        case credit
        case is_required
        case is_elective
        case category
        case source_url
        case last_verified_at
        case is_active
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        university_id = try container.decodeIfPresent(UUID.self, forKey: .university_id)
        major_id = try container.decode(UUID.self, forKey: .major_id)
        year_number = try container.decode(Int.self, forKey: .year_number)
        term_number = try container.decodeIfPresent(Int.self, forKey: .term_number)
        course_code = try container.decode(String.self, forKey: .course_code)
        course_name = try container.decode(String.self, forKey: .course_name)

        ects = Self.decodeFlexibleString(container, key: .ects)
        credit = Self.decodeFlexibleString(container, key: .credit)

        is_required = try container.decode(Bool.self, forKey: .is_required)
        is_elective = try container.decodeIfPresent(Bool.self, forKey: .is_elective)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        source_url = try container.decodeIfPresent(String.self, forKey: .source_url)
        last_verified_at = try container.decodeIfPresent(String.self, forKey: .last_verified_at)
        is_active = try container.decodeIfPresent(Bool.self, forKey: .is_active)
    }

    private static func decodeFlexibleString(
        _ container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> String? {
        if let value = try? container.decodeIfPresent(String.self, forKey: key) {
            return value
        }

        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }

        if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
            if value.rounded() == value {
                return String(Int(value))
            }

            return String(value)
        }

        return nil
    }
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
        countryCode: String? = nil,
        query: String = ""
    ) async throws -> [CatalogUniversity] {
        var components = URLComponents(string: "\(baseURL)/v1/catalog/universities")!

        // No countryCode → global alphabetical search across the whole catalog
        // (TR + KKTC + world) — the single unified list the onboarding uses.
        var items: [URLQueryItem] = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: "300")
        ]
        if let countryCode {
            items.append(URLQueryItem(name: "countryCode", value: countryCode))
            items.append(URLQueryItem(name: "country_code", value: countryCode))
        }
        components.queryItems = items

        guard let url = components.url else {
            throw CatalogServiceError.invalidResponse
        }

        let response: CatalogUniversitiesResponse = try await sendRequest(
            url: url,
            method: "GET",
            debugName: "fetchUniversities"
        )

        guard response.ok else {
            throw CatalogServiceError.backend(response.error ?? "University catalog failed")
        }

        Log.debug("📚 Catalog universities count:", response.universities.count)
        Log.debug("📚 Catalog universities country:", countryCode)

        return response.universities
    }

    static func fetchMajors(
        universityID: UUID,
        query: String = ""
    ) async throws -> [CatalogMajor] {
        let universityIDString = universityID.uuidString.lowercased()

        var components = URLComponents(
            string: "\(baseURL)/v1/catalog/universities/\(universityIDString)/majors"
        )!

        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: "300")
        ]

        Log.debug("📚 Catalog fetchMajors universityID:", universityIDString)

        guard let url = components.url else {
            throw CatalogServiceError.invalidResponse
        }

        let response: CatalogMajorsResponse = try await sendRequest(
            url: url,
            method: "GET",
            debugName: "fetchMajors"
        )

        guard response.ok else {
            throw CatalogServiceError.backend(response.error ?? "Major catalog failed")
        }

        Log.debug("📚 Catalog majors count:", response.majors.count)
        Log.debug("📚 Catalog majors names:", response.majors.prefix(8).map(\.name).joined(separator: ", "))

        return response.majors
    }

    static func fetchCurriculumCourses(
        majorID: UUID,
        gradeLevel: String
    ) async throws -> [CatalogCurriculumCourse] {
        let majorIDString = majorID.uuidString.lowercased()

        var components = URLComponents(
            string: "\(baseURL)/v1/catalog/majors/\(majorIDString)/curriculum"
        )!

        components.queryItems = [
            URLQueryItem(name: "gradeLevel", value: gradeLevel)
        ]

        Log.debug("📚 Catalog fetchCurriculum majorID:", majorIDString)
        Log.debug("📚 Catalog fetchCurriculum gradeLevel:", gradeLevel)

        guard let url = components.url else {
            throw CatalogServiceError.invalidResponse
        }

        let response: CatalogCurriculumResponse = try await sendRequest(
            url: url,
            method: "GET",
            debugName: "fetchCurriculumCourses"
        )

        guard response.ok else {
            throw CatalogServiceError.backend(response.error ?? "Curriculum catalog failed")
        }

        Log.debug("📚 Catalog curriculum count:", response.courses.count)

        return response.courses
    }

    static func fetchAllCurriculumCourses(
        majorID: UUID
    ) async throws -> [CatalogCurriculumCourse] {
        let majorIDString = majorID.uuidString.lowercased()

        let url = URL(
            string: "\(baseURL)/v1/catalog/majors/\(majorIDString)/curriculum/all"
        )!

        Log.debug("📚 Catalog fetchAllCurriculum majorID:", majorIDString)

        let response: CatalogCurriculumResponse = try await sendRequest(
            url: url,
            method: "GET",
            debugName: "fetchAllCurriculumCourses"
        )

        guard response.ok else {
            throw CatalogServiceError.backend(response.error ?? "All curriculum catalog failed")
        }

        Log.debug("📚 Catalog all curriculum count:", response.courses.count)

        return response.courses
    }

    private static func sendRequest<T: Decodable>(
        url: URL,
        method: String,
        debugName: String
    ) async throws -> T {
        guard let accessToken = SupabaseManager.shared.client.auth.currentSession?.accessToken,
              !accessToken.isEmpty else {
            Log.debug("❌ Catalog missing access token:", debugName)
            throw CatalogServiceError.missingAccessToken
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        Log.debug("📡 Catalog request:", debugName)
        Log.debug("📡 Catalog URL:", url.absoluteString)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            Log.debug("❌ Catalog invalid response:", debugName)
            throw CatalogServiceError.invalidResponse
        }

        let body = String(data: data, encoding: .utf8) ?? "no-body"

        Log.debug("📡 Catalog status:", debugName, http.statusCode)

        if !(200...299).contains(http.statusCode) {
            Log.debug("❌ Catalog HTTP failed:", debugName)
            Log.debug("❌ Catalog body:", body)
            throw CatalogServiceError.backend("Catalog request failed: \(http.statusCode) \(body)")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            Log.debug("❌ Catalog decode failed:", debugName)
            Log.debug("❌ Catalog decode error:", error)
            Log.debug("❌ Catalog response body:", body)
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
            return tr("scat_no_token")
        case .invalidResponse:
            return tr("scat_invalid_response")
        case .backend(let message):
            return message
        }
    }
}
