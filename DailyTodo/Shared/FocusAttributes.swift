//
//  FocusAttributes.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 24.03.2026.
//

import Foundation
import ActivityKit

struct FocusAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var subtitle: String
        var startDate: Date
        var endDate: Date
        var modeRaw: String
        var isPaused: Bool
        var isResting: Bool
        var pausedRemainingSeconds: Int?
        var pausedProgress: Double?
    }

    var name: String
}
