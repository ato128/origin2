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
    var ownerUserID: UUID?

    var title: String

    /// 0=Pzt, 1=Sal, 2=Çar, 3=Per, 4=Cum, 5=Cmt, 6=Paz
    var weekday: Int

    /// Dakika cinsinden: 0...1439
    var startMinute: Int

    /// Dakika cinsinden: en az 15
    var durationMinute: Int

    /// Tek seferlik ileri tarihli kayıt için
    var scheduledDate: Date?

    var location: String?
    var notes: String?
    
    /// Renk (HEX) ör: "4F46E5" veya "#4F46E5"
    var colorHex: String
    
    var sourceTaskUUID: String?
    var createdAt: Date
    var isCompleted: Bool

    init(
        ownerUserID: UUID? = nil,
        title: String,
        weekday: Int,
        startMinute: Int,
        durationMinute: Int,
        scheduledDate: Date? = nil,
        location: String? = nil,
        notes: String? = nil,
        colorHex: String = "#3B82F6",
        createdAt: Date = Date(),
        sourceTaskUUID: String? = nil,
        isCompleted: Bool = false
    ) {
        self.id = UUID()
        self.ownerUserID = ownerUserID
        self.title = title
        self.weekday = weekday
        self.startMinute = max(0, min(1439, startMinute))
        self.durationMinute = max(15, durationMinute)
        self.scheduledDate = scheduledDate
        self.location = location
        self.notes = notes
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.sourceTaskUUID = sourceTaskUUID
        self.isCompleted = isCompleted
    }
}
