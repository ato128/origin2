//
//  PerformanceSettings.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 5.05.2026.
//

import SwiftUI

enum PerformanceSettings {
    static let reduceExpensiveEffects = true
    static let enableSlowAmbientAnimations = false
    static let enableHeavyBlurEffects = false

    static var cardShadowRadius: CGFloat {
        reduceExpensiveEffects ? 8 : 16
    }

    static var glowShadowRadius: CGFloat {
        reduceExpensiveEffects ? 8 : 18
    }

    static var radialOpacityMultiplier: Double {
        reduceExpensiveEffects ? 0.62 : 1.0
    }

    static var animationDurationMultiplier: Double {
        reduceExpensiveEffects ? 0.72 : 1.0
    }
}
