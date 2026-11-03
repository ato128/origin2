//
//  PersonalSyncEngine.swift
//  DailyTodo
//
//  Mirrors the student's personal data — tasks, week events, exams, focus
//  history and Updo AI chats — to our backend (POST /v1/sync) so the web app
//  (updo.me) shows and edits the same data:
//
//    • Snapshot diff, no call-site changes: every round encodes each record to
//      canonical JSON and compares its hash with the last synced one. Changed
//      → pushed; a known record that's gone → tombstone (AI chats: only
//      explicit deletes, see UpdoAIChatStore).
//    • Server is last-write-wins on modifiedAt; pull returns rows after our
//      cursor. A pulled record never overwrites a local edit made since our
//      snapshot (it's pushed next round instead).
//    • Safety: an emptied / mostly-vanished local store (store recovery,
//      reinstall) is treated as a fresh device and re-pulled — never a mass
//      delete on the server.
//
//  Runs on the main actor with the container's mainContext so @Query screens
//  update directly. Triggers: sign-in, foreground, local saves (debounced) and
//  a slow poll while active.
//

import Combine
import CryptoKit
import Foundation
import Supabase
import SwiftData

@MainActor
final class PersonalSyncEngine {
    static let shared = PersonalSyncEngine()
    private init() {}

    private var container: ModelContainer?
    private var userID: String?
    private var isSyncing = false
    private var needsAnotherRound = false
    private var isApplying = false
    /// Our own apply-saves land here asynchronously; don't sync them back.
    private var suppressUntil = Date.distantPast
    private var debounceTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var observers: Set<AnyCancellable> = []

    private static let pollInterval: UInt64 = 45_000_000_000
    private static let debounceInterval: UInt64 = 3_000_000_000

    // MARK: - Lifecycle

