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
            return tr("hd_friends")
        case .requests:
            return tr("ch_requests")
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
            return tr("ch_scope_department")
        case .university:
            return tr("ch_scope_university")
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
    
    func headerEyebrow(studentContext: CrewArenaStudentContext) -> String {
        switch self {
        case .department:
            let department = studentContext.departmentShortName
            let courseCount = studentContext.courseCount

            if courseCount > 0 {
                return tr("ch_eyebrow_dept_courses", department, courseCount)
            }

            return tr("ch_eyebrow_dept_arena", department)

        case .university:
            let university = studentContext.universityShortName

            if university == "Üniversite" {
                return tr("ch_eyebrow_campus")
            }

            return tr("ch_eyebrow_campus_named", university)

        case .country:
            let country = studentContext.institutionCountry?.uppercased() ?? "TÜRKİYE"
            return tr("ch_eyebrow_country", country)

        case .global:
            return tr("ch_eyebrow_global")
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
            return tr("ch_range_week")
        case .month:
            return tr("ch_range_month")
        case .all:
            return tr("ch_range_all")
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
            return tr("ch_join_caps")
        case .pending:
            return tr("ch_pending_caps")
        case .full:
            return tr("ch_full_caps")
        case .member:
            return tr("ch_member_caps")
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

    // Real data only. `rankText` is nil (no real ranking system yet) and
    // `streakDays` 0 means "no streak" — the UI hides those badges instead of
    // showing invented numbers.
    let weeklyFocusMinutes: Int
    let rankText: String?
    let streakDays: Int

    // Weekly focus goal. `weeklyGoalMinutes` 0 = no goal set (row hidden);
    // `thisWeekFocusMinutes` is the crew's real focus total for the current week.
    let thisWeekFocusMinutes: Int
    let weeklyGoalMinutes: Int
    
    let lastMessageText: String?
    let unreadCount: Int
    let isPinned: Bool
    let isMuted: Bool
    let isArchived: Bool

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

    var goalProgress: Double {
        guard weeklyGoalMinutes > 0 else { return 0 }
        return min(max(Double(thisWeekFocusMinutes) / Double(weeklyGoalMinutes), 0), 1)
    }

    var goalProgressText: String {
        "\(CrewHomeFormatters.focusTime(thisWeekFocusMinutes)) / \(CrewHomeFormatters.focusTime(weeklyGoalMinutes))"
    }

    var memberText: String {
        tr("ch_member_count_caps", memberCount)
    }

    var progressText: String {
        if taskCount <= 0 {
            return "CREW HAZIR"
        }

        return "\(completedTaskCount)/\(taskCount) TAMAM"
    }

    var statusText: String {
        isLive ? tr("ch_live_caps") : tr("ch_active_caps")
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

    /// Pro social-stats layer (nil when not shared / not yet loaded).
    var streak: Int? = nil
    var level: Int? = nil

    var hasSharedStats: Bool { streak != nil || level != nil }

    var stateText: String {
        if isFocusing {
            return "ODAKTA"
        }

        return isOnline ? tr("ch_online_caps") : tr("ch_offline_caps")
    }

    var focusText: String {
        guard let focusMinutes else { return subtitle }
        return "\(tr("ch_focusing")) · \(tr("rel_min_short_n", focusMinutes))"
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
            return tr("ch_sent_label_caps")
        case .crewInvite:
            return "CREW"
        case .pendingCrew:
            return tr("ch_pending_caps")
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
                label: tr("ch_sum_dept_label"),
                title: departmentCode,
                italicTitle: departmentName,
                subtitle: tr("ch_sum_dept_sub"),
                icon: "graduationcap.fill",
                rankDeltaText: "↑ 12",
                primaryLiveText: tr("ch_focusing_now", "847"),
                secondaryText: tr("ch_active_courses", studentContext.courseCount),
                metrics: [
                    CrewMetricData(value: "340", title: "CREW", accentHex: "#FBBF24"),
                    CrewMetricData(value: "12.4K", title: tr("ch_member_caps"), accentHex: "#FBBF24"),
                    CrewMetricData(value: "847", title: tr("ch_metric_live"), accentHex: "#A3E635"),
                    CrewMetricData(value: "+18", title: tr("ch_metric_today"), accentHex: "#A3E635")
                ]
            )

        case .university:
            return CrewCommunityScopeSummary(
                label: tr("ch_sum_uni_label"),
                title: universityCode,
                italicTitle: universityName,
                subtitle: tr("ch_sum_uni_sub"),
                icon: "building.columns.fill",
                rankDeltaText: "↑ 8",
                primaryLiveText: tr("ch_focusing_now", "2.8K"),
                secondaryText: studentContext.institutionCountry ?? "Campus",
                metrics: [
                    CrewMetricData(value: "1.2K", title: "CREW", accentHex: "#FBBF24"),
                    CrewMetricData(value: "41K", title: tr("ch_member_caps"), accentHex: "#FBBF24"),
                    CrewMetricData(value: "2.8K", title: tr("ch_metric_live"), accentHex: "#A3E635"),
                    CrewMetricData(value: "+124", title: tr("ch_metric_today"), accentHex: "#A3E635")
                ]
            )

        case .country:
            return CrewCommunityScopeSummary(
                label: tr("ch_sum_country_label"),
                title: "Türkiye",
                italicTitle: tr("ch_sum_league"),
                subtitle: tr("ch_sum_country_sub"),
                icon: "flag.fill",
                rankDeltaText: "↑ 21",
                primaryLiveText: tr("ch_focusing_now", "84K"),
                secondaryText: tr("ch_nationwide"),
                metrics: [
                    CrewMetricData(value: "29K", title: "CREW", accentHex: "#FBBF24"),
                    CrewMetricData(value: "1.7M", title: tr("ch_member_caps"), accentHex: "#FBBF24"),
                    CrewMetricData(value: "84K", title: tr("ch_metric_live"), accentHex: "#A3E635"),
                    CrewMetricData(value: "+18K", title: tr("ch_metric_today"), accentHex: "#A3E635")
                ]
            )

        case .global:
            return CrewCommunityScopeSummary(
                label: "GLOBAL ARENA",
                title: "10.4M",
                italicTitle: tr("ch_students_lc"),
                subtitle: tr("ch_sum_global_sub"),
                icon: "globe",
                rankDeltaText: "↑ 247K",
                primaryLiveText: tr("ch_focusing_now", "284K"),
                secondaryText: "global",
                metrics: [
                    CrewMetricData(value: "127K", title: tr("ch_metric_uni"), accentHex: "#FBBF24"),
                    CrewMetricData(value: "340K", title: "CREW", accentHex: "#FBBF24"),
                    CrewMetricData(value: "2.4B", title: tr("ch_metric_hours"), accentHex: "#FBBF24"),
                    CrewMetricData(value: "+247K", title: tr("ch_metric_today"), accentHex: "#A3E635")
                ]
            )
        }
    }

}

