//
//  CrewHomeModels.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 4.05.2026.
//

import Foundation
import SwiftUI

// MARK: - Main Crew Home Modes

enum CrewHomeMode: String, CaseIterable, Identifiable {
    case social
    case community

    var id: String { rawValue }

    var title: String {
        switch self {
        case .social:
            return "Social"
        case .community:
            return "Community"
        }
    }

    var icon: String {
        switch self {
        case .social:
            return "person.2.fill"
        case .community:
            return "globe.europe.africa.fill"
        }
    }
}

// MARK: - Social

enum CrewSocialTab: String, CaseIterable, Identifiable {
    case crews
    case friends
    case requests

    var id: String { rawValue }

    var title: String {
        switch self {
        case .crews:
            return "Crewler"
        case .friends:
            return "Arkadaşlar"
        case .requests:
            return "İstekler"
        }
    }

    var shortTitle: String {
        switch self {
        case .crews:
            return "Crew"
        case .friends:
            return "Friend"
        case .requests:
            return "Request"
        }
    }
}

// MARK: - Community

enum CrewCommunityScope: String, CaseIterable, Identifiable {
    case department
    case university
    case country
    case global

    var id: String { rawValue }

    var title: String {
        switch self {
        case .department:
            return "Bölüm"
        case .university:
            return "Üni"
        case .country:
            return "Türkiye"
        case .global:
            return "Global"
        }
    }

    var icon: String {
        switch self {
        case .department:
            return "graduationcap.fill"
        case .university:
            return "building.columns.fill"
        case .country:
            return "flag.fill"
        case .global:
            return "globe"
        }
    }

    var headerEyebrow: String {
        switch self {
        case .department:
            return "CMSE · GÜZ '26 · LIVE"
        case .university:
            return "CAMPUS · LIVE"
        case .country:
            return "TÜRKİYE · LIVE"
        case .global:
            return "III. GLOBAL"
        }
    }

    var headerTitleFirst: String {
        switch self {
        case .department:
            return "The"
        case .university:
            return "Campus"
        case .country:
            return "Türkiye"
        case .global:
            return "The"
        }
    }

    var headerTitleAccent: String {
        switch self {
        case .department:
            return "Arena"
        case .university:
            return "Arena"
        case .country:
            return "Arena"
        case .global:
            return "World"
        }
    }
}

enum CrewLeaderboardRange: String, CaseIterable, Identifiable {
    case week
    case month
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week:
            return "Hafta"
        case .month:
            return "Ay"
        case .all:
            return "All"
        }
    }
}

enum CrewJoinState: String, CaseIterable {
    case join
    case pending
    case full
    case member

    var title: String {
        switch self {
        case .join:
            return "KATIL"
        case .pending:
            return "BEKLİYOR"
        case .full:
            return "DOLU"
        case .member:
            return "ÜYE"
        }
    }
}

// MARK: - Display Models

struct CrewHomeSummary: Equatable {
    let crewCount: Int
    let friendCount: Int
    let requestCount: Int
    let liveCount: Int

    static let empty = CrewHomeSummary(
        crewCount: 0,
        friendCount: 0,
        requestCount: 0,
        liveCount: 0
    )
}
struct CrewArenaStudentContext: Equatable {
    let institutionName: String?
    let majorName: String?
    let institutionCountry: String?
    let courseCount: Int

    static let empty = CrewArenaStudentContext(
        institutionName: nil,
        majorName: nil,
        institutionCountry: nil,
        courseCount: 0
    )

    var universityShortName: String {
        guard let institutionName, !institutionName.isEmpty else {
            return "Üniversite"
        }

        let upper = institutionName.uppercased()

        if upper.contains("DOĞU AKDENİZ") || upper.contains("EASTERN MEDITERRANEAN") {
            return "EMU"
        }

        if upper.contains("BOĞAZİÇİ") {
            return "BOĞ"
        }

        if upper.contains("ORTA DOĞU") || upper.contains("METU") {
            return "METU"
        }

        if upper.contains("İSTANBUL TEKNİK") {
            return "İTÜ"
        }

        let words = institutionName
            .split(separator: " ")
            .filter { !$0.isEmpty }

        let initials = words
            .prefix(3)
            .compactMap { $0.first }
            .map { String($0).uppercased() }
            .joined()

        return initials.isEmpty ? institutionName : initials
    }

    var departmentShortName: String {
        guard let majorName, !majorName.isEmpty else {
            return "Bölüm"
        }

        let upper = majorName.uppercased()

        if upper.contains("YAZILIM") || upper.contains("SOFTWARE") {
            return "CMSE"
        }

        if upper.contains("BİLGİSAYAR") || upper.contains("COMPUTER") {
            return "CENG"
        }

        if upper.contains("HEMŞİRELİK") || upper.contains("NURSING") {
            return "NURS"
        }

        let words = majorName
            .split(separator: " ")
            .filter { !$0.isEmpty }

        let initials = words
            .prefix(4)
            .compactMap { $0.first }
            .map { String($0).uppercased() }
            .joined()

        return initials.isEmpty ? "Bölüm" : initials
    }