    func configure(container: ModelContainer) {
        guard self.container == nil else { return }
        self.container = container

        NotificationCenter.default.publisher(for: ModelContext.didSave)
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let self, !self.isApplying, Date() > self.suppressUntil else { return }
                    self.scheduleSync()
                }
            }
            .store(in: &observers)

        let chat = UpdoAIChatStore.shared
        chat.$messages.map { _ in () }
            .merge(with: chat.$threads.map { _ in () })
            .dropFirst()
            .sink { [weak self] in
                Task { @MainActor in
                    guard let self, !self.isApplying, Date() > self.suppressUntil else { return }
                    self.scheduleSync()
                }
            }
            .store(in: &observers)
    }

    /// Sign-in / sign-out / account switch.
    func setUser(_ id: String?) {
        guard id != userID else { return }
        userID = id
        debounceTask?.cancel()
        if id != nil { syncSoon() } else { pollTask?.cancel() }
    }

    func appBecameActive() {
        guard userID != nil else { return }
        syncSoon()
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.pollInterval)
                guard !Task.isCancelled else { return }
                await self?.sync()
            }
        }
    }

    func appEnteredBackground() {
        pollTask?.cancel()
        debounceTask?.cancel()
        guard userID != nil else { return }
        Task { await sync() }   // push what was just written
    }

    private func scheduleSync() {
        guard userID != nil else { return }
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.debounceInterval)
            guard !Task.isCancelled else { return }
            await self?.sync()
        }
    }

    private func syncSoon() {
        debounceTask?.cancel()
        Task { await sync() }
    }

    // MARK: - One round

    func sync() async {
        guard let container, let uid = userID else { return }
        if isSyncing { needsAnotherRound = true; return }
        isSyncing = true
        defer { isSyncing = false }

        repeat {
            needsAnotherRound = false
            do {
                try await runRound(container: container, uid: uid)
            } catch {
                Log.debug("⚠️ personal sync failed:", error.localizedDescription)
                return
            }
        } while needsAnotherRound && userID == uid
    }

    private func runRound(container: ModelContainer, uid: String) async throws {
        let context = container.mainContext
        let chat = UpdoAIChatStore.shared
        var state = SyncState.load(uid: uid)

        if !chat.claimForSync(userID: uid) {
            state.known = state.known.filter { !SyncKind.isAI($0.key) }
        }

        // 1. Snapshot + diff.
        var local = snapshot(context: context, uid: uid)
        let vanished = state.known.keys.filter { !SyncKind.isAI($0) && local[$0] == nil }
        let knownStore = state.known.keys.filter { !SyncKind.isAI($0) }.count
        if knownStore > 0, vanished.count >= 20, Double(vanished.count) > Double(knownStore) * 0.5 {
            // Store was reset/restored: re-pull everything instead of deleting it everywhere.
            Log.debug("⚠️ personal sync: \(vanished.count)/\(knownStore) local records vanished — full re-pull")
            state = SyncState(cursor: 0, known: [:])
        }

        var changes: [SyncChange] = []
        let now = SyncCodec.string(Date())
        for (key, entry) in local where state.known[key] != entry.hash {
            changes.append(SyncChange(key: key, data: entry.payload, modifiedAt: now, deleted: false))
        }
        for key in state.known.keys where !SyncKind.isAI(key) && local[key] == nil {
            changes.append(SyncChange(key: key, data: [:], modifiedAt: now, deleted: true))
        }
        let aiDeletes = chat.pendingSyncDeletes
        for key in aiDeletes {
            changes.append(SyncChange(key: key, data: [:], modifiedAt: now, deleted: true))
        }

        // 2. Push (in chunks) + pull pages.
        var pushQueue = changes
        var pulled: [SyncRecord] = []
        var cursor = state.cursor
        var hasMore = true
        while !pushQueue.isEmpty || hasMore {
            let batch = Array(pushQueue.prefix(400))
            pushQueue.removeFirst(batch.count)
            let response = try await SyncAPI.post(cursor: cursor, changes: batch)
            guard userID == uid else { return }   // signed out / switched mid-round
            for change in batch {
                if change.deleted { state.known[change.key] = nil } else { state.known[change.key] = local[change.key]?.hash }
            }
            pulled.append(contentsOf: response.records)
            cursor = response.cursor
            hasMore = response.hasMore
        }
        chat.clearPendingSyncDeletes(aiDeletes)

        // 3. Apply what other devices wrote.
        if !pulled.isEmpty {
            local = snapshot(context: context, uid: uid)   // fresh: catches edits made during the request
            apply(pulled, context: context, uid: uid, local: local, state: &state)
        }

        state.cursor = cursor
        state.save(uid: uid)
    }

    // MARK: - Snapshot

    private struct Entry {
        let payload: [String: Any]
        let hash: String
    }

    private func snapshot(context: ModelContext, uid: String) -> [String: Entry] {
        var out: [String: Entry] = [:]
        func add(_ kind: SyncKind, _ id: String, _ payload: [String: Any]) {
            out[kind.key(id)] = Entry(payload: payload, hash: SyncCodec.hash(payload))
        }
        let mine: (String?) -> Bool = { $0 == nil || $0 == uid }

        for t in (try? context.fetch(FetchDescriptor<DTTaskItem>())) ?? [] where mine(t.ownerUserID) {
            add(.task, t.taskUUID, SyncCodec.payload(t))
        }
        for e in (try? context.fetch(FetchDescriptor<EventItem>())) ?? [] where mine(e.ownerUserID) {
            add(.event, e.id.uuidString, SyncCodec.payload(e))
        }
        for x in (try? context.fetch(FetchDescriptor<ExamItem>())) ?? [] where mine(x.ownerUserID) {
            add(.exam, x.id.uuidString, SyncCodec.payload(x))
        }
        for f in (try? context.fetch(FetchDescriptor<FocusSessionRecord>())) ?? [] where mine(f.ownerUserID) {
            add(.focus, f.id.uuidString, SyncCodec.payload(f))
        }
        let chat = UpdoAIChatStore.shared
        for th in chat.syncableThreads { add(.aiThread, th.id.uuidString, SyncCodec.payload(th)) }
        for m in chat.syncableMessages { add(.aiMessage, m.id.uuidString, SyncCodec.payload(m)) }
        return out
    }

    // MARK: - Apply

    private func apply(_ records: [SyncRecord], context: ModelContext, uid: String,
                       local: [String: Entry], state: inout SyncState) {
        // Last write per key wins within the page set.
        var latest: [String: SyncRecord] = [:]
        for r in records { latest[r.key] = r }

        var toApply: [SyncRecord] = []
        for (key, r) in latest {
            if let entry = local[key], state.known[key] != entry.hash { continue }   // edited here since the snapshot
            if r.deleted {
                if local[key] == nil { state.known[key] = nil; continue }
            } else if let entry = local[key], SyncCodec.hash(r.data) == entry.hash {
                state.known[key] = entry.hash
                continue
            }
            toApply.append(r)
        }
        guard !toApply.isEmpty else { return }

        isApplying = true
        defer {
            isApplying = false
            suppressUntil = Date().addingTimeInterval(1.5)
        }

        let grouped = Dictionary(grouping: toApply, by: \.kind)
        if let rs = grouped[.task] { applyTasks(rs, context: context, uid: uid) }
        if let rs = grouped[.event] { applyEvents(rs, context: context, uid: uid) }
        if let rs = grouped[.exam] { applyExams(rs, context: context, uid: uid) }
        if let rs = grouped[.focus] { applyFocus(rs, context: context, uid: uid) }
        try? context.save()

        let threadRecords = grouped[.aiThread] ?? []
        let messageRecords = grouped[.aiMessage] ?? []
        if !threadRecords.isEmpty || !messageRecords.isEmpty {
            UpdoAIChatStore.shared.applyRemoteSync(
                threads: threadRecords.filter { !$0.deleted }.compactMap { SyncCodec.thread($0.id, $0.data) },
                deletedThreads: Set(threadRecords.filter(\.deleted).compactMap { UUID(uuidString: $0.id) }),
                messages: messageRecords.filter { !$0.deleted }.compactMap { SyncCodec.message($0.id, $0.data) },
                deletedMessages: Set(messageRecords.filter(\.deleted).compactMap { UUID(uuidString: $0.id) })
            )
        }

        // Remember what we now hold, in our own canonical form (no echo push).
        let after = snapshot(context: context, uid: uid)
        for r in toApply { state.known[r.key] = after[r.key]?.hash }
    }

    private func applyTasks(_ records: [SyncRecord], context: ModelContext, uid: String) {
        let all = (try? context.fetch(FetchDescriptor<DTTaskItem>())) ?? []
        var byID = Dictionary(all.map { ($0.taskUUID, $0) }, uniquingKeysWith: { a, _ in a })
        for r in records {
            if r.deleted { if let t = byID[r.id] { context.delete(t) }; continue }
            let t = byID[r.id] ?? {
                let n = DTTaskItem(taskUUID: r.id, ownerUserID: uid, title: "")
                context.insert(n); byID[r.id] = n; return n
            }()
            SyncCodec.update(t, from: r.data)
        }
    }

    private func applyEvents(_ records: [SyncRecord], context: ModelContext, uid: String) {
        let all = (try? context.fetch(FetchDescriptor<EventItem>())) ?? []
        var byID = Dictionary(all.map { ($0.id.uuidString, $0) }, uniquingKeysWith: { a, _ in a })
        for r in records {
            let key = UUID(uuidString: r.id)?.uuidString ?? r.id
            if r.deleted { if let e = byID[key] { context.delete(e) }; continue }
            guard let uuid = UUID(uuidString: r.id) else { continue }
            let e = byID[key] ?? {
                let n = EventItem(ownerUserID: uid, title: "", weekday: 0, startMinute: 0, durationMinute: 60)
                n.id = uuid
                context.insert(n); byID[key] = n; return n
            }()
            SyncCodec.update(e, from: r.data)
        }
    }

    private func applyExams(_ records: [SyncRecord], context: ModelContext, uid: String) {
        let all = (try? context.fetch(FetchDescriptor<ExamItem>())) ?? []
        var byID = Dictionary(all.map { ($0.id.uuidString, $0) }, uniquingKeysWith: { a, _ in a })
        for r in records {
            let key = UUID(uuidString: r.id)?.uuidString ?? r.id
            if r.deleted { if let x = byID[key] { context.delete(x) }; continue }
            guard let uuid = UUID(uuidString: r.id) else { continue }
            let x = byID[key] ?? {
                let n = ExamItem(id: uuid, title: "", courseName: "", examDate: Date(), ownerUserID: uid)
                context.insert(n); byID[key] = n; return n
            }()
            SyncCodec.update(x, from: r.data)
        }
    }

    private func applyFocus(_ records: [SyncRecord], context: ModelContext, uid: String) {
        let all = (try? context.fetch(FetchDescriptor<FocusSessionRecord>())) ?? []
        var byID = Dictionary(all.map { ($0.id.uuidString, $0) }, uniquingKeysWith: { a, _ in a })
        for r in records {
            let key = UUID(uuidString: r.id)?.uuidString ?? r.id
            if r.deleted { if let f = byID[key] { context.delete(f) }; continue }
            guard let uuid = UUID(uuidString: r.id) else { continue }
            let f = byID[key] ?? {
                let n = FocusSessionRecord(id: uuid, ownerUserID: uid, title: "", startedAt: Date(), endedAt: Date(),
                                           totalSeconds: 0, completedSeconds: 0, isCompleted: false)
                context.insert(n); byID[key] = n; return n
            }()
            SyncCodec.update(f, from: r.data)
        }
    }
}

