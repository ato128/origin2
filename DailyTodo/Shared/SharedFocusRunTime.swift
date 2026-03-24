//
//  SharedFocusRunTime.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 24.03.2026.
//

import Foundation

enum FocusRuntimeMode: String, Codable {
    case standard
    case workout
    case crew
}

struct SharedFocusRuntime: Codable {
    var ownerUserID: String?
    var title: String
    var subtitle: String?
    var mode: FocusRuntimeMode

    var startedAt: Date
    var endDate: Date
    var totalSeconds: Int
    var isRunning: Bool
    var isPaused: Bool

    var isResting: Bool

    var exerciseName: String?
    var currentSet: Int?
    var totalSets: Int?

    var crewName: String?

    var updatedAt: Date

    var remainingSeconds: Int {
        if isPaused { return max(0, Int(endDate.timeIntervalSince(startedAt))) }
        return max(0, Int(endDate.timeIntervalSinceNow))
    }

    var isActive: Bool {
        isRunning && remainingSeconds > 0
    }
}

enum SharedFocusRuntimeStore {
    private static let runtimeKey = "shared_focus_runtime_v1"

    static func save(_ runtime: SharedFocusRuntime) {
        guard let data = try? JSONEncoder().encode(runtime) else { return }
        UserDefaults.standard.set(data, forKey: runtimeKey)
    }

    static func load() -> SharedFocusRuntime? {
        guard let data = UserDefaults.standard.data(forKey: runtimeKey) else { return nil }
        return try? JSONDecoder().decode(SharedFocusRuntime.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: runtimeKey)
    }
}
