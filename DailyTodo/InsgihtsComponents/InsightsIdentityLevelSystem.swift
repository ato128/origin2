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

    static let maxLevel = 50

    static func info(for rawLevel: Int) -> IdentityLevelInfo {
        let level = min(max(rawLevel, 1), maxLevel)

        return IdentityLevelInfo(
            level: level,
            title: title(for: level),
            accent: accent(for: level),
            requiredFocusSessions: focus(for: level),
            requiredCompletedTasks: tasks(for: level),
            requiredStreakDays: streak(for: level),
            rarity: rarity(for: level)
        )
    }

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
        default: return "Momentum Starter"
        }
    }

    private static func accent(for level: Int) -> Color {
        switch level {
        case 1:
            return .orange
        case 2:
            return Color(red: 1.00, green: 0.48, blue: 0.18)
        case 3:
            return Color(red: 0.22, green: 0.72, blue: 1.00)
        case 4:
            return Color(red: 0.45, green: 0.50, blue: 1.00)
        case 5:
            return Color(red: 0.70, green: 0.38, blue: 1.00)
        case 6:
            return Color(red: 0.20, green: 0.86, blue: 0.48)
        case 7:
            return Color(red: 0.12, green: 0.78, blue: 0.68)
        case 8:
            return Color(red: 0.96, green: 0.70, blue: 0.20)
        case 9:
            return Color(red: 1.00, green: 0.34, blue: 0.52)
        case 10:
            return Color(red: 0.38, green: 0.82, blue: 1.00)
        default:
            switch rarity(for: level) {
            case .common:
                return Color(hue: Double(level % 10) / 10.0, saturation: 0.72, brightness: 1.0)
            case .rare:
                return Color(hue: 0.56 + Double(level % 6) * 0.025, saturation: 0.78, brightness: 1.0)
            case .epic:
                return Color(hue: 0.72 + Double(level % 6) * 0.025, saturation: 0.72, brightness: 1.0)
            case .legendary:
                return Color(hue: 0.10 + Double(level % 5) * 0.025, saturation: 0.86, brightness: 1.0)
            case .mythic:
                return Color(hue: 0.88 + Double(level % 5) * 0.02, saturation: 0.80, brightness: 1.0)
            }
        }
    }

    private static func rarity(for level: Int) -> IdentityRarity {
        switch level {
        case 1...10: return .common
        case 11...25: return .rare
        case 26...38: return .epic
        case 39...47: return .legendary
        default: return .mythic
        }
    }

    private static func focus(for level: Int) -> Int {
        guard level > 1 else { return 0 }
        return max(1, level / 2)
    }

    private static func tasks(for level: Int) -> Int {
        guard level > 1 else { return 0 }
        return max(2, level * 2)
    }

    private static func streak(for level: Int) -> Int {
        guard level > 1 else { return 0 }
        return max(1, level / 3)
    }
}
