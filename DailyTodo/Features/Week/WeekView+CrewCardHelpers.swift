//
//  WeekView+CrewCardHelpers.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 11.03.2026.
//
import SwiftUI

extension WeekView {
    func crewName(for task: CrewTask) -> String? {
        crewMap[task.crewID]?.name
    }

    func commentPreviewItems(for task: CrewTask) -> [CrewTaskCommentPreviewItem] {
        previewCommentsForTask(task).map {
            CrewTaskCommentPreviewItem(
                id: $0.id,
                authorName: $0.authorName,
                message: $0.message
            )
        }
    }

    func taskTimeText(_ task: CrewTask) -> String? {
        guard let start = task.scheduledStartMinute else { return nil }
        return hm(start)
    }
}

