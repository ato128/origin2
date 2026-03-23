//
//  BackendCrewDetailView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import SwiftUI
import UIKit

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

    var body: some View {
        ZStack(alignment: .top) {
            ambientBackground

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Color.clear.frame(height: 76)

                    customHeader

                    heroCard(
                        memberCount: crewMembers.count,
                        totalTasks: sortedCrewTasks.count,
                        progress: crewProgressValue
                    )
                    .offset(y: showHeroCard ? 0 : 18)
                    .opacity(showHeroCard ? 1 : 0)
                    .scaleEffect(showHeroCard ? 1 : 0.985)

                    quickStatsRow(
                        completed: completedTasksCount,
                        pending: pendingTasksCount,
                        memberCount: crewMembers.count
                    )
                    .offset(y: showStatsRow ? 0 : 18)
                    .opacity(showStatsRow ? 1 : 0)
                    .scaleEffect(showStatsRow ? 1 : 0.985)

                    leaderboardCard
                        .offset(y: showStatsRow ? 0 : 18)
                        .opacity(showStatsRow ? 1 : 0)
                        .scaleEffect(showStatsRow ? 1 : 0.985)

                    backendBadgeCard
                        .offset(y: showStatsRow ? 0 : 18)
                        .opacity(showStatsRow ? 1 : 0)
                        .scaleEffect(showStatsRow ? 1 : 0.985)

                    membersSection(crewMembers)
                        .offset(y: showMembersSection ? 0 : 18)
                        .opacity(showMembersSection ? 1 : 0)
                        .scaleEffect(showMembersSection ? 1 : 0.985)

                    tasksSection(sortedCrewTasks)
                        .offset(y: showTasksSection ? 0 : 18)
                        .opacity(showTasksSection ? 1 : 0)
                        .scaleEffect(showTasksSection ? 1 : 0.985)

                    focusPlaceholderSection(memberCount: crewMembers.count)
                        .offset(y: showFocusSection ? 0 : 18)
                        .opacity(showFocusSection ? 1 : 0)
                        .scaleEffect(showFocusSection ? 1 : 0.985)

                    backendActivitySection
                        .offset(y: showActivitySection ? 0 : 18)
                        .opacity(showActivitySection ? 1 : 0)
                        .scaleEffect(showActivitySection ? 1 : 0.985)

                    Spacer(minLength: 90)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
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
        .refreshable {
            await loadCrewDetail()
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
                "Join my crew on DailyTodo 🚀\nOpen the app and enter this code: \(inviteCode)"
            ])
        }
        .sheet(isPresented: $showInviteSheet, onDismiss: {
            inviteCopied = false
        }) {
            VStack(spacing: 24) {
                Text("Invite Code")
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)

                Text(inviteCode)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)
                    .textSelection(.enabled)

                Button {
                    UIPasteboard.general.string = inviteCode
                    inviteCopied = true
                } label: {
                    Text(inviteCopied ? "Copied" : "Copy")
                        .font(.headline)
                        .foregroundStyle(.blue)
                }

                if inviteCopied {
                    Text("Code copied successfully")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                        .transition(.opacity)
                }
            }
            .padding(28)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .confirmationDialog(
            "Remove Member",
            isPresented: $showRemoveMemberConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove from Crew", role: .destructive) {
                guard let member = memberToRemove else { return }

                guard member.role.lowercased() != "owner" else {
                    errorMessage = "Owner cannot be removed from the crew."
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

            Button("Cancel", role: .cancel) {
                memberToRemove = nil
            }
        } message: {
            Text("This member will be removed from the crew.")
        }
        .confirmationDialog(
            "Delete Crew",
            isPresented: $showDeleteCrewConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Crew", role: .destructive) {
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

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This crew, its tasks, members, activity and related records will be removed.")
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

    var ambientBackground: some View {
        ZStack(alignment: .topLeading) {
            AppBackground()

            if appTheme == AppTheme.gradient.rawValue {
                RadialGradient(
                    colors: [
                        Color.purple.opacity(0.12),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 30,
                    endRadius: 260
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        hexColor(crew.color_hex).opacity(0.10),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 60,
                    endRadius: 320
                )
                .ignoresSafeArea()
            }
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
                Text("Leaderboard")
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)

                Spacer()

                Text("Today")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
            }

            if topThreeLeaderboard.isEmpty {
                Text("No shared focus records today")
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
                    Text("Crew Badge")
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)

                    Text("Unlocked by total focus time")
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
                        Text("Next badge")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.secondaryText)

                        Spacer()

                        Text("\(focusTimeText(max(0, nextTarget - minutes))) left")
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

                Text("Streak: \(currentStreakText)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    func focusTimeText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60

        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
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

    func backendActivityRow(title: String, subtitle: String, time: String, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(hexColor(crew.color_hex).opacity(0.16))
                        .frame(width: 34, height: 34)

                    Image(systemName: activityIcon(for: subtitle))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(hexColor(crew.color_hex))
                }

                if !isLast {
                    Rectangle()
                        .fill(palette.secondaryCardFill)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 6)
                }
            }
            .frame(width: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(2)

                Text(time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    var backendActivitySection: some View {
        let items = Array(crewStore.crewActivities.filter { $0.crew_id == crew.id }.prefix(5))

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Activity")
                    .font(.headline)

                Text("Recent team updates")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(items.count)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.12))
                    )
                    .foregroundStyle(.secondary)
            }

            if items.isEmpty {
                emptyMiniState(text: "No activity yet")
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    backendActivityRow(
                        title: item.member_name,
                        subtitle: item.action_text,
                        time: activityTimeText(item.created_at),
                        isLast: index == items.count - 1
                    )
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    func activityTimeText(_ raw: String?) -> String {
        guard let raw else { return "Now" }

        if let date = Self.backendISOFormatter.date(from: raw) {
            let out = DateFormatter()
            out.dateFormat = "HH:mm"
            return out.string(from: date)
        }

        return "Now"
    }

    var customHeader: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(palette.primaryText)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(palette.cardFill)
                            .overlay(
                                Circle()
                                    .stroke(palette.cardStroke, lineWidth: 1)
                            )
                    )
                    .shadow(color: palette.shadowColor, radius: 10, y: 4)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(crew.name)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            Spacer()

            Menu {
                Button(role: .destructive) {
                    showDeleteCrewConfirm = true
                } label: {
                    Label("Delete Crew", systemImage: "trash")
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(palette.cardFill)
                        .overlay(
                            Circle()
                                .stroke(palette.cardStroke, lineWidth: 1)
                        )

                    if isDeletingCrew {
                        ProgressView()
                            .tint(palette.primaryText)
                    } else {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(palette.primaryText)
                    }
                }
                .frame(width: 56, height: 56)
                .shadow(color: palette.shadowColor, radius: 10, y: 4)
            }
            .disabled(isDeletingCrew)
        }
    }

    func heroCard(memberCount: Int, totalTasks: Int, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(hexColor(crew.color_hex).opacity(0.18))
                        .frame(width: 64, height: 64)

                    Image(systemName: crew.icon)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(hexColor(crew.color_hex))
                }

                Spacer()

                Button {
                    Task {
                        guard let user = session.currentUser else { return }

                        do {
                            let code = try await crewStore.createInvite(
                                for: crew.id,
                                userID: user.id
                            )
                            inviteCode = code
                            showShareSheet = true
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.badge.plus")
                        Text("Invite")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(hexColor(crew.color_hex))
                    )
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(crew.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                Text("Manage members, shared tasks, and project activity in one place.")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            }

            HStack(spacing: 10) {
                infoPill(text: "\(memberCount) members", tint: hexColor(crew.color_hex))
                infoPill(text: "\(totalTasks) tasks", tint: palette.secondaryText)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Crew Progress")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.secondaryText)

                    Spacer()

                    Text("\(Int(progress * 100))%")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.secondaryText)
                }

                ProgressView(value: progress)
                    .tint(hexColor(crew.color_hex))
                    .scaleEffect(y: 1.8)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .shadow(color: hexColor(crew.color_hex).opacity(0.10), radius: 12, y: 6)
    }

    func quickStatsRow(completed: Int, pending: Int, memberCount: Int) -> some View {
        HStack(spacing: 10) {
            statCard(
                value: "\(completed)",
                title: "Done",
                icon: "checkmark.circle.fill",
                tint: .green
            )

            statCard(
                value: "\(pending)",
                title: "Pending",
                icon: "clock.fill",
                tint: .orange
            )

            statCard(
                value: "\(memberCount)",
                title: "Members",
                icon: "person.3.fill",
                tint: hexColor(crew.color_hex)
            )
        }
    }

    func statCard(value: String, title: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)

            Text(value)
                .font(.title3.bold())
                .foregroundStyle(palette.primaryText)
                .monospacedDigit()

            Text(title)
                .font(.caption2)
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(palette.secondaryCardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(palette.cardStroke.opacity(0.7), lineWidth: 1)
                )
        )
    }

    var memberProfilesByID: [UUID: ProfileDTO] {
        Dictionary(uniqueKeysWithValues: crewStore.memberProfiles.map { ($0.id, $0) })
    }

    func membersSection(_ crewMembers: [CrewMemberDTO]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Members")
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)

                Spacer()

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
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(Color.green.opacity(0.14))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    showAddMember = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(0.14))
                        )
                }
                .buttonStyle(.plain)

                Text("\(crewMembers.count)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(palette.secondaryCardFill)
                    )
                    .foregroundStyle(palette.secondaryText)
            }

            if crewMembers.isEmpty {
                emptyMiniState(text: "No members yet • Tap + to add one")
            } else {
                ForEach(crewMembers) { member in
                    let profile = memberProfilesByID[member.user_id]

                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(hexColor(crew.color_hex).opacity(0.14))
                                .frame(width: 42, height: 42)

                            Text(memberInitial(from: profile))
                                .font(.headline)
                                .foregroundStyle(hexColor(crew.color_hex))
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(memberName(from: profile))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.primaryText)

                            Text("@\(memberUsername(from: profile))")
                                .font(.caption)
                                .foregroundStyle(palette.secondaryText)
                        }

                        Spacer()

                        Text(member.role.capitalized)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(
                                        member.role.lowercased() == "owner"
                                        ? Color.accentColor.opacity(0.16)
                                        : Color.white.opacity(0.08)
                                    )
                            )
                            .foregroundStyle(
                                member.role.lowercased() == "owner"
                                ? Color.accentColor
                                : palette.secondaryText
                            )
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(palette.secondaryCardFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(palette.cardStroke.opacity(0.7), lineWidth: 1)
                            )
                    )
                    .contextMenu {
                        if member.role.lowercased() != "owner" {
                            Button(role: .destructive) {
                                memberToRemove = member
                                showRemoveMemberConfirm = true
                            } label: {
                                Label("Remove from Crew", systemImage: "person.crop.circle.badge.minus")
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

    func tasksSection(_ crewTasks: [CrewTaskDTO]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Shared Tasks")
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)

                Spacer()

                Button {
                    showCreateTask = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("New")
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(hexColor(crew.color_hex).opacity(0.12))
                    )
                    .foregroundStyle(hexColor(crew.color_hex))
                }
                .buttonStyle(.plain)
            }

            if crewTasks.isEmpty {
                emptyMiniState(text: "No shared tasks yet")
            } else {
                LazyVStack(spacing: 12) {
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
                                        task.is_done ? "Reopen Task" : "Mark as Done",
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
                                    Label("Delete Task", systemImage: "trash")
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
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(task.is_done ? Color.green.opacity(0.18) : Color.orange.opacity(0.18))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: task.is_done ? "checkmark.circle.fill" : "circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(task.is_done ? .green : .orange)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                    .strikethrough(task.is_done, color: palette.secondaryText)
                    .opacity(task.is_done ? 0.65 : 1.0)
                    .lineLimit(2)

                if let details = task.details,
                   !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    miniMeta(icon: "person.fill", text: assigneeName(for: task) ?? "Unassigned")

                    taskPill(
                        text: priorityLabel(task.priority),
                        tint: priorityColor(task.priority)
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

            Spacer()

            Button {
                Task {
                    await crewStore.toggleTask(task)
                }
            } label: {
                Image(systemName: task.is_done ? "arrow.uturn.backward.circle" : "checkmark.circle")
                    .font(.title3)
                    .foregroundStyle(task.is_done ? palette.secondaryText : .green)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(palette.secondaryCardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(palette.cardStroke.opacity(0.7), lineWidth: 1)
        )
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
        switch raw {
        case "low": return "Low"
        case "medium": return "Medium"
        case "high": return "High"
        case "urgent": return "Urgent"
        default: return raw.capitalized
        }
    }

    func statusTitle(_ raw: String) -> String {
        switch raw {
        case "todo": return "Todo"
        case "inProgress": return "In Progress"
        case "review": return "Review"
        case "done": return "Done"
        default: return raw.capitalized
        }
    }

    func weekdayShort(_ weekday: Int) -> String {
        let titles = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
        return titles[max(0, min(6, weekday))]
    }

    func hm(_ minute: Int) -> String {
        let h = max(0, min(23, minute / 60))
        let m = max(0, min(59, minute % 60))
        return String(format: "%02d:%02d", h, m)
    }

    func focusPlaceholderSection(memberCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Focus Together")
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)

                Spacer()

                Image(systemName: "timer")
                    .foregroundStyle(hexColor(crew.color_hex))
            }

            Text("Shared focus sessions will be enabled after backend integration.")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)

            HStack(spacing: 10) {
                infoPill(text: "\(memberCount) members", tint: hexColor(crew.color_hex))
                infoPill(text: "Soon", tint: palette.secondaryText)
            }

            Button {
            } label: {
                HStack {
                    Image(systemName: "hourglass")
                    Text("Coming Soon")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(palette.secondaryCardFill)
                .foregroundStyle(palette.secondaryText)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
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
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(palette.secondaryText)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
        }
        .padding(.vertical, 4)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }

    func memberName(from profile: ProfileDTO?) -> String {
        guard let profile else { return "Unknown user" }

        if let fullName = profile.full_name,
           !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fullName
        }

        if let username = profile.username,
           !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return username
        }

        return profile.email ?? "Unkown user"
    }

    func memberUsername(from profile: ProfileDTO?) -> String {
        guard let profile else { return "unknown" }
        if let username = profile.username, !username.isEmpty {
            return username
        }
        return profile.email ?? "Unkown user"
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
}
