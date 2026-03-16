//
//  CrewBadgeHelpers.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI

enum CrewBadgeHelper {
    static func title(for minutes: Int) -> String {
        switch minutes {
        case 0..<15:
            return "No Badge"
        case 15..<30:
            return "First Focus"
        case 30..<60:
            return "Warm Up"
        case 60..<120:
            return "Focus Starter"
        case 120..<180:
            return "On Fire"
        case 180..<300:
            return "Deep Diver"
        case 300..<480:
            return "Bronze Crew"
        case 480..<720:
            return "Silver Spark"
        case 720..<1080:
            return "Gold Pulse"
        case 1080..<1500:
            return "Focus Force"
        case 1500..<2400:
            return "Platinum Crew"
        case 2400..<3600:
            return "Diamond Flow"
        case 3600..<6000:
            return "Legend Crew"
        default:
            return "Mythic Focus"
        }
    }

    static func color(for minutes: Int) -> Color {
        switch minutes {
        case 0..<15:
            return .gray
        case 15..<30:
            return .mint
        case 30..<60:
            return .teal
        case 60..<120:
            return .blue
        case 120..<180:
            return .orange
        case 180..<300:
            return .purple
        case 300..<480:
            return Color(red: 0.80, green: 0.55, blue: 0.25)
        case 480..<720:
            return .gray
        case 720..<1080:
            return .yellow
        case 1080..<1500:
            return .pink
        case 1500..<2400:
            return .indigo
        case 2400..<3600:
            return .cyan
        case 3600..<6000:
            return .green
        default:
            return .red
        }
    }

    static func nextTarget(for minutes: Int) -> Int? {
        let targets = [15, 30, 60, 120, 180, 300, 480, 720, 1080, 1500, 2400, 3600, 6000]
        return targets.first(where: { minutes < $0 })
    }

    static func progress(for minutes: Int) -> Double {
        let targets = [0, 15, 30, 60, 120, 180, 300, 480, 720, 1080, 1500, 2400, 3600, 6000]

        guard let upper = targets.first(where: { minutes < $0 }),
              let upperIndex = targets.firstIndex(of: upper),
              upperIndex > 0 else {
            return 1
        }

        let lower = targets[upperIndex - 1]
        let span = upper - lower
        guard span > 0 else { return 1 }

        return min(1, max(0, Double(minutes - lower) / Double(span)))
    }
}