// MARK: - Kinds, state, wire types

enum SyncKind: String {
    case task, event, exam, focus
    case aiThread = "ai_thread"
    case aiMessage = "ai_message"

    func key(_ id: String) -> String { "\(rawValue):\(id)" }

    static func isAI(_ key: String) -> Bool { key.hasPrefix("ai_") }
}

private struct SyncState: Codable {
    var cursor: Int
    /// "kind:id" → hash of the payload last pushed/pulled.
    var known: [String: String]

    private static func url(uid: String) -> URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return dir.appendingPathComponent("personal-sync-\(uid).json")
    }

    static func load(uid: String) -> SyncState {
        guard let url = url(uid: uid), let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(SyncState.self, from: data) else {
            return SyncState(cursor: 0, known: [:])
        }
        return state
    }

    func save(uid: String) {
        guard let url = Self.url(uid: uid), let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

private struct SyncChange {
    let key: String
    let data: [String: Any]
    let modifiedAt: String
    let deleted: Bool

    var json: [String: Any] {
        let parts = key.split(separator: ":", maxSplits: 1).map(String.init)
        return ["kind": parts[0], "id": parts.count > 1 ? parts[1] : "", "data": data,
                "modifiedAt": modifiedAt, "deleted": deleted]
    }
}

private struct SyncRecord {
    let kind: SyncKind
    let id: String
    let data: [String: Any]
    let deleted: Bool

    var key: String { kind.key(id) }
}

private enum SyncAPI {
    struct Response {
        let records: [SyncRecord]
        let cursor: Int
        let hasMore: Bool
    }

    static func post(cursor: Int, changes: [SyncChange]) async throws -> Response {
        #if DEBUG
        // Local test server: launch with `-personalSyncBaseURL http://127.0.0.1:4555`.
        let base = UserDefaults.standard.string(forKey: "personalSyncBaseURL") ?? ChatBackendEnvironment.httpBaseURL
        #else
        let base = ChatBackendEnvironment.httpBaseURL
        #endif
        guard let url = URL(string: "\(base)/v1/sync") else { throw URLError(.badURL) }
        let token = try await SupabaseManager.shared.client.auth.session.accessToken
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "cursor": cursor,
            "changes": changes.map(\.json),
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status),
              let body = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Log.debug("❌ sync backend →", status, String(data: data, encoding: .utf8) ?? "")
            throw URLError(.badServerResponse)
        }

        let records = (body["records"] as? [[String: Any]] ?? []).compactMap { raw -> SyncRecord? in
            guard let kind = (raw["kind"] as? String).flatMap(SyncKind.init(rawValue:)),
                  let id = raw["id"] as? String else { return nil }
            return SyncRecord(kind: kind, id: id, data: raw["data"] as? [String: Any] ?? [:],
                              deleted: raw["deleted"] as? Bool ?? false)
        }
        return Response(records: records,
                        cursor: (body["cursor"] as? NSNumber)?.intValue ?? cursor,
                        hasMore: body["hasMore"] as? Bool ?? false)
    }
}

