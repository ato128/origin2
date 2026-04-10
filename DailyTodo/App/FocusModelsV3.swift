//
//  FocusModels.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 9.04.2026.
//

import SwiftUI
import Foundation

enum FocusMode: String, CaseIterable, Identifiable, Codable {
    case personal
    case crew
    case friend

    var id: String { rawValue }

    var title: String {
        switch self {
        case .personal: return "Personal"
        case .crew: return "Crew"
        case .friend: return "Friend"
        }
    }

    var heroEyebrow: String {
        switch self {
        case .personal: return "Personal"
        case .crew: return "Crew"
        case .friend: return "Friend"
        }
    }

    var heroTitle: String {
        switch self {
        case .personal: return "Kişisel\nFocus"
        case .crew: return "Crew\nFocus"
        case .friend: return "Friend\nFocus"
        }
    }

    var heroSubtitle: String {
        switch self {
        case .personal: return "Sessiz bir odak oturumu başlat"
        case .crew: return "Ekibinle birlikte ortak akışa gir"
        case .friend: return "Bir arkadaşınla birlikte odakta kal"
        }
    }

    var statusText: String {
        switch self {
        case .personal: return "Hazır"
        case .crew: return "Takım hazır"
        case .friend: return "Eşleşti"
        }
    }

    var supportText: String {
        switch self {
        case .personal: return "başlamaya uygun"
        case .crew: return "eş zamanlı başlatılabilir"
        case .friend: return "beraber odaklanmaya hazır"
        }
    }

    var ctaTitle: String {
        switch self {
        case .personal: return "Kişisel Focus Başlat"
        case .crew: return "Crew Focus Başlat"
        case .friend: return "Friend Focus Başlat"
        }
    }

    var startLine: String {
        switch self {
        case .personal: return "Kişisel odak akışını başlat"
        case .crew: return "Crew ile ortak focus başlat"
        case .friend: return "Arkadaşınla focus akışını başlat"
        }
    }

    var detailBadge: String {
        switch self {
        case .personal: return "PERSONAL"
        case .crew: return "CREW"
        case .friend: return "FRIEND"
        }
    }
}

enum FocusDurationPreset: Int, CaseIterable, Identifiable {
    case short = 15
    case medium = 25
    case long = 45
    case custom = -1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .short: return "15 dk"
        case .medium: return "25 dk"
        case .long: return "45 dk"
        case .custom: return "Custom"
        }
    }

    var minuteValue: Int? {
        switch self {
        case .short: return 15
        case .medium: return 25
        case .long: return 45
        case .custom: return nil
        }
    }

    var shortLabel: String {
        switch self {
        case .short: return "KISA"
        case .medium: return "ORTA"
        case .long: return "UZUN"
        case .custom: return "ÖZEL"
        }
    }

    var subtitle: String {
        switch self {
        case .short: return "hızlı çalışma"
        case .medium: return "derin odak"
        case .long: return "yoğun akış"
        case .custom: return "özel süre"
        }
    }
}

struct FocusParticipant: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var isHost: Bool
    var isReady: Bool
    var isActive: Bool
}

struct FocusSessionState: Codable {
    var id: UUID
    var mode: FocusMode
    var durationMinutes: Int
    var startDate: Date
    var endDate: Date
    var isPaused: Bool
    var pausedRemainingSeconds: Int?
    var participants: [FocusParticipant]
    var goal: FocusGoal
    var style: FocusStyle
}

extension FocusParticipant {
    static let mockCrew: [FocusParticipant] = [
        FocusParticipant(id: UUID(), name: "Atakan", isHost: true, isReady: true, isActive: true),
        FocusParticipant(id: UUID(), name: "Ece", isHost: false, isReady: true, isActive: false),
        FocusParticipant(id: UUID(), name: "Can", isHost: false, isReady: false, isActive: false)
    ]

    static let mockFriend: [FocusParticipant] = [
        FocusParticipant(id: UUID(), name: "Atakan", isHost: true, isReady: true, isActive: true),
        FocusParticipant(id: UUID(), name: "Ece", isHost: false, isReady: true, isActive: true)
    ]
}

struct FocusCompletionSummary: Identifiable, Codable {
    let id: UUID
    let mode: FocusMode
    let durationMinutes: Int
    let completedAt: Date
    let totalTodayMinutes: Int
    let streakDays: Int
    let completedSessionsToday: Int
    let goal: FocusGoal
    let style: FocusStyle
    let participantCount: Int
}
