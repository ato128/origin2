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
//  Design principle: PRECISION over recall. A statement, question or negation must
//  NEVER be mistaken for a command. We only fire on a clean imperative:
//    • Turkish: the bare verb is the LAST word  ("matematik ekle", "5-8 ders koy")
//    • English: the bare verb is the FIRST word ("add math", "delete math")
//  Verbs are matched EXACTLY (so "ekledim", "ekleme", "ekliyorum" never match), and
//  any question/negation marker bails to the LLM.
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

    private enum Action { case add, delete, done, move }

    // MARK: - Exact imperative forms (diacritic-folded, lowercased)

    private static let trAdd: Set<String>  = ["ekle", "ekleyin", "koy", "koyun", "olustur", "olusturun", "yaz", "yazin"]
    private static let trDel: Set<String>  = ["sil", "silin", "kaldir", "kaldirin", "cikar", "cikarin", "cikart", "cikartin"]
    private static let trDone: Set<String> = ["tamamla", "tamamlayin", "bitir", "bitirin", "isaretle"]
    private static let enAdd: Set<String>  = ["add", "create"]
    private static let enDel: Set<String>  = ["delete", "remove"]
    private static let enDone: Set<String> = ["complete", "finish", "done", "check"]
    // "al"/"alalim" only count as move with a dative day ("yarına al") — see makeMove.
    private static let trMove: Set<String> = ["tasi", "tasiyin", "ertele", "erteleyin", "al", "alalim"]
    private static let enMove: Set<String> = ["move", "postpone", "reschedule"]

    private static var allVerbs: Set<String> {
        trAdd.union(trDel).union(trDone).union(enAdd).union(enDel).union(enDone)
            .union(trMove).union(enMove)
    }

    // Words that mean "this is a question / negation / statement", never a command.
    private static let stopWords: Set<String> = [
        "mi", "mu", "misin", "misiniz", "misind", "miyim",
        "nereye", "nerede", "nereden", "nasil", "neden", "niye", "nicin", "hangi",
        "kim", "kac", "yapma", "etme", "yapmasana", "olmaz",
        "gozukmuyor", "gorunmuyor", "goremiyorum", "gozukmedi", "gelmedi", "gozukmuyo",
        "diyorum", "diyor", "dedim", "dedin", "dedi", "demistim", "sanirim", "galiba", "herhalde",
        "how", "why", "where", "which", "dont", "don't", "not"
    ]

    // Time-of-day hints (ignored in the title; "akşam/gece" push a <12 hour to PM).
    private static let pmHints: Set<String> = ["aksam", "gece", "evening", "night", "pm"]
    private static let dayPartWords: Set<String> = ["aksam", "gece", "sabah", "ogle", "ogleden", "evening", "night", "morning", "noon"]

    // MARK: - Vocabularies

    // Stem-based so suffixed forms match too ("sınavı", "dersi", "etkinliğe"…).
    private static let examStems  = ["sinav", "vize", "final", "quiz", "exam", "midterm", "butunleme"]
    private static let eventStems = ["ders", "etkinlik", "class", "lecture", "toplanti",
                                     "meeting", "randevu", "seans", "appointment", "event"]

    private static func isExamWord(_ tok: String) -> Bool { examStems.contains { tok.hasPrefix($0) } }
    private static func isEventWord(_ tok: String) -> Bool { eventStems.contains { tok.hasPrefix($0) } }
    private static let rangeConnectors: Set<String> = ["ile", "ila", "-", "–", "to", "ve"]
    private static let durationUnits: Set<String> = ["saat", "saatlik", "hour", "hours", "hr",
                                                     "dk", "dakika", "dakikalik", "min", "mins", "minute", "minutes"]
    private static let fillers: Set<String> = [
        "gorev", "gorevi", "gorevini", "gorevler", "gorevleri", "task", "tasks",
        "bir", "bana", "benim", "liste", "listeme", "listemden", "listeden", "listene",
        "to", "my", "the", "a", "an", "lutfen", "please", "updo", "ai",
        "sunu", "su", "bunu", "bu", "olarak", "diye", "adli", "adinda", "isimli",
        "icin", "for", "off", "as", "at", "on", "arasi", "arasina", "arasinda", "arasını", "saat"
    ]

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

    private struct DayParse {
        let weekday: Int
        let date: Date?
        let label: String
    }

    // MARK: - Entry point

    static func interpret(
        _ raw: String,
        store: TodoStore,
        context: ModelContext,
        ownerUserID: String?
    ) -> Result? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.hasSuffix("?") else { return nil }

        // Split on whitespace/commas only — keep internal "." and ":" so "10.30"
        // and "10:30" survive as one time token. Trim edge punctuation per word.
        let tokens = tokenize(fold(text))
        let originalWords = tokenize(text)

        // Commands are short imperatives. One word is too ambiguous; long sentences
        // are conversation.
        guard tokens.count >= 2, tokens.count <= 9 else { return nil }

        // Any question/negation/statement marker → not a command.
        if tokens.contains(where: { stopWords.contains($0) }) { return nil }

        // References to prior conversation content ("bu dediklerini ekle", "planı
        // ekle", "bunları haftaya koy") aren't literal add-commands — the user
        // means the AI's proposal, which the plan card handles. Send to the LLM.
        let referenceStems = ["dedik", "dedig", "soyled", "bunlar", "sunlar", "onlar",
                              "yukar", "seklinde", "onerd", "hepsi", "plani", "planlari", "program"]
        if tokens.contains(where: { tok in referenceStems.contains { tok.hasPrefix($0) } }) { return nil }

        // Exactly one intent verb anywhere → action. (Exact match already rejects
        // "ekledim"/"ekleme"; stop-words reject questions/statements. Position is
        // NOT required, so "Fizik dersi koy 21 ile 22.30" works.)
        guard let action = detectAction(tokens) else { return nil }

        switch action {
        case .add:
            return makeAdd(tokens: tokens, originalWords: originalWords,
                           store: store, context: context, ownerUserID: ownerUserID)
        case .delete:
            return makeRemove(tokens: tokens, store: store, context: context, ownerUserID: ownerUserID)
        case .done:
            return makeComplete(tokens: tokens, store: store)
        case .move:
            return makeMove(tokens: tokens, store: store)
        }
    }

    /// Exactly one intent verb in the message decides the action. Multiple verbs
    /// (e.g. "ekle … sil") are ambiguous → bail to the LLM.
    private static func detectAction(_ tokens: [String]) -> Action? {
        let verbs = tokens.filter { allVerbs.contains($0) }
        guard verbs.count == 1, let v = verbs.first else { return nil }
        if trAdd.contains(v)  || enAdd.contains(v)  { return .add }
        if trDel.contains(v)  || enDel.contains(v)  { return .delete }
        if trDone.contains(v) || enDone.contains(v) { return .done }
        if trMove.contains(v) || enMove.contains(v) {
            // A move needs a day target; "al" additionally needs the dative form
            // ("yarına al", "pazartesiye al") because bare "al" usually means "buy".
            guard let dayTok = tokens.first(where: { dayParse($0) != nil }) else { return nil }
            if (v == "al" || v == "alalim") && !isDativeDay(dayTok) { return nil }
            return .move
        }
        return nil
    }

    /// "yarına", "pazartesiye", "cumaya", "bugüne" — day word carrying a dative
    /// suffix (folded). The bare form ("yarin") is NOT dative.
    private static func isDativeDay(_ tok: String) -> Bool {
        guard dayParse(tok) != nil else { return false }
        let bases = ["bugun", "yarin", "today", "tomorrow"] + Array(weekdayNames.keys)
        guard !bases.contains(tok) else { return false }
        return tok.hasSuffix("a") || tok.hasSuffix("e")
    }

    /// Split on whitespace/commas; trim edge punctuation but keep internal "." / ":".
    private static func tokenize(_ s: String) -> [String] {
        let edges = CharacterSet(charactersIn: ".,!?;:'\"’")
        return s.split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\n" || $0 == "\t" })
            .map { $0.trimmingCharacters(in: edges) }
            .filter { !$0.isEmpty }
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
        var startMin: Int? = nil
        var endMin: Int? = nil
        var duration: Int? = nil
        var examDate: Date? = nil
        var sawExamWord = false
        var sawEventWord = false
        var titleWords: [String] = []

        let pmHint = tokens.contains { pmHints.contains($0) }
        // Strong "this is about a time" signal — lets a lone bare hour ("pazartesi
        // 9 ders ekle") read as 09:00 without misreading "Fizik 2" as 02:00.
        let timeContext = tokens.contains { isEventWord($0) }
            || tokens.contains { dayParse($0) != nil }
            || tokens.contains("saat")

        var i = 0
        while i < tokens.count {
            let tok = tokens[i]

            if isVerb(tok) { i += 1; continue }
            if fillers.contains(tok) || rangeConnectors.contains(tok) || dayPartWords.contains(tok) { i += 1; continue }
            if isExamWord(tok) { sawExamWord = true; i += 1; continue }
            if isEventWord(tok) { sawEventWord = true; i += 1; continue }

            if let d = dayParse(tok) {
                day = d
                if examDate == nil, let dt = d.date { examDate = dt }
                i += 1; continue
            }

            // Exam date "12 mayıs" → consume the day-number + month.
            if let n = pureInt(tok), n >= 1, n <= 31,
               i + 1 < tokens.count, let mo = monthNames[tokens[i + 1]] {
                examDate = dateFrom(day: n, month: mo)
                i += 2; continue
            }
            if let dm = numericDate(tok) { examDate = dm; i += 1; continue }

            // Duration "<n> saat/dk"
            if let n = pureInt(tok), i + 1 < tokens.count, durationUnits.contains(tokens[i + 1]) {
                duration = isHourUnit(tokens[i + 1]) ? n * 60 : n
                i += 2; continue
            }
            if durationUnits.contains(tok) { i += 1; continue }

            // Compact range "5-8"
            if let (a, b) = compactHourRange(tok) {
                startMin = applyPM(a * 60, pm: pmHint); endMin = applyPM(b * 60, pm: pmHint); i += 1; continue
            }

            // A time-ish token (bare hour or clock). In a RANGE, a bare hour is
            // unambiguous; as a LONE value a bare number is only a time after
            // "saat" or when written as a clock (9:30 / 10.30).
            if let a = timeValue(tok) {
                // range: "21 ile 22.30" / "9 10.30"
                if i + 2 < tokens.count, rangeConnectors.contains(tokens[i + 1]), let b = timeValue(tokens[i + 2]) {
                    startMin = applyPM(a, pm: pmHint); endMin = applyPM(b, pm: pmHint); i += 3; continue
                }
                if i + 1 < tokens.count, let b = timeValue(tokens[i + 1]) {
                    startMin = applyPM(a, pm: pmHint); endMin = applyPM(b, pm: pmHint); i += 2; continue
                }
                let isClock = clockTime(tok) != nil
                let afterSaat = i > 0 && tokens[i - 1] == "saat"
                let plausibleHour = timeContext && a % 60 == 0 && (7 * 60 ... 23 * 60).contains(a)
                if isClock || afterSaat || plausibleHour {
                    let m = applyPM(a, pm: pmHint)
                    if startMin == nil { startMin = m } else if endMin == nil { endMin = m }
                    i += 1; continue
                }
                // lone bare number with no time context → title text (e.g. "Fizik 2")
            }

            titleWords.append(i < originalWords.count ? originalWords[i] : tok)
            i += 1
        }

        // Derive duration from an explicit end time.
        if let s = startMin, let e = endMin, e > s, duration == nil { duration = e - s }

        let title = titleWords.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

        // 1 — Exam: exam word + a concrete date.
        if sawExamWord, let date = examDate {
            return makeAddExam(title: title, date: date, store: store, context: context, ownerUserID: ownerUserID)
        }

        // 2 — Event: a start time is present, plus a day OR an event word OR an
        //     explicit end time. A time range strongly implies a calendar slot.
        if let start = startMin, (day != nil || sawEventWord || endMin != nil) {
            let resolvedDay = day ?? todayDayParse()
            let evTitle = title.isEmpty ? widgetEventDefault() : title
            return makeAddEvent(
                title: evTitle, day: resolvedDay, startMinute: start,
                duration: duration ?? 60, context: context, ownerUserID: ownerUserID
            )
        }

        // 3 — Plain task.
        guard title.count >= 2 else { return nil }
        let displayTitle = capitalizeFirst(title)
        let due = day?.date
        let dueLabel = (due != nil) ? day?.label : nil
        return Result(
            reply: dueLabel.map { tr("ai_cmd_added_due", displayTitle, $0) } ?? tr("ai_cmd_added", displayTitle),
            apply: { store.add(title: displayTitle, dueDate: due) }
        )
    }

    private static func widgetEventDefault() -> String { tr("ai_cmd_event_default") }

    // MARK: - Event

    private static func makeAddEvent(
        title: String, day: DayParse, startMinute: Int, duration: Int,
        context: ModelContext, ownerUserID: String?
    ) -> Result {
        let displayTitle = capitalizeFirst(title)
        let whenText = "\(day.label) \(clockString(startMinute))–\(clockString(min(1439, startMinute + duration)))"
        return Result(
            reply: tr("ai_cmd_event_added", displayTitle, whenText),
            apply: {
                let ev = EventItem(
                    ownerUserID: ownerUserID, title: displayTitle,
                    weekday: day.weekday, startMinute: startMinute,
                    durationMinute: max(15, duration), scheduledDate: day.date, colorHex: "#3B82F6"
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
        title: String, date: Date, store: TodoStore,
        context: ModelContext, ownerUserID: String?
    ) -> Result {
        let name = capitalizeFirst(title.isEmpty ? tr("ai_cmd_exam_default") : title)
        let dateText = examDateText(date)
        return Result(
            reply: tr("ai_cmd_exam_added", name, dateText),
            apply: {
                let exam = ExamItem(title: name, courseName: name, examDate: date, ownerUserID: ownerUserID)
                context.insert(exam)
                store.addExamStudyTask(exam: exam, title: name, dueDate: date)
                try? context.save()
                WidgetAppSync.refreshFromSwiftData(context: context)
            }
        )
    }

    // MARK: - Remove (tasks + events + exams)

    private static func makeRemove(
        tokens: [String], store: TodoStore, context: ModelContext, ownerUserID: String?
    ) -> Result? {
        let query = targetQuery(tokens)
        guard !query.isEmpty else { return nil }

        let sawExam = tokens.contains { isExamWord($0) }
        let sawEvent = tokens.contains { isEventWord($0) }

        let taskHit = bestMatch(query, in: store.items, title: { $0.title })
        let events = ownedEvents(context: context, ownerUserID: ownerUserID)
        let eventHit = bestMatch(query, in: events, title: { $0.title })
        let exams = ownedExams(context: context, ownerUserID: ownerUserID)
        let examHit = bestMatch(query, in: exams, title: { $0.title.isEmpty ? $0.courseName : $0.title })

        if sawExam, let ex = examHit?.item { return removeExamResult(ex, store: store, context: context) }
        if sawEvent, let ev = eventHit?.item { return removeEventResult(ev, context: context) }

        let candidates: [(score: Int, make: () -> Result)] = [
            taskHit.map  { hit in (hit.score, { Result(reply: tr("ai_cmd_deleted", hit.item.title), apply: { store.delete(hit.item) }) }) },
            eventHit.map { hit in (hit.score, { removeEventResult(hit.item, context: context) }) },
            examHit.map  { hit in (hit.score, { removeExamResult(hit.item, store: store, context: context) }) }
        ].compactMap { $0 }

        if let best = candidates.max(by: { $0.score < $1.score }) { return best.make() }
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
            for task in store.items where task.linkedExamID == examID { store.delete(task) }
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

    private static func ownedEvents(context: ModelContext, ownerUserID: String?) -> [EventItem] {
        let all = (try? context.fetch(FetchDescriptor<EventItem>())) ?? []
        guard let uid = ownerUserID else { return all }
        let owned = all.filter { $0.ownerUserID == uid }
        return owned.isEmpty ? all.filter { $0.ownerUserID == nil } : owned
    }

    // MARK: - Move / postpone (tasks)

    private static func makeMove(tokens: [String], store: TodoStore) -> Result? {
        // detectAction already guaranteed a day token exists.
        guard let dayTok = tokens.first(where: { dayParse($0) != nil }),
              let day = dayParse(dayTok),
              let date = day.date
        else { return nil }

        let query = targetQuery(tokens.filter { dayParse($0) == nil })
        guard !query.isEmpty else { return nil }

        let pending = store.items.filter { !$0.isDone }
        let pool = pending.isEmpty ? store.items : pending
        guard let match = bestMatch(query, in: pool, title: { $0.title })?.item else {
            return Result(reply: tr("ai_cmd_not_found", query), apply: {})
        }

        return Result(reply: tr("ai_cmd_moved", match.title, day.label), apply: {
            store.reschedule(match, to: date)
        })
    }

    // MARK: - Complete (tasks)

    private static func makeComplete(tokens: [String], store: TodoStore) -> Result? {
        let query = targetQuery(tokens)
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

    private static func targetQuery(_ tokens: [String]) -> String {
        tokens.filter { tok in
            !isVerb(tok) && !fillers.contains(tok) && !isEventWord(tok) && !isExamWord(tok)
        }
        .joined(separator: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func bestMatch<T>(_ query: String, in items: [T], title: (T) -> String) -> (item: T, score: Int)? {
        let q = fold(query)
        guard !q.isEmpty else { return nil }
        let qTokens = Set(q.split(separator: " ").map(String.init))
        var best: (item: T, score: Int)? = nil
        for item in items {
            let t = fold(title(item))
            var score = 0
            if t == q { score = 100 }
            else if t.contains(q) || q.contains(t) { score = 60 + min(q.count, t.count) }
            else {
                let tTokens = Set(t.split(separator: " ").map(String.init))
                let overlap = qTokens.intersection(tTokens).count
                // Turkish case suffixes: "matematiği" should still hit "matematik".
                // A shared ≥4-char stem counts as a token match.
                var stemHits = 0
                for qt in qTokens where qt.count >= 4 {
                    if tTokens.contains(where: { tt in
                        tt.count >= 4 && (tt.hasPrefix(qt) || qt.hasPrefix(tt)
                                          || tt.commonPrefix(with: qt).count >= 4)
                    }) { stemHits += 1 }
                }
                score = max(overlap, stemHits) * 25
            }
            if score > 0, best == nil || score > best!.score { best = (item, score) }
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
        // Longest name first so "pazartesiye" resolves to pazartesi, not pazar.
        for (name, idx) in weekdayNames.sorted(by: { $0.key.count > $1.key.count })
        where tok == name || (name.count > 3 && tok.hasPrefix(name)) {
            return DayParse(weekday: idx, date: nextDate(forModelWeekday: idx), label: weekdayLabel(idx))
        }
        return nil
    }

    private static func todayDayParse() -> DayParse {
        DayParse(weekday: modelWeekday(Date()), date: Calendar.current.startOfDay(for: Date()), label: tr("ai_cmd_today"))
    }

    private static func clockTime(_ tok: String) -> Int? {
        let t = tok.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "’", with: "")
        if let r = t.range(of: #"^(\d{1,2})[:\.](\d{2})$"#, options: .regularExpression) {
            let parts = t[r].split(whereSeparator: { $0 == ":" || $0 == "." })
            if let h = Int(parts[0]), let m = Int(parts[1]), h < 24, m < 60 { return h * 60 + m }
        }
        if t.range(of: #"^(\d{1,2})(am|pm)$"#, options: .regularExpression) != nil {
            let pm = t.hasSuffix("pm")
            let h = Int(t.dropLast(2)) ?? 0
            return ((pm ? (h % 12) + 12 : (h % 12)) * 60)
        }
        if let r = t.range(of: #"^(\d{1,2})(te|ta|de|da)$"#, options: .regularExpression) {
            let digits = t[r].prefix { $0.isNumber }
            if let h = Int(digits), h < 24 { return h * 60 }
        }
        return nil
    }

    /// Minutes-of-day for a clock ("9:30", "10.30") or a bare hour ("9"). The
    /// caller decides whether a bare value is allowed to stand alone as a time.
    private static func timeValue(_ tok: String) -> Int? {
        if let m = clockTime(tok) { return m }
        if let h = bareHour(tok) { return h * 60 }
        return nil
    }

    /// Push a pre-noon hour into the evening when an "akşam/gece" hint is present.
    private static func applyPM(_ minutes: Int, pm: Bool) -> Int {
        guard pm, minutes < 12 * 60 else { return minutes }
        return minutes + 12 * 60
    }

    private static func compactHourRange(_ tok: String) -> (Int, Int)? {
        guard tok.range(of: #"^\d{1,2}[-–]\d{1,2}$"#, options: .regularExpression) != nil else { return nil }
        let parts = tok.split(whereSeparator: { $0 == "-" || $0 == "–" })
        guard parts.count == 2, let a = Int(parts[0]), let b = Int(parts[1]), a < 24, b < 24 else { return nil }
        return (a, b)
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
            if let d = cal.date(byAdding: .day, value: offset, to: today), modelWeekday(d) == w { return d }
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

    private static func weekdayLabel(_ idx: Int) -> String { localizedWeekdayFull(idx) }

    private static func examDateText(_ date: Date) -> String {
        let cal = Calendar.current
        return "\(cal.component(.day, from: date)) \(localizedMonthShort(cal.component(.month, from: date) - 1))"
    }

    private static func capitalizeFirst(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.uppercased() + s.dropFirst()
    }

    // MARK: - Generic helpers

    private static func isVerb(_ tok: String) -> Bool { allVerbs.contains(tok) }

    private static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