// MARK: - Codec (model ↔ JSON payload shared with the web app)

private enum SyncCodec {
    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plainFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func string(_ date: Date) -> String { formatter.string(from: date) }

    static func date(_ value: Any?) -> Date? {
        guard let s = value as? String else { return nil }
        return formatter.date(from: s) ?? plainFormatter.date(from: s)
    }

    static func hash(_ payload: [String: Any]) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func put(_ d: inout [String: Any], _ key: String, _ value: Any?) {
        switch value {
        case let date as Date: d[key] = string(date)
        case let uuid as UUID: d[key] = uuid.uuidString
        case .some(let v): d[key] = v
        case .none: break
        }
    }

    private static func int(_ v: Any?) -> Int? { (v as? NSNumber)?.intValue }
    private static func bool(_ v: Any?) -> Bool? { (v as? NSNumber)?.boolValue }
    private static func str(_ v: Any?) -> String? { v as? String }
    private static func uuid(_ v: Any?) -> UUID? { (v as? String).flatMap(UUID.init(uuidString:)) }

    // Task
    static func payload(_ t: DTTaskItem) -> [String: Any] {
        var d: [String: Any] = [
            "title": t.title, "isDone": t.isDone, "createdAt": string(t.createdAt), "notes": t.notes,
            "taskType": t.taskType, "colorName": t.colorName, "courseName": t.courseName, "studyTopic": t.studyTopic,
        ]
        put(&d, "dueDate", t.dueDate)
        put(&d, "completedAt", t.completedAt)
        put(&d, "workoutDay", t.workoutDay)
        put(&d, "workoutDurationMinutes", t.workoutDurationMinutes)
        put(&d, "scheduledWeekDate", t.scheduledWeekDate)
        put(&d, "scheduledWeekDurationMinutes", t.scheduledWeekDurationMinutes)
        put(&d, "linkedExamID", t.linkedExamID)
        return d
    }

