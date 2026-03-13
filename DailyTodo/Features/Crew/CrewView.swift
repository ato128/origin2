//
//  CrewView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 9.03.2026.
//

import SwiftUI
import SwiftData

enum CrewTabMode: String, CaseIterable {
    case crews = "Crews"
    case friends = "Friends"
}

struct CrewView: View {
    @Environment(\.modelContext) private var modelContext
    
    let initialTab: CrewTabMode

    @Query(sort: \Crew.createdAt, order: .reverse)
    private var crews: [Crew]

    @Query private var members: [CrewMember]
    @Query private var tasks: [CrewTask]

    @Query(sort: \CrewActivity.createdAt, order: .reverse)
    private var activities: [CrewActivity]
    
    @Query(sort: \Friend.createdAt, order: .reverse)
    private var friends: [Friend]
    
    @Query(sort: \FriendFocusSession.startedAt, order: .reverse)
    private var focusSessions: [FriendFocusSession]

    @State private var showCreateCrew = false
    @State private var crewTabMode: CrewTabMode
    @State private var showJoinFocusSheet = false
    @State private var selectedFocusSession: FriendFocusSession?
    
    init(initialTab: CrewTabMode = .crews) {
        self.initialTab = initialTab
        _crewTabMode = State(initialValue: initialTab)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    topHeader
                    crewTopSegment
                    
                    if crewTabMode == .crews {
                        crewsContent
                    } else {
                        friendsContent
                    }
                }
                .padding(16)
                .padding(.bottom, 28)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Crew")
            .sheet(isPresented: $showCreateCrew) {
                CreateCrewView()
                    .sheet(isPresented: $showJoinFocusSheet) {
                        if let session = selectedFocusSession,
                           let friend = friendForFocusSession(session) {
                            JoinFocusSheet(
                                friend: friend,
                                session: session
                            )
                        }
                    }
            }
        }
    }
}

// MARK: - Sections

private extension CrewView {

    var topHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Crew Space")
                        .font(.title2.bold())

                    Text("Build together, focus together, finish together.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if crewTabMode == .crews {
                    Button {
                        showCreateCrew = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline.weight(.bold))
                            .frame(width: 42, height: 42)
                            .background(
                                Circle()
                                    .fill(Color.accentColor.opacity(0.14))
                            )
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.headline.weight(.bold))
                            .frame(width: 42, height: 42)
                            .background(
                                Circle()
                                    .fill(Color.accentColor.opacity(0.14))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    var crewTopSegment: some View {
        HStack(spacing: 8) {
            ForEach(CrewTabMode.allCases, id: \.self) { mode in
                let isSelected = crewTabMode == mode

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        crewTabMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    isSelected
                                    ? Color.accentColor.opacity(0.14)
                                    : Color.white.opacity(0.04)
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    isSelected
                                    ? Color.accentColor.opacity(0.20)
                                    : Color.white.opacity(0.05),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    var crewsContent: some View {
        Group {
            if crews.isEmpty {
                emptyStateCard
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    crewOverviewCard
                    crewsSection
                }
            }
        }
    }

    var friendsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            friendsOverviewCard

            if !activeFocusSessions.isEmpty {
                friendsFocusActivityCard
            }

            if friends.isEmpty {
                friendsEmptyStateCard
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Your Friends")
                        .font(.headline)

                    ForEach(friends) { friend in
                        friendRow(friend)
                    }
                }

                friendsEmptyHintCard
            }
        }
    }
    var friendsFocusActivityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Focus Activity")
                        .font(.headline)

