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
        case .personal: return tr("fm_mode_personal")
        case .crew: return "Crew"
        case .friend: return tr("fm_mode_friend")
        }
    }

    var heroEyebrow: String {
        switch self {
        case .personal: return tr("fm_mode_personal")
        case .crew: return "Crew"
        case .friend: return tr("fm_mode_friend")
        }
    }

    var heroTitle: String {
        switch self {
        case .personal: return tr("fm_personal_focus")
        case .crew: return "Crew\nFocus"
        case .friend: return "Friend\nFocus"
        }
    }

    var heroSubtitle: String {
        switch self {
        case .personal: return tr("fm_personal_desc")
        case .crew: return tr("fm_crew_desc")
        case .friend: return tr("fm_friend_desc")
        }
    }

    var statusText: String {
        switch self {
        case .personal: return tr("hf_ready")
        case .crew: return tr("fv_team_ready")
        case .friend: return tr("fv_matched")
        }
    }

    var supportText: String {
        switch self {
        case .personal: return tr("fm_ready_start")
        case .crew: return tr("fm_sync_start")
        case .friend: return tr("fm_ready_together")
        }
    }

    var ctaTitle: String {
        switch self {
        case .personal: return tr("fv_start_personal")
        case .crew: return tr("fv_start_crew")
        case .friend: return tr("fv_start_friend")
        }
    }

    var startLine: String {
        switch self {
        case .personal: return tr("fm_personal_flow")
        case .crew: return tr("fm_crew_flow")
        case .friend: return tr("fm_friend_flow")
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
        case .custom: return tr("fm_custom_caps")
        }
    }

    var subtitle: String {
        switch self {
        case .short: return tr("fm_quick_study")
        case .medium: return "derin odak"
        case .long: return tr("fm_intense_flow")
        case .custom: return tr("fm_custom_time")
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
    let previousMinutes: Int? 
}

enum FocusGoal: String, CaseIterable, Identifiable, Codable {
    case study
    case deepWork
    case reading
    case planning
    case workout

    var id: String { rawValue }

    var title: String {
        switch self {
        case .study: return tr("fm_goal_study")
        case .deepWork: return tr("fm_goal_deep")
        case .reading: return tr("fm_goal_reading")
        case .planning: return tr("fm_goal_planning")
        case .workout: return tr("fm_goal_workout")
        }
    }

    var subtitle: String {
        switch self {
        case .study: return tr("fm_study_sub")
        case .deepWork: return tr("fm_uninterrupted")
        case .reading: return tr("fm_reading")
        case .planning: return tr("fm_planning")
        case .workout: return tr("fm_workout_sub")
        }
    }

    var icon: String {
        switch self {
        case .study: return "book.closed.fill"
        case .deepWork: return "brain.head.profile"
        case .reading: return "text.book.closed.fill"
        case .planning: return "calendar"
        case .workout: return "figure.run"
        }
    }
}

enum FocusStyle: String, CaseIterable, Identifiable, Codable {
    case silent
    case ambient
    case rain
    case library

    var id: String { rawValue }

    var title: String {
        switch self {
        case .silent: return tr("fm_style_silent")
        case .ambient: return tr("fm_style_ambient")
        case .rain: return tr("fm_style_rain")
        case .library: return tr("fm_style_library")
        }
    }

    var subtitle: String {
        switch self {
        case .silent: return tr("fm_silent_sub")
        case .ambient: return tr("fm_soft_bg")
        case .rain: return tr("fm_rain")
        case .library: return tr("fm_library")
        }
    }

    var icon: String {
        switch self {
        case .silent: return "speaker.slash.fill"
        case .ambient: return "waveform"
        case .rain: return "cloud.rain.fill"
        case .library: return "building.columns.fill"
        }
    }
}
