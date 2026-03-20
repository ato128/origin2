//
//  CrewDateParser.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 20.03.2026.
//

import Foundation

enum CrewDateParser {
    private static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        return f
    }()

    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [
            .withInternetDateTime
        ]
        return f
    }()

    static func parse(_ raw: String?) -> Date? {
        guard let raw else { return nil }

        if let d = withFractional.date(from: raw) {
            return d
        }
        if let d = plain.date(from: raw) {
            return d
        }
        return nil
    }

    static func string(from date: Date) -> String {
        withFractional.string(from: date)
    }
}
