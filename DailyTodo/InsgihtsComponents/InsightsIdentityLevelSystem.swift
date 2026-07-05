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

    // Level titles follow the app language (TR/EN) — index 0 = level 1.
    private static let titlesEN: [String] = [
        "Momentum Starter", "Momentum Builder", "Momentum Runner", "Momentum Keeper", "Momentum Locked",
        "Habit Starter", "Habit Builder", "Habit Charger", "Habit Driver", "Habit Engine",
        "Discipline Seed", "Discipline Core", "Discipline Guard", "Discipline Flame", "Discipline Elite",
        "Consistency Mind", "Consistency Force", "Consistency Wall", "Consistency Prime", "Routine Weapon",
        "Deep Worker", "Focus Hunter", "Focus Machine", "Flow Operator", "Time Operator",
        "Precision Mind", "Precision Builder", "Sharp Executor", "Silent Achiever", "Peak Performer",
        "Scholar Prime", "Master Learner", "Exam Crusher", "Quiz Survivor", "Final Hunter",
        "Dean Candidate", "Dean's List", "GPA Monster", "Academic Weapon", "Knowledge Titan",
        "Limitless", "Apex Human", "Iron Identity", "Ultra Driven", "Elite Entity",
        "System Master", "Productivity God", "Time Emperor", "Reality Shifter", "Identity Legend"
    ]

    private static let titlesTR: [String] = [
        "İvme Başlangıcı", "İvme Kurucusu", "İvme Koşucusu", "İvme Bekçisi", "İvme Kilidi",
        "Alışkanlık Çırağı", "Alışkanlık Kurucusu", "Alışkanlık Motoru", "Alışkanlık Sürücüsü", "Alışkanlık Makinesi",
        "Disiplin Tohumu", "Disiplin Çekirdeği", "Disiplin Muhafızı", "Disiplin Alevi", "Elit Disiplin",
        "İstikrar Zihni", "İstikrar Gücü", "İstikrar Duvarı", "Saf İstikrar", "Rutin Silahı",
        "Derin Çalışan", "Odak Avcısı", "Odak Makinesi", "Akış Operatörü", "Zaman Operatörü",
        "Hassas Zihin", "Hassas Kurucu", "Keskin İcracı", "Sessiz Başaran", "Zirve Performansı",
        "Baş Bilgin", "Usta Öğrenen", "Sınav Ezici", "Quiz Gazisi", "Final Avcısı",
        "Dekan Adayı", "Dekan Listesi", "Ortalama Canavarı", "Akademik Silah", "Bilgi Titanı",
        "Limitsiz", "Zirve İnsan", "Demir Kimlik", "Ultra Azim", "Elit Varlık",
        "Sistem Ustası", "Verimlilik Tanrısı", "Zaman İmparatoru", "Gerçeklik Bükücü", "Kimlik Efsanesi"
    ]

    private static func title(for level: Int) -> String {
        let titles = appLanguageIsEnglish() ? titlesEN : titlesTR
        let index = min(max(level, 1), maxLevel) - 1
        return index < titles.count ? titles[index] : titles[0]
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
