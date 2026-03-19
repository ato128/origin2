//
//  WeekCrewMemberItem.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import Foundation

struct WeekCrewMemberItem: Identifiable, Hashable {
    let id: UUID
    let crewID: UUID
    let userID: UUID
    let name: String
    let role: String
}
