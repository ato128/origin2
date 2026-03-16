//
//  NextClassResult.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 5.03.2026.
//

import Foundation

struct NextClassResult {
    let event: EventItem
    let startDate: Date
    let endDate: Date
    let minutesUntilStart: Int
    let minutesLeft: Int
    let isOngoing: Bool
}