    static func update(_ t: DTTaskItem, from d: [String: Any]) {
        t.title = str(d["title"]) ?? t.title
        t.isDone = bool(d["isDone"]) ?? false
        t.createdAt = date(d["createdAt"]) ?? t.createdAt
        t.notes = str(d["notes"]) ?? ""
        t.taskType = str(d["taskType"]) ?? "standard"
        t.colorName = str(d["colorName"]) ?? "blue"
        t.courseName = str(d["courseName"]) ?? ""
        t.studyTopic = str(d["studyTopic"]) ?? ""
        t.dueDate = date(d["dueDate"])
        t.completedAt = date(d["completedAt"])
        t.workoutDay = str(d["workoutDay"])
        t.workoutDurationMinutes = int(d["workoutDurationMinutes"])
        t.scheduledWeekDate = date(d["scheduledWeekDate"])
        t.scheduledWeekDurationMinutes = int(d["scheduledWeekDurationMinutes"])
        t.linkedExamID = uuid(d["linkedExamID"])
    }

    // Week event
    static func payload(_ e: EventItem) -> [String: Any] {
        var d: [String: Any] = [
            "title": e.title, "weekday": e.weekday, "startMinute": e.startMinute, "durationMinute": e.durationMinute,
            "colorHex": e.colorHex, "createdAt": string(e.createdAt), "isCompleted": e.isCompleted,
        ]
        put(&d, "scheduledDate", e.scheduledDate)
        put(&d, "location", e.location)
        put(&d, "notes", e.notes)
        put(&d, "sourceTaskUUID", e.sourceTaskUUID)
        return d
    }

    static func update(_ e: EventItem, from d: [String: Any]) {
        e.title = str(d["title"]) ?? e.title
        e.weekday = min(max(int(d["weekday"]) ?? e.weekday, 0), 6)
        e.startMinute = min(max(int(d["startMinute"]) ?? e.startMinute, 0), 1439)
        e.durationMinute = max(int(d["durationMinute"]) ?? e.durationMinute, 5)
        e.colorHex = str(d["colorHex"]) ?? e.colorHex
        e.createdAt = date(d["createdAt"]) ?? e.createdAt
        e.isCompleted = bool(d["isCompleted"]) ?? false
        e.scheduledDate = date(d["scheduledDate"])
        e.location = str(d["location"])
        e.notes = str(d["notes"])
        e.sourceTaskUUID = str(d["sourceTaskUUID"])
    }

