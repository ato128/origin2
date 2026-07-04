//
//  UpdoAIPlanParser.swift
//  DailyTodo
//
//  Turns an Updo AI reply into concrete, schedulable plan items. Unlike the old
//  naive bullet scraper, this parser:
//    • skips questions and non-actionable lines (so "Hangi dersler var?" never
//      becomes a task),
//    • strips markdown (**bold**, *italic*, `code`) and emoji noise,
//    • understands Turkish/English dates ("10 Temmuz", "10.07", "yarın",
//      weekday names) and durations ("3 saat", "1,5 saat", "90 dk"),
//  so accepted plans land on the RIGHT day in the week with the RIGHT duration.
//

import Foundation

struct UpdoAIPlanItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let dueDate: Date?
    let durationMinutes: Int?
}

enum UpdoAIPlanParser {

    private static let monthNames: [String: Int] = [
        "ocak": 1, "subat": 2, "mart": 3, "nisan": 4, "mayis": 5, "haziran": 6,
        "temmuz": 7, "agustos": 8, "eylul": 9, "ekim": 10, "kasim": 11, "aralik": 12,
        "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
        "july": 7, "august": 8, "september": 9, "october": 10, "november": 11, "december": 12,
        "jan": 1, "feb": 2, "mar": 3, "apr": 4, "jun": 6, "jul": 7, "aug": 8,
        "sep": 9, "sept": 9, "oct": 10, "nov": 11, "dec": 12
    ]

    private static let weekdayNames: [String: Int] = [
        "pazartesi": 2, "sali": 3, "carsamba": 4, "persembe": 5,
        "cuma": 6, "cumartesi": 7, "pazar": 1,
        "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5,
        "friday": 6, "saturday": 7, "sunday": 1
    ]

    /// Words that mark a line as a question / meta-instruction, not a task.
    private static let questionMarkers = [
        "hangi", "kac saat", "nedir", "var mi", "misin", "musun",
        "which", "what", "how many", "priority"
    ]

    // MARK: - Public

    static func parse(_ text: String) -> [UpdoAIPlanItem] {
        var seen: Set<String> = []
        var items: [UpdoAIPlanItem] = []

        for rawLine in text.components(separatedBy: "\n") {
            guard let body = bulletBody(rawLine) else { continue }
            guard let item = parseLine(body) else { continue }
            guard seen.insert(fold(item.title)).inserted else { continue }
            items.append(item)
            if items.count == 10 { break }
        }
        return items
    }

    // MARK: - Line handling

    /// Returns the content of a bullet/numbered line, or nil for prose lines.
    private static func bulletBody(_ line: String) -> String? {
        let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["• ", "- ", "* ", "– ", "→ "] where t.hasPrefix(prefix) {
            return String(t.dropFirst(prefix.count))
        }
        if let r = t.range(of: #"^\d+[.)]\s+"#, options: .regularExpression) {
            return String(t[r.upperBound...])
        }
        return nil
    }