    var departmentDisplayName: String {
        guard let majorName, !majorName.isEmpty else {
            return "Bölüm"
        }

        if majorName.count > 18 {
            return String(majorName.prefix(18)) + "."
        }

        return majorName
    }

    var universityDisplayName: String {
        guard let institutionName, !institutionName.isEmpty else {
            return "Üniversite"
        }

        if institutionName.count > 18 {
            return String(institutionName.prefix(18)) + "."
        }

        return institutionName
    }
}

struct CrewSocialCrewCardData: Identifiable, Equatable {
    let id: UUID
    let name: String
    let icon: String
    let colorHex: String
    let memberCount: Int
    let taskCount: Int
    let completedTaskCount: Int
    let isLive: Bool

    // İlk MVP’de gerçek weekly focus backend yok.
    // Şimdilik task/member verisinden türetilmiş premium display hissi veriyoruz.
    let weeklyFocusMinutes: Int
    let rankText: String
    let streakDays: Int

    var progress: Double {
        guard taskCount > 0 else { return 0 }
        return min(max(Double(completedTaskCount) / Double(taskCount), 0), 1)
    }

    var progressPercentText: String {
        "\(Int(progress * 100))%"
    }

    var focusTimeText: String {
        CrewHomeFormatters.focusTime(weeklyFocusMinutes)
    }

    var memberText: String {
        "\(memberCount) ÜYE"
    }

    var progressText: String {
        if taskCount <= 0 {
            return "CREW HAZIR"
        }

        return "\(completedTaskCount)/\(taskCount) TAMAM"
    }

    var statusText: String {
        isLive ? "LIVE NOW" : "ACTIVE"
    }
}

struct CrewSocialFriendCardData: Identifiable, Equatable {
    let id: UUID
    let displayName: String
    let subtitle: String
    let avatarSymbol: String
    let colorHex: String
    let isOnline: Bool
    let isFocusing: Bool
    let focusMinutes: Int?

    var stateText: String {
        if isFocusing {
            return "ODAKTA"
        }

        return isOnline ? "ÇEVRİMİÇİ" : "ÇEVRİMDIŞI"
    }

    var focusText: String {
        guard let focusMinutes else { return subtitle }
        return "Odaklanıyor · \(focusMinutes) dk"
    }
}

struct CrewSocialRequestCardData: Identifiable, Equatable {
    let id: UUID
    let title: String
    let subtitle: String
    let username: String
    let kind: CrewSocialRequestKind
}

enum CrewSocialRequestKind: String, Equatable {
    case incoming
    case sent
    case crewInvite
    case pendingCrew

    var title: String {
        switch self {
        case .incoming:
            return "GELEN"
        case .sent:
            return "GİDEN"
        case .crewInvite:
            return "CREW"
        case .pendingCrew:
            return "BEKLİYOR"
        }
    }

    var accentHex: String {
        switch self {
        case .incoming:
            return "#34D399"
        case .sent:
            return "#F59E0B"
        case .crewInvite:
            return "#FF523D"
        case .pendingCrew:
            return "#8B5CF6"
        }
    }
}

// MARK: - Community Display Models

struct CrewCommunityScopeSummary: Equatable {
    let label: String
    let title: String
    let italicTitle: String
    let subtitle: String
    let icon: String
    let rankDeltaText: String
    let primaryLiveText: String
    let secondaryText: String
    let metrics: [CrewMetricData]
}

struct CrewMetricData: Identifiable, Equatable {
    let id = UUID()
    let value: String
    let title: String
    let accentHex: String
}

struct CrewWeeklyChallengeData: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let title: String
    let italicTitle: String
    let timeLeftText: String
    let participantText: String
    let rewardText: String
    let progress: Double
}

struct CrewStudentLeaderboardEntry: Identifiable, Equatable {
    let id = UUID()
    let rank: Int
    let displayName: String
    let universityShort: String
    let focusMinutes: Int
    let badges: [String]
    let colorHex: String
    let isCurrentUser: Bool
    let deltaRank: Int

    var focusTimeText: String {
        CrewHomeFormatters.focusTime(focusMinutes)
    }
}

struct CrewCommunityCrewEntry: Identifiable, Equatable {
    let id = UUID()
    let rank: Int
    let name: String
    let icon: String
    let universityShort: String
    let focusMinutes: Int
    let memberCount: Int
    let capacity: Int
    let badges: [String]
    let colorHex: String
    let joinState: CrewJoinState
    let deltaRank: Int
    let isLive: Bool