    // Exam
    static func payload(_ x: ExamItem) -> [String: Any] {
        [
            "title": x.title, "courseName": x.courseName, "examType": x.examType, "examDate": string(x.examDate),
            "notes": x.notes, "colorHex": x.colorHex, "preferredStudyMinutes": x.preferredStudyMinutes,
            "isCompleted": x.isCompleted, "createdAt": string(x.createdAt),
            "targetStudyTaskCount": x.targetStudyTaskCount, "targetStudyMinutes": x.targetStudyMinutes,
        ]
    }

    static func update(_ x: ExamItem, from d: [String: Any]) {
        x.title = str(d["title"]) ?? x.title
        x.courseName = str(d["courseName"]) ?? x.courseName
        x.examType = str(d["examType"]) ?? x.examType
        x.examDate = date(d["examDate"]) ?? x.examDate
        x.notes = str(d["notes"]) ?? ""
        x.colorHex = str(d["colorHex"]) ?? x.colorHex
        x.preferredStudyMinutes = int(d["preferredStudyMinutes"]) ?? x.preferredStudyMinutes
        x.isCompleted = bool(d["isCompleted"]) ?? false
        x.createdAt = date(d["createdAt"]) ?? x.createdAt
        x.targetStudyTaskCount = int(d["targetStudyTaskCount"]) ?? x.targetStudyTaskCount
        x.targetStudyMinutes = int(d["targetStudyMinutes"]) ?? x.targetStudyMinutes
    }

    // Focus record
    static func payload(_ f: FocusSessionRecord) -> [String: Any] {
        var d: [String: Any] = [
            "title": f.title, "startedAt": string(f.startedAt), "endedAt": string(f.endedAt),
            "totalSeconds": f.totalSeconds, "completedSeconds": f.completedSeconds, "isCompleted": f.isCompleted,
        ]
        put(&d, "courseName", f.courseName)
        return d
    }

    static func update(_ f: FocusSessionRecord, from d: [String: Any]) {
        f.title = str(d["title"]) ?? f.title
        f.startedAt = date(d["startedAt"]) ?? f.startedAt
        f.endedAt = date(d["endedAt"]) ?? f.endedAt
        f.totalSeconds = max(int(d["totalSeconds"]) ?? f.totalSeconds, 0)
        f.completedSeconds = max(int(d["completedSeconds"]) ?? f.completedSeconds, 0)
        f.isCompleted = bool(d["isCompleted"]) ?? false
        f.courseName = str(d["courseName"])
    }

    // Updo AI chats
    static func payload(_ th: AIChatThread) -> [String: Any] {
        ["title": th.title, "updatedAt": string(th.updatedAt)]
    }

    static func thread(_ id: String, _ d: [String: Any]) -> AIChatThread? {
        guard let tid = UUID(uuidString: id), let title = str(d["title"]) else { return nil }
        return AIChatThread(id: tid, title: title, updatedAt: date(d["updatedAt"]) ?? Date())
    }

    static func payload(_ m: AIMessage) -> [String: Any] {
        var d: [String: Any] = ["role": m.role, "text": m.text, "timestamp": string(m.timestamp)]
        put(&d, "threadID", m.threadID)
        put(&d, "actionTitle", m.actionTitle)
        put(&d, "actionPayload", m.actionPayload)
        return d
    }

    static func message(_ id: String, _ d: [String: Any]) -> AIMessage? {
        guard let mid = UUID(uuidString: id), let role = str(d["role"]), let text = str(d["text"]) else { return nil }
        return AIMessage(id: mid, role: role, text: text, timestamp: date(d["timestamp"]) ?? Date(),
                         actionTitle: str(d["actionTitle"]), actionPayload: str(d["actionPayload"]),
                         threadID: uuid(d["threadID"]))
    }
}
