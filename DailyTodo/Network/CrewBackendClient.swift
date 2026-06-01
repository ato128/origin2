//
//  CrewBackendClient.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 1.06.2026.
//

import Foundation
import Supabase
import Auth
 
// MARK: - Crew Backend Client
//
// CrewStore'un Supabase çağrılarının yerine geçecek REST client.
// Pattern: ChatBackendClient ile birebir aynı (auth, error handling, logging).
//
// Bu dosya YENİ — mevcut kodu kırmaz. CrewStore'da Supabase çağrılarını
// PARÇA PARÇA bu client'a çevireceğiz.
//
// Base URL ve auth helper'ları ChatBackendEnvironment / SupabaseManager
// üzerinden geliyor — kod tekrarı yok.
 
// MARK: - Response Wrappers
 
struct CrewBackendCrewsResponse: Decodable {
    let ok: Bool
    let crews: [CrewDTO]?
    let error: String?
}
 
struct CrewBackendCrewResponse: Decodable {
    let ok: Bool
    let crew: CrewDTO?
    let error: String?
}
 
struct CrewBackendMembersResponse: Decodable {
    let ok: Bool
    let members: [CrewMemberDTO]?
    let error: String?
}
 
struct CrewBackendMemberResponse: Decodable {
    let ok: Bool
    let member: CrewMemberDTO?
    let error: String?
}
 
struct CrewBackendCountResponse: Decodable {
    let ok: Bool
    let count: Int?
    let error: String?
}
 
struct CrewBackendTaskCountsResponse: Decodable {
    let ok: Bool
    let total: Int?
    let completed: Int?
    let error: String?
}
 
struct CrewBackendTasksResponse: Decodable {
    let ok: Bool
    let tasks: [CrewTaskDTO]?
    let error: String?
}
 
struct CrewBackendTaskResponse: Decodable {
    let ok: Bool
    let task: CrewTaskDTO?
    let error: String?
}
 
struct CrewBackendActivitiesResponse: Decodable {
    let ok: Bool
    let activities: [CrewActivityDTO]?
    let error: String?
}
 
struct CrewBackendActivityResponse: Decodable {
    let ok: Bool
    let activity: CrewActivityDTO?
    let error: String?
}
 
struct CrewBackendFocusRecordsResponse: Decodable {
    let ok: Bool
    let records: [CrewFocusRecordDTO]?
    let error: String?
}
 
struct CrewBackendFocusRecordResponse: Decodable {
    let ok: Bool
    let record: CrewFocusRecordDTO?
    let error: String?
}
 
struct CrewBackendFocusSessionResponse: Decodable {
    let ok: Bool
    let session: CrewFocusSessionDTO?
    let error: String?
}
 
struct CrewBackendFocusParticipantResponse: Decodable {
    let ok: Bool
    let participant: CrewFocusParticipantDTO?
    let error: String?
}
 
struct CrewBackendFocusParticipantsResponse: Decodable {
    let ok: Bool
    let participants: [CrewFocusParticipantDTO]?
    let error: String?
}
 
struct CrewBackendInviteDTO: Decodable {
    let id: UUID
    let crew_id: UUID
    let code: String
    let created_by: UUID?
    let created_at: String?
}
 
struct CrewBackendInviteResponse: Decodable {
    let ok: Bool
    let invite: CrewBackendInviteDTO?
    let error: String?
}
 
struct CrewBackendAcceptInviteResponse: Decodable {
    let ok: Bool
    let crewID: UUID?
    let error: String?
}
 
struct CrewBackendOKResponse: Decodable {
    let ok: Bool
    let error: String?
}
 
// MARK: - Error
 
enum CrewBackendClientError: LocalizedError {
    case invalidURL
    case missingAccessToken
    case apiError(String)
    case invalidResponse
    case decodingFailed(String)
 
    var errorDescription: String? {
        switch self {
        case .invalidURL:        return "Invalid backend URL"
        case .missingAccessToken: return "Missing access token"
        case .apiError(let m):    return m
        case .invalidResponse:   return "Invalid backend response"
        case .decodingFailed(let m): return "Decode failed: \(m)"
        }
    }
}
 
// MARK: - Client
 
final class CrewBackendClient {
    static let shared = CrewBackendClient()
 
    private init() {}
 
    private let baseURL = ChatBackendEnvironment.httpBaseURL
 