    var focusTimeText: String {
        CrewHomeFormatters.focusTime(focusMinutes)
    }

    var memberText: String {
        "\(memberCount)/\(capacity)"
    }
}

// MARK: - Static Mock Community Data

enum CrewCommunityMockFactory {
    static func summary(
        for scope: CrewCommunityScope,
        studentContext: CrewArenaStudentContext = .empty
    ) -> CrewCommunityScopeSummary {
        let departmentCode = studentContext.departmentShortName
        let departmentName = studentContext.departmentDisplayName
        let universityCode = studentContext.universityShortName
        let universityName = studentContext.universityDisplayName

        switch scope {
        case .department:
            return CrewCommunityScopeSummary(
                label: "SENİN BÖLÜMÜN",
                title: departmentCode,
                italicTitle: departmentName,
                subtitle: "Bölüm içi canlı akademik rekabet",
                icon: "graduationcap.fill",
                rankDeltaText: "↑ 12",
                primaryLiveText: "847 şimdi odakta",
                secondaryText: "\(studentContext.courseCount) aktif ders",
                metrics: [
                    CrewMetricData(value: "340", title: "CREW", accentHex: "#FBBF24"),
                    CrewMetricData(value: "12.4K", title: "ÜYE", accentHex: "#FBBF24"),
                    CrewMetricData(value: "847", title: "LIVE", accentHex: "#A3E635"),
                    CrewMetricData(value: "+18", title: "BUGÜN", accentHex: "#A3E635")
                ]
            )

        case .university:
            return CrewCommunityScopeSummary(
                label: "SENİN ÜNİVERSİTEN",
                title: universityCode,
                italicTitle: universityName,
                subtitle: "Üniversite içi focus ve crew ligi",
                icon: "building.columns.fill",
                rankDeltaText: "↑ 8",
                primaryLiveText: "2.8K şimdi odakta",
                secondaryText: studentContext.institutionCountry ?? "Campus",
                metrics: [
                    CrewMetricData(value: "1.2K", title: "CREW", accentHex: "#FBBF24"),
                    CrewMetricData(value: "41K", title: "ÜYE", accentHex: "#FBBF24"),
                    CrewMetricData(value: "2.8K", title: "LIVE", accentHex: "#A3E635"),
                    CrewMetricData(value: "+124", title: "BUGÜN", accentHex: "#A3E635")
                ]
            )

        case .country:
            return CrewCommunityScopeSummary(
                label: "ÜLKE ARENASI",
                title: "Türkiye",
                italicTitle: "Ligi",
                subtitle: "Üniversiteler arası akademik yarış",
                icon: "flag.fill",
                rankDeltaText: "↑ 21",
                primaryLiveText: "84K şimdi odakta",
                secondaryText: "ülke geneli",
                metrics: [
                    CrewMetricData(value: "29K", title: "CREW", accentHex: "#FBBF24"),
                    CrewMetricData(value: "1.7M", title: "ÜYE", accentHex: "#FBBF24"),
                    CrewMetricData(value: "84K", title: "LIVE", accentHex: "#A3E635"),
                    CrewMetricData(value: "+18K", title: "BUGÜN", accentHex: "#A3E635")
                ]
            )

        case .global:
            return CrewCommunityScopeSummary(
                label: "GLOBAL ARENA",
                title: "10.4M",
                italicTitle: "öğrenci",
                subtitle: "Dünyanın canlı akademik arenası",
                icon: "globe",
                rankDeltaText: "↑ 247K",
                primaryLiveText: "284K şimdi odakta",
                secondaryText: "global",
                metrics: [
                    CrewMetricData(value: "127K", title: "ÜNİ", accentHex: "#FBBF24"),
                    CrewMetricData(value: "340K", title: "CREW", accentHex: "#FBBF24"),
                    CrewMetricData(value: "2.4B", title: "SAAT", accentHex: "#FBBF24"),
                    CrewMetricData(value: "+247K", title: "BUGÜN", accentHex: "#A3E635")
                ]
            )
        }
    }

    static let weeklyChallenge = CrewWeeklyChallengeData(
        label: "HAFTANIN MEYDAN OKUMASI",
        title: "CMSE Focus War",
        italicTitle: "Hafta 18",
        timeLeftText: "3h 24m kaldı",
        participantText: "1,247 katılımcı",
        rewardText: "Diamond Badge + Arena Rank Boost",
        progress: 0.64
    )

