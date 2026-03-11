//
//  WeekView+ScrollTracking.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 12.03.2026.
//

import SwiftUI

struct WeekScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
