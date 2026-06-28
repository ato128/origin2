//
//  UpdoAICommandInterpreter.swift
//  DailyTodo
//
//  Token-free local NLU: recognises "add / remove / complete" intents for tasks,
//  plus "add" for calendar events (ders/etkinlik) and exams (sınav), in Turkish
//  or English, and executes them directly — so the most common Updo AI requests
//  never reach the LLM (zero tokens, zero credits). Anything it can't *confidently*
//  parse returns nil → normal Haiku chat.
//
//  Design principle: be conservative. An event is only created when BOTH a day and
//  a clock time are unambiguously present; an exam only when a real date is present.
//  When in doubt we fall back to a plain task (or to the LLM), never to a garbage
//  calendar entry.
//

import Foundation
import SwiftData

@MainActor
enum UpdoAICommandInterpreter {

    /// The outcome of a recognised command: a confirmation line to show in chat
    /// plus the mutation to run. No network, no credits.
    struct Result {
        let reply: String
        let apply: () -> Void
    }

    // MARK: - Vocabularies (diacritic-folded, lowercased)

    private static let addVerbs    = ["ekle", "olustur", "yaz", "koy", "ayarla", "kur", "add", "create", "new", "schedule", "set"]
    private static let deleteVerbs = ["sil", "kaldir", "cikar", "cikart", "delete", "remove", "drop"]
    private static let doneVerbs   = ["tamamla", "bitir", "yaptim", "tamamladim", "bitirdim",
                                      "complete", "done", "finish", "isaretle", "check"]

    private static let examWords  = ["sinav", "vize", "vizem", "final", "finalim", "quiz", "exam", "midterm", "butunleme"]
    private static let eventWords = ["ders", "dersi", "dersim", "etkinlik", "class", "lecture",
                                     "toplanti", "meeting", "randevu", "seans", "appointment", "event"]

    private static let durationUnits: Set<String> = ["saat", "saatlik", "hour", "hours", "hr",
                                                      "dk", "dakika", "dakikalik", "min", "mins", "minute", "minutes"]

    private static let fillers: Set<String> = [
        "gorev", "gorevi", "gorevini", "gorevler", "gorevleri", "task", "tasks",
        "bir", "bana", "benim", "liste", "listeme", "listemden", "listeden", "listene",
        "to", "my", "the", "a", "an", "lutfen", "please", "updo", "ai",
        "sunu", "su", "bunu", "bu", "olarak", "diye", "adli", "adinda", "isimli",
        "icin", "for", "off", "as", "at", "on", "var", "ekleyebilir", "misin", "misiniz"
    ]

    private static let questionWords = ["nasil", "neden", "nicin", "kim", "nerede",
                                        "how", "why", "what", "which", "where", "who", "when"]

    // weekday name (folded) → model index (0=Mon … 6=Sun)
    private static let weekdayNames: [String: Int] = [
        "pazartesi": 0, "pzt": 0, "monday": 0, "mon": 0,
        "sali": 1, "sal": 1, "tuesday": 1, "tue": 1,
        "carsamba": 2, "car": 2, "wednesday": 2, "wed": 2,
        "persembe": 3, "per": 3, "thursday": 3, "thu": 3,
        "cuma": 4, "cum": 4, "friday": 4, "fri": 4,
        "cumartesi": 5, "cmt": 5, "saturday": 5, "sat": 5,
        "pazar": 6, "paz": 6, "sunday": 6, "sun": 6
    ]

    private static let monthNames: [String: Int] = [
        "ocak": 1, "subat": 2, "mart": 3, "nisan": 4, "mayis": 5, "haziran": 6,
        "temmuz": 7, "agustos": 8, "eylul": 9, "ekim": 10, "kasim": 11, "aralik": 12,
        "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
        "july": 7, "august": 8, "september": 9, "october": 10, "november": 11, "december": 12,
        "jan": 1, "feb": 2, "mar": 3, "apr": 4, "jun": 6, "jul": 7, "aug": 8,
        "sep": 9, "sept": 9, "oct": 10, "nov": 11, "dec": 12
    ]

    // MARK: - Parsed pieces

    private struct DayParse {
        let weekday: Int       // model index 0=Mon … 6=Sun
        let date: Date?        // concrete date for one-offs (bugün/yarın); nil = recurring weekly
        let label: String      // user-facing ("bugün", "yarın", "Salı"…)
    }