// MARK: - Weekly focus goal (offline cache)
//
// The shared goal lives on the backend (crews.weekly_goal_minutes) and syncs
// through CrewStore; this UserDefaults copy is only the offline/last-known
// cache so the card renders instantly before the snapshot arrives.

enum CrewWeeklyGoalStore {

    static let presetsMinutes = [120, 300, 600, 1200]  // 2h, 5h, 10h, 20h

    private static func key(_ crewID: UUID) -> String {
        "crew.weeklyGoalMinutes.\(crewID.uuidString)"
    }

    /// 0 = no goal set.
    static func goalMinutes(for crewID: UUID) -> Int {
        max(0, UserDefaults.standard.integer(forKey: key(crewID)))
    }

    static func setGoalMinutes(_ minutes: Int, for crewID: UUID) {
        if minutes <= 0 {
            UserDefaults.standard.removeObject(forKey: key(crewID))
        } else {
            UserDefaults.standard.set(minutes, forKey: key(crewID))
        }
    }
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

    /// The crew's real focus total (minutes) for the current calendar week.
    static func weeklyFocusMinutes(
        records: [CrewFocusRecordDTO],
        crewID: UUID,
        now: Date = Date()
    ) -> Int {
        let cal = Calendar.current
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }

        return records
            .filter { $0.crew_id == crewID }
            .compactMap { record -> Int? in
                guard let created = record.created_at.flatMap({ CrewDateParser.parse($0) }),
                      created >= weekStart else { return nil }
                return record.minutes
            }
            .reduce(0, +)
    }

    /// REAL crew streak: consecutive days (counting back from today) on which the
    /// crew logged at least one focus session. Today not having one yet doesn't
    /// break the streak — counting simply starts from yesterday.
    static func crewStreakDays(
        records: [CrewFocusRecordDTO],
        crewID: UUID,
        now: Date = Date()
    ) -> Int {
        let cal = Calendar.current
        let days = Set(
            records
                .filter { $0.crew_id == crewID }
                .compactMap { $0.created_at.flatMap { CrewDateParser.parse($0) } }
                .map { cal.startOfDay(for: $0) }
        )
        guard !days.isEmpty else { return 0 }

        var streak = 0
        var cursor = cal.startOfDay(for: now)
        if days.contains(cursor) { streak += 1 }
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: cursor) else { return streak }
        cursor = yesterday

        while days.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }
}
