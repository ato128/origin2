//
//  TodoListView+Helpers.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI
import UIKit

extension TodoListView {
    func currentMinuteOfDay() -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    func weekdayIndexToday() -> Int {
        let w = Calendar.current.component(.weekday, from: now)
        return (w + 5) % 7
    }

     func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare()
        gen.impactOccurred()
    }
}
