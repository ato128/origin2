//
//  EventItem.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import Foundation
import SwiftData

@Model
final class EventItem {
    var id: UUID
    var title: String

    /// 0=Pzt, 1=Sal, 2=Çar, 3=Per, 4=Cum, 5=Cmt, 6=Paz
    var weekday: Int

    /// Dakika cinsinden: 0...1439
    var startMinute: Int

    /// Dakika cinsinden: en az 15
    var durationMinute: Int

    var location: String?
    var notes: String?

    /// Renk (HEX) ör: "4F46E5" veya "#4F46E5"
    /// Not: SwiftData migrate işleriyle uğraşmamak için default veriyoruz.
    var colorHex: String

    var createdAt: Date

    init(
        title: String,
        weekday: Int,
        startMinute: Int,
        durationMinute: Int,
        location: String? = nil,
        notes: String? = nil,
        colorHex: String = "#3B82F6",
        createdAt: Date = Date()
    ) {
        self.id = UUID()
        self.title = title
        self.weekday = weekday
        self.startMinute = max(0, min(1439, startMinute))
        self.durationMinute = max(15, durationMinute)
        self.location = location
        self.notes = notes
        self.colorHex = colorHex
        self.createdAt = createdAt
    }
}
