//
//  NextClassEngine.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 5.03.2026.
//

import Foundation

struct DTNextClassResult {
    let event: EventItem
    let startDate: Date
    let endDate: Date
    let isOngoing: Bool

    var minutesUntilStart: Int { max(0, Int(startDate.timeIntervalSinceNow / 60)) }
    var minutesLeft: Int { max(0, Int(endDate.timeIntervalSinceNow / 60)) }
}

enum DTNextClassEngine {

    static func next(from events: [EventItem], now: Date = Date(), calendar: Calendar = .current) -> DTNextClassResult? {
        guard !events.isEmpty else { return nil }

        let todayIndex = weekdayIndexToday(now: now, calendar: calendar)

        if let today = nextInDay(events: events, dayIndex: todayIndex, now: now, calendar: calendar) {
            return today
        }

        for offset in 1...6 {
            let day = (todayIndex + offset) % 7
            if let first = firstInDay(events: events, dayIndex: day, reference: now, calendar: calendar) {
                return first
            }
        }

        return nil
    }

    // MARK: - Helpers

    private static func nextInDay(events: [EventItem], dayIndex: Int, now: Date, calendar: Calendar) -> DTNextClassResult? {
        let nowMinute = currentMinuteOfDay(now: now, calendar: calendar)

        let dayEvents = events
            .filter { $0.weekday == dayIndex }
            .sorted { $0.startMinute < $1.startMinute }

        guard !dayEvents.isEmpty else { return nil }

        if let live = dayEvents.first(where: { ev in
            let s = ev.startMinute
            let e = ev.startMinute + ev.durationMinute
            return nowMinute >= s && nowMinute < e
        }) {
            let start = nextOccurrenceDate(for: dayIndex, startMinute: live.startMinute, reference: now, calendar: calendar)
            let end = calendar.date(byAdding: .minute, value: live.durationMinute, to: start) ?? start
            return DTNextClassResult(event: live, startDate: start, endDate: end, isOngoing: true)
        }

        if let next = dayEvents.first(where: { $0.startMinute > nowMinute }) {
            let start = nextOccurrenceDate(for: dayIndex, startMinute: next.startMinute, reference: now, calendar: calendar)
            let end = calendar.date(byAdding: .minute, value: next.durationMinute, to: start) ?? start
            return DTNextClassResult(event: next, startDate: start, endDate: end, isOngoing: false)
        }

        return nil
    }

    private static func firstInDay(events: [EventItem], dayIndex: Int, reference: Date, calendar: Calendar) -> DTNextClassResult? {
        let dayEvents = events
            .filter { $0.weekday == dayIndex }
            .sorted { $0.startMinute < $1.startMinute }

        guard let first = dayEvents.first else { return nil }

        let start = nextOccurrenceDate(for: dayIndex, startMinute: first.startMinute, reference: reference, calendar: calendar)
        let end = calendar.date(byAdding: .minute, value: first.durationMinute, to: start) ?? start
        return DTNextClassResult(event: first, startDate: start, endDate: end, isOngoing: false)
    }

    private static func currentMinuteOfDay(now: Date, calendar: Calendar) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: now)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private static func weekdayIndexToday(now: Date, calendar: Calendar) -> Int {
        let w = calendar.component(.weekday, from: now) // 1=Paz ... 7=Cmt
        return (w + 5) % 7 // 0=Pzt ... 6=Paz
    }

    private static func mapToGregorianWeekday(_ weekdayIndex: Int) -> Int {
        switch weekdayIndex {
        case 0: return 2
        case 1: return 3
        case 2: return 4
        case 3: return 5
        case 4: return 6
        case 5: return 7
        case 6: return 1
        default: return 2
        }
    }

    private static func nextOccurrenceDate(for weekdayIndex: Int, startMinute: Int, reference: Date, calendar: Calendar) -> Date {
        let hour = max(0, min(23, startMinute / 60))
        let minute = max(0, min(59, startMinute % 60))

        var comps = DateComponents()
        comps.weekday = mapToGregorianWeekday(weekdayIndex)
        comps.hour = hour
        comps.minute = minute

        return calendar.nextDate(
            after: reference,
            matching: comps,
            matchingPolicy: .nextTimePreservingSmallerComponents,
            direction: .forward
        ) ?? reference
    }
}