    private static func parseLine(_ raw: String) -> UpdoAIPlanItem? {
        var line = stripMarkdown(raw)

        // Questions and meta lines are never tasks.
        if line.hasSuffix("?") { return nil }
        let folded = fold(line)
        if questionMarkers.contains(where: { folded.contains($0) }) { return nil }

        let date = extractDate(&line)
        let duration = extractDuration(&line)

        // Clean leftovers: emojis at the head, stray separators, "(Ders):" wrappers.
        line = line.replacingOccurrences(of: #"^[\s:—–\-·,]+"#, with: "", options: .regularExpression)
        line = line.replacingOccurrences(of: #"[\s:—–\-·,]+$"#, with: "", options: .regularExpression)
        line = line.replacingOccurrences(of: #"^\(([^)]+)\)\s*:?\s*"#, with: "$1 ", options: .regularExpression)
        line = line.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        line = line.trimmingCharacters(in: .whitespacesAndNewlines)

        guard line.count >= 3, line.count < 120 else { return nil }

        let title = line.prefix(1).uppercased() + line.dropFirst()
        return UpdoAIPlanItem(title: title, dueDate: date, durationMinutes: duration)
    }

    // MARK: - Extraction

    private static func stripMarkdown(_ s: String) -> String {
        var out = s
        for token in ["**", "__", "`", "*"] {
            out = out.replacingOccurrences(of: token, with: "")
        }
        // Leading emoji / symbols (calendar, bulb, flags…) before the first letter or digit.
        out = out.replacingOccurrences(
            of: #"^[^\p{L}\p{N}(]+"#,
            with: "",
            options: .regularExpression
        )
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Finds and REMOVES a date phrase from the line; returns the resolved date.
    private static func extractDate(_ line: inout String) -> Date? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let folded = fold(line)

        // Relative words
        if let r = folded.range(of: #"\b(bugun|today)\b"#, options: .regularExpression) {
            removeFoldedRange(&line, foldedRange: r, in: folded)
            return today
        }
        if let r = folded.range(of: #"\b(yarin|tomorrow)\b"#, options: .regularExpression) {
            removeFoldedRange(&line, foldedRange: r, in: folded)
            return cal.date(byAdding: .day, value: 1, to: today)
        }

        // "10 Temmuz" / "July 10"
        if let m = folded.range(of: #"\b(\d{1,2})\s+([a-z]+)\b"#, options: .regularExpression) {
            let phrase = String(folded[m])
            let parts = phrase.split(separator: " ")
            if parts.count == 2, let day = Int(parts[0]), let month = monthNames[String(parts[1])],
               (1...31).contains(day) {
                removeFoldedRange(&line, foldedRange: m, in: folded)
                return resolve(day: day, month: month)
            }
        }
        if let m = folded.range(of: #"\b([a-z]+)\s+(\d{1,2})\b"#, options: .regularExpression) {
            let parts = folded[m].split(separator: " ")
            if parts.count == 2, let month = monthNames[String(parts[0])], let day = Int(parts[1]),
               (1...31).contains(day) {
                removeFoldedRange(&line, foldedRange: m, in: folded)
                return resolve(day: day, month: month)
            }
        }

        // "10.07" / "10/07"
        if let m = folded.range(of: #"\b(\d{1,2})[./](\d{1,2})\b"#, options: .regularExpression) {
            let parts = folded[m].split(whereSeparator: { $0 == "." || $0 == "/" })
            if parts.count == 2, let d = Int(parts[0]), let mo = Int(parts[1]),
               (1...31).contains(d), (1...12).contains(mo) {
                removeFoldedRange(&line, foldedRange: m, in: folded)
                return resolve(day: d, month: mo)
            }
        }

        // Weekday name → next occurrence
        for (name, weekday) in weekdayNames {
            if let r = folded.range(of: #"\b"# + name + #"\b"#, options: .regularExpression) {
                removeFoldedRange(&line, foldedRange: r, in: folded)
                for offset in 1...7 {
                    if let d = cal.date(byAdding: .day, value: offset, to: today),
                       cal.component(.weekday, from: d) == weekday {
                        return d
                    }
                }
            }
        }
        return nil
    }

    /// Finds and REMOVES a duration phrase; returns minutes. Handles "3 saat",
    /// "1,5 saat", "90 dk", "45 min".
    private static func extractDuration(_ line: inout String) -> Int? {
        let folded = fold(line)
        guard let m = folded.range(
            of: #"\b(\d+(?:[.,]\d+)?)\s*(saatlik|saat|sa|dakika|dk|hours|hour|hr|minutes|min)\b"#,
            options: .regularExpression
        ) else { return nil }

        let phrase = String(folded[m])
        let numberPart = phrase.prefix { $0.isNumber || $0 == "." || $0 == "," }
        let value = Double(numberPart.replacingOccurrences(of: ",", with: ".")) ?? 0
        let isHours = phrase.contains("saat") || phrase.contains("hour") || phrase.contains("hr") || phrase.hasSuffix("sa")
        removeFoldedRange(&line, foldedRange: m, in: folded)

        let minutes = Int(isHours ? value * 60 : value)
        return minutes > 0 ? minutes : nil
    }

    // MARK: - Helpers

    private static func resolve(day: Int, month: Int) -> Date {
        let cal = Calendar.current
        let now = Date()
        var comps = DateComponents()
        comps.day = day; comps.month = month; comps.year = cal.component(.year, from: now); comps.hour = 9
        let candidate = cal.date(from: comps) ?? now
        if candidate < cal.startOfDay(for: now) {
            comps.year = cal.component(.year, from: now) + 1
            return cal.date(from: comps) ?? candidate
        }
        return candidate
    }

    /// Removes the substring of `line` that corresponds to a range found in its
    /// folded twin. Folding is 1:1 for our inputs (case/diacritic only), so the
    /// offsets line up.
    private static func removeFoldedRange(_ line: inout String, foldedRange: Range<String.Index>, in folded: String) {
        let start = folded.distance(from: folded.startIndex, to: foldedRange.lowerBound)
        let length = folded.distance(from: foldedRange.lowerBound, to: foldedRange.upperBound)
        guard start >= 0, start + length <= line.count else { return }
        let s = line.index(line.startIndex, offsetBy: start)
        let e = line.index(s, offsetBy: length)
        line.removeSubrange(s..<e)
    }

    private static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr"))
            .lowercased()
    }
}
