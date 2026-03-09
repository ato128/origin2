//
//  ScheduleShare.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 3.03.2026.
//

import Foundation
import SwiftData

struct ScheduleExport: Codable {
    var app: String = "DailyTodo"
    var version: Int = 1
    var createdAt: Date = Date()
    var events: [ScheduleExportEvent]
}

struct ScheduleExportEvent: Codable {
    var title: String
    var weekday: Int
    var startMinute: Int
    var durationMinute: Int
    var location: String?
    var notes: String?
    var colorHex: String
}

enum ScheduleShare {

    static func makeExport(from events: [EventItem]) -> ScheduleExport {
        let mapped = events.map {
            ScheduleExportEvent(
                title: $0.title,
                weekday: $0.weekday,
                startMinute: $0.startMinute,
                durationMinute: $0.durationMinute,
                location: $0.location,
                notes: $0.notes,
                colorHex: $0.colorHex.isEmpty ? "#3B82F6" : $0.colorHex
            )
        }
        return ScheduleExport(events: mapped)
    }

    static func writeTempJSON(_ export: ScheduleExport) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(export)

        let dir = FileManager.default.temporaryDirectory
        let name = "DailyTodo-Schedule-\(Int(Date().timeIntervalSince1970)).json"
        let url = dir.appendingPathComponent(name)

        try data.write(to: url, options: [.atomic])
        return url
    }

    static func readJSON(from url: URL) throws -> ScheduleExport {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ScheduleExport.self, from: data)
    }
}
