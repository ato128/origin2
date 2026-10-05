//
//  SmartNotificationScheduler.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 4.06.2026.
//

import Foundation
import SwiftData
import UserNotifications
import Supabase

@MainActor
final class SmartNotificationScheduler {
    static let shared = SmartNotificationScheduler()

    private init() {}

    private let smartPrefix = "smart."

    func reschedule(
        context: ModelContext,
        currentUserID: String?,
        reason: String
    ) async {
        guard let currentUserID, !currentUserID.isEmpty else {
            Log.debug("SMART NOTIFICATIONS SKIPPED: missing currentUserID")
            return
        }

        await NotificationManager.shared.requestPermissionIfNeeded()

        let tasks = fetchTasks(context: context, currentUserID: currentUserID)
        let exams = fetchExams(context: context, currentUserID: currentUserID)
        let events = fetchEvents(context: context, currentUserID: currentUserID)
        let focusRecords = fetchFocusRecords(context: context, currentUserID: currentUserID)

        let candidates = SmartNotificationBrain.makeCandidates(
            tasks: tasks,
            exams: exams,
            events: events,
            focusRecords: focusRecords
        )

        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let pendingIDs = Set(pending.map(\.identifier))

        // A pending smart notification whose condition no longer holds must
        // die here — e.g. the streak-risk nudge after the user already saved
        // today's streak. The brain regenerates every still-valid candidate
        // with the same day-keyed ID, so anything pending but absent is stale.
        let validIDs = Set(candidates.map(\.id))
        let staleIDs = pendingIDs.filter { $0.hasPrefix(smartPrefix) && !validIDs.contains($0) }
        if !staleIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(staleIDs))
            Log.debug("SMART NOTIFICATIONS CANCELLED (stale):", staleIDs.joined(separator: ", "))
        }

        guard !candidates.isEmpty else {
            Log.debug("SMART NOTIFICATIONS: no candidates - \(reason)")
            return
        }

        // Win-back slots live outside the per-day history: they're re-anchored
        // (same day-1/2/4/7/14 sequence, new IDs) on every reschedule and only
        // ever fire on days the user didn't open the app.
        let winbacks = candidates.filter { $0.category == .winback }
        for candidate in winbacks {
            try? await schedule(candidate)
        }

        // A win-back that already fired today counts toward today's cap of 2.
        let delivered = await center.deliveredNotifications()
        let winbacksToday = delivered.filter {
            $0.request.identifier.hasPrefix("smart.winback.") && Calendar.current.isDateInToday($0.date)
        }.count
        let dailyCap = max(0, 2 - winbacksToday)

        var scheduledCount = 0

        for candidate in candidates where candidate.category != .winback {
            guard scheduledCount < dailyCap else { break }
            if pendingIDs.contains(candidate.id) {
                // Still valid — re-add with the same identifier so the body
                // reflects the current numbers (streak days etc.), not the
                // ones from when it was first scheduled.
                try? await schedule(candidate)
                continue
            }

            guard SmartNotificationHistory.shared.canSchedule(
                id: candidate.id,
                category: candidate.category,
                triggerAt: candidate.triggerDate
            ) else {
                continue
            }

            do {
                try await schedule(candidate)
                SmartNotificationHistory.shared.recordScheduled(
                    id: candidate.id,
                    category: candidate.category,
                    triggerAt: candidate.triggerDate
                )
                scheduledCount += 1
            } catch {
                Log.debug("SMART NOTIFICATION SCHEDULE ERROR:", error.localizedDescription)
            }

        }

        Log.debug("SMART NOTIFICATIONS SCHEDULED:", scheduledCount, "reason:", reason)
    }

    func cancelAllSmartNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()

        let ids = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(smartPrefix) }

        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    private func schedule(_ candidate: SmartNotificationCandidate) async throws {
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: candidate.triggerDate
        )

        let relevance = min(1.0, Double(candidate.priority) / 100.0)

        let content = NotificationContentFactory.make(
            title: candidate.title,
            body: candidate.body,
            category: "SMART_NOTIFICATION",
            threadID: "smart.\(candidate.category.rawValue)",
            userInfo: [
                "type": "smart_notification",
                "smart_category": candidate.category.rawValue,
                "deep_link": candidate.deepLink,
                "ai_opener": candidate.opener ?? ""
            ],
            relevance: relevance
        )

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: candidate.id,
            content: content,
            trigger: trigger
        )

        try await center.add(request)

        Log.debug("SMART NOTIFICATION ADDED:", candidate.id, candidate.title)
    }

    // MARK: - Fetch

    private func fetchTasks(
        context: ModelContext,
        currentUserID: String
    ) -> [DTTaskItem] {
        do {
            let descriptor = FetchDescriptor<DTTaskItem>(
                sortBy: [
                    SortDescriptor(\DTTaskItem.createdAt, order: .reverse)
                ]
            )

            return try context.fetch(descriptor).filter {
                $0.ownerUserID == currentUserID
            }
        } catch {
            Log.debug("SMART TASK FETCH ERROR:", error.localizedDescription)
            return []
        }
    }

    private func fetchExams(
        context: ModelContext,
        currentUserID: String
    ) -> [ExamItem] {
        do {
            let descriptor = FetchDescriptor<ExamItem>(
                sortBy: [
                    SortDescriptor(\ExamItem.examDate, order: .forward)
                ]
            )

            return try context.fetch(descriptor).filter {
                $0.ownerUserID == currentUserID
            }
        } catch {
            Log.debug("SMART EXAM FETCH ERROR:", error.localizedDescription)
            return []
        }
    }

    private func fetchEvents(
        context: ModelContext,
        currentUserID: String
    ) -> [EventItem] {
        do {
            let descriptor = FetchDescriptor<EventItem>()
            return try context.fetch(descriptor).filter {
                $0.ownerUserID == currentUserID
            }
        } catch {
            Log.debug("SMART EVENT FETCH ERROR:", error.localizedDescription)
            return []
        }
    }

    private func fetchFocusRecords(
        context: ModelContext,
        currentUserID: String
    ) -> [FocusSessionRecord] {
        do {
            let descriptor = FetchDescriptor<FocusSessionRecord>(
                sortBy: [
                    SortDescriptor(\FocusSessionRecord.endedAt, order: .reverse)
                ]
            )

            return try context.fetch(descriptor).filter {
                $0.ownerUserID == currentUserID
            }
        } catch {
            Log.debug("SMART FOCUS RECORD FETCH ERROR:", error.localizedDescription)
            return []
        }
    }
}

