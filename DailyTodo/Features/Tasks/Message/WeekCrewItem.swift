//
//  WeekCrewItem.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import Foundation

struct WeekCrewItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let icon: String
    let colorHex: String
}
