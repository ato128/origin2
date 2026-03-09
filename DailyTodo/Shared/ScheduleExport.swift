//
//  ScheduleExport.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 3.03.2026.
//

import Foundation
import SwiftData

// Paylaşacağımız minimal model
struct ExportedEvent: Codable {
    var title: String
    var weekday: Int
    var startMinute: Int
    var durationMinute: Int
    var location: String?
    var notes: String?
    var colorHex: String
}

struct ExportedSchedule: Codable {
    var version: Int = 1
    var createdAt: Date = Date()
    var events: [ExportedEvent]
}

enum ScheduleExportService {

    static func makeExport(from events: [EventItem]) -> ExportedSchedule {
        ExportedSchedule(
            events: events.map {
                ExportedEvent(
                    title: $0.title,
                    weekday: $0.weekday,
                    startMinute: $0.startMinute,
                    durationMinute: $0.durationMinute,
                    location: $0.location,
                    notes: $0.notes,
                    colorHex: $0.colorHex
                )
            }
        )
    }

    static func encode(_ schedule: ExportedSchedule) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(schedule)
    }

    static func decode(_ data: Data) throws -> ExportedSchedule {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ExportedSchedule.self, from: data)
    }

    @MainActor
    static func importSchedule(_ schedule: ExportedSchedule, into context: ModelContext) throws {
        for e in schedule.events {
            let item = EventItem(
                title: e.title,
                weekday: max(0, min(6, e.weekday)),
                startMinute: max(0, min(1439, e.startMinute)),
                durationMinute: max(15, e.durationMinute),
                location: e.location,
                notes: e.notes,
                colorHex: e.colorHex.isEmpty ? "#3B82F6" : e.colorHex
            )
            context.insert(item)
        }
        try context.save()
    }
}
