//
//  BackendCrewDetailView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import SwiftUI
import UIKit

private enum BackendCrewArenaPalette {
    static let backgroundTop = Color(crewDetailHex: "#05060D")
    static let backgroundMid = Color(crewDetailHex: "#070713")
    static let backgroundBottom = Color(crewDetailHex: "#07040C")

    static let blue = Color(crewDetailHex: "#1593FF")
    static let cyan = Color(crewDetailHex: "#2DD4FF")
    static let purple = Color(crewDetailHex: "#7C3AED")
    static let coral = Color(crewDetailHex: "#FF5A44")
    static let gold = Color(crewDetailHex: "#FBBF24")
    static let green = Color(crewDetailHex: "#A3E635")

    static let surface = Color(crewDetailHex: "#101118")
    static let surface2 = Color(crewDetailHex: "#171821")

    static var appGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(crewDetailHex: "#1E6BFF"),
                Color(crewDetailHex: "#7C3AED")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var crewGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(crewDetailHex: "#1E6BFF").opacity(0.88),
                Color(crewDetailHex: "#7C3AED").opacity(0.86),
                Color(crewDetailHex: "#FF5A44").opacity(0.58)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct BackendCrewDetailView: View {
    let crew: CrewDTO

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var session: SessionStore

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private var palette: ThemePalette { ThemePalette() }

    @State private var showAddMember = false
    @State private var showCreateTask = false
    @State private var showInviteSheet = false
    @State private var selectedTask: CrewTaskDTO?

    @State private var inviteCode = ""
    @State private var errorMessage: String?

    @State private var showHeroCard = false
    @State private var showStatsRow = false
    @State private var showMembersSection = false
    @State private var showTasksSection = false
    @State private var showFocusSection = false
    @State private var showActivitySection = false
    @State private var showShareSheet = false
    @State private var didInitialLoad = false
    @State private var memberToRemove: CrewMemberDTO?
    @State private var showRemoveMemberConfirm = false
    @State private var inviteCopied = false
    @State private var showDeleteCrewConfirm = false
    @State private var isDeletingCrew = false
    @State private var taskFilter: CrewTaskFilter = .open
    
    enum CrewTaskFilter: String, CaseIterable, Identifiable {
            case open
            case done
            case all

            var id: String { rawValue }

            var title: String {
                switch self {
                case .open: return "Açık"
                case .done: return "Biten"
                case .all: return "Tümü"
                }
            }
        }

    var body: some View {
        ZStack(alignment: .top) {
            ambientBackground

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    Color.clear.frame(height: 6)

                    customHeader

                    crewContextLine

                    heroCard(
                        memberCount: crewMembers.count,
                        totalTasks: sortedCrewTasks.count,
                        progress: crewProgressValue
                    )

                    quickStatsRow(
                        completed: completedTasksCount,
                        pending: pendingTasksCount,
                        memberCount: crewMembers.count
                    )

                    performanceCard

                    membersSection(crewMembers)

                    tasksSection(filteredCrewTasks)

                    focusComingSoonStrip(memberCount: crewMembers.count)

                    backendActivitySection

                    Color.clear.frame(height: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 18)
            }
            .refreshable {
                await loadCrewDetail()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard !didInitialLoad else { return }
            didInitialLoad = true

            await loadCrewDetail()
            playEntranceAnimations()
        }
        .onAppear {
            crewStore.subscribeToCrewRealtime(crewID: crew.id)

            Task {
                await loadCrewDetail()
            }
        }
        .onDisappear {
            crewStore.unsubscribe()
        }
        .sheet(isPresented: $showAddMember) {
            AddCrewMemberView(crewID: crew.id)
                .environmentObject(crewStore)
        }
        .sheet(isPresented: $showCreateTask) {
            BackendCreateCrewTaskSheet(
                crew: crew,
                members: crewStore.crewMembers.filter { $0.crew_id == crew.id },
                memberProfiles: crewStore.memberProfiles
            )
            .environmentObject(crewStore)
            .environmentObject(session)
        }
        .sheet(item: $selectedTask) { task in
            BackendCrewTaskDetailView(task: task, crew: crew)
                .environmentObject(crewStore)
                .environmentObject(session)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [
                String(
                    format: String(localized: "backend_crew_share_text"),
                    inviteCode
                )
            ])
        }
        .sheet(isPresented: $showInviteSheet, onDismiss: {
            inviteCopied = false
        }) {
            inviteSheet
        }
        .alert(
            String(localized: "common_error"),
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button(String(localized: "common_ok"), role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? String(localized: "common_unknown_error"))
        }
        .confirmationDialog(
            String(localized: "backend_crew_remove_member_title"),
            isPresented: $showRemoveMemberConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "backend_crew_remove_member_action"), role: .destructive) {
                guard let member = memberToRemove else { return }

                guard member.role.lowercased() != "owner" else {
                    errorMessage = String(localized: "backend_crew_owner_cannot_be_removed")
                    return
                }

                Task {
                    do {
                        try await crewStore.removeMember(member, from: crew.id)
                        memberToRemove = nil
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }

            Button(String(localized: "common_cancel"), role: .cancel) {
                memberToRemove = nil
            }
        } message: {
            Text("backend_crew_remove_member_message")
        }
        .confirmationDialog(
            String(localized: "backend_crew_delete_title"),
            isPresented: $showDeleteCrewConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "backend_crew_delete_action"), role: .destructive) {
                Task {
                    guard let currentUserID = session.currentUser?.id else { return }

                    isDeletingCrew = true

                    do {
                        try await crewStore.deleteCrew(
                            crewID: crew.id,
                            currentUserID: currentUserID
                        )
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                    }

                    isDeletingCrew = false
                }
            }

