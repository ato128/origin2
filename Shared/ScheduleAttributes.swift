//
//  ScheduleAttributes.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 9.03.2026.
//

import ActivityKit
import Foundation

struct ScheduleAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var startDate: Date
        var endDate: Date
    }

    var name: String
}