// MARK: - Updo AI notification copy
//
//  Updo AI writes the words of the smart notifications (and the chat opener
//  shown when one is tapped) from a compact snapshot of the student's real
//  state. Generated at most once a day on app open; the rules in
//  `SmartNotificationBrain` still decide when/whether each one fires.

struct AINudgeCopy: Codable, Equatable {
    let title: String
    let body: String
    let opener: String
}

struct AINudgeBatch: Codable {
    let dayKey: String
    let generatedAt: Date
    let language: String
    let copies: [String: AINudgeCopy]
    /// The exam course the "exam_prep" copy was written about.
    let examPrepCourse: String?
}

@MainActor
enum AINudgeStore {
    private static let storageKey = "updo.ai_nudges.v1"
    private static let attemptKey = "updo.ai_nudges.last_attempt"

    /// Set when an Updo AI notification is tapped; the chat consumes it once.
    static var pendingOpener: String?

    static func load() -> AINudgeBatch? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(AINudgeBatch.self, from: data)
    }

    static func save(_ batch: AINudgeBatch) {
        if let data = try? JSONEncoder().encode(batch) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    static var lastAttempt: Date? {
        get { UserDefaults.standard.object(forKey: attemptKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: attemptKey) }
    }

    static func examPrepKey(for subject: String) -> String {
        "exam_prep:" + SmartNotificationBrain.fold(subject)
    }

    /// Copy for a slot, if still valid: daily slots only on the day they were
    /// written; win-back slots (time-agnostic) for 14 days; same app language.
    static func copy(for key: String, now: Date = Date()) -> AINudgeCopy? {
        guard let batch = load(),
              batch.language == (appLanguageIsEnglish() ? "en" : "tr") else { return nil }

        if key.hasPrefix("winback_") {
            guard now.timeIntervalSince(batch.generatedAt) < 14 * 24 * 3600 else { return nil }
            return batch.copies[key]
        }
        guard batch.dayKey == SmartNotificationBrain.dayKey(now) else { return nil }

        if key.hasPrefix("exam_prep:") {
            guard let course = batch.examPrepCourse,
                  examPrepKey(for: course) == key else { return nil }
            return batch.copies["exam_prep"]
        }
        return batch.copies[key]
    }
}

