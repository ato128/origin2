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
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var friendStore: FriendStore

    @State private var showCreateCrewBackend = false

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue

    private let palette = ThemePalette()

    let initialTab: CrewTabMode

    @Query(sort: \Friend.createdAt, order: .reverse)
    private var friends: [Friend]

    @Query(sort: \FriendFocusSession.startedAt, order: .reverse)
    private var focusSessions: [FriendFocusSession]
    
    @Query(sort: \FriendRequest.createdAt, order: .reverse)
    private var friendRequests: [FriendRequest]

    @State private var crewTabMode: CrewTabMode
    @State private var showJoinFocusSheet = false
    @State private var selectedFocusSession: FriendFocusSession?
    @State private var pulseLiveIndicator = false
    @State private var showJoinCrewSheet = false
    @State private var pendingInviteCode = ""
    
   
    

    init(initialTab: CrewTabMode = .crews) {
        self.initialTab = initialTab
        _crewTabMode = State(initialValue: initialTab)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                crewAmbientBackground

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Color.clear.frame(height: 50)

                        topHeader
                        crewTopSegment

                        if crewTabMode == .crews {
                            crewsContent
                        } else {
                            friendsContent
                        }

                        Spacer(minLength: 90)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
                .onAppear {
                    pulseLiveIndicator = true
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showCreateCrewBackend) {
                CreateCrewBackendView()
                    .environmentObject(session)
                    .environmentObject(crewStore)
            }
            .sheet(isPresented: $showJoinCrewSheet) {
                JoinCrewSheet(code: pendingInviteCode)
                    .environmentObject(crewStore)
                    .environmentObject(session)
            }
            .sheet(isPresented: $showJoinFocusSheet) {
                if let session = selectedFocusSession,
                   let friend = friendForFocusSession(session) {
                    JoinFocusSheet(
                        friend: friend,
                        session: session
                    )
                }
            }
            .task {
                await crewStore.loadCrews()
                await crewStore.loadStatsForAllCrews()

                guard let currentUserID = session.currentUser?.id else { return }

                // ✅ Backend friendships çek
                await friendStore.loadAcceptedFriendships(currentUserID: currentUserID)

                // ✅ karşı taraf userID'leri bul
                let otherUserIDs = friendStore.friendships.map {
                    $0.requester_id == currentUserID ? $0.addressee_id : $0.requester_id
                }

                // ✅ profilleri çek
                await friendStore.loadProfiles(for: otherUserIDs)

                // 🔥 KRİTİK: modelContext oluştur
               

                // ✅ local'e yaz
                friendStore.syncAcceptedFriendsToLocal(
                    currentUserID: currentUserID,
                    modelContext: modelContext
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .openCrewInviteFromLink)) { notification in
                if let code = notification.object as? String {
                    pendingInviteCode = code
                    showJoinCrewSheet = true
                }
            }
        }
    }
}

// MARK: - Sections

private extension CrewView {

    var crewAmbientBackground: some View {
        ZStack(alignment: .topLeading) {
            AppBackground()

            if appTheme == AppTheme.gradient.rawValue {
                RadialGradient(
                    colors: [
                        Color.purple.opacity(0.18),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 40,
                    endRadius: 320
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        Color.blue.opacity(0.14),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 60,
                    endRadius: 360
                )
                .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.05),
                        Color.clear,
                        Color.black.opacity(0.08)
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
                .ignoresSafeArea()
            }
        }
    }