            Button(String(localized: "common_cancel"), role: .cancel) { }
        } message: {
            Text("backend_crew_delete_message")
        }
    }

    @MainActor
    private func loadCrewDetail() async {
        await crewStore.loadMembers(for: crew.id)
        await crewStore.loadMemberProfiles(for: crewStore.crewMembers)
        await crewStore.loadTasks(for: crew.id)
        await crewStore.loadActivities(for: crew.id)
        await crewStore.loadFocusRecords(for: crew.id)
    }
}

extension BackendCrewDetailView {
    
    var inviteSheet: some View {
        VStack(spacing: 22) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BackendCrewArenaPalette.appGradient)
                .frame(width: 74, height: 74)
                .overlay(
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(.white)
                )

            VStack(spacing: 8) {
                Text("Davet Kodu")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)

                Text("Bu kodu arkadaşlarınla paylaşarak crew’e davet edebilirsin.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.52))
                    .multilineTextAlignment(.center)
            }

            Text(inviteCode)
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .textSelection(.enabled)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.075))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )

            Button {
                UIPasteboard.general.string = inviteCode
                inviteCopied = true
            } label: {
                Text(inviteCopied ? String(localized: "common_copied") : String(localized: "common_copy"))
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        Capsule()
                            .fill(BackendCrewArenaPalette.green)
                    )
            }
            .buttonStyle(.plain)

            if inviteCopied {
                Text("backend_crew_code_copied_success")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.52))
                    .transition(.opacity)
            }
        }
        .padding(24)
        .background(Color.black)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    var ambientBackground: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    BackendCrewArenaPalette.backgroundTop,
                    BackendCrewArenaPalette.backgroundMid,
                    BackendCrewArenaPalette.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(BackendCrewArenaPalette.blue.opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 96)
                .offset(x: 165, y: -245)

            Circle()
                .fill(BackendCrewArenaPalette.purple.opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 110)
                .offset(x: -175, y: 500)

            Circle()
                .fill(BackendCrewArenaPalette.coral.opacity(0.08))
                .frame(width: 270, height: 270)
                .blur(radius: 100)
                .offset(x: 170, y: 280)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.16),
                    Color.clear,
                    Color.black.opacity(0.42)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    var crewMembers: [CrewMemberDTO] {
        crewStore.crewMembers.filter { $0.crew_id == crew.id }
    }

    private static let backendISOFormatter = ISO8601DateFormatter()

    var sortedCrewTasks: [CrewTaskDTO] {
        crewStore.crewTasks
            .filter { $0.crew_id == crew.id }
            .sorted {
                if $0.is_done != $1.is_done {
                    return !$0.is_done && $1.is_done
                }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
    }
    
    var crewContextLine: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(BackendCrewArenaPalette.green)
                .frame(width: 8, height: 8)

            Text("Ortak görevler · üyeler · takım akışı")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.42))

            Spacer()
        }
        .padding(.horizontal, 4)
    }
    
    var performanceCard: some View {
        let minutes = totalFocusMinutes
        let badgeTitle = CrewBadgeHelper.title(for: minutes)
        let badgeColor = CrewBadgeHelper.color(for: minutes)
        let nextTarget = CrewBadgeHelper.nextTarget(for: minutes)
        let topMember = topThreeLeaderboard.first

        return VStack(alignment: .leading, spacing: 16) {
            sectionTitle(
                eyebrow: "CREW RHYTHM",
                title: "Performans",
                italic: "özeti"
            )

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    miniIcon(systemName: "medal.fill", tint: badgeColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(badgeTitle)
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(focusTimeText(minutes))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.52))
                    }

                    if let nextTarget {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text("Sonraki rozet")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .tracking(1.1)
                                    .foregroundStyle(.white.opacity(0.38))

                                Spacer()

                                Text(focusTimeText(max(0, nextTarget - minutes)))
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.52))
                            }

                            ProgressView(value: CrewBadgeHelper.progress(for: minutes))
                                .tint(badgeColor)
                                .scaleEffect(y: 1.15)
                        }
                    }

                    HStack(spacing: 7) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(BackendCrewArenaPalette.coral)

                        Text("Seri \(currentStreakText)")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(BackendCrewArenaPalette.coral)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 164, alignment: .leading)
                .padding(16)
                .background(detailSurface(cornerRadius: 24, tint: badgeColor))

                VStack(alignment: .leading, spacing: 12) {
                    miniIcon(systemName: "crown.fill", tint: BackendCrewArenaPalette.gold)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bugünün Lideri")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(.white)

                        if let topMember {
                            Text(topMember.name)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white.opacity(0.78))
                                .lineLimit(1)

                            Text("\(topMember.minutes) dk odak")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(BackendCrewArenaPalette.gold)
                        } else {
                            Text("Henüz focus kaydı yok")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.52))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if !topThreeLeaderboard.isEmpty {
                        HStack(spacing: 7) {
                            ForEach(Array(topThreeLeaderboard.prefix(3).enumerated()), id: \.offset) { index, entry in
                                VStack(spacing: 4) {
                                    Text("#\(index + 1)")
                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                        .foregroundStyle(index == 0 ? BackendCrewArenaPalette.gold : .white.opacity(0.42))

                                    Text("\(entry.minutes)")
                                        .font(.system(size: 12, weight: .black, design: .monospaced))
                                        .foregroundStyle(.white)
                                        .monospacedDigit()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .fill(Color.white.opacity(0.055))
                                )
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 164, alignment: .leading)
                .padding(16)
                .background(detailSurface(cornerRadius: 24, tint: BackendCrewArenaPalette.gold))
            }
        }
        .padding(18)
        .background(cardBackground)
    }
    
    var filteredCrewTasks: [CrewTaskDTO] {
            switch taskFilter {
            case .open:
                return sortedCrewTasks.filter { !$0.is_done }
            case .done:
                return sortedCrewTasks.filter(\.is_done)
            case .all:
                return sortedCrewTasks
            }
        }

    var completedTasksCount: Int {
        sortedCrewTasks.filter(\.is_done).count
    }

    var pendingTasksCount: Int {
        max(0, sortedCrewTasks.count - completedTasksCount)
    }

    var crewProgressValue: Double {
        sortedCrewTasks.isEmpty ? 0 : Double(completedTasksCount) / Double(sortedCrewTasks.count)
    }

    var totalFocusMinutes: Int {
        crewStore.crewFocusRecords
            .filter { $0.crew_id == crew.id }
            .reduce(0) { $0 + $1.minutes }
    }

    var currentStreakText: String {
        let calendar = Calendar.current

        let uniqueDays = Set(
            crewStore.crewFocusRecords
                .filter { $0.crew_id == crew.id }
                .compactMap { record -> Date? in
                    guard let raw = record.created_at else { return nil }
                    return Self.backendISOFormatter.date(from: raw)
                }
                .map { calendar.startOfDay(for: $0) }
        )

        guard !uniqueDays.isEmpty else { return "0" }

        let sortedDays = uniqueDays.sorted(by: >)

        var streak = 0
        var cursor = calendar.startOfDay(for: Date())

        for day in sortedDays {
            if calendar.isDate(day, inSameDayAs: cursor) {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = previousDay
            } else if day < cursor {
                break
            }
        }

        return "\(streak)"
    }

    var todayLeaderboard: [(name: String, minutes: Int)] {
        let todayPrefix = Self.backendISOFormatter.string(from: Date()).prefix(10)

        let todayRecords = crewStore.crewFocusRecords.filter {
            $0.crew_id == crew.id &&
            ($0.created_at ?? "").hasPrefix(String(todayPrefix))
        }

        let grouped = Dictionary(grouping: todayRecords, by: { $0.member_name })

        return grouped
            .map { name, records in
                (name: name, minutes: records.reduce(0) { $0 + $1.minutes })
            }
            .sorted { lhs, rhs in
                if lhs.minutes == rhs.minutes {
                    return lhs.name < rhs.name
                }
                return lhs.minutes > rhs.minutes
            }
    }

    var topThreeLeaderboard: [(name: String, minutes: Int)] {
        Array(todayLeaderboard.prefix(3))
    }

    var leaderboardCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("backend_crew_leaderboard")
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)

                Spacer()

                Text("common_today")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
            }

            if topThreeLeaderboard.isEmpty {
                Text("backend_crew_no_focus_today")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            } else {
                ForEach(Array(topThreeLeaderboard.enumerated()), id: \.offset) { index, entry in
                    CrewLeaderboardRow(
                        rank: index + 1,
                        name: entry.name,
                        minutes: entry.minutes,
                        palette: palette
                    )
                }
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    var backendBadgeCard: some View {
        let minutes = totalFocusMinutes
        let badgeTitle = CrewBadgeHelper.title(for: minutes)
        let badgeColor = CrewBadgeHelper.color(for: minutes)
        let nextTarget = CrewBadgeHelper.nextTarget(for: minutes)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("backend_crew_badge")
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)

                    Text("backend_crew_badge_subtitle")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer()

                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(badgeColor)
            }

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(badgeColor.opacity(0.16))
                        .frame(width: 56, height: 56)

                    Image(systemName: "medal.fill")
                        .font(.title3)
                        .foregroundStyle(badgeColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(badgeTitle)
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)

                    Text(focusTimeText(minutes))
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(badgeColor.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(badgeColor.opacity(0.24), lineWidth: 1)
                    )
            )

            if let nextTarget {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("backend_crew_next_badge")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.secondaryText)

                        Spacer()

                        Text(String(format: String(localized: "backend_crew_time_left"), focusTimeText(max(0, nextTarget - minutes))))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(palette.secondaryText)
                    }

                    ProgressView(value: CrewBadgeHelper.progress(for: minutes))
                        .tint(badgeColor)
                        .scaleEffect(y: 1.5)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)

                Text(String(format: String(localized: "backend_crew_streak"), currentStreakText))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    func focusTimeText(_ minutes: Int) -> String {
        let isTurkish = Locale.current.language.languageCode?.identifier == "tr"
        let hours = minutes / 60
        let mins = minutes % 60

        if hours > 0 {
            return isTurkish ? "\(hours) sa \(mins) dk" : "\(hours)h \(mins)m"
        } else {
            return isTurkish ? "\(mins) dk" : "\(mins)m"
        }
    }

    func activityIcon(for text: String) -> String {
        let lower = text.lowercased()

        if lower.contains("comment") {
            return "text.bubble.fill"
        } else if lower.contains("vote") {
            return "hand.thumbsup.fill"
        } else if lower.contains("complete") || lower.contains("done") {
            return "checkmark.circle.fill"
        } else if lower.contains("status") {
            return "arrow.triangle.2.circlepath.circle.fill"
        } else if lower.contains("create") {
            return "plus.circle.fill"
        } else if lower.contains("reaction") {
            return "face.smiling.fill"
        } else {
            return "bolt.fill"
        }
    }

    var backendActivitySection: some View {
        let items = Array(crewStore.crewActivities.filter { $0.crew_id == crew.id }.prefix(4))

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                sectionTitle(
                    eyebrow: "LIVE ACTIVITY",
                    title: "Aktivite",
                    italic: "akışı"
                )

                Spacer()

                Text("\(items.count)")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(Capsule().fill(Color.white.opacity(0.075)))
            }

            if items.isEmpty {
                emptyMiniState(text: String(localized: "backend_crew_no_activity"))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        backendActivityRow(
                            title: item.member_name,
                            subtitle: item.action_text,
                            time: activityTimeText(item.created_at),
                            isLast: index == items.count - 1
                        )
                    }
                }
                .padding(16)
                .background(detailSurface(cornerRadius: 24, tint: BackendCrewArenaPalette.purple))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    func backendActivityRow(title: String, subtitle: String, time: String, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(spacing: 0) {
                Image(systemName: activityIcon(for: subtitle))
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(BackendCrewArenaPalette.cyan)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(BackendCrewArenaPalette.cyan.opacity(0.13))
                    )

                if !isLast {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 2, height: 32)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(2)

                Text(time)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.32))
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    func activityTimeText(_ raw: String?) -> String {
        guard let raw else { return String(localized: "common_now") }

        if let date = Self.backendISOFormatter.date(from: raw) {
            let out = DateFormatter()
            out.dateFormat = "HH:mm"
            return out.string(from: date)
        }

        return String(localized: "common_now")
    }

    var customHeader: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(Color.white.opacity(0.075))
                            .overlay(
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 3) {
                Text("CREW SPACE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(BackendCrewArenaPalette.cyan)

                Text(crew.name)
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer()

            Menu {
                Button(role: .destructive) {
                    showDeleteCrewConfirm = true
                } label: {
                    Label(String(localized: "backend_crew_delete_action"), systemImage: "trash")
                }
            } label: {
                ZStack {
                    if isDeletingCrew {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 19, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 46, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(Color.white.opacity(0.075))
                        .overlay(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
            }
            .disabled(isDeletingCrew)
        }
    }

    func heroCard(memberCount: Int, totalTasks: Int, progress: Double) -> some View {
        let accent = hexColor(crew.color_hex)
        let percent = Int(progress * 100)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.90),
                                BackendCrewArenaPalette.purple.opacity(0.82),
                                BackendCrewArenaPalette.coral.opacity(0.65)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 62, height: 62)
                    .overlay(
                        Image(systemName: crew.icon)
                            .font(.system(size: 26, weight: .black))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text("ACTIVE CREW")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(BackendCrewArenaPalette.cyan)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(crew.name)
                            .font(.system(size: 30, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)

                        Text("crew")
                            .font(.system(size: 25, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(BackendCrewArenaPalette.cyan)
                    }

                    Text(heroSubtitle(memberCount: memberCount, totalTasks: totalTasks))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(2)
                        .minimumScaleFactor(0.70)
                }

                Spacer()
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("İlerleme")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.42))

                    Text(totalTasks == 0 ? "Crew hazır" : "\(completedTasksCount)/\(totalTasks) tamamlandı")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)
                }

                Spacer()

                Text("%\(percent)")
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.09))
                        .frame(height: 7)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    BackendCrewArenaPalette.cyan,
                                    BackendCrewArenaPalette.purple,
                                    BackendCrewArenaPalette.coral
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(32, geo.size.width * max(progress, 0.10)), height: 7)
                }
            }
            .frame(height: 7)

            HStack(spacing: 10) {
                Button {
                    Task {
                        guard let user = session.currentUser else { return }

                        do {
                            let code = try await crewStore.createInvite(
                                for: crew.id,
                                userID: user.id
                            )
                            inviteCode = code
                            showInviteSheet = true
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Label("Davet Et", systemImage: "person.badge.plus")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(BackendCrewArenaPalette.green)
                        .padding(.horizontal, 14)
                        .frame(height: 42)
                        .background(
                            Capsule()
                                .fill(BackendCrewArenaPalette.green.opacity(0.13))
                                .overlay(
                                    Capsule()
                                        .stroke(BackendCrewArenaPalette.green.opacity(0.22), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)

                Button {
                    showCreateTask = true
                } label: {
                    Label("Görev", systemImage: "plus")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .frame(height: 42)
                        .background(
                            Capsule()
                                .fill(BackendCrewArenaPalette.blue)
                        )
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.14),
                            BackendCrewArenaPalette.purple.opacity(0.12),
                            BackendCrewArenaPalette.surface.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(accent.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.24), radius: 20, y: 12)
        )
    }
    func heroSubtitle(memberCount: Int, totalTasks: Int) -> String {
            if totalTasks == 0 {
                return "Crew hazır. İlk ortak görevi ekleyerek akışı başlat."
            }

            if pendingTasksCount == 0 {
                return "Bugün için tüm ortak görevler tamamlandı."
            }

            return "\(pendingTasksCount) açık görev, \(memberCount) üyeyle akış devam ediyor."
        }
    
    func quickStatsRow(completed: Int, pending: Int, memberCount: Int) -> some View {
        HStack(spacing: 10) {
            detailMiniStatCard(
                title: "Biten",
                value: "\(completed)",
                icon: "checkmark.circle.fill",
                tint: BackendCrewArenaPalette.green
            )

            detailMiniStatCard(
                title: "Açık",
                value: "\(pending)",
                icon: "clock.fill",
                tint: BackendCrewArenaPalette.coral
            )

            detailMiniStatCard(
                title: "Üye",
                value: "\(memberCount)",
                icon: "person.3.fill",
                tint: BackendCrewArenaPalette.cyan
            )
        }
    }

    func detailMiniStatCard(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(tint)

            Text(value)
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(.white)
                .monospacedDigit()

            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.42))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 96)
        .padding(.horizontal, 14)
        .background(detailSurface(cornerRadius: 22, tint: tint))
    }
    var memberProfilesByID: [UUID: ProfileDTO] {
        Dictionary(uniqueKeysWithValues: crewStore.memberProfiles.map { ($0.id, $0) })
    }
    
    func detailSurface(cornerRadius: CGFloat, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.055),
                        BackendCrewArenaPalette.purple.opacity(0.040),
                        Color.white.opacity(0.038)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tint.opacity(0.13), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 14, y: 8)
    }

    func membersSection(_ crewMembers: [CrewMemberDTO]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                sectionTitle(
                    eyebrow: "CREW MEMBERS",
                    title: "Üyeler",
                    italic: "takımı"
                )

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        Task {
                            guard let user = session.currentUser else { return }

                            do {
                                let code = try await crewStore.createInvite(
                                    for: crew.id,
                                    userID: user.id
                                )
                                inviteCode = code
                                showInviteSheet = true
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(BackendCrewArenaPalette.green)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(BackendCrewArenaPalette.green.opacity(0.13))
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showAddMember = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(BackendCrewArenaPalette.blue)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(BackendCrewArenaPalette.blue.opacity(0.13))
                            )
                    }
                    .buttonStyle(.plain)

                    Text("\(crewMembers.count)")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 36)
                        .background(Capsule().fill(Color.white.opacity(0.075)))
                }
            }

            if crewMembers.isEmpty {
                emptyMiniState(text: String(localized: "backend_crew_no_members"))
            } else {
                VStack(spacing: 10) {
                    ForEach(crewMembers) { member in
                        let profile = memberProfilesByID[member.user_id]
                        memberRow(member: member, profile: profile)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }
    
    func memberRow(member: CrewMemberDTO, profile: ProfileDTO?) -> some View {
        let isOwner = member.role.lowercased() == "owner"
        let tint = isOwner ? BackendCrewArenaPalette.gold : BackendCrewArenaPalette.cyan

        return HStack(spacing: 13) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.22),
                            BackendCrewArenaPalette.purple.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 52, height: 52)
                .overlay(
                    Text(memberInitial(from: profile))
                        .font(.system(size: 21, weight: .black))
                        .foregroundStyle(tint)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(memberName(from: profile))
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("@\(memberUsername(from: profile))")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.40))
                    .lineLimit(1)
            }

            Spacer()

            Text(localizedRole(member.role))
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(isOwner ? BackendCrewArenaPalette.gold : .white.opacity(0.70))
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(
                    Capsule()
                        .fill(isOwner ? BackendCrewArenaPalette.gold.opacity(0.12) : Color.white.opacity(0.075))
                )
        }
        .padding(14)
        .background(detailSurface(cornerRadius: 22, tint: tint))
        .contextMenu {
            if !isOwner {
                Button(role: .destructive) {
                    memberToRemove = member
                    showRemoveMemberConfirm = true
                } label: {
                    Label(String(localized: "backend_crew_remove_member_action"), systemImage: "person.crop.circle.badge.minus")
                }
            }
        }
    }

    func tasksSection(_ crewTasks: [CrewTaskDTO]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                sectionTitle(
                    eyebrow: "SHARED TASKS",
                    title: "Ortak",
                    italic: "görevler"
                )

                Spacer()

                Button {
                    showCreateTask = true
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "plus")
                        Text("Yeni")
                    }
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 13)
                    .frame(height: 36)
                    .background(Capsule().fill(BackendCrewArenaPalette.blue))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 7) {
                ForEach(CrewTaskFilter.allCases) { filter in
                    let isSelected = taskFilter == filter

                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            taskFilter = filter
                        }
                    } label: {
                        Text(filter.title)
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(isSelected ? .black : .white.opacity(0.46))
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(
                                Capsule()
                                    .fill(isSelected ? BackendCrewArenaPalette.blue : Color.white.opacity(0.070))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(isSelected ? 0 : 0.08), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            if crewTasks.isEmpty {
                emptyMiniState(text: String(localized: "backend_crew_no_shared_tasks"))
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(crewTasks) { task in
                        taskCardView(task)
                            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .onTapGesture {
                                selectedTask = task
                            }
                            .contextMenu {
                                Button {
                                    Task {
                                        await crewStore.toggleTask(task)
                                    }
                                } label: {
                                    Label(
                                        task.is_done
                                        ? String(localized: "backend_crew_reopen_task")
                                        : String(localized: "backend_crew_mark_done"),
                                        systemImage: task.is_done
                                        ? "arrow.uturn.backward.circle"
                                        : "checkmark.circle"
                                    )
                                }

                                Button(role: .destructive) {
                                    Task {
                                        do {
                                            try await crewStore.deleteTask(
                                                taskID: task.id,
                                                crewID: task.crew_id,
                                                title: task.title
                                            )
                                        } catch {
                                            print("DELETE TASK ERROR:", error.localizedDescription)
                                        }
                                    }
                                } label: {
                                    Label(String(localized: "backend_crew_delete_task"), systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    func taskCardView(_ task: CrewTaskDTO) -> some View {
        let priorityTint = priorityColor(task.priority)
        let stateTint = task.is_done ? BackendCrewArenaPalette.green : BackendCrewArenaPalette.coral

        return HStack(alignment: .top, spacing: 13) {
            Button {
                Task {
                    await crewStore.toggleTask(task)
                }
            } label: {
                Image(systemName: task.is_done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 25, weight: .black))
                    .foregroundStyle(task.is_done ? BackendCrewArenaPalette.green : .white.opacity(0.28))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(stateTint.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                Text(task.title)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
                    .strikethrough(task.is_done, color: .white.opacity(0.45))
                    .opacity(task.is_done ? 0.62 : 1.0)
                    .lineLimit(2)

                if let details = task.details,
                   !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(details)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(2)
                }

                HStack(spacing: 7) {
                    miniMeta(icon: "person.fill", text: assigneeName(for: task) ?? String(localized: "backend_crew_unassigned"))

                    taskPill(
                        text: priorityLabel(task.priority),
                        tint: priorityTint
                    )

                    taskPill(
                        text: statusTitle(task.status),
                        tint: statusColor(task.status)
                    )
                }

                if task.show_on_week,
                   let weekday = task.scheduled_weekday,
                   let start = task.scheduled_start_minute {
                    miniMeta(
                        icon: "calendar",
                        text: "\(weekdayShort(weekday)) \(hm(start))"
                    )
                }
            }

            Spacer(minLength: 8)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(detailSurface(cornerRadius: 22, tint: priorityTint))
    }

    func priorityColor(_ value: String) -> Color {
        switch value {
        case "low": return .gray
        case "medium": return .blue
        case "high": return .orange
        case "urgent": return .red
        default: return .secondary
        }
    }

    func statusColor(_ value: String) -> Color {
        switch value {
        case "todo": return .gray
        case "inProgress": return .blue
        case "review": return .orange
        case "done": return .green
        default: return .secondary
        }
    }

    func priorityLabel(_ raw: String) -> String {
        let isTurkish = Locale.current.language.languageCode?.identifier == "tr"
        switch raw {
        case "low": return isTurkish ? "Düşük" : "Low"
        case "medium": return isTurkish ? "Orta" : "Medium"
        case "high": return isTurkish ? "Yüksek" : "High"
        case "urgent": return isTurkish ? "Acil" : "Urgent"
        default: return raw.capitalized
        }
    }

    func statusTitle(_ raw: String) -> String {
        let isTurkish = Locale.current.language.languageCode?.identifier == "tr"
        switch raw {
        case "todo": return isTurkish ? "Yapılacak" : "Todo"
        case "inProgress": return isTurkish ? "Devam Ediyor" : "In Progress"
        case "review": return isTurkish ? "İncelemede" : "Review"
        case "done": return isTurkish ? "Tamamlandı" : "Done"
        default: return raw.capitalized
        }
    }

    func localizedRole(_ role: String) -> String {
        let isTurkish = Locale.current.language.languageCode?.identifier == "tr"
        switch role.lowercased() {
        case "owner": return isTurkish ? "Sahip" : "Owner"
        case "admin": return isTurkish ? "Yönetici" : "Admin"
        case "member": return isTurkish ? "Üye" : "Member"
        default: return role.capitalized
        }
    }

    func weekdayShort(_ weekday: Int) -> String {
        let isTurkish = Locale.current.language.languageCode?.identifier == "tr"
        let titles = isTurkish
        ? ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
        : ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return titles[max(0, min(6, weekday))]
    }

    func hm(_ minute: Int) -> String {
        let h = max(0, min(23, minute / 60))
        let m = max(0, min(59, minute % 60))
        return String(format: "%02d:%02d", h, m)
    }

    func focusComingSoonStrip(memberCount: Int) -> some View {
        HStack(spacing: 14) {
            miniIcon(systemName: "timer", tint: BackendCrewArenaPalette.green)

            VStack(alignment: .leading, spacing: 4) {
                Text("Birlikte Focus")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)

                Text("\(memberCount) üyeyle ortak odak alanı hazır")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(2)
            }

            Spacer()

            Text("Yakında")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(BackendCrewArenaPalette.green)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(
                    Capsule()
                        .fill(BackendCrewArenaPalette.green.opacity(0.13))
                )
        }
        .padding(16)
        .background(detailSurface(cornerRadius: 24, tint: BackendCrewArenaPalette.green))
    }
    func taskPill(text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
            .foregroundStyle(tint)
    }

    func miniMeta(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption2)
        .foregroundStyle(palette.secondaryText)
    }

    func assigneeName(for task: CrewTaskDTO) -> String? {
        guard let assignedID = task.assigned_to else { return nil }
        let profile = memberProfilesByID[assignedID]
        return memberName(from: profile)
    }

    func infoPill(text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
            .foregroundStyle(tint)
    }

    func emptyMiniState(text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(BackendCrewArenaPalette.cyan)

            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.50))
                .lineLimit(2)

            Spacer()
        }
        .padding(16)
        .background(detailSurface(cornerRadius: 22, tint: BackendCrewArenaPalette.cyan))
    }
    
    func sectionTitle(eyebrow: String, title: String, italic: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("— \(eyebrow) —")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2.4)
                .foregroundStyle(.white.opacity(0.34))
                .lineLimit(1)
                .minimumScaleFactor(0.60)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)

                Text(italic)
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(.white)
            }
        }
    }

    func miniIcon(systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .black))
            .foregroundStyle(tint)
            .frame(width: 42, height: 42)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(tint.opacity(0.13))
            )
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        palette.cardFill,
                        palette.cardFill.opacity(0.97)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.035),
                                Color.clear,
                                Color.black.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }

    func memberName(from profile: ProfileDTO?) -> String {
        guard let profile else { return String(localized: "backend_crew_unknown_user") }

        if let fullName = profile.full_name,
           !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fullName
        }

        if let username = profile.username,
           !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return username
        }

        return profile.email ?? String(localized: "backend_crew_unknown_user")
    }

    func memberUsername(from profile: ProfileDTO?) -> String {
        guard let profile else { return String(localized: "backend_crew_unknown") }
        if let username = profile.username, !username.isEmpty {
            return username
        }
        return profile.email ?? String(localized: "backend_crew_unknown")
    }

    func memberInitial(from profile: ProfileDTO?) -> String {
        let name = memberName(from: profile)
        return String(name.prefix(1)).uppercased()
    }

    func playEntranceAnimations() {
        showHeroCard = false
        showStatsRow = false
        showMembersSection = false
        showTasksSection = false
        showFocusSection = false
        showActivitySection = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                showHeroCard = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                showStatsRow = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.86)) {
                showMembersSection = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                showTasksSection = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            withAnimation(.spring(response: 0.50, dampingFraction: 0.86)) {
                showFocusSection = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) {
                showActivitySection = true
            }
        }
    }
    func premiumCrewHeroBackground(accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.52, blue: 0.34).opacity(0.18),
                        accent.opacity(0.14),
                        Color(red: 0.46, green: 0.22, blue: 0.88).opacity(0.20),
                        Color(red: 0.11, green: 0.04, blue: 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.10),
                                Color.clear,
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .blendMode(.screen)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(0.16),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 10,
                            endRadius: 140
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.46, green: 0.22, blue: 0.88).opacity(0.18),
                                Color.clear
                            ],
                            center: .bottomTrailing,
                            startRadius: 12,
                            endRadius: 170
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.00),
                                Color.black.opacity(0.07),
                                Color.black.opacity(0.16)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
    }
}

private extension Color {
    init(crewDetailHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64

        switch cleaned.count {
        case 3:
            a = 255
            r = (int >> 8) * 17
            g = ((int >> 4) & 0xF) * 17
            b = (int & 0xF) * 17

        case 6:
            a = 255
            r = int >> 16
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        case 8:
            a = int >> 24
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        default:
            a = 255
            r = 255
            g = 255
            b = 255
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
