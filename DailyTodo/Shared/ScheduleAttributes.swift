//
//  ScheduleAttributes.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 9.03.2026.
//

import Foundation
import ActivityKit

struct ScheduleAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var startDate: Date
        var endDate: Date
        var colorHex: String
    }

    var scheduleName: String
}