    var topHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack(alignment: .leading) {
                if appTheme == AppTheme.gradient.rawValue {
                    Text("Crew")
                        .font(.system(size: 68, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.purple.opacity(0.14),
                                    Color.blue.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blur(radius: 3)
                        .opacity(0.55)
                        .offset(x: 2, y: -6)
                }

                Text("Crew")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(palette.primaryText)
            }

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Crew Space")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Text("Build together, focus together, finish together.")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer()

                if crewTabMode == .crews {
                    HStack(spacing: 10) {
                        Button {
                            pendingInviteCode = ""
                            showJoinCrewSheet = true
                        } label: {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.green)
                                .frame(width: 54, height: 54)
                                .background(
                                    Circle()
                                        .fill(palette.cardFill)
                                        .overlay(
                                            Circle()
                                                .stroke(palette.cardStroke, lineWidth: 1)
                                        )
                                )
                                .shadow(color: palette.shadowColor, radius: 12, y: 6)
                        }
                        .buttonStyle(.plain)

                        Button {
                            showCreateCrewBackend = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 54, height: 54)
                                .background(
                                    Circle()
                                        .fill(palette.cardFill)
                                        .overlay(
                                            Circle()
                                                .stroke(palette.cardStroke, lineWidth: 1)
                                        )
                                )
                                .shadow(color: palette.shadowColor, radius: 12, y: 6)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button {
                        seedMockFriendRequestsIfNeeded()
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 54, height: 54)
                            .background(
                                Circle()
                                    .fill(palette.cardFill)
                                    .overlay(
                                        Circle()
                                            .stroke(palette.cardStroke, lineWidth: 1)
                                    )
                            )
                            .shadow(color: palette.shadowColor, radius: 12, y: 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    var crewTopSegment: some View {
        HStack(spacing: 10) {
            ForEach(CrewTabMode.allCases, id: \.self) { mode in
                let isSelected = crewTabMode == mode

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        crewTabMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? palette.primaryText : palette.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    isSelected
                                    ? LinearGradient(
                                        colors: [
                                            Color.accentColor.opacity(0.22),
                                            Color.accentColor.opacity(0.12)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [
                                            palette.secondaryCardFill,
                                            palette.secondaryCardFill.opacity(0.7)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(
                                    isSelected
                                    ? Color.accentColor.opacity(0.30)
                                    : palette.cardStroke,
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: isSelected ? Color.accentColor.opacity(0.16) : .clear,
                            radius: isSelected ? 10 : 0,
                            y: 4
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(palette.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
    }

    var crewsContent: some View {
        Group {
            if crewStore.crews.isEmpty {
                emptyStateCard
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    backendCrewOverviewCard
                    backendCrewsSection
                }
            }
        }
    }

    var backendCrewOverviewCard: some View {
        let totalCrews = crewStore.crews.count
        let totalMembers = crewStore.memberCountByCrew.values.reduce(0, +)
        let totalTasks = crewStore.taskCountByCrew.values.reduce(0, +)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Overview")
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)

                    Text("Your team productivity at a glance")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer()

                Image(systemName: "person.3.sequence.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }

            HStack(spacing: 10) {
                statPill(title: "\(totalCrews)", subtitle: "Crews")
                statPill(title: "\(totalMembers)", subtitle: "Members")
                statPill(title: "\(totalTasks)", subtitle: "Tasks")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    func backendCrewCard(for crew: CrewDTO) -> some View {
        let memberCount = crewStore.memberCountByCrew[crew.id] ?? 0
        let taskCount = crewStore.taskCountByCrew[crew.id] ?? 0
        let completedTasks = crewStore.completedTaskCountByCrew[crew.id] ?? 0
        let pendingCount = max(0, taskCount - completedTasks)
        let progress = taskCount == 0 ? 0.0 : Double(completedTasks) / Double(taskCount)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(hexColor(crew.color_hex).opacity(0.18))
                        .frame(width: 52, height: 52)

                    Image(systemName: crew.icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(hexColor(crew.color_hex))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(crew.name)
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(1)

                    Text("\(memberCount) members • \(taskCount) tasks")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.tertiaryText)
            }

            HStack(alignment: .center) {
                backendAvatarStack(memberCount: memberCount, tint: hexColor(crew.color_hex))

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(progress * 100))%")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(palette.primaryText)

                    Text("completed")
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.secondaryText)

                    Spacer()

                    Text("\(completedTasks) done • \(pendingCount) left")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.secondaryText)
                }

                ProgressView(value: progress)
                    .tint(hexColor(crew.color_hex))
                    .scaleEffect(y: 1.7)
                    .animation(.easeInOut, value: progress)
            }

            HStack(spacing: 10) {
                miniPill(
                    icon: "checkmark.circle.fill",
                    text: "\(completedTasks)/\(taskCount) tasks",
                    tint: hexColor(crew.color_hex)
                )

                miniPill(
                    icon: "person.crop.circle.fill",
                    text: memberCount > 0 ? "\(memberCount) members" : "No members",
                    tint: .secondary
                )
            }

            HStack(spacing: 8) {
                Image(systemName: "bolt.horizontal.circle.fill")
                    .foregroundStyle(hexColor(crew.color_hex))

                Text(taskCount > 0 ? "Shared crew tasks are active" : "Backend crew is ready for shared tasks")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)

                Spacer()

                Text("Now")
                    .font(.caption2)
                    .foregroundStyle(palette.tertiaryText)
            }
            .padding(.top, 2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .shadow(
            color: hexColor(crew.color_hex).opacity(0.12),
            radius: 10,
            y: 6
        )
    }

    func backendAvatarStack(memberCount: Int, tint: Color) -> some View {
        HStack(spacing: -10) {
            ForEach(0..<min(memberCount, 4), id: \.self) { _ in
                ZStack {
                    Circle()
                        .fill(palette.cardFill)
                        .frame(width: 30, height: 30)

                    Circle()
                        .fill(palette.secondaryCardFill)
                        .frame(width: 26, height: 26)

                    Image(systemName: "person.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                }
            }

            if memberCount > 4 {
                ZStack {
                    Circle()
                        .fill(palette.cardFill)
                        .frame(width: 30, height: 30)

                    Circle()
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 26, height: 26)

                    Text("+\(memberCount - 4)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    var backendCrewsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your Crews")
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            ForEach(crewStore.crews) { crew in
                NavigationLink {
                    BackendCrewDetailView(crew: crew)
                        .environmentObject(crewStore)
                        .environmentObject(session)
                } label: {
                    backendCrewCard(for: crew)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    var incomingRequests: [FriendRequest] {
        friendRequests.filter { $0.direction == .incoming && $0.status == .pending }
    }

    var sentRequests: [FriendRequest] {
        friendRequests.filter { $0.direction == .sent && $0.status == .pending }
    }

    var friendsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            friendsOverviewCard

            if !incomingRequests.isEmpty {
                incomingRequestsCard
            }

            if !sentRequests.isEmpty {
                sentRequestsCard
            }

            if !activeFocusSessions.isEmpty {
                friendsFocusActivityCard
            }

            if friends.isEmpty && incomingRequests.isEmpty && sentRequests.isEmpty {
                friendsEmptyStateCard
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Your Friends")
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)

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
                        .foregroundStyle(palette.primaryText)

                    Text("Friends currently studying together")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.16))
                        .frame(width: 48, height: 48)

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
                                    .frame(width: 42, height: 42)

                                Image(systemName: friend.avatarSymbol)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(hexColor(friend.colorHex))
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(friend.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(palette.primaryText)

                                Text("\(session.title) • \(focusMinutesLeft(for: session)) min left")
                                    .font(.caption)
                                    .foregroundStyle(palette.secondaryText)
                            }

                            Spacer()

                            HStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)

                                    Circle()
                                        .stroke(Color.green.opacity(0.40), lineWidth: 1.5)
                                        .frame(width: 16, height: 16)
                                        .scaleEffect(pulseLiveIndicator ? 1.22 : 0.86)
                                        .opacity(pulseLiveIndicator ? 0.0 : 0.9)
                                        .animation(
                                            .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                                            value: pulseLiveIndicator
                                        )
                                }

                                Text("Live")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(palette.secondaryCardFill)
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

    var friendsOverviewCard: some View {
        let onlineCount = friends.filter(\.isOnline).count

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Friends")
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)

                    Text("Shared schedules and direct collaboration")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer()

                Image(systemName: "person.2.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }

            HStack(spacing: 10) {
                statPill(title: "\(friends.count)", subtitle: "Friends")
                statPill(title: "\(incomingRequests.count)", subtitle: "Requests")
                statPill(title: "\(activeFriendFocusCount)", subtitle: "In Focus")
            }

            if activeFriendFocusCount > 0 {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)

                    Text("\(activeFriendFocusCount) friend\(activeFriendFocusCount == 1 ? "" : "s") studying now")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.secondaryText)

                    Spacer()
                }
                .padding(.top, 2)
            } else if !incomingRequests.isEmpty {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 8, height: 8)

                    Text("\(incomingRequests.count) pending friend request")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.secondaryText)

                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }
    
    var incomingRequestsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Incoming Requests")
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)

                Spacer()

                Text("\(incomingRequests.count)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.14))
                    )
                    .foregroundStyle(.orange)
            }

            ForEach(incomingRequests) { request in
                incomingRequestRow(request)
            }
        }
        .padding(18)
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
                .foregroundStyle(palette.primaryText)

            Text("Add your first friend to start sharing schedules and chatting.")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)

            Button {
                print("ADD SAMPLE REQUESTS TAPPED")
                seedMockFriendRequestsIfNeeded()
            } label: {
                Text("Add Sample Requests")
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
                .foregroundStyle(palette.primaryText)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.secondaryCardFill)
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
                .foregroundStyle(palette.primaryText)

            Text("Create your first crew and start managing shared tasks, members, and activity together.")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)

            Button {
                showCreateCrewBackend = true
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
                .foregroundStyle(palette.primaryText)

            Text("Next step: open a friend profile, view today's schedule, and start messaging.")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(cardBackground)
    }
    
    func acceptRequest(_ request: FriendRequest) {
        request.status = .accepted
        try? modelContext.save()

        Task {
            guard let currentUserID = session.currentUser?.id else { return }

            await friendStore.loadAcceptedFriendships(currentUserID: currentUserID)

            let allUserIDs = friendStore.friendships.flatMap { friendship -> [UUID] in
                [friendship.requester_id, friendship.addressee_id]
            }

            await friendStore.loadProfiles(for: allUserIDs)

            await MainActor.run {
                friendStore.syncAcceptedFriendsToLocal(
                    currentUserID: currentUserID,
                    modelContext: modelContext
                )
            }
        }
    }

    func declineRequest(_ request: FriendRequest) {
        request.status = .declined
        try? modelContext.save()
    }

    func cancelRequest(_ request: FriendRequest) {
        request.status = .cancelled
        try? modelContext.save()
    }
    
    func sentRequestRow(_ request: FriendRequest) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(hexColor(request.colorHex).opacity(0.16))
                    .frame(width: 42, height: 42)

                Image(systemName: request.avatarSymbol)
                    .foregroundStyle(hexColor(request.colorHex))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(request.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)

                Text("@\(request.username)")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }

            Spacer()

            Button {
                cancelRequest(request)
            } label: {
                Text("Cancel")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.orange.opacity(0.14))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.secondaryCardFill)
        )
    }
    var sentRequestsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Sent Requests")
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)

                Spacer()

                Text("\(sentRequests.count)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.14))
                    )
                    .foregroundStyle(.blue)
            }

            ForEach(sentRequests) { request in
                sentRequestRow(request)
            }
        }
        .padding(18)
        .background(cardBackground)
    }
    
    func incomingRequestRow(_ request: FriendRequest) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(hexColor(request.colorHex).opacity(0.16))
                    .frame(width: 42, height: 42)

                Image(systemName: request.avatarSymbol)
                    .foregroundStyle(hexColor(request.colorHex))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(request.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)

                Text("@\(request.username)")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    acceptRequest(request)
                } label: {
                    Text("Accept")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.green.opacity(0.14))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    declineRequest(request)
                } label: {
                    Text("Decline")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.red.opacity(0.14))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.secondaryCardFill)
        )
    }

    func friendRow(_ friend: Friend) -> some View {
        let activeSession = activeFocusSession(for: friend)

        return NavigationLink {
            FriendDetailView(friend: friend)
                .environmentObject(friendStore)
                .environmentObject(session)
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
                        .foregroundStyle(palette.primaryText)

                    if let session = activeSession {
                        Text("Focusing • \(session.durationMinute) min")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text(friend.subtitle)
                            .font(.caption)
                            .foregroundStyle(palette.secondaryText)
                    }
                }

                Spacer()

                if activeSession != nil {
                    HStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)

                            Circle()
                                .stroke(Color.green.opacity(0.45), lineWidth: 1.5)
                                .frame(width: 16, height: 16)
                                .scaleEffect(pulseLiveIndicator ? 1.25 : 0.85)
                                .opacity(pulseLiveIndicator ? 0.0 : 0.9)
                                .animation(
                                    .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                                    value: pulseLiveIndicator
                                )
                        }

                        Text("Live")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)

                        Text("Focusing")
                            .font(.caption2)
                            .foregroundStyle(palette.secondaryText)
                    }
                } else {
                    HStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(friend.isOnline ? Color.green : Color.gray.opacity(0.5))
                                .frame(width: 8, height: 8)

                            if friend.isOnline {
                                Circle()
                                    .stroke(Color.green.opacity(0.35), lineWidth: 1.5)
                                    .frame(width: 16, height: 16)
                                    .scaleEffect(pulseLiveIndicator ? 1.18 : 0.88)
                                    .opacity(pulseLiveIndicator ? 0.0 : 0.85)
                                    .animation(
                                        .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                                        value: pulseLiveIndicator
                                    )
                            }
                        }

                        Text(friend.isOnline ? "Online" : "Offline")
                            .font(.caption2)
                            .foregroundStyle(palette.secondaryText)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(palette.tertiaryText)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(palette.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(palette.cardStroke, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    func activeFocusSession(for friend: Friend) -> FriendFocusSession? {
        focusSessions.first(where: { $0.friendID == friend.id && $0.isActive })
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
    
    func seedMockFriendRequestsIfNeeded() {
        let existingPending = friendRequests.filter { $0.status == .pending }
        guard existingPending.isEmpty else {
            print("Pending requests already exist")
            return
        }

        let incoming1 = FriendRequest(
            name: "Ahmet",
            username: "ahmetk",
            avatarSymbol: "person.fill",
            colorHex: "#3B82F6",
            direction: .incoming
        )

        let incoming2 = FriendRequest(
            name: "Selin",
            username: "selinnotes",
            avatarSymbol: "person.fill",
            colorHex: "#8B5CF6",
            direction: .incoming
        )

        let sent1 = FriendRequest(
            name: "Atakan",
            username: "atakan12",
            avatarSymbol: "person.fill",
            colorHex: "#22C55E",
            direction: .sent
        )

        modelContext.insert(incoming1)
        modelContext.insert(incoming2)
        modelContext.insert(sent1)

        do {
            try modelContext.save()
            print("Sample friend requests added")
        } catch {
            print("SAVE FRIEND REQUEST ERROR:", error.localizedDescription)
        }
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
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }
}