                    Text("Friends currently studying together")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.16))
                        .frame(width: 40, height: 40)

                    Image(systemName: "timer")
                        .foregroundStyle(.green)
                }
            }

            VStack(spacing: 10) {
                ForEach(activeFocusSessions.prefix(3)) { session in
                    if let friend = friendForFocusSession(session) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(hexColor(friend.colorHex).opacity(0.16))
                                    .frame(width: 38, height: 38)

                                Image(systemName: friend.avatarSymbol)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(hexColor(friend.colorHex))
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(friend.name)
                                    .font(.subheadline.weight(.semibold))

                                Text("\(session.title) • \(focusMinutesLeft(for: session)) min left")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            HStack(spacing: 6) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 8, height: 8)

                                Text("Live")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                        )
                    }
                }
            }

            Button {
                selectedFocusSession = activeFocusSessions.first
                showJoinFocusSheet = selectedFocusSession != nil
            } label: {
                HStack {
                    Image(systemName: "person.2.wave.2.fill")
                    Text("Join Focus")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.accentColor.opacity(0.14))
                .foregroundStyle(Color.accentColor)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    var crewOverviewCard: some View {
        let totalCrews = crews.count
        let totalTasks = tasks.count
        let completedTasks = tasks.filter(\.isDone).count
        let totalMembers = members.count

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Overview")
                        .font(.headline)

                    Text("Your team productivity at a glance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "person.3.sequence.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }

            HStack(spacing: 10) {
                statPill(title: "\(totalCrews)", subtitle: "Crews")
                statPill(title: "\(totalMembers)", subtitle: "Members")
                statPill(title: "\(completedTasks)/\(totalTasks)", subtitle: "Tasks")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    var friendsOverviewCard: some View {
        let onlineCount = friends.filter(\.isOnline).count

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Friends")
                        .font(.headline)

                    Text("Shared schedules and direct collaboration")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "person.2.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }

            HStack(spacing: 10) {
                statPill(title: "\(friends.count)", subtitle: "Friends")
                statPill(title: "\(onlineCount)", subtitle: "Online")
                statPill(title: "\(activeFriendFocusCount)", subtitle: "In Focus")
            }

            if activeFriendFocusCount > 0 {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)

                    Text("\(activeFriendFocusCount) friend\(activeFriendFocusCount == 1 ? "" : "s") studying now")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }
    
    var friendsEmptyStateCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 70, height: 70)

                Image(systemName: "person.2.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)
            }

            Text("No friends yet")
                .font(.headline)

            Text("Add your first friend to start sharing schedules and chatting.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                seedMockFriendsIfNeeded()
            } label: {
                Text("Add Sample Friends")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(cardBackground)
    }

    func statPill(title: String, subtitle: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.headline.weight(.bold))

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    var emptyStateCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 70, height: 70)

                Image(systemName: "person.3.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)
            }

            Text("No crew yet")
                .font(.headline)

            Text("Create your first crew and start managing shared tasks, members, and activity together.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showCreateCrew = true
            } label: {
                Text("Create Your First Crew")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(cardBackground)
    }
    
    var activeFriendFocusCount: Int {
        focusSessions.filter(\.isActive).count
    }

    var friendsEmptyHintCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "message.badge.waveform.fill")
                .font(.system(size: 26))
                .foregroundStyle(Color.accentColor)

            Text("Friends chat & schedule sharing")
                .font(.headline)

            Text("Next step: open a friend profile, view today's schedule, and start messaging.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(cardBackground)
    }

    var crewsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your Crews")
                .font(.headline)

            ForEach(crews) { crew in
                NavigationLink {
                    CrewDetailView(crew: crew)
                } label: {
                    crewCard(for: crew)
                }
                .buttonStyle(.plain)
            }
        }
    }

    func crewCard(for crew: Crew) -> some View {
        let crewMembers = members.filter { $0.crewID == crew.id }
        let crewTasks = tasks.filter { $0.crewID == crew.id }
        let crewActivities = activities.filter { $0.crewID == crew.id }

        let completedTasks = crewTasks.filter(\.isDone).count
        let progress = crewTasks.isEmpty ? 0 : Double(completedTasks) / Double(crewTasks.count)
        let pendingCount = max(0, crewTasks.count - completedTasks)
        let lastActivity = crewActivities.first

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(hexColor(crew.colorHex).opacity(0.18))
                        .frame(width: 52, height: 52)

                    Image(systemName: crew.icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(hexColor(crew.colorHex))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(crew.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("\(crewMembers.count) members • \(crewTasks.count) tasks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .center) {
                avatarStack(for: crewMembers)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(progress * 100))%")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("completed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(completedTasks) done • \(pendingCount) left")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: progress)
                    .tint(hexColor(crew.colorHex))
                    .scaleEffect(y: 1.7)
            }

            HStack(spacing: 10) {
                miniPill(
                    icon: "checkmark.circle.fill",
                    text: "\(completedTasks)/\(crewTasks.count) tasks",
                    tint: hexColor(crew.colorHex)
                )

                if let firstMember = crewMembers.first {
                    miniPill(
                        icon: firstMember.avatarSymbol,
                        text: firstMember.name,
                        tint: .secondary
                    )
                }
            }

            if let activity = lastActivity {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .foregroundStyle(hexColor(crew.colorHex))

                    Text("\(activity.memberName) \(activity.actionText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Text(activity.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    func friendRow(_ friend: Friend) -> some View {
        let activeSession = activeFocusSession(for: friend)

        return NavigationLink {
            FriendDetailView(friend: friend)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(hexColor(friend.colorHex).opacity(0.16))
                        .frame(width: 46, height: 46)

                    Image(systemName: friend.avatarSymbol)
                        .font(.headline.bold())
                        .foregroundStyle(hexColor(friend.colorHex))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if let session = activeSession {
                        Text("Focusing • \(session.durationMinute) min")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text(friend.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if activeSession != nil {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)

                        Text("Focusing")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(friend.isOnline ? Color.green : Color.gray.opacity(0.5))
                            .frame(width: 8, height: 8)

                        Text(friend.isOnline ? "Online" : "Offline")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    func activeFocusSession(for friend: Friend) -> FriendFocusSession? {
        focusSessions.first(where: { $0.friendID == friend.id && $0.isActive })
    }
    
    func avatarStack(for crewMembers: [CrewMember]) -> some View {
        HStack(spacing: -10) {
            ForEach(Array(crewMembers.prefix(4).enumerated()), id: \.offset) { _, member in
                ZStack {
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 30, height: 30)

                    Circle()
                        .fill(Color.secondary.opacity(0.14))
                        .frame(width: 26, height: 26)

                    Image(systemName: member.avatarSymbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }

            if crewMembers.count > 4 {
                ZStack {
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 30, height: 30)

                    Circle()
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 26, height: 26)

                    Text("+\(crewMembers.count - 4)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    func miniPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(tint.opacity(0.12))
        )
        .foregroundStyle(tint)
    }
    func weekdayIndexToday() -> Int {
        let w = Calendar.current.component(.weekday, from: Date())
        return (w + 5) % 7
    }
    
    func seedMockFriendsIfNeeded() {
        guard friends.isEmpty else { return }

        let ahmet = Friend(
            name: "Ahmet",
            subtitle: "Bugün 3 etkinlik",
            avatarSymbol: "person.fill",
            colorHex: "#3B82F6",
            isOnline: true
        )

        let selin = Friend(
            name: "Selin",
            subtitle: "Yarın sınav haftası",
            avatarSymbol: "person.fill",
            colorHex: "#8B5CF6",
            isOnline: false
        )

        let atakan = Friend(
            name: "Atakan",
            subtitle: "Bu hafta 8 ders",
            avatarSymbol: "person.fill",
            colorHex: "#22C55E",
            isOnline: true
        )

        modelContext.insert(ahmet)
        modelContext.insert(selin)
        modelContext.insert(atakan)

        let focusSession = FriendFocusSession(
            friendID: ahmet.id,
            title: "Shared Focus",
            startedAt: Date(),
            durationMinute: 25,
            isActive: true
        )

        modelContext.insert(focusSession)

        let startMessage = FriendMessage(
            friendID: ahmet.id,
            senderName: ahmet.name,
            text: "\(ahmet.name) started a 25 min shared focus session.",
            isFromMe: false
        )

        modelContext.insert(startMessage)

        let sharedItems = [
            SharedWeekItem(
                friendID: ahmet.id,
                title: "Math Lecture",
                weekday: weekdayIndexToday(),
                startMinute: 9 * 60,
                durationMinute: 90
            ),
            SharedWeekItem(
                friendID: ahmet.id,
                title: "UI Study Session",
                weekday: weekdayIndexToday(),
                startMinute: 13 * 60,
                durationMinute: 60
            ),
            SharedWeekItem(
                friendID: ahmet.id,
                title: "Physics Lab Prep",
                weekday: weekdayIndexToday(),
                startMinute: 18 * 60,
                durationMinute: 60
            )
        ]

        for item in sharedItems {
            modelContext.insert(item)
        }

        try? modelContext.save()
    }
    
    var activeFocusSessions: [FriendFocusSession] {
        focusSessions.filter(\.isActive)
    }

    func friendForFocusSession(_ session: FriendFocusSession) -> Friend? {
        friends.first(where: { $0.id == session.friendID })
    }

    func focusMinutesLeft(for session: FriendFocusSession) -> Int {
        let endDate = session.startedAt.addingTimeInterval(TimeInterval(session.durationMinute * 60))
        let remaining = Int(endDate.timeIntervalSinceNow / 60.0)
        return max(0, remaining)
    }
    
    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}
