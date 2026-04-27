//
//  InsightsIdentityLevelSystem.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 27.04.2026.
//

import SwiftUI
import Foundation

struct IdentityLevelInfo: Identifiable, Hashable {
    let id = UUID()

    let level: Int
    let title: String
    let accent: Color

    let requiredXP: Int
    let requiredFocusSessions: Int
    let requiredCompletedTasks: Int
    let requiredStreakDays: Int

    let rarity: IdentityRarity
}

enum IdentityRarity: String {
    case common
    case rare
    case epic
    case legendary
    case mythic

    var glow: Color {
        switch self {
        case .common: return .white.opacity(0.18)
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        case .mythic: return .pink
        }
    }
}

enum InsightsIdentityLevelSystem {

    static func info(for rawLevel: Int) -> IdentityLevelInfo {
        let level = min(max(rawLevel, 1), 50)

        return IdentityLevelInfo(
            level: level,
            title: title(for: level),
            accent: accent(for: level),
            requiredXP: xp(for: level),
            requiredFocusSessions: focus(for: level),
            requiredCompletedTasks: tasks(for: level),
            requiredStreakDays: streak(for: level),
            rarity: rarity(for: level)
        )
    }

    // MARK: Titles

    private static func title(for level: Int) -> String {
        switch level {

        case 1: return "Momentum Starter"
        case 2: return "Momentum Builder"
        case 3: return "Momentum Runner"
        case 4: return "Momentum Keeper"
        case 5: return "Momentum Locked"

        case 6: return "Habit Starter"
        case 7: return "Habit Builder"
        case 8: return "Habit Charger"
        case 9: return "Habit Driver"
        case 10: return "Habit Engine"

        case 11: return "Discipline Seed"
        case 12: return "Discipline Core"
        case 13: return "Discipline Guard"
        case 14: return "Discipline Flame"
        case 15: return "Discipline Elite"

        case 16: return "Consistency Mind"
        case 17: return "Consistency Force"
        case 18: return "Consistency Wall"
        case 19: return "Consistency Prime"
        case 20: return "Routine Weapon"

        case 21: return "Deep Worker"
        case 22: return "Focus Hunter"
        case 23: return "Focus Machine"
        case 24: return "Flow Operator"
        case 25: return "Time Operator"

        case 26: return "Precision Mind"
        case 27: return "Precision Builder"
        case 28: return "Sharp Executor"
        case 29: return "Silent Achiever"
        case 30: return "Peak Performer"

        case 31: return "Scholar Prime"
        case 32: return "Master Learner"
        case 33: return "Exam Crusher"
        case 34: return "Quiz Survivor"
        case 35: return "Final Hunter"

        case 36: return "Dean Candidate"
        case 37: return "Dean's List"
        case 38: return "GPA Monster"
        case 39: return "Academic Weapon"
        case 40: return "Knowledge Titan"

        case 41: return "Limitless"
        case 42: return "Apex Human"
        case 43: return "Iron Identity"
        case 44: return "Ultra Driven"
        case 45: return "Elite Entity"

        case 46: return "System Master"
        case 47: return "Productivity God"
        case 48: return "Time Emperor"
        case 49: return "Reality Shifter"
        case 50: return "Identity Legend"

        default:
            return "Momentum Starter"
        }
    }

    // MARK: Colors

    private static func accent(for level: Int) -> Color {
        switch rarity(for: level) {
        case .common:
            return .orange

        case .rare:
            return .blue

        case .epic:
            return .purple

        case .legendary:
            return .yellow

        case .mythic:
            return .pink
        }
    }

    // MARK: Rarity

    private static func rarity(for level: Int) -> IdentityRarity {
        switch level {
        case 1...10:
            return .common

        case 11...25:
            return .rare

        case 26...38:
            return .epic

        case 39...47:
            return .legendary

        default:
            return .mythic
        }
    }

    // MARK: Requirements

    private static func xp(for level: Int) -> Int {
        Int(pow(Double(level), 1.75) * 95)
    }

    private static func focus(for level: Int) -> Int {
        max(1, level / 2)
    }

    private static func tasks(for level: Int) -> Int {
        max(2, level * 2)
    }

    private static func streak(for level: Int) -> Int {
        max(1, level / 3)
    }
}
