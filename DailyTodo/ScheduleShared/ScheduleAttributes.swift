//
//  ScheduleAttributes.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 6.03.2026.
//

import Foundation
import ActivityKit

struct ScheduleAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        var title: String
        var startDate: Date
        var endDate: Date
    }

    var name: String
}