extension SmartNotificationScheduler {

    /// Asks Updo AI for today's notification copy (once a day, on app open),
    /// then reschedules so pending notifications pick it up. Silent on failure —
    /// the template copy keeps working.
    func refreshAINudgesIfNeeded(context: ModelContext, currentUserID: String?) async {
        guard let currentUserID, !currentUserID.isEmpty else { return }
        let prefs = SmartNotificationPreferences.current
        guard prefs.enabled, prefs.aiSuggestionEnabled else { return }

        let now = Date()
        let today = SmartNotificationBrain.dayKey(now)
        let language = appLanguageIsEnglish() ? "en" : "tr"
        if let batch = AINudgeStore.load(), batch.dayKey == today, batch.language == language { return }
        if let last = AINudgeStore.lastAttempt, now.timeIntervalSince(last) < 2 * 3600 { return }
        AINudgeStore.lastAttempt = now

        let tasks = fetchTasks(context: context, currentUserID: currentUserID)
        let exams = fetchExams(context: context, currentUserID: currentUserID)
        let events = fetchEvents(context: context, currentUserID: currentUserID)
        let focus = fetchFocusRecords(context: context, currentUserID: currentUserID)
        let courses = ((try? context.fetch(FetchDescriptor<Course>())) ?? [])
            .filter { !$0.isArchived && ($0.ownerUserID == currentUserID || $0.ownerUserID == nil) }
            .map { $0.name.isEmpty ? $0.code : $0.name }
            .filter { !$0.isEmpty }

        let (signals, examCourse) = AINudgeSignals.build(
            tasks: tasks, exams: exams, events: events, focus: focus, courses: courses, now: now
        )

        guard let copies = await AINudgeClient.fetch(signals: signals, language: language),
              !copies.isEmpty else { return }

        AINudgeStore.save(AINudgeBatch(
            dayKey: today, generatedAt: now, language: language,
            copies: copies, examPrepCourse: examCourse
        ))
        await reschedule(context: context, currentUserID: currentUserID, reason: "ai nudges ready")
    }
}

/// A compact, factual snapshot of what the student did and left empty — the
/// only thing Updo AI sees when writing notifications. Labels are English (the
/// model writes in the app language); names are the user's own.
@MainActor
enum AINudgeSignals {
    static func build(
        tasks: [DTTaskItem],
        exams: [ExamItem],
        events: [EventItem],
        focus: [FocusSessionRecord],
        courses: [String],
        now: Date
    ) -> (String, String?) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        var lines: [String] = []

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "EEEE HH:mm"
        lines.append("Now: \(df.string(from: now))")

        // Streak (same rule as the rest of the app: task AND focus per day).
        let streak = StreakProgressEngine.currentStreak(asOf: now, tasks: tasks, focusRecords: focus)
        let qualified = StreakProgressEngine.dayQualifies(today, tasks: tasks, focusRecords: focus)
        let taskDoneToday = tasks.contains { $0.isDone && ($0.completedAt.map { cal.isDate($0, inSameDayAs: now) } ?? false) }
        let counted = focus.filter { $0.countsTowardStats }
        let focusedToday = counted.contains { cal.isDate($0.endedAt, inSameDayAs: now) }
        lines.append("Streak: \(streak) days; today \(qualified ? "already saved" : "not saved yet") (task done today: \(taskDoneToday ? "yes" : "no"), focus today: \(focusedToday ? "yes" : "no"))")

