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

enum FocusGoal: String, CaseIterable, Identifiable, Codable {
    case study
    case deepWork
    case reading
    case planning
    case workout

    var id: String { rawValue }

    var title: String {
        switch self {
        case .study: return "Study"
        case .deepWork: return "Deep Work"
        case .reading: return "Reading"
        case .planning: return "Planning"
        case .workout: return "Workout"
        }
    }

    var subtitle: String {
        switch self {
        case .study: return "Ders ve tekrar"
        case .deepWork: return "Kesintisiz çalışma"
        case .reading: return "Okuma akışı"
        case .planning: return "Planlama zamanı"
        case .workout: return "Aktif odak modu"
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
        case .silent: return "Silent"
        case .ambient: return "Ambient"
        case .rain: return "Rain"
        case .library: return "Library"
        }
    }

    var subtitle: String {
        switch self {
        case .silent: return "Sessiz mod"
        case .ambient: return "Yumuşak arka plan"
        case .rain: return "Yağmur sesi hissi"
        case .library: return "Kütüphane atmosferi"
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