    private var jsonDecoder: JSONDecoder { JSONDecoder() }
 
    // ─────────────────────────────────────────────────────────────────
    // Auth + Request helpers (ChatBackendClient ile birebir)
    // ─────────────────────────────────────────────────────────────────
 
    private func accessToken() async throws -> String {
        let session = try await SupabaseManager.shared.client.auth.session
        return session.accessToken
    }
 
    private func makeURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(string: "\(baseURL)\(path)") else {
            throw CrewBackendClientError.invalidURL
        }
 
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
 
        guard let url = components.url else {
            throw CrewBackendClientError.invalidURL
        }
 
        return url
    }
 
    private func makeRequest(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Any? = nil,
        timeout: TimeInterval = 15
    ) async throws -> URLRequest {
        let token = try await accessToken()
        let url = try makeURL(path: path, queryItems: queryItems)
 
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
 
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
 
        return request
    }
 
    private func perform<Response: Decodable>(
        _ request: URLRequest,
        responseType: Response.Type,
        debugName: String
    ) async throws -> Response {
        let (data, response) = try await URLSession.shared.data(for: request)
 
        guard let http = response as? HTTPURLResponse else {
            throw CrewBackendClientError.invalidResponse
        }
 
        #if DEBUG
        let responseText = String(data: data, encoding: .utf8) ?? ""
        ChatBackendLogger.log("✅ CREW BACKEND \(debugName) STATUS:", http.statusCode)
        ChatBackendLogger.log("✅ CREW BACKEND \(debugName) RESPONSE:", responseText)
        #endif
 
        do {
            let decoded = try jsonDecoder.decode(Response.self, from: data)
 
            if http.statusCode >= 200 && http.statusCode < 300 {
                return decoded
            }
 
            if let apiError = extractAPIError(from: data) {
                throw CrewBackendClientError.apiError(apiError)
            }
 
            throw CrewBackendClientError.apiError(
                "Backend request failed with status \(http.statusCode)"
            )
        } catch let error as CrewBackendClientError {
            throw error
        } catch {
            throw CrewBackendClientError.decodingFailed(error.localizedDescription)
        }
    }
 
    private func extractAPIError(from data: Data) -> String? {
        struct ErrorResponse: Decodable {
            let ok: Bool?
            let error: String?
        }
 
        return try? jsonDecoder.decode(ErrorResponse.self, from: data).error
    }
 
    private func isCancelledError(_ error: Error) -> Bool {
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }
        return (error as NSError).code == NSURLErrorCancelled
    }
 
    // ═════════════════════════════════════════════════════════════════
    // CREWS
    // ═════════════════════════════════════════════════════════════════
 
    /// Kullanıcının üye olduğu crew'leri döndür.
    /// CrewStore.loadCrews()'in yerine geçer.
    @discardableResult
    func listCrews() async -> [CrewDTO] {
        do {
            let request = try await makeRequest(
                path: "/v1/crews",
                method: "GET",
                timeout: 20
            )
 
            let decoded = try await perform(
                request,
                responseType: CrewBackendCrewsResponse.self,
                debugName: "listCrews"
            )
 
            guard decoded.ok else {
                ChatBackendLogger.error("❌ CREW BACKEND listCrews API ERROR:", decoded.error ?? "unknown")
                return []
            }
 
            return decoded.crews ?? []
        } catch {
            if isCancelledError(error) { return [] }
            ChatBackendLogger.error("❌ CREW BACKEND listCrews ERROR:", error.localizedDescription)
            return []
        }
    }
 
    /// Yeni crew oluştur (owner otomatik üye olur).
    /// CrewStore.createCrew()'in yerine geçer.
    @discardableResult
    func createCrew(
        name: String,
        icon: String?,
        colorHex: String?
    ) async -> CrewDTO? {
        do {
            var body: [String: Any] = ["name": name]
            if let icon { body["icon"] = icon }
            if let colorHex { body["colorHex"] = colorHex }
 
            let request = try await makeRequest(
                path: "/v1/crews",
                method: "POST",
                body: body,
                timeout: 25
            )
 
            let decoded = try await perform(
                request,
                responseType: CrewBackendCrewResponse.self,
                debugName: "createCrew"
            )
 
            guard decoded.ok else {
                ChatBackendLogger.error("❌ CREW BACKEND createCrew API ERROR:", decoded.error ?? "unknown")
                return nil
            }
 
            return decoded.crew
        } catch {
            ChatBackendLogger.error("❌ CREW BACKEND createCrew ERROR:", error.localizedDescription)
            return nil
        }
    }
 
    /// Crew'ü sil (sadece owner).
    /// CrewStore.deleteCrew()'in yerine geçer.
    @discardableResult
    func deleteCrew(crewID: UUID) async -> Bool {
        do {
            let request = try await makeRequest(
                path: "/v1/crews/\(crewID.uuidString)",
                method: "DELETE",
                timeout: 25
            )
 
            let decoded = try await perform(
                request,
                responseType: CrewBackendOKResponse.self,
                debugName: "deleteCrew"
            )
 
            return decoded.ok
        } catch {
            ChatBackendLogger.error("❌ CREW BACKEND deleteCrew ERROR:", error.localizedDescription)
            return false
        }
    }
 
    // ═════════════════════════════════════════════════════════════════
    // MEMBERS
    // ═════════════════════════════════════════════════════════════════
 
    /// Crew'ün üyelerini listele.
    /// CrewStore.loadMembers()'in yerine geçer.
    @discardableResult
    func listMembers(crewID: UUID) async -> [CrewMemberDTO] {
        do {
            let request = try await makeRequest(
                path: "/v1/crews/\(crewID.uuidString)/members",
                method: "GET",
                timeout: 20
            )
 
            let decoded = try await perform(
                request,
                responseType: CrewBackendMembersResponse.self,
                debugName: "listMembers"
            )
 
            guard decoded.ok else {
                ChatBackendLogger.error("❌ CREW BACKEND listMembers API ERROR:", decoded.error ?? "unknown")
                return []
            }
 
            return decoded.members ?? []
        } catch {
            if isCancelledError(error) { return [] }
            ChatBackendLogger.error("❌ CREW BACKEND listMembers ERROR:", error.localizedDescription)
            return []
        }
    }
 
    /// Üye sayısı (light call).
    /// CrewStore.loadMemberCount()'in yerine geçer.
    @discardableResult
    func memberCount(crewID: UUID) async -> Int {
        do {
            let request = try await makeRequest(
                path: "/v1/crews/\(crewID.uuidString)/member-count",
                method: "GET",
                timeout: 15
            )
 
            let decoded = try await perform(
                request,
                responseType: CrewBackendCountResponse.self,
                debugName: "memberCount"
            )
 
            return decoded.count ?? 0
        } catch {
            ChatBackendLogger.error("❌ CREW BACKEND memberCount ERROR:", error.localizedDescription)
            return 0
        }
    }
 
    /// Username ile crew'e üye ekle.
    /// CrewStore.addMember()'in yerine geçer.
    @discardableResult
    func addMember(crewID: UUID, username: String) async throws -> CrewMemberDTO {
        let request = try await makeRequest(
            path: "/v1/crews/\(crewID.uuidString)/members",
            method: "POST",
            body: ["username": username],
            timeout: 25
        )
 
        let decoded = try await perform(
            request,
            responseType: CrewBackendMemberResponse.self,
            debugName: "addMember"
        )
 
        guard decoded.ok, let member = decoded.member else {
            throw CrewBackendClientError.apiError(decoded.error ?? "addMember failed")
        }
 
        return member
    }
 
    /// Üyeyi crew'den çıkar.
    /// CrewStore.removeMember()'in yerine geçer.
    @discardableResult
    func removeMember(crewID: UUID, memberID: UUID) async -> Bool {
        do {
            let request = try await makeRequest(
                path: "/v1/crews/\(crewID.uuidString)/members/\(memberID.uuidString)",
                method: "DELETE",
                timeout: 20
            )
 
            let decoded = try await perform(
                request,
                responseType: CrewBackendOKResponse.self,
                debugName: "removeMember"
            )
 
            return decoded.ok
        } catch {
            ChatBackendLogger.error("❌ CREW BACKEND removeMember ERROR:", error.localizedDescription)
            return false
        }
    }
 
    /// Kendi pin/mute/archive durumunu güncelle.
    /// CrewStore.setCrewChat{Pinned,Muted,Archived}()'in yerine geçer.
    @discardableResult
    func updateMyMemberState(
        crewID: UUID,
        isPinned: Bool? = nil,
        isMuted: Bool? = nil,
        isArchived: Bool? = nil
    ) async -> CrewMemberDTO? {
        do {
            var body: [String: Bool] = [:]
            if let isPinned { body["isPinned"] = isPinned }
            if let isMuted { body["isMuted"] = isMuted }
            if let isArchived { body["isArchived"] = isArchived }
 
            let request = try await makeRequest(
                path: "/v1/crews/\(crewID.uuidString)/members/me",
                method: "PATCH",
                body: body,
                timeout: 20
            )
 
            let decoded = try await perform(
                request,
                responseType: CrewBackendMemberResponse.self,
                debugName: "updateMemberState"
            )
 
            guard decoded.ok else {
                ChatBackendLogger.error("❌ CREW BACKEND updateMemberState API ERROR:", decoded.error ?? "unknown")
                return nil
            }
 
            return decoded.member
        } catch {
            ChatBackendLogger.error("❌ CREW BACKEND updateMemberState ERROR:", error.localizedDescription)
            return nil
        }
    }
 
    // ═════════════════════════════════════════════════════════════════
    // INVITES
    // ═════════════════════════════════════════════════════════════════
 
    /// Davet kodu oluştur. Döner: 6-haneli code.
    /// CrewStore.createInvite()'in yerine geçer.
    func createInvite(crewID: UUID) async throws -> String {
        let request = try await makeRequest(
            path: "/v1/crews/\(crewID.uuidString)/invites",
            method: "POST",
            body: [:] as [String: String],
            timeout: 20
        )
 
        let decoded = try await perform(
            request,
            responseType: CrewBackendInviteResponse.self,
            debugName: "createInvite"
        )
 
        guard decoded.ok, let invite = decoded.invite else {
            throw CrewBackendClientError.apiError(decoded.error ?? "createInvite failed")
        }
 
        return invite.code
    }
 
    /// Davet kodunu kullanarak crew'e katıl. Döner: crewID.
    /// CrewStore.joinCrew()'in yerine geçer.
    func acceptInvite(code: String) async throws -> UUID {
        let request = try await makeRequest(
            path: "/v1/invites/accept",
            method: "POST",
            body: ["code": code],
            timeout: 25
        )
 
        let decoded = try await perform(
            request,
            responseType: CrewBackendAcceptInviteResponse.self,
            debugName: "acceptInvite"
        )
 
        guard decoded.ok, let crewID = decoded.crewID else {
            throw CrewBackendClientError.apiError(decoded.error ?? "acceptInvite failed")
        }
 
        return crewID
    }
 
    // ═════════════════════════════════════════════════════════════════
    // TASKS
    // ═════════════════════════════════════════════════════════════════
 
    /// Crew'ün tüm task'ları.
    /// CrewStore.loadTasks()'in yerine geçer.
    @discardableResult
    func listTasks(crewID: UUID) async -> [CrewTaskDTO] {
        do {
            let request = try await makeRequest(
                path: "/v1/crews/\(crewID.uuidString)/tasks",
                method: "GET",
                timeout: 20
            )
 
            let decoded = try await perform(
                request,
                responseType: CrewBackendTasksResponse.self,
                debugName: "listTasks"
            )
 
            return decoded.tasks ?? []
        } catch {
            if isCancelledError(error) { return [] }
            ChatBackendLogger.error("❌ CREW BACKEND listTasks ERROR:", error.localizedDescription)
            return []
        }
    }
 
    /// Task sayımı: total + completed TEK çağrıda.
    /// CrewStore.loadTaskCount() + loadCompletedTaskCount()'in yerine geçer.
    func taskCounts(crewID: UUID) async -> (total: Int, completed: Int) {
        do {
            let request = try await makeRequest(
                path: "/v1/crews/\(crewID.uuidString)/task-counts",
                method: "GET",
                timeout: 15
            )
 
            let decoded = try await perform(
                request,
                responseType: CrewBackendTaskCountsResponse.self,
                debugName: "taskCounts"
            )
 
            return (decoded.total ?? 0, decoded.completed ?? 0)
        } catch {
            ChatBackendLogger.error("❌ CREW BACKEND taskCounts ERROR:", error.localizedDescription)
            return (0, 0)
        }
    }
 
    /// Task oluştur.
    /// CrewStore.createTask()'in yerine geçer.
    func createTask(
        crewID: UUID,
        title: String,
        assignedTo: UUID?,
        details: String = "",
        priority: String = "medium",
        status: String = "todo",
        showOnWeek: Bool = false,
        scheduledWeekday: Int? = nil,
        scheduledStartMinute: Int? = nil,
        scheduledDurationMinute: Int? = nil
    ) async throws -> CrewTaskDTO {
        var body: [String: Any] = [
            "title": title,
            "details": details,
            "priority": priority,
            "status": status,
            "showOnWeek": showOnWeek,
        ]
        if let assignedTo {
            body["assignedTo"] = assignedTo.uuidString
        }
        if let scheduledWeekday {
            body["scheduledWeekday"] = scheduledWeekday
        }
        if let scheduledStartMinute {
            body["scheduledStartMinute"] = scheduledStartMinute
        }
        if let scheduledDurationMinute {
            body["scheduledDurationMinute"] = scheduledDurationMinute
        }
 
        let request = try await makeRequest(
            path: "/v1/crews/\(crewID.uuidString)/tasks",
            method: "POST",
            body: body,
            timeout: 25
        )
 
        let decoded = try await perform(
            request,
            responseType: CrewBackendTaskResponse.self,
            debugName: "createTask"
        )
 
        guard decoded.ok, let task = decoded.task else {
            throw CrewBackendClientError.apiError(decoded.error ?? "createTask failed")
        }
 
        return task
    }
 
    /// Task'ı güncelle (dinamik alanlar).
    /// CrewStore.updateTask()'in yerine geçer.
    func updateTask(
        taskID: UUID,
        title: String? = nil,
        assignedTo: UUID? = nil,
        isDone: Bool? = nil,
        details: String? = nil,
        priority: String? = nil,
        status: String? = nil,
        showOnWeek: Bool? = nil,
        scheduledWeekday: Int? = nil,
        scheduledStartMinute: Int? = nil,
        scheduledDurationMinute: Int? = nil
    ) async throws -> CrewTaskDTO {
        var body: [String: Any] = [:]
 
        if let title { body["title"] = title }
        if let assignedTo { body["assignedTo"] = assignedTo.uuidString }
        if let isDone { body["isDone"] = isDone }
        if let details { body["details"] = details }
        if let priority { body["priority"] = priority }
        if let status { body["status"] = status }
        if let showOnWeek { body["showOnWeek"] = showOnWeek }
        if let scheduledWeekday { body["scheduledWeekday"] = scheduledWeekday }
        if let scheduledStartMinute { body["scheduledStartMinute"] = scheduledStartMinute }
        if let scheduledDurationMinute { body["scheduledDurationMinute"] = scheduledDurationMinute }
 
        let request = try await makeRequest(
            path: "/v1/tasks/\(taskID.uuidString)",
            method: "PATCH",
            body: body,
            timeout: 25
        )
 
        let decoded = try await perform(
            request,
            responseType: CrewBackendTaskResponse.self,
            debugName: "updateTask"
        )
 
        guard decoded.ok, let task = decoded.task else {
            throw CrewBackendClientError.apiError(decoded.error ?? "updateTask failed")
        }
 
        return task
    }
 
    /// Task'ın is_done flagi'ni flip et.
    /// CrewStore.toggleTask()'in yerine geçer.
    func toggleTask(taskID: UUID) async throws -> CrewTaskDTO {
        let request = try await makeRequest(
            path: "/v1/tasks/\(taskID.uuidString)/toggle",
            method: "POST",
            body: [:] as [String: String],
            timeout: 20
        )
 
        let decoded = try await perform(
            request,
            responseType: CrewBackendTaskResponse.self,
            debugName: "toggleTask"
        )
 
        guard decoded.ok, let task = decoded.task else {
            throw CrewBackendClientError.apiError(decoded.error ?? "toggleTask failed")
        }
 
        return task
    }
 
    /// Focus session sonrası task'ı tamamla.
    /// CrewStore.completeCrewTaskAfterFocus()'in yerine geçer.
    func completeTaskAfterFocus(taskID: UUID, crewID: UUID) async throws -> CrewTaskDTO {
        let request = try await makeRequest(
            path: "/v1/crews/\(crewID.uuidString)/tasks/\(taskID.uuidString)/complete-after-focus",
            method: "POST",
            body: [:] as [String: String],
            timeout: 25
        )
 
        let decoded = try await perform(
            request,
            responseType: CrewBackendTaskResponse.self,
            debugName: "completeTaskAfterFocus"
        )
 
        guard decoded.ok, let task = decoded.task else {
            throw CrewBackendClientError.apiError(decoded.error ?? "completeTaskAfterFocus failed")
        }
 
        return task
    }
 
    /// Task'ı sil.
    /// CrewStore.deleteTask()'in yerine geçer.
    @discardableResult
    func deleteTask(taskID: UUID) async -> Bool {
        do {
            let request = try await makeRequest(
                path: "/v1/tasks/\(taskID.uuidString)",
                method: "DELETE",
                timeout: 20
            )
 
            let decoded = try await perform(
                request,
                responseType: CrewBackendOKResponse.self,
                debugName: "deleteTask"
            )
 
            return decoded.ok
        } catch {
            ChatBackendLogger.error("❌ CREW BACKEND deleteTask ERROR:", error.localizedDescription)
            return false
        }
    }
 
    // ═════════════════════════════════════════════════════════════════
    // ACTIVITIES
    // ═════════════════════════════════════════════════════════════════
 
    /// Activity feed.
    /// CrewStore.loadActivities()'in yerine geçer.
    @discardableResult
    func listActivities(crewID: UUID) async -> [CrewActivityDTO] {
        do {
            let request = try await makeRequest(
                path: "/v1/crews/\(crewID.uuidString)/activities",
                method: "GET",
                timeout: 20
            )
 
            let decoded = try await perform(
                request,
                responseType: CrewBackendActivitiesResponse.self,
                debugName: "listActivities"
            )
 
            return decoded.activities ?? []
        } catch {
            if isCancelledError(error) { return [] }
            ChatBackendLogger.error("❌ CREW BACKEND listActivities ERROR:", error.localizedDescription)
            return []
        }
    }
 
    /// Yeni activity oluştur.
    /// CrewStore.createActivity()'in yerine geçer.
    @discardableResult
    func createActivity(
        crewID: UUID,
        memberName: String,
        actionText: String
    ) async -> CrewActivityDTO? {
        do {
            let body: [String: String] = [
                "memberName": memberName,
                "actionText": actionText,
            ]
 
            let request = try await makeRequest(
                path: "/v1/crews/\(crewID.uuidString)/activities",
                method: "POST",
                body: body,
                timeout: 20
            )
 
            let decoded = try await perform(
                request,
                responseType: CrewBackendActivityResponse.self,
                debugName: "createActivity"
            )
 
            return decoded.activity
        } catch {
            ChatBackendLogger.error("❌ CREW BACKEND createActivity ERROR:", error.localizedDescription)
            return nil
        }
    }
 
    // ═════════════════════════════════════════════════════════════════
    // FOCUS SESSIONS
    // ═════════════════════════════════════════════════════════════════
 
    /// Yeni focus session başlat.
    /// CrewStore.startCrewFocusSession()'in yerine geçer.
    func startFocusSession(
        crewID: UUID,
        hostName: String,
        title: String,
        taskID: UUID?,
        taskTitle: String?,
        durationMinutes: Int,
        participantCount: Int
    ) async throws -> CrewFocusSessionDTO {
        var body: [String: Any] = [
            "hostName": hostName,
            "title": title,
            "durationMinutes": durationMinutes,
            "participantCount": participantCount,
        ]
        if let taskID { body["taskID"] = taskID.uuidString }
        if let taskTitle { body["taskTitle"] = taskTitle }
 
        let request = try await makeRequest(
            path: "/v1/crews/\(crewID.uuidString)/focus-sessions",
            method: "POST",
            body: body,
            timeout: 25
        )
 
        let decoded = try await perform(
            request,
            responseType: CrewBackendFocusSessionResponse.self,
            debugName: "startFocusSession"
        )
 
        guard decoded.ok, let session = decoded.session else {
            throw CrewBackendClientError.apiError(decoded.error ?? "startFocusSession failed")
        }
 
        return session
    }
 
    /// Crew'deki aktif session (yoksa nil).
    /// CrewStore.loadActiveFocusSession()'in yerine geçer.
    func getActiveFocusSession(crewID: UUID) async -> CrewFocusSessionDTO? {
        do {
            let request = try await makeRequest(
                path: "/v1/crews/\(crewID.uuidString)/focus-sessions/active",
                method: "GET",
                timeout: 15
            )
 
            let decoded = try await perform(
                request,
                responseType: CrewBackendFocusSessionResponse.self,
                debugName: "activeFocusSession"
            )
 
            return decoded.session
        } catch {
            if isCancelledError(error) { return nil }
            ChatBackendLogger.error("❌ CREW BACKEND activeFocusSession ERROR:", error.localizedDescription)
            return nil
        }
    }
 
    /// Waiting → live geçişi.
    /// CrewStore.beginWaitingCrewFocusSession()'in yerine geçer.
    func beginWaitingFocusSession(sessionID: UUID, crewID: UUID) async throws -> CrewFocusSessionDTO {
        let request = try await makeRequest(
            path: "/v1/crews/\(crewID.uuidString)/focus-sessions/\(sessionID.uuidString)/begin",
            method: "POST",
            body: [:] as [String: String],
            timeout: 20
        )
 
        let decoded = try await perform(
            request,
            responseType: CrewBackendFocusSessionResponse.self,
            debugName: "beginFocusSession"
        )
 
        guard decoded.ok, let session = decoded.session else {
            throw CrewBackendClientError.apiError(decoded.error ?? "beginFocusSession failed")
        }
 
        return session
    }
 
    /// Pause.
    /// CrewStore.pauseCrewFocusSession()'in yerine geçer.
    func pauseFocusSession(
        sessionID: UUID,
        crewID: UUID,
        pausedRemainingSeconds: Int
    ) async throws -> CrewFocusSessionDTO {
        let request = try await makeRequest(
            path: "/v1/crews/\(crewID.uuidString)/focus-sessions/\(sessionID.uuidString)/pause",
            method: "POST",
            body: ["pausedRemainingSeconds": pausedRemainingSeconds],
            timeout: 20
        )
 
        let decoded = try await perform(
            request,
            responseType: CrewBackendFocusSessionResponse.self,
            debugName: "pauseFocusSession"
        )
 
        guard decoded.ok, let session = decoded.session else {
            throw CrewBackendClientError.apiError(decoded.error ?? "pauseFocusSession failed")
        }
 
        return session
    }
 
    /// Resume.
    /// CrewStore.resumeCrewFocusSession()'in yerine geçer.
    func resumeFocusSession(
        sessionID: UUID,
        crewID: UUID,
        durationMinutes: Int,
        pausedRemainingSeconds: Int
    ) async throws -> CrewFocusSessionDTO {
        let body: [String: Int] = [
            "durationMinutes": durationMinutes,
            "pausedRemainingSeconds": pausedRemainingSeconds,
        ]
 
        let request = try await makeRequest(
            path: "/v1/crews/\(crewID.uuidString)/focus-sessions/\(sessionID.uuidString)/resume",
            method: "POST",
            body: body,
            timeout: 20
        )
 
        let decoded = try await perform(
            request,
            responseType: CrewBackendFocusSessionResponse.self,
            debugName: "resumeFocusSession"
        )
 
        guard decoded.ok, let session = decoded.session else {
            throw CrewBackendClientError.apiError(decoded.error ?? "resumeFocusSession failed")
        }
 
        return session
    }
 
    /// End — session'ı kapat + record'ları yaz (atomik).
    /// CrewStore.endCrewFocusSession()'in yerine geçer.
    func endFocusSession(
        sessionID: UUID,
        crewID: UUID,
        hostUserID: UUID?,
        hostName: String,
        completedMinutes: Int,
        participantNames: [String]
    ) async throws -> CrewFocusSessionDTO {
        var body: [String: Any] = [
            "hostName": hostName,
            "completedMinutes": completedMinutes,
            "participantNames": participantNames,
        ]
        if let hostUserID { body["hostUserID"] = hostUserID.uuidString }
 
        let request = try await makeRequest(
            path: "/v1/crews/\(crewID.uuidString)/focus-sessions/\(sessionID.uuidString)/end",
            method: "POST",
            body: body,
            timeout: 30
        )
 
        let decoded = try await perform(
            request,
            responseType: CrewBackendFocusSessionResponse.self,
            debugName: "endFocusSession"
        )
 
        guard decoded.ok, let session = decoded.session else {
            throw CrewBackendClientError.apiError(decoded.error ?? "endFocusSession failed")
        }
 
        return session
    }
 
    // ═════════════════════════════════════════════════════════════════
    // FOCUS PARTICIPANTS
    // ═════════════════════════════════════════════════════════════════
 
    /// Session'a katıl (idempotent upsert).
    /// CrewStore.joinCrewFocusSession()'in yerine geçer.
    func joinFocusSession(
        sessionID: UUID,
        crewID: UUID,
        memberName: String
    ) async throws -> CrewFocusParticipantDTO {
        let request = try await makeRequest(
            path: "/v1/crews/\(crewID.uuidString)/focus-sessions/\(sessionID.uuidString)/join",
            method: "POST",
            body: ["memberName": memberName],
            timeout: 20
        )
 
        let decoded = try await perform(
            request,
            responseType: CrewBackendFocusParticipantResponse.self,
            debugName: "joinFocusSession"
        )
 
        guard decoded.ok, let participant = decoded.participant else {
            throw CrewBackendClientError.apiError(decoded.error ?? "joinFocusSession failed")
        }
 
        return participant
    }
 
    /// Session'dan ayrıl (soft).
    /// CrewStore.leaveCrewFocusSession()'in yerine geçer.
    @discardableResult
    func leaveFocusSession(sessionID: UUID, crewID: UUID) async -> Bool {
        do {
            let request = try await makeRequest(
                path: "/v1/crews/\(crewID.uuidString)/focus-sessions/\(sessionID.uuidString)/leave",
                method: "POST",
                body: [:] as [String: String],
                timeout: 20
            )
 
            let decoded = try await perform(
                request,
                responseType: CrewBackendOKResponse.self,
                debugName: "leaveFocusSession"
            )
 
            return decoded.ok
        } catch {
            ChatBackendLogger.error("❌ CREW BACKEND leaveFocusSession ERROR:", error.localizedDescription)
            return false
        }
    }
 
    /// Session'ın aktif katılımcıları.
    /// CrewStore.loadFocusParticipants()'in yerine geçer.
    @discardableResult
    func listFocusParticipants(sessionID: UUID) async -> [CrewFocusParticipantDTO] {
        do {
            let request = try await makeRequest(
                path: "/v1/focus-sessions/\(sessionID.uuidString)/participants",
                method: "GET",
                timeout: 20
            )
 
            let decoded = try await perform(
                request,
                responseType: CrewBackendFocusParticipantsResponse.self,
                debugName: "listFocusParticipants"
            )
 
            return decoded.participants ?? []
        } catch {
            if isCancelledError(error) { return [] }
            ChatBackendLogger.error("❌ CREW BACKEND listFocusParticipants ERROR:", error.localizedDescription)
            return []
        }
    }
 
    // ═════════════════════════════════════════════════════════════════
    // FOCUS RECORDS
    // ═════════════════════════════════════════════════════════════════
 
    /// Crew'ün focus geçmişi.
    /// CrewStore.loadFocusRecords()'in yerine geçer.
    @discardableResult
    func listFocusRecords(crewID: UUID) async -> [CrewFocusRecordDTO] {
        do {
            let request = try await makeRequest(
                path: "/v1/crews/\(crewID.uuidString)/focus-records",
                method: "GET",
                timeout: 20
            )
 
            let decoded = try await perform(
                request,
                responseType: CrewBackendFocusRecordsResponse.self,
                debugName: "listFocusRecords"
            )
 
            return decoded.records ?? []
        } catch {
            if isCancelledError(error) { return [] }
            ChatBackendLogger.error("❌ CREW BACKEND listFocusRecords ERROR:", error.localizedDescription)
            return []
        }
    }
 
    /// Tekil focus record ekle.
    /// CrewStore.createFocusRecord()'in yerine geçer.
    @discardableResult
    func createFocusRecord(
        crewID: UUID,
        userID: UUID?,
        memberName: String,
        minutes: Int
    ) async -> CrewFocusRecordDTO? {
        do {
            var body: [String: Any] = [
                "memberName": memberName,
                "minutes": minutes,
            ]
            if let userID { body["userID"] = userID.uuidString }
 
            let request = try await makeRequest(
                path: "/v1/crews/\(crewID.uuidString)/focus-records",
                method: "POST",
                body: body,
                timeout: 20
            )
 
            let decoded = try await perform(
                request,
                responseType: CrewBackendFocusRecordResponse.self,
                debugName: "createFocusRecord"
            )
 
            return decoded.record
        } catch {
            ChatBackendLogger.error("❌ CREW BACKEND createFocusRecord ERROR:", error.localizedDescription)
            return nil
        }
    }
}