    // MARK: - Entry point

    static func interpret(
        _ raw: String,
        store: TodoStore,
        context: ModelContext,
        ownerUserID: String?
    ) -> Result? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let foldedFull = fold(text)

        // Questions and long conversational sentences are never commands.
        if text.hasSuffix("?") { return nil }
        let foldedTokens = foldedFull.split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init)
        if foldedTokens.count > 12 { return nil }
        if let first = foldedTokens.first, questionWords.contains(first) { return nil }
        guard !foldedTokens.isEmpty else { return nil }

        let originalWords = text.split(whereSeparator: { $0 == " " || $0 == "," }).map(String.init)

        // Delete / complete reference something that already exists → highest priority.
        if hasVerb(foldedTokens, deleteVerbs) {
            return makeRemove(tokens: foldedTokens, store: store, context: context, ownerUserID: ownerUserID)
        }
        if hasVerb(foldedTokens, doneVerbs) {
            return makeComplete(tokens: foldedTokens, store: store)
        }
        if hasVerb(foldedTokens, addVerbs) {
            return makeAdd(tokens: foldedTokens, originalWords: originalWords,
                           store: store, context: context, ownerUserID: ownerUserID)
        }
        return nil
    }

    // MARK: - Add (routes to exam / event / task)

    private static func makeAdd(
        tokens: [String],
        originalWords: [String],
        store: TodoStore,
        context: ModelContext,
        ownerUserID: String?
    ) -> Result? {
        var day: DayParse? = nil
        var minute: Int? = nil
        var duration: Int? = nil
        var examDate: Date? = nil
        var sawExamWord = false
        var sawEventWord = false
        var titleWords: [String] = []

        var i = 0
        while i < tokens.count {
            let tok = tokens[i]

            if addVerbs.contains(where: { tok.hasPrefix($0) }) { i += 1; continue }
            if fillers.contains(tok) { i += 1; continue }

            if examWords.contains(tok) { sawExamWord = true; i += 1; continue }
            if eventWords.contains(tok) { sawEventWord = true; i += 1; continue }

            // Day words
            if let d = dayParse(tok) {
                day = d
                if examDate == nil, let dt = d.date { examDate = dt }
                i += 1; continue
            }

            // "saat 15" → 15:00
            if tok == "saat", i + 1 < tokens.count, let h = bareHour(tokens[i + 1]) {
                minute = h * 60; i += 2; continue
            }
            // Clock times: 15:00 / 15.30 / 3pm / 15te
            if let m = clockTime(tok) { minute = m; i += 1; continue }

            // Duration: "<n> saat/dk"
            if let n = pureInt(tok), i + 1 < tokens.count, durationUnits.contains(tokens[i + 1]) {
                duration = isHourUnit(tokens[i + 1]) ? n * 60 : n
                i += 2; continue
            }
            if durationUnits.contains(tok) { i += 1; continue }

            // Numeric day-of-month followed/preceded by a month name → exam date
            if let n = pureInt(tok), n >= 1, n <= 31,
               i + 1 < tokens.count, let mo = monthNames[tokens[i + 1]] {
                examDate = dateFrom(day: n, month: mo)
                i += 2; continue
            }
            // "DD.MM" / "DD/MM"
            if let dm = numericDate(tok) { examDate = dm; i += 1; continue }

            // Leftover → part of the title (keep original casing where possible)
            titleWords.append(i < originalWords.count ? originalWords[i] : tok)
            i += 1
        }

        let title = titleWords.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

        // 1 — Exam: an exam word + a concrete date.
        if sawExamWord, let date = examDate {
            return makeAddExam(title: title, date: date, store: store, context: context, ownerUserID: ownerUserID)
        }

        // 2 — Event: a clock time AND (a day OR an event word). Day defaults to today
        //     only when an explicit event word is present.
        if let minute, (day != nil || sawEventWord) {
            let resolvedDay = day ?? todayDayParse()
            return makeAddEvent(
                title: title.isEmpty ? defaultEventTitle(sawEventWord: sawEventWord) : title,
                day: resolvedDay, startMinute: minute, duration: duration ?? 60,
                context: context, ownerUserID: ownerUserID
            )
        }

        // 3 — Plain task (optionally due bugün/yarın).
        guard title.count >= 2 else { return nil }
        let displayTitle = capitalizeFirst(title)
        let due = day?.date
        let dueLabel = (due != nil) ? day?.label : nil
        return Result(
            reply: dueLabel.map { tr("ai_cmd_added_due", displayTitle, $0) } ?? tr("ai_cmd_added", displayTitle),
            apply: { store.add(title: displayTitle, dueDate: due) }
        )
    }

    // MARK: - Event

    private static func makeAddEvent(
        title: String,
        day: DayParse,
        startMinute: Int,
        duration: Int,
        context: ModelContext,
        ownerUserID: String?
    ) -> Result {
        let displayTitle = capitalizeFirst(title)
        let whenText = "\(day.label) \(clockString(startMinute))"

        return Result(
            reply: tr("ai_cmd_event_added", displayTitle, whenText),
            apply: {
                let ev = EventItem(
                    ownerUserID: ownerUserID,
                    title: displayTitle,
                    weekday: day.weekday,
                    startMinute: startMinute,
                    durationMinute: max(15, duration),
                    scheduledDate: day.date,
                    colorHex: "#3B82F6"
                )
                context.insert(ev)
                try? context.save()
                WidgetAppSync.refreshFromSwiftData(context: context)
                Task {
                    await NotificationManager.shared.schedule(for: ev, minutesBefore: 10)
                    await NotificationManager.shared.schedule(for: ev, minutesBefore: 0)
                }
            }
        )
    }

    // MARK: - Exam

    private static func makeAddExam(
        title: String,
        date: Date,
        store: TodoStore,
        context: ModelContext,
        ownerUserID: String?
    ) -> Result {
        let name = capitalizeFirst(title.isEmpty ? tr("ai_cmd_exam_default") : title)
        let dateText = examDateText(date)

        return Result(
            reply: tr("ai_cmd_exam_added", name, dateText),
            apply: {
                let exam = ExamItem(
                    title: name,
                    courseName: name,
                    examDate: date,
                    ownerUserID: ownerUserID
                )
                context.insert(exam)
                // Companion study task, linked by exam id so deletion can cascade.
                store.addExamStudyTask(exam: exam, title: name, dueDate: date)
                try? context.save()
                WidgetAppSync.refreshFromSwiftData(context: context)
            }
        )
    }

    // MARK: - Remove (tasks AND calendar events)

    private static func makeRemove(
        tokens: [String],
        store: TodoStore,
        context: ModelContext,
        ownerUserID: String?
    ) -> Result? {
        let query = targetQuery(tokens: tokens, verbs: deleteVerbs)
        guard !query.isEmpty else { return nil }

        let sawExam = tokens.contains { examWords.contains($0) }
        let sawEvent = tokens.contains { eventWords.contains($0) }

        let taskHit = bestMatch(query, in: store.items, title: { $0.title })
        let events = ownedEvents(context: context, ownerUserID: ownerUserID)
        let eventHit = bestMatch(query, in: events, title: { $0.title })
        let exams = ownedExams(context: context, ownerUserID: ownerUserID)
        let examHit = bestMatch(query, in: exams, title: { $0.title.isEmpty ? $0.courseName : $0.title })

        // An explicit "sınav/vize" or "ders/etkinlik" word forces that kind.
        if sawExam, let ex = examHit?.item { return removeExamResult(ex, store: store, context: context) }
        if sawEvent, let ev = eventHit?.item { return removeEventResult(ev, context: context) }

        // Otherwise pick the highest-confidence match across all three kinds.
        let candidates: [(score: Int, make: () -> Result)] = [
            taskHit.map  { hit in (hit.score, { Result(reply: tr("ai_cmd_deleted", hit.item.title), apply: { store.delete(hit.item) }) }) },
            eventHit.map { hit in (hit.score, { removeEventResult(hit.item, context: context) }) },
            examHit.map  { hit in (hit.score, { removeExamResult(hit.item, store: store, context: context) }) }
        ].compactMap { $0 }

        if let best = candidates.max(by: { $0.score < $1.score }) {
            return best.make()
        }
        return Result(reply: tr("ai_cmd_not_found", query), apply: {})
    }

    private static func removeEventResult(_ ev: EventItem, context: ModelContext) -> Result {
        Result(reply: tr("ai_cmd_event_deleted", ev.title), apply: {
            Task { await NotificationManager.shared.cancel(for: ev) }
            context.delete(ev)
            try? context.save()
            WidgetAppSync.refreshFromSwiftData(context: context)
        })
    }

    private static func removeExamResult(_ ex: ExamItem, store: TodoStore, context: ModelContext) -> Result {
        let name = ex.title.isEmpty ? ex.courseName : ex.title
        let examID = ex.id
        return Result(reply: tr("ai_cmd_exam_deleted", name), apply: {
            // Cascade: delete the companion study tasks linked to this exam.
            for task in store.items where task.linkedExamID == examID {
                store.delete(task)
            }
            context.delete(ex)
            try? context.save()
            WidgetAppSync.refreshFromSwiftData(context: context)
        })
    }

    private static func ownedExams(context: ModelContext, ownerUserID: String?) -> [ExamItem] {
        let all = (try? context.fetch(FetchDescriptor<ExamItem>())) ?? []
        guard let uid = ownerUserID else { return all }
        let owned = all.filter { $0.ownerUserID == uid }
        return owned.isEmpty ? all.filter { $0.ownerUserID == nil } : owned
    }

    // MARK: - Complete (tasks)

    private static func makeComplete(tokens: [String], store: TodoStore) -> Result? {
        let query = targetQuery(tokens: tokens, verbs: doneVerbs)
        guard !query.isEmpty else { return nil }

        let pending = store.items.filter { !$0.isDone }
        let pool = pending.isEmpty ? store.items : pending
        guard let match = bestMatch(query, in: pool, title: { $0.title })?.item else {
            return Result(reply: tr("ai_cmd_not_found", query), apply: {})
        }
        return Result(reply: tr("ai_cmd_completed", match.title), apply: {
            if !match.isDone { store.toggleDone(match) }
        })
    }

    private static func targetQuery(tokens: [String], verbs: [String]) -> String {
        tokens.filter { tok in
            !verbs.contains(where: { tok.hasPrefix($0) })
                && !fillers.contains(tok)
                && !eventWords.contains(tok)
                && !examWords.contains(tok)
        }
        .joined(separator: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func ownedEvents(context: ModelContext, ownerUserID: String?) -> [EventItem] {
        let all = (try? context.fetch(FetchDescriptor<EventItem>())) ?? []
        guard let uid = ownerUserID else { return all }
        let owned = all.filter { $0.ownerUserID == uid }
        return owned.isEmpty ? all.filter { $0.ownerUserID == nil } : owned
    }

    /// Generic fuzzy matcher over any item's title. Returns the best item with its
    /// confidence score (≥25), or nil.
    private static func bestMatch<T>(_ query: String, in items: [T], title: (T) -> String) -> (item: T, score: Int)? {
        let q = fold(query)
        guard !q.isEmpty else { return nil }
        let qTokens = Set(q.split(separator: " ").map(String.init))

        var best: (item: T, score: Int)? = nil
        for item in items {
            let t = fold(title(item))
            var score = 0
            if t == q {
                score = 100
            } else if t.contains(q) || q.contains(t) {
                score = 60 + min(q.count, t.count)
            } else {
                let overlap = qTokens.intersection(Set(t.split(separator: " ").map(String.init))).count
                score = overlap * 25
            }
            if score > 0, best == nil || score > best!.score {
                best = (item, score)
            }
        }
        if let b = best, b.score >= 25 { return b }
        return nil
    }

    // MARK: - Day / time parsing

    private static func dayParse(_ tok: String) -> DayParse? {
        let cal = Calendar.current
        if tok.hasPrefix("bugun") || tok == "today" {
            return DayParse(weekday: modelWeekday(Date()), date: cal.startOfDay(for: Date()), label: tr("ai_cmd_today"))
        }
        if tok.hasPrefix("yarin") || tok == "tomorrow" {
            let d = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) ?? Date()
            return DayParse(weekday: modelWeekday(d), date: d, label: tr("ai_cmd_tomorrow"))
        }
        // Named weekday → recurring slot (date nil), label = the weekday word.
        for (name, idx) in weekdayNames where tok == name || (name.count > 3 && tok.hasPrefix(name)) {
            return DayParse(weekday: idx, date: nextDate(forModelWeekday: idx), label: weekdayLabel(idx))
        }
        return nil
    }

    private static func todayDayParse() -> DayParse {
        DayParse(weekday: modelWeekday(Date()),
                 date: Calendar.current.startOfDay(for: Date()),
                 label: tr("ai_cmd_today"))
    }

    /// Parses a single token into minutes-of-day, only when a time indicator is
    /// present (":", ".", am/pm, or a Turkish locative suffix) — never a bare number.
    private static func clockTime(_ tok: String) -> Int? {
        let t = tok.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "’", with: "")

        // HH:MM or HH.MM
        if let r = t.range(of: #"^(\d{1,2})[:\.](\d{2})$"#, options: .regularExpression) {
            let parts = t[r].split(whereSeparator: { $0 == ":" || $0 == "." })
            if let h = Int(parts[0]), let m = Int(parts[1]), h < 24, m < 60 { return h * 60 + m }
        }
        // HHam / HHpm
        if let m = t.range(of: #"^(\d{1,2})(am|pm)$"#, options: .regularExpression) {
            let s = String(t[m])
            let pm = s.hasSuffix("pm")
            let h = Int(s.dropLast(2)) ?? 0
            let hour = pm ? (h % 12) + 12 : (h % 12)
            return hour * 60
        }
        // Turkish locative on an hour: 15te, 3te, 9da, 15de
        if let r = t.range(of: #"^(\d{1,2})(te|ta|de|da)$"#, options: .regularExpression) {
            let s = String(t[r])
            let digits = s.prefix { $0.isNumber }
            if let h = Int(digits), h < 24 { return h * 60 }
        }
        return nil
    }

    private static func bareHour(_ tok: String) -> Int? {
        guard let h = pureInt(tok), h >= 0, h < 24 else { return nil }
        return h
    }

    private static func pureInt(_ tok: String) -> Int? {
        guard tok.allSatisfy({ $0.isNumber }), !tok.isEmpty else { return nil }
        return Int(tok)
    }

    private static func isHourUnit(_ unit: String) -> Bool {
        ["saat", "saatlik", "hour", "hours", "hr"].contains(unit)
    }

    /// "12.05" / "12/05" → a date this year (or next year if already passed).
    private static func numericDate(_ tok: String) -> Date? {
        guard tok.range(of: #"^\d{1,2}[\./]\d{1,2}$"#, options: .regularExpression) != nil else { return nil }
        let parts = tok.split(whereSeparator: { $0 == "." || $0 == "/" })
        guard parts.count == 2, let d = Int(parts[0]), let m = Int(parts[1]),
              (1...31).contains(d), (1...12).contains(m) else { return nil }
        return dateFrom(day: d, month: m)
    }

    private static func dateFrom(day: Int, month: Int) -> Date {
        let cal = Calendar.current
        let now = Date()
        let year = cal.component(.year, from: now)
        var comps = DateComponents()
        comps.day = day; comps.month = month; comps.year = year; comps.hour = 9
        let candidate = cal.date(from: comps) ?? now
        if candidate < cal.startOfDay(for: now) {
            comps.year = year + 1
            return cal.date(from: comps) ?? candidate
        }
        return candidate
    }

    private static func nextDate(forModelWeekday w: Int) -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        for offset in 1...7 {
            if let d = cal.date(byAdding: .day, value: offset, to: today), modelWeekday(d) == w {
                return d
            }
        }
        return today
    }

    private static func modelWeekday(_ date: Date) -> Int {
        (Calendar.current.component(.weekday, from: date) + 5) % 7
    }

    // MARK: - Formatting

    private static func clockString(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    private static func weekdayLabel(_ idx: Int) -> String {
        localizedWeekdayFull(idx)
    }

    private static func examDateText(_ date: Date) -> String {
        let cal = Calendar.current
        let day = cal.component(.day, from: date)
        let month = cal.component(.month, from: date)
        return "\(day) \(localizedMonthShort(month - 1))"
    }

    private static func defaultEventTitle(sawEventWord: Bool) -> String {
        tr("ai_cmd_event_default")
    }

    private static func capitalizeFirst(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.uppercased() + s.dropFirst()
    }

    // MARK: - Generic helpers

    private static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive],
                  locale: Locale(identifier: "tr"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func hasVerb(_ tokens: [String], _ verbs: [String]) -> Bool {
        tokens.contains { tok in verbs.contains { tok.hasPrefix($0) } }
    }
}
