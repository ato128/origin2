//
//  NotebookStore.swift
//  DailyTodo
//
//  Notebook (Defter): a student's notes — typed text plus an Apple Pencil
//  drawing per page, filed under a course — synced through our backend:
//    GET    /v1/notes?since=ISO     changed pages (deletions included)
//    PUT    /v1/notes/:id           create / update (drawing base64, optional)
//    GET    /v1/notes/:id/drawing   the page's PencilKit data
//    DELETE /v1/notes/:id           soft delete
//
//  Local-first: pages live in a per-user cache on disk (JSON + one drawing
//  file per page) so the notebook opens instantly and works offline; edits
//  are marked dirty and pushed after a short pause, then the server's changes
//  are pulled. Last write wins (server time).
//

import Foundation
import Combine
import Supabase

// MARK: - Model

enum NotebookPaper: String, Codable, CaseIterable, Identifiable {
    case lined, grid, dotted, blank
    var id: String { rawValue }

    var titleKey: String { "nb_paper_\(rawValue)" }

    var icon: String {
        switch self {
        case .lined: return "line.3.horizontal"
        case .grid: return "squareshape.split.3x3"
        case .dotted: return "circle.grid.3x3"
        case .blank: return "square"
        }
    }
}

struct NotebookNote: Codable, Identifiable, Hashable {
    var id: UUID
    /// The course (notebook) the page is filed under; nil = "Genel".
    var course: String?
    var title: String
    var body: String
    var paper: NotebookPaper
    /// Extra page length the student added below the first screen.
    var pageHeight: Double
    var summary: String?
    var hasDrawing: Bool
    var drawingUpdatedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    // Local sync state (never sent).
    var isDirty: Bool = false
    var isDrawingDirty: Bool = false
    var isDeleted: Bool = false

    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        let firstLine = body.split(separator: "\n").first.map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return firstLine.isEmpty ? tr("nb_untitled") : String(firstLine.prefix(60))
    }

    /// Body text without the title line, for list previews.
    var preview: String {
        body.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Backend client

private struct NotesListResponse: Decodable {
    let ok: Bool
    let notes: [RemoteNote]
    let serverTime: String?
}

private struct NoteResponse: Decodable {
    let ok: Bool
    let note: RemoteNote?
}

private struct RemoteNote: Decodable {
    let id: String
    let course: String?
    let title: String
    let body: String
    let paper: String
    let pageHeight: Double
    let summary: String?
    let hasDrawing: Bool
    let drawingUpdatedAt: String?
    let createdAt: String
    let updatedAt: String
    let deletedAt: String?
}

final class NotesBackendClient {
    static let shared = NotesBackendClient()
    private init() {}

    private let baseURL = ChatBackendEnvironment.httpBaseURL

    private func request(_ path: String, method: String, timeout: TimeInterval = 30) async throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else { throw URLError(.badURL) }
        let token = try await SupabaseManager.shared.client.auth.session.accessToken
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    fileprivate func list(since: Date?) async throws -> (notes: [RemoteNote], serverTime: Date?) {
        var path = "/v1/notes"
        if let since {
            let iso = NotebookDates.format(since)
            path += "?since=\(iso.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? iso)"
        }
        let req = try await request(path, method: "GET")
        let (data, response) = try await URLSession.shared.data(for: req)
        try Self.check(response)
        let decoded = try JSONDecoder().decode(NotesListResponse.self, from: data)
        return (decoded.notes, decoded.serverTime.flatMap(NotebookDates.parse))
    }

    /// `drawing`: nil = leave the stored drawing alone; empty Data = clear it.
    fileprivate func upsert(_ note: NotebookNote, drawing: Data?) async throws -> RemoteNote? {
        var req = try await request("/v1/notes/\(note.id.uuidString.lowercased())", method: "PUT", timeout: 60)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [
            "title": note.title,
            "body": note.body,
            "paper": note.paper.rawValue,
            "page_height": note.pageHeight,
            "created_at": NotebookDates.format(note.createdAt)
        ]
        body["course"] = note.course ?? NSNull()
        body["summary"] = note.summary ?? NSNull()
        if let drawing {
            body["drawing_base64"] = drawing.isEmpty ? NSNull() : drawing.base64EncodedString() as Any
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        try Self.check(response)
        return try JSONDecoder().decode(NoteResponse.self, from: data).note
    }

    func drawing(for id: UUID) async throws -> Data? {
        let req = try await request("/v1/notes/\(id.uuidString.lowercased())/drawing", method: "GET", timeout: 60)
        let (data, response) = try await URLSession.shared.data(for: req)
        if (response as? HTTPURLResponse)?.statusCode == 404 { return nil }
        try Self.check(response)
        return data
    }

    func delete(_ id: UUID) async throws {
        let req = try await request("/v1/notes/\(id.uuidString.lowercased())", method: "DELETE")
        let (_, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        // Already gone on the server is fine.
        guard (200..<300).contains(status) || status == 404 else { throw URLError(.badServerResponse) }
    }

    private static func check(_ response: URLResponse) throws {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw URLError(.badServerResponse) }
    }
}

enum NotebookDates {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain = ISO8601DateFormatter()

    static func parse(_ value: String) -> Date? {
        withFraction.date(from: value) ?? plain.date(from: value)
    }

    static func format(_ date: Date) -> String {
        withFraction.string(from: date)
    }
}

// MARK: - Store

@MainActor
final class NotebookStore: ObservableObject {
    static let shared = NotebookStore()

    @Published private(set) var notes: [NotebookNote] = []
    @Published private(set) var isSyncing = false
    /// Set when the last sync failed (offline); edits stay queued.
    @Published private(set) var syncFailed = false

    private var userID: String?
    private var lastPulledAt: Date?
    private var syncTask: Task<Void, Never>?
    private var pendingSync: Task<Void, Never>?

    private init() {}

    /// Live pages, newest first.
    var liveNotes: [NotebookNote] {
        notes.filter { !$0.isDeleted }.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Courses that have pages (in the order they were last written to).
    var courses: [String] {
        var seen = Set<String>()
        return liveNotes.compactMap(\.course).filter { seen.insert($0).inserted }
    }

    func note(_ id: UUID) -> NotebookNote? {
        notes.first { $0.id == id }
    }

    // MARK: Lifecycle

    /// Loads this user's cached pages (instant) and syncs in the background.
    func activate(userID: String?) {
        guard let userID, !userID.isEmpty else { return }
        if self.userID != userID {
            self.userID = userID
            loadCache()
        }
        sync()
    }

    // MARK: Editing

    @discardableResult
    func createNote(course: String?) -> NotebookNote {
        let now = Date()
        let note = NotebookNote(
            id: UUID(), course: course, title: "", body: "", paper: .lined,
            pageHeight: 0, summary: nil, hasDrawing: false, drawingUpdatedAt: nil,
            createdAt: now, updatedAt: now, isDirty: true
        )
        notes.append(note)
        saveCache()
        scheduleSync()
        return note
    }

    /// Text / settings change. Pushed after a short pause.
    func update(_ id: UUID, _ change: (inout NotebookNote) -> Void) {
        guard let index = notes.firstIndex(where: { $0.id == id }), !notes[index].isDeleted else { return }
        var note = notes[index]
        change(&note)
        note.updatedAt = Date()
        note.isDirty = true
        notes[index] = note
        saveCache()
        scheduleSync()
    }

    func saveDrawing(_ id: UUID, data: Data, isEmpty: Bool) {
        // A deleted page's editor may flush on its way out — ignore it.
        guard let index = notes.firstIndex(where: { $0.id == id }), !notes[index].isDeleted else { return }
        writeDrawing(isEmpty ? nil : data, for: id)
        notes[index].hasDrawing = !isEmpty
        notes[index].updatedAt = Date()
        notes[index].isDirty = true
        notes[index].isDrawingDirty = true
        saveCache()
        scheduleSync()
    }

    func delete(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].isDeleted = true
        notes[index].isDirty = true
        writeDrawing(nil, for: id)
        saveCache()
        scheduleSync(delay: 0.2)
    }

    /// The page's drawing: from disk, or fetched from the server when another
    /// device drew it and we don't have it yet.
    func drawingData(for id: UUID) async -> Data? {
        if let local = readDrawing(for: id) { return local }
        guard note(id)?.hasDrawing == true else { return nil }
        guard let data = try? await NotesBackendClient.shared.drawing(for: id) else { return nil }
        writeDrawing(data, for: id)
        return data
    }

    func cachedDrawingData(for id: UUID) -> Data? {
        readDrawing(for: id)
    }

    // MARK: Sync

    func scheduleSync(delay: TimeInterval = 1.5) {
        pendingSync?.cancel()
        pendingSync = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.sync()
        }
    }

    func sync() {
        guard userID != nil, syncTask == nil else { return }
        syncTask = Task { [weak self] in
            await self?.runSync()
            self?.syncTask = nil
        }
    }

    private func runSync() async {
        isSyncing = true
        defer { isSyncing = false }
        var failed = false

        // 1) Push local changes.
        for note in notes where note.isDirty {
            do {
                if note.isDeleted {
                    try await NotesBackendClient.shared.delete(note.id)
                    notes.removeAll { $0.id == note.id }
                } else {
                    let drawing: Data? = note.isDrawingDirty ? (readDrawing(for: note.id) ?? Data()) : nil
                    let remote = try await NotesBackendClient.shared.upsert(note, drawing: drawing)
                    if let index = notes.firstIndex(where: { $0.id == note.id }) {
                        // Only clear the flags if nothing changed while uploading.
                        if notes[index].updatedAt == note.updatedAt {
                            notes[index].isDirty = false
                            notes[index].isDrawingDirty = false
                        }
                        if let remote, let drawn = remote.drawingUpdatedAt.flatMap(NotebookDates.parse) {
                            notes[index].drawingUpdatedAt = drawn
                        }
                    }
                }
            } catch {
                failed = true
            }
        }

        // 2) Pull the server's changes.
        do {
            let (remote, serverTime) = try await NotesBackendClient.shared.list(since: lastPulledAt)
            for item in remote { merge(item) }
            if let serverTime { lastPulledAt = serverTime }
        } catch {
            failed = true
        }

        syncFailed = failed
        saveCache()
    }

    private func merge(_ remote: RemoteNote) {
        guard let id = UUID(uuidString: remote.id) else { return }
        let index = notes.firstIndex { $0.id == id }

        if remote.deletedAt != nil {
            if let index, !notes[index].isDirty {
                notes.remove(at: index)
                writeDrawing(nil, for: id)
            }
            return
        }

        let updatedAt = NotebookDates.parse(remote.updatedAt) ?? Date()
        let drawingUpdatedAt = remote.drawingUpdatedAt.flatMap(NotebookDates.parse)

        if let index {
            // Unsent local edits win until they're pushed.
            guard !notes[index].isDirty else { return }
            let drawingChanged = drawingUpdatedAt != notes[index].drawingUpdatedAt
            notes[index].course = remote.course
            notes[index].title = remote.title
            notes[index].body = remote.body
            notes[index].paper = NotebookPaper(rawValue: remote.paper) ?? .lined
            notes[index].pageHeight = remote.pageHeight
            notes[index].summary = remote.summary
            notes[index].hasDrawing = remote.hasDrawing
            notes[index].drawingUpdatedAt = drawingUpdatedAt
            notes[index].updatedAt = updatedAt
            // Another device redrew it: drop our copy, it's fetched on open.
            if drawingChanged { writeDrawing(nil, for: id) }
        } else {
            notes.append(NotebookNote(
                id: id,
                course: remote.course,
                title: remote.title,
                body: remote.body,
                paper: NotebookPaper(rawValue: remote.paper) ?? .lined,
                pageHeight: remote.pageHeight,
                summary: remote.summary,
                hasDrawing: remote.hasDrawing,
                drawingUpdatedAt: drawingUpdatedAt,
                createdAt: NotebookDates.parse(remote.createdAt) ?? updatedAt,
                updatedAt: updatedAt
            ))
        }
    }

    // MARK: Disk cache

    private struct CacheFile: Codable {
        var notes: [NotebookNote]
        var lastPulledAt: Date?
    }

    private var directory: URL? {
        guard let userID else { return nil }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let dir = base?.appendingPathComponent("Notebook/\(userID)", isDirectory: true)
        if let dir {
            try? FileManager.default.createDirectory(at: dir.appendingPathComponent("drawings"), withIntermediateDirectories: true)
        }
        return dir
    }

    private func loadCache() {
        guard let url = directory?.appendingPathComponent("notes.json"),
              let data = try? Data(contentsOf: url),
              let cache = try? JSONDecoder().decode(CacheFile.self, from: data) else {
            notes = []
            lastPulledAt = nil
            return
        }
        notes = cache.notes
        lastPulledAt = cache.lastPulledAt
        removeOrphanDrawings()
    }

    /// Drawing files whose page is gone (e.g. deleted mid-save).
    private func removeOrphanDrawings() {
        guard let dir = directory?.appendingPathComponent("drawings"),
              let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return }
        let live = Set(notes.filter { !$0.isDeleted }.map { "\($0.id.uuidString).drawing" })
        for file in files where !live.contains(file) {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(file))
        }
    }

    private func saveCache() {
        guard let url = directory?.appendingPathComponent("notes.json") else { return }
        let cache = CacheFile(notes: notes, lastPulledAt: lastPulledAt)
        if let data = try? JSONEncoder().encode(cache) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func drawingURL(_ id: UUID) -> URL? {
        directory?.appendingPathComponent("drawings/\(id.uuidString).drawing")
    }

    private func readDrawing(for id: UUID) -> Data? {
        guard let url = drawingURL(id) else { return nil }
        return try? Data(contentsOf: url)
    }

    private func writeDrawing(_ data: Data?, for id: UUID) {
        guard let url = drawingURL(id) else { return }
        if let data {
            try? data.write(to: url, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
