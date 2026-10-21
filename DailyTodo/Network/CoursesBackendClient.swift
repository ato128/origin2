//
//  CoursesBackendClient.swift
//  DailyTodo
//
//  Active courses ("Derslerim") on our own backend (Railway) — replaced
//  Supabase student_courses, whose source_type check rejected scanned /
//  schedule lessons:
//    GET  /v1/courses            my courses (first call copies my Supabase ones)
//    POST /v1/courses            add one (idempotent by name + code)
//    POST /v1/courses/delete     remove by name + code
//    PUT  /v1/courses            replace all (onboarding)
//

import Foundation
import Supabase

struct BackendCourse: Decodable {
    let id: String
    let code: String
    let name: String
    let colorHex: String?
    let sourceType: String
    let yearNumber: Int?
    let termNumber: Int?
    let isArchived: Bool
}

/// What the app sends for one course.
struct BackendCourseInput: Codable {
    let code: String
    let name: String
    var color_hex: String?
    let source_type: String
    var institution_name: String?
    var major_name: String?
    var grade_level: String?
    var year_number: Int?
    var term_number: Int?
}

final class CoursesBackendClient {
    static let shared = CoursesBackendClient()
    private init() {}

    private let baseURL = ChatBackendEnvironment.httpBaseURL

    private struct ListResponse: Decodable {
        let ok: Bool
        let courses: [BackendCourse]
    }

    private func request(_ path: String, method: String, body: Data? = nil) async throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else { throw URLError(.badURL) }
        let token = try await SupabaseManager.shared.client.auth.session.accessToken
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 25
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            Log.debug("❌ courses backend \(request.httpMethod ?? "") \(request.url?.path ?? "") →", status,
                      String(data: data, encoding: .utf8) ?? "")
            throw URLError(.badServerResponse)
        }
        return data
    }

    func list() async throws -> [BackendCourse] {
        let data = try await send(try await request("/v1/courses", method: "GET"))
        return try JSONDecoder().decode(ListResponse.self, from: data).courses
    }

    func add(_ course: BackendCourseInput) async throws {
        _ = try await send(try await request("/v1/courses", method: "POST", body: try JSONEncoder().encode(course)))
    }

    func delete(name: String, code: String) async throws {
        let body = try JSONEncoder().encode(["name": name, "code": code])
        _ = try await send(try await request("/v1/courses/delete", method: "POST", body: body))
    }

    func replaceAll(_ courses: [BackendCourseInput]) async throws {
        let body = try JSONEncoder().encode(["courses": courses])
        _ = try await send(try await request("/v1/courses", method: "PUT", body: body))
    }
}
