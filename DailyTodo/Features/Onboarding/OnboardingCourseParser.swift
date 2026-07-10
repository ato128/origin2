//
//  OnboardingCourseParser.swift
//  DailyTodo
//
//  Turns a typed or pasted course list into structured courses. One course per
//  line; day names (TR/EN, full or abbreviated) and times ("10.30", "10:30",
//  "10:30-12:20") are detected anywhere in the line and become schedule slots.
//  Whatever remains is the course name (with an optional leading course code
//  like "MATH101" / "BLG 102").
//
//    Matematik MATH101 Pzt 10.30-12.20
//    Fizik II salı 14:00
//    Veri Yapıları
//    - Lineer Cebir Çarşamba 09.30, Cuma 11.30
//

import Foundation

struct ParsedCourseSlot: Hashable {
    /// 0=Mon … 6=Sun (same convention as EventItem.weekday).
    var weekday: Int
    var startMinute: Int
    var durationMinute: Int
}

struct ParsedCourse: Identifiable, Hashable {
    let id = UUID()
    var code: String
    var name: String
    var slots: [ParsedCourseSlot]

    var hasSchedule: Bool { !slots.isEmpty }
}

enum OnboardingCourseParser {

    static let defaultDurationMinutes = 60

    /// TR/EN day tokens → weekday index (0=Mon). Longest names first so
    /// "pazartesi" wins over "pazar".
    private static let dayTokens: [(token: String, weekday: Int)] = [
        ("pazartesi", 0), ("wednesday", 2), ("carsamba", 2), ("thursday", 3),
        ("saturday", 5), ("persembe", 3), ("tuesday", 1), ("cumartesi", 5),
        ("monday", 0), ("friday", 4), ("sunday", 6),
        ("pazar", 6), ("sali", 1), ("cuma", 4),
        ("pzt", 0), ("sal", 1), ("car", 2), ("per", 3), ("cum", 4), ("cmt", 5), ("paz", 6),
        ("mon", 0), ("tue", 1), ("wed", 2), ("thu", 3), ("fri", 4), ("sat", 5), ("sun", 6)
    ].sorted { $0.token.count > $1.token.count }

    static func parse(_ text: String) -> [ParsedCourse] {
        text
            .components(separatedBy: .newlines)
            .compactMap { parseLine($0) }
    }

