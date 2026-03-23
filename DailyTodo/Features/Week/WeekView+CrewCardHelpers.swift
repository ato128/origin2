//
//  WeekView+CrewCardHelpers.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 11.03.2026.
//
import SwiftUI

extension WeekView {
    func crewName(for task: WeekCrewTaskItem) -> String? {
        crewMap[task.crewID]?.name
    }

    

    func taskTimeText(_ task: WeekCrewTaskItem) -> String? {
        guard let start = task.scheduledStartMinute else { return nil }
        return hm(start)
    }
}
