//
//  IdentityXPManager.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 27.04.2026.
//

//
//  IdentityXPManager.swift
//  DailyTodo
//

import SwiftUI
import Foundation
import Combine

@MainActor
final class IdentityXPManager: ObservableObject {

    static let shared = IdentityXPManager()

    // MARK: - Published

    @Published var totalXP: Int = 0
    @Published var currentLevel: Int = 1
    @Published var pendingLevelUp: Bool = false
    @Published var pendingLevel: Int?
    @Published var showBanner: Bool = false
    @Published var bannerText: String = ""

    // MARK: - Storage

    private let xpKey = "identity.totalXP"
    private let levelKey = "identity.currentLevel"
    private let pendingKey = "identity.pendingLevel"

    private init() {
        load()
    }

    // MARK: - Event Types

    enum Event {
        case focusCompleted(minutes: Int)
        case taskCompleted
        case streakDay(days: Int)
        case examStudyCompleted
        case crewFocus(minutes: Int)
        case custom(Int)
    }

    // MARK: - Public API

    func add(_ event: Event) {
        let gained = xp(for: event)
        addXP(gained)
    }

    func addXP(_ amount: Int) {
        guard amount > 0 else { return }

        totalXP += amount
        checkLevelUp()
        save()
    }

    func claimPendingLevel() {
        guard let level = pendingLevel else { return }

        currentLevel = level
        pendingLevel = nil
        pendingLevelUp = false

        banner("Lv.\(level) unlocked")
        save()
    }

    func resetAll() {
        totalXP = 0
        currentLevel = 1
        pendingLevel = nil
        pendingLevelUp = false
        save()
    }

    // MARK: - Computed

    var progress: Double {
        let currentReq = xpRequired(for: currentLevel)
        let nextReq = xpRequired(for: min(currentLevel + 1, 50))

        if nextReq == currentReq { return 1 }

        let local = totalXP - currentReq
        let needed = nextReq - currentReq

        return min(max(Double(local) / Double(needed), 0), 1)
    }

    var xpToNextLevel: Int {
        let nextReq = xpRequired(for: min(currentLevel + 1, 50))
        return max(0, nextReq - totalXP)
    }

    var nextLevel: Int {
        min(currentLevel + 1, 50)
    }

    var currentTitle: String {
        IdentityRankEngine.title(for: currentLevel)
    }

    var accent: Color {
        IdentityRankEngine.color(for: currentLevel)
    }

    // MARK: - Private

    private func xp(for event: Event) -> Int {
        switch event {

        case .custom(let amount):
            return amount

        case .taskCompleted:
            return 10

        case .examStudyCompleted:
            return 18

        case .focusCompleted(let minutes):
            if minutes >= 90 { return 40 }
            if minutes >= 60 { return 32 }
            if minutes >= 30 { return 24 }
            return 16

        case .crewFocus(let minutes):
            if minutes >= 60 { return 45 }
            return 28

        case .streakDay(let days):
            if days >= 30 { return 100 }
            if days >= 14 { return 55 }
            if days >= 7 { return 30 }
            return 15
        }
    }

    private func checkLevelUp() {
        var target = currentLevel

        while target < 50 && totalXP >= xpRequired(for: target + 1) {
            target += 1
        }

        if target > currentLevel {
            pendingLevel = target
            pendingLevelUp = true
            banner("Yeni seviye hazır • Lv.\(target)")
        }
    }

    private func xpRequired(for level: Int) -> Int {
        guard level > 1 else { return 0 }

        // harder every level
        // lv2 = 100
        // lv10 ≈ 1450
        // lv50 high grind
        return Int(pow(Double(level - 1), 1.55) * 100)
    }

    private func banner(_ text: String) {
        bannerText = text

        withAnimation(.spring()) {
            showBanner = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            withAnimation(.spring()) {
                self.showBanner = false
            }
        }
    }

    private func save() {
        UserDefaults.standard.set(totalXP, forKey: xpKey)
        UserDefaults.standard.set(currentLevel, forKey: levelKey)
        UserDefaults.standard.set(pendingLevel, forKey: pendingKey)
    }

    private func load() {
        totalXP = UserDefaults.standard.integer(forKey: xpKey)

        let level = UserDefaults.standard.integer(forKey: levelKey)
        currentLevel = max(level, 1)

        if let pending = UserDefaults.standard.object(forKey: pendingKey) as? Int {
            pendingLevel = pending
            pendingLevelUp = true
        }
    }
}


//
//  IdentityRankEngine.swift
//

import SwiftUI

enum IdentityRankEngine {

    static func title(for level: Int) -> String {

        switch level {
        case 1...3: return "Starter"
        case 4...7: return "Builder"
        case 8...12: return "Focused"
        case 13...17: return "Disciplined"
        case 18...24: return "Elite"
        case 25...32: return "Master"
        case 33...40: return "Legend"
        default: return "Mythic"
        }
    }

    static func color(for level: Int) -> Color {

        switch level {
        case 1...3: return .gray
        case 4...7: return .blue
        case 8...12: return .green
        case 13...17: return .orange
        case 18...24: return .purple
        case 25...32: return .pink
        case 33...40: return .red
        default: return .yellow
        }
    }
}