    // All positions below are CHARACTER OFFSETS into `chars` — the folded
    // string is a same-length transform, so offsets found there map 1:1 back
    // onto the original characters.
    static func parseLine(_ rawLine: String) -> ParsedCourse? {
        var line = rawLine.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { return nil }

        // Strip list bullets / numbering ("- ", "• ", "3. ", "3) ").
        line = line.replacingOccurrences(
            of: #"^\s*(?:[-•*·]|\d{1,2}[.)])\s+"#,
            with: "",
            options: .regularExpression
        )
        guard !line.isEmpty else { return nil }

        let chars = Array(line)
        let folded = String(chars.map(foldCharacter))
        let foldedChars = Array(folded)

        // 1 — Times: "10.30", "10:30", ranges "10.30-12.20" / "10:30 – 12:20".
        struct TimeHit { let lower: Int; let upper: Int; let start: Int; let duration: Int }
        var times: [TimeHit] = []

        let timePattern = #"(\d{1,2})[:.](\d{2})(?:\s*[-–—]\s*(\d{1,2})[:.](\d{2}))?"#
        if let regex = try? NSRegularExpression(pattern: timePattern) {
            let ns = folded as NSString
            for match in regex.matches(in: folded, range: NSRange(location: 0, length: ns.length)) {
                guard let swiftRange = Range(match.range, in: folded) else { continue }

                let h = Int(ns.substring(with: match.range(at: 1))) ?? 0
                let m = Int(ns.substring(with: match.range(at: 2))) ?? 0
                guard h < 24, m < 60 else { continue }
                let start = h * 60 + m

                var duration = defaultDurationMinutes
                if match.range(at: 3).location != NSNotFound,
                   let eh = Int(ns.substring(with: match.range(at: 3))),
                   let em = Int(ns.substring(with: match.range(at: 4))),
                   eh < 24, em < 60 {
                    let end = eh * 60 + em
                    if end > start { duration = min(end - start, 12 * 60) }
                }

                times.append(TimeHit(
                    lower: folded.distance(from: folded.startIndex, to: swiftRange.lowerBound),
                    upper: folded.distance(from: folded.startIndex, to: swiftRange.upperBound),
                    start: start,
                    duration: max(duration, 15)
                ))
            }
        }

        // 2 — Days, with word boundaries so "salon" doesn't read as "sal".
        struct DayHit { let lower: Int; let upper: Int; let weekday: Int }
        var days: [DayHit] = []

        for (token, weekday) in dayTokens {
            let tokenChars = Array(token)
            var offset = 0

            while offset + tokenChars.count <= foldedChars.count {
                if Array(foldedChars[offset..<(offset + tokenChars.count)]) == tokenChars {
                    let beforeOK = offset == 0 || !foldedChars[offset - 1].isLetter
                    let afterIdx = offset + tokenChars.count
                    let afterOK = afterIdx == foldedChars.count || !foldedChars[afterIdx].isLetter
                    let overlapping = days.contains { $0.lower < afterIdx && offset < $0.upper }

                    if beforeOK, afterOK, !overlapping {
                        days.append(DayHit(lower: offset, upper: afterIdx, weekday: weekday))
                        offset = afterIdx
                        continue
                    }
                }
                offset += 1
            }
        }
        days.sort { $0.lower < $1.lower }

        // 3 — Pair each day with the first time after it (before the next day);
        //     with a single day, a leading "10.30 Pazartesi" time also counts.
        var slots: [ParsedCourseSlot] = []
        var usedTimes = Set<Int>()

        for (index, day) in days.enumerated() {
            let nextDayLower = index + 1 < days.count ? days[index + 1].lower : Int.max

            var matched: (start: Int, duration: Int)?
            for (tIndex, time) in times.enumerated() where !usedTimes.contains(tIndex) {
                if time.lower >= day.upper, time.lower < nextDayLower {
                    matched = (time.start, time.duration)
                    usedTimes.insert(tIndex)
                    break
                }
            }

            if matched == nil, days.count == 1,
               let tIndex = times.indices.first(where: { !usedTimes.contains($0) }) {
                matched = (times[tIndex].start, times[tIndex].duration)
                usedTimes.insert(tIndex)
            }

            if let matched {
                slots.append(ParsedCourseSlot(
                    weekday: day.weekday,
                    startMinute: matched.start,
                    durationMinute: matched.duration
                ))
            }
        }

        // 4 — Remove day + time fragments from the ORIGINAL characters; what's
        //     left is code + name.
        var keep = [Bool](repeating: true, count: chars.count)
        for time in times { for i in time.lower..<time.upper { keep[i] = false } }
        for day in days { for i in day.lower..<day.upper { keep[i] = false } }

        var working = String(chars.indices.filter { keep[$0] }.map { chars[$0] })
        working = working
            .replacingOccurrences(of: #"[,;|·•@]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespaces.union(.punctuationCharacters))

        guard !working.isEmpty else { return nil }

        // 5 — Optional course code: "MATH101", "BLG 102", "CS-201".
        var code = ""
        var name = working

        let codePattern = #"(?:^|\s)([A-ZÇĞİÖŞÜ]{2,5}\s?-?\d{2,4})(?:\s|$)"#
        if let regex = try? NSRegularExpression(pattern: codePattern),
           let match = regex.firstMatch(in: working, range: NSRange(working.startIndex..., in: working)),
           let codeRange = Range(match.range(at: 1), in: working) {
            code = String(working[codeRange]).replacingOccurrences(of: " ", with: "")
            name.removeSubrange(codeRange)
            name = name
                .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet.whitespaces.union(.punctuationCharacters))
        }

        if name.isEmpty {
            name = code
            code = ""
        }
        guard !name.isEmpty else { return nil }

        return ParsedCourse(code: code, name: name, slots: slots)
    }

    /// Lowercase + flatten Turkish letters, PRESERVING character count.
    private static func foldCharacter(_ ch: Character) -> Character {
        switch ch {
        case "ı", "İ", "I", "i": return "i"
        case "ç", "Ç": return "c"
        case "ğ", "Ğ": return "g"
        case "ö", "Ö": return "o"
        case "ş", "Ş": return "s"
        case "ü", "Ü": return "u"
        default:
            let lowered = ch.lowercased()
            return lowered.count == 1 ? Character(lowered) : ch
        }
    }
}