    static let students: [CrewStudentLeaderboardEntry] = [
        CrewStudentLeaderboardEntry(
            rank: 2,
            displayName: "Mert K.",
            universityShort: "ODTÜ",
            focusMinutes: 2302,
            badges: ["⚡️", "🔥", "💎"],
            colorHex: "#E5E7EB",
            isCurrentUser: false,
            deltaRank: 2
        ),
        CrewStudentLeaderboardEntry(
            rank: 1,
            displayName: "Deniz Y.",
            universityShort: "BOĞ",
            focusMinutes: 3134,
            badges: ["👑", "🏆", "💎", "⚡️", "🔥"],
            colorHex: "#FBBF24",
            isCurrentUser: false,
            deltaRank: 7
        ),
        CrewStudentLeaderboardEntry(
            rank: 3,
            displayName: "Selin A.",
            universityShort: "İTÜ",
            focusMinutes: 1868,
            badges: ["🥉", "🔥"],
            colorHex: "#C7783A",
            isCurrentUser: false,
            deltaRank: -1
        ),
        CrewStudentLeaderboardEntry(
            rank: 247,
            displayName: "Ali",
            universityShort: "CMSE",
            focusMinutes: 1172,
            badges: ["🔥"],
            colorHex: "#FF523D",
            isCurrentUser: true,
            deltaRank: 18
        )
    ]

    static let topCrews: [CrewCommunityCrewEntry] = [
        CrewCommunityCrewEntry(
            rank: 1,
            name: "Quantum Lab",
            icon: "👑",
            universityShort: "İTÜ",
            focusMinutes: 8842,
            memberCount: 8,
            capacity: 8,
            badges: ["👑", "🏆", "💎"],
            colorHex: "#FBBF24",
            joinState: .full,
            deltaRank: 2,
            isLive: false
        ),
        CrewCommunityCrewEntry(
            rank: 2,
            name: "Code Rangers",
            icon: "🚀",
            universityShort: "BOĞ",
            focusMinutes: 7725,
            memberCount: 4,
            capacity: 6,
            badges: ["🏆", "⚡️", "🔥"],
            colorHex: "#FF523D",
            joinState: .join,
            deltaRank: 1,
            isLive: true
        ),
        CrewCommunityCrewEntry(
            rank: 3,
            name: "Logic Lab",
            icon: "🧠",
            universityShort: "ODTÜ",
            focusMinutes: 5892,
            memberCount: 5,
            capacity: 6,
            badges: ["⚡️", "💎"],
            colorHex: "#8B5CF6",
            joinState: .pending,
            deltaRank: -2,
            isLive: false
        ),
        CrewCommunityCrewEntry(
            rank: 4,
            name: "Green Code",
            icon: "🌱",
            universityShort: "METU",
            focusMinutes: 5224,
            memberCount: 5,
            capacity: 8,
            badges: ["⚡️"],
            colorHex: "#84CC16",
            joinState: .join,
            deltaRank: 3,
            isLive: true
        ),
        CrewCommunityCrewEntry(
            rank: 5,
            name: "Star Builders",
            icon: "⭐️",
            universityShort: "BOĞ",
            focusMinutes: 4491,
            memberCount: 2,
            capacity: 6,
            badges: ["⚡️"],
            colorHex: "#FBBF24",
            joinState: .join,
            deltaRank: 0,
            isLive: false
        )
    ]
}

// MARK: - Formatters

enum CrewHomeFormatters {
    static func focusTime(_ minutes: Int) -> String {
        let safeMinutes = max(0, minutes)
        let hours = safeMinutes / 60
        let mins = safeMinutes % 60

        if hours <= 0 {
            return "\(mins)m"
        }

        if mins == 0 {
            return "\(hours)h"
        }

        return "\(hours)h \(String(format: "%02d", mins))m"
    }

    static func compactNumber(_ value: Int) -> String {
        if value >= 1_000_000_000 {
            return String(format: "%.1fB", Double(value) / 1_000_000_000)
        }

        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }

        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }

        return "\(value)"
    }

    static func pseudoFocusMinutes(
        memberCount: Int,
        completedTaskCount: Int,
        taskCount: Int,
        isLive: Bool
    ) -> Int {
        let base = max(1, memberCount) * 180
        let taskBonus = completedTaskCount * 45
        let liveBonus = isLive ? 212 : 0
        let totalBonus = taskCount * 18

        return base + taskBonus + liveBonus + totalBonus
    }

    static func pseudoStreakDays(
        memberCount: Int,
        completedTaskCount: Int,
        isLive: Bool
    ) -> Int {
        let base = max(1, memberCount) * 7
        let completionBonus = completedTaskCount * 3
        let liveBonus = isLive ? 12 : 0

        return min(99, base + completionBonus + liveBonus)
    }

    static func pseudoRankText(index: Int) -> String {
        "CMSE #\(max(1, index + 6))"
    }
}