        // Focus: by subject this week, usual time, recency.
        let weekAgo = cal.date(byAdding: .day, value: -7, to: now) ?? now
        var bySubject: [String: Int] = [:]
        for r in counted where r.startedAt >= weekAgo {
            let t = r.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { bySubject[t, default: 0] += r.completedSeconds / 60 }
        }
        if bySubject.isEmpty {
            lines.append("Focus last 7 days: none")
        } else {
            let top = bySubject.sorted { $0.value > $1.value }.prefix(4).map { "\($0.key) \($0.value)m" }
            lines.append("Focus last 7 days by subject: " + top.joined(separator: ", "))
        }
        if let typical = SmartNotificationBrain.typicalFocusMinute(records: focus, now: now) {
            lines.append(String(format: "Usually studies around %02d:%02d", typical / 60, typical % 60))
        }
        if let last = counted.map(\.endedAt).max() {
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: last), to: today).day ?? 0
            lines.append("Last focus session: \(days == 0 ? "today" : "\(days) days ago")")
        } else {
            lines.append("Has never completed a focus session")
        }

        // Tasks: presence (not counts — copy must not go stale), real examples.
        let pending = tasks.filter { !$0.isDone }
        let dueToday = pending.contains { $0.dueDate.map { cal.isDateInToday($0) } ?? false }
        let overdue = pending.contains { ($0.dueDate ?? .distantFuture) < today }
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today) ?? today
        let tomorrowTasks = pending.contains { $0.dueDate.map { cal.isDate($0, inSameDayAs: tomorrow) } ?? false }
        lines.append("Tasks: due today \(dueToday ? "yes" : "no"), overdue \(overdue ? "yes" : "no"), pending total \(pending.isEmpty ? "none" : "some")")
        let examples = pending.prefix(4).map(\.title).filter { !$0.isEmpty }
        if !examples.isEmpty { lines.append("Pending task examples: " + examples.joined(separator: "; ")) }

        // Week schedule (weekday 0 = Monday).
        let todayIdx = (cal.component(.weekday, from: now) + 5) % 7
        let tomorrowIdx = (todayIdx + 1) % 7
        func onDay(_ e: EventItem, _ idx: Int, _ date: Date) -> Bool {
            if let d = e.scheduledDate { return cal.isDate(d, inSameDayAs: date) }
            return e.weekday == idx
        }
        let todayLessons = events.filter { onDay($0, todayIdx, now) }.map(\.title)
        let tomorrowLessons = events.filter { onDay($0, tomorrowIdx, tomorrow) }.map(\.title)
        lines.append("Today's classes: " + (todayLessons.isEmpty ? "none" : Array(Set(todayLessons)).prefix(5).joined(separator: ", ")))
        lines.append("Plan for tomorrow: \(tomorrowTasks || !tomorrowLessons.isEmpty ? "has items" : "empty")")

        // Exams + the one the exam_prep copy should be about (same neglect rule
        // as the brain: 2–10 days out, no focus on it in the last 3 days).
        let upcoming = exams.filter { !$0.isCompleted && $0.examDate >= today }.sorted { $0.examDate < $1.examDate }
        let recentCutoff = cal.date(byAdding: .day, value: -3, to: now) ?? now
        var examCourse: String? = nil
        var examParts: [String] = []
        for exam in upcoming.prefix(4) {
            let days = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: exam.examDate)).day ?? 0
            let course = exam.courseName.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = course.isEmpty ? exam.title : course
            let studied = counted.contains { $0.startedAt >= recentCutoff && SmartNotificationBrain.fold($0.title) == SmartNotificationBrain.fold(name) }
            examParts.append("\(name) in \(days) days (studied in last 3 days: \(studied ? "yes" : "no"))")
            if examCourse == nil, (2...10).contains(days), !studied { examCourse = name }
        }
        lines.append("Upcoming exams: " + (examParts.isEmpty ? "none" : examParts.joined(separator: "; ")))
        if let examCourse { lines.append("exam_prep is about: \(examCourse)") }

        if !courses.isEmpty { lines.append("Courses: " + courses.prefix(8).joined(separator: ", ")) }

        // What they never set up — gentle feature discovery material.
        var unused: [String] = []
        if exams.isEmpty { unused.append("exams") }
        if events.isEmpty { unused.append("weekly class schedule") }
        if counted.isEmpty { unused.append("focus sessions") }
        if !unused.isEmpty { lines.append("Never set up: " + unused.joined(separator: ", ")) }

        if !AIStudyMemory.shared.notes.isEmpty {
            lines.append("Notes about the student: " + AIStudyMemory.shared.notes.prefix(5).joined(separator: "; "))
        }

        return (String(lines.joined(separator: "\n").prefix(3800)), examCourse)
    }
}

enum AINudgeClient {
    static func fetch(signals: String, language: String) async -> [String: AINudgeCopy]? {
        guard let url = URL(string: "\(ChatBackendEnvironment.httpBaseURL)/v1/ai/nudges"),
              let session = try? await SupabaseManager.shared.client.auth.session else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["signals": signals, "language": language])

        struct Response: Decodable {
            let ok: Bool
            let nudges: [String: AINudgeCopy]?
        }
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(Response.self, from: data),
              decoded.ok else { return nil }
        return decoded.nudges
    }
}
