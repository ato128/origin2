//
//  CrewView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 9.03.2026.
//

import SwiftUI
import SwiftData
import Supabase

enum CrewTabMode: String, CaseIterable {
    case crews = "Crews"
    case friends = "Friends"
}

struct CrewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var friendStore: FriendStore
    @EnvironmentObject var studentStore: StudentStore

    let initialTab: CrewTabMode

    @Query(sort: \Friend.createdAt, order: .reverse)
    private var friends: [Friend]

    @Query(sort: \FriendFocusSession.startedAt, order: .reverse)
    private var focusSessions: [FriendFocusSession]

    @State private var showCreateCrewBackend = false
    @State private var showJoinCrewSheet = false
    @State private var showAddFriendSheet = false

    @State private var pendingInviteCode = ""
    @State private var didLoad = false

    @State private var selectedCrewIDForDetail: UUID?
    @State private var selectedFriendIDForDetail: UUID?
    @StateObject private var arenaStore = ArenaStore()
    @ObservedObject private var socialStats = SocialStatsStore.shared

    init(initialTab: CrewTabMode = .crews) {
        self.initialTab = initialTab
    }

    var body: some View {
        NavigationStack {
            CrewHomeView(
                initialTab: initialTab,
                summary: crewHomeSummary,
                studentContext: crewArenaStudentContext,
                arenaStore: arenaStore,
                crews: crewHomeCrewCards,
                friends: crewHomeFriendCards,
                incomingRequests: crewHomeIncomingRequestCards,
                sentRequests: crewHomeSentRequestCards,
                onCreateCrew: {
                    showCreateCrewBackend = true
                },
                onJoinCrew: {
                    pendingInviteCode = ""
                    showJoinCrewSheet = true
                },
                onAddFriend: {
                    showAddFriendSheet = true
                },
                onOpenCrew: { crewID in
                    selectedCrewIDForDetail = crewID
                },
                onOpenFriend: { friendID in
                    selectedFriendIDForDetail = friendID
                },
                onAcceptRequest: { friendshipID in
                    guard let request = incomingRequests.first(where: { $0.id == friendshipID }) else { return }

                    Task {
                        await acceptRequest(request)
                    }
                },
                onRemoveRequest: { friendshipID in
                    guard let request = (incomingRequests + sentRequests).first(where: { $0.id == friendshipID }) else { return }

                    Task {
                        await removePendingRequest(request)
                    }
                }
            )
            .navigationBarHidden(true)
            .navigationDestination(
                isPresented: Binding(
                    get: { selectedCrewIDForDetail != nil },
                    set: { isPresented in
                        if !isPresented {
                            selectedCrewIDForDetail = nil
                        }
                    }
                )
            ) {
                if let crew = selectedCrewForDetail {
                    BackendCrewDetailView(crew: crew)
                        .environmentObject(crewStore)
                        .environmentObject(session)
                } else {
                    CrewRedesignLoadingView(text: tr("cv_crew_preparing"))
                }
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { selectedFriendIDForDetail != nil },
                    set: { isPresented in
                        if !isPresented {
                            selectedFriendIDForDetail = nil
                        }
                    }
                )
            ) {
                if let friend = selectedFriendForDetail {
                    FriendDetailView(friend: friend)
                        .environmentObject(friendStore)
                        .environmentObject(session)
                } else {
                    CrewRedesignLoadingView(text: tr("cv_friend_preparing"))
                }
            }
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
            .sheet(isPresented: $showAddFriendSheet) {
                AddFriendSheetView()
                    .environmentObject(friendStore)
                    .environmentObject(session)
            }
            .task {
                guard !didLoad else { return }
                guard let userID = session.currentUser?.id else { return }

                didLoad = true
                
                await initialLoadIfNeeded()

                await crewStore.loadCrews()
                await crewStore.loadCrewHomeSnapshot()
                crewStore.subscribeToGlobalFocusRealtime()
                crewStore.startObservingFocusSocketEvents()

                friendStore.subscribeToFriendshipsRealtime(currentUserID: userID)

                let otherUserIDs = friendStore.friendships.compactMap { friendship -> UUID? in
                    if friendship.requester_id == userID {
                        return friendship.addressee_id
                    } else if friendship.addressee_id == userID {
                        return friendship.requester_id
                    } else {
                        return nil
                    }
                }

                friendStore.subscribeToPresenceRealtime(for: otherUserIDs)

                didLoad = true
            }
            .onChange(of: session.currentUser?.id) { _, newID in
                Task {
                    if newID == nil {
                        crewStore.resetForUserChange()
                        friendStore.unsubscribeFriendshipsRealtime()
                        friendStore.unsubscribePresenceRealtime()
                        didLoad = false
                        return
                    }

                    crewStore.resetForUserChange()
                    friendStore.unsubscribeFriendshipsRealtime()
                    friendStore.unsubscribePresenceRealtime()
                    didLoad = false

                    await reloadAllCrewAndFriendData(forceCrews: true)

                    if let newID {
                        crewStore.subscribeToCrewsListRealtime(for: newID)
                        crewStore.subscribeToGlobalFocusRealtime()
                        friendStore.subscribeToFriendshipsRealtime(currentUserID: newID)

                        let otherUserIDs = friendStore.friendships.compactMap { friendship -> UUID? in
                            if friendship.requester_id == newID {
                                return friendship.addressee_id
                            } else if friendship.addressee_id == newID {
                                return friendship.requester_id
                            } else {
                                return nil
                            }
                        }

                        friendStore.subscribeToPresenceRealtime(for: otherUserIDs)
                    }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }

                Task {
                    await crewStore.loadHomeCacheForAllCrews()
                    await reloadBackendFriends(force: false)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openCrewInviteFromLink)) { notification in
                if let code = notification.object as? String {
                    pendingInviteCode = code
                    showJoinCrewSheet = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("focus_completed"))) { _ in
                Task {
                    await crewStore.loadHomeCacheForAllCrews()

                    await arenaStore.load(
                        scope: .department,
                        range: .week,
                        force: true
                    )
                }
            }
        }
    }
}

// MARK: - CrewHome Mapping

private extension CrewView {
    var currentUserID: UUID? {
        session.currentUser?.id
    }

    var backendFriends: [Friend] {
        guard let currentUserID else { return [] }

        return friends.filter {
            $0.ownerUserID == currentUserID.uuidString &&
            $0.backendFriendshipID != nil
        }
    }

    var selectedCrewForDetail: CrewDTO? {
        guard let selectedCrewIDForDetail else { return nil }

        return crewStore.crews.first {
            $0.id == selectedCrewIDForDetail
        }
    }

    var selectedFriendForDetail: Friend? {
        guard let selectedFriendIDForDetail else { return nil }

        return backendFriends.first {
            $0.id == selectedFriendIDForDetail
        }
    }

    var crewArenaStudentContext: CrewArenaStudentContext {
        CrewArenaStudentContext(
            institutionName: studentStore.profile?.institutionName,
            majorName: studentStore.profile?.majorName,
            institutionCountry: studentStore.profile?.institutionCountry,
            courseCount: studentStore.courses.count
        )
    }

    var crewHomeSummary: CrewHomeSummary {
        CrewHomeSummary(
            crewCount: visibleCrewCount,
            friendCount: backendFriends.count,
            requestCount: incomingRequests.count + sentRequests.count,
            liveCount: activeFriendFocusCount + crewStore.activeFocusSessionByCrew.count
        )
    }
    var visibleCrewCount: Int {
        crewStore.crews.filter { crew in
            guard let currentUserID else { return true }

            let myMemberState = crewStore.crewMembers.first {
                $0.crew_id == crew.id && $0.user_id == currentUserID
            }

            return myMemberState?.is_archived != true
        }.count
    }
    
    var crewHomeCrewCards: [CrewSocialCrewCardData] {
        let userID = currentUserID

        let visibleCrews = crewStore.crews
            .filter { crew in
                guard let userID else { return true }

                let myMemberState = crewStore.crewMembers.first { member in
                    member.crew_id == crew.id && member.user_id == userID
                }

                return myMemberState?.is_archived != true
            }
            .sorted { lhs, rhs in
                let lhsMember = userID.flatMap { resolvedUserID in
                    crewStore.crewMembers.first { member in
                        member.crew_id == lhs.id && member.user_id == resolvedUserID
                    }
                }

                let rhsMember = userID.flatMap { resolvedUserID in
                    crewStore.crewMembers.first { member in
                        member.crew_id == rhs.id && member.user_id == resolvedUserID
                    }
                }

                let lhsPinned = lhsMember?.is_pinned ?? false
                let rhsPinned = rhsMember?.is_pinned ?? false

                if lhsPinned != rhsPinned {
                    return lhsPinned && !rhsPinned
                }

                let lhsDate = lhs.last_message_at.flatMap { CrewDateParser.parse($0) }
                    ?? CrewDateParser.parse(lhs.created_at)
                    ?? .distantPast

                let rhsDate = rhs.last_message_at.flatMap { CrewDateParser.parse($0) }
                    ?? CrewDateParser.parse(rhs.created_at)
                    ?? .distantPast

                return lhsDate > rhsDate
            }

        return visibleCrews.enumerated().map { _, crew in
            let memberCount = crewStore.memberCountByCrew[crew.id] ?? 0
            let taskCount = crewStore.taskCountByCrew[crew.id] ?? 0
            let completedTaskCount = crewStore.completedTaskCountByCrew[crew.id] ?? 0
            let isLive = crewStore.activeFocusSessionByCrew[crew.id] != nil

            let realFocusMinutes = crewStore.crewFocusRecords
                .filter { record in
                    record.crew_id == crew.id
                }
                .map(\.minutes)
                .reduce(0, +)

            // Real numbers only — an honest 0 beats an invented streak/minute.
            let streakDays = CrewHomeFormatters.crewStreakDays(
                records: crewStore.crewFocusRecords,
                crewID: crew.id
            )

            let myMemberState = userID.flatMap { resolvedUserID in
                crewStore.crewMembers.first { member in
                    member.crew_id == crew.id && member.user_id == resolvedUserID
                }
            }

            return CrewSocialCrewCardData(
                id: crew.id,
                name: crew.name,
                icon: crew.icon,
                colorHex: crew.color_hex,
                memberCount: max(memberCount, 1),
                taskCount: taskCount,
                completedTaskCount: completedTaskCount,
                isLive: isLive,
                weeklyFocusMinutes: realFocusMinutes,
                rankText: nil,
                streakDays: streakDays,
                thisWeekFocusMinutes: CrewHomeFormatters.weeklyFocusMinutes(
                    records: crewStore.crewFocusRecords,
                    crewID: crew.id
                ),
                weeklyGoalMinutes: crewStore.weeklyGoalMinutes(for: crew.id),
                lastMessageText: crew.last_message_text,
                unreadCount: myMemberState?.unread_count ?? 0,
                isPinned: myMemberState?.is_pinned ?? false,
                isMuted: myMemberState?.is_muted ?? false,
                isArchived: myMemberState?.is_archived ?? false
            )
        }
    }
    
    var crewHomeFriendCards: [CrewSocialFriendCardData] {
        backendFriends.map { friend in
            let activeSession = activeFocusSession(for: friend)
            let resolvedOnline = resolvedOnlineState(for: friend)
            let sharedStat = socialStats.stat(for: friend.backendUserID)

            return CrewSocialFriendCardData(
                id: friend.id,
                displayName: friend.name,
                subtitle: friend.subtitle,
                avatarSymbol: friend.avatarSymbol,
                colorHex: friend.colorHex,
                isOnline: resolvedOnline,
                isFocusing: (sharedStat?.isFocusing ?? false) || activeSession != nil,
                focusMinutes: activeSession.map { focusMinutesLeft(for: $0) },
                streak: sharedStat?.currentStreak,
                level: sharedStat?.level
            )
        }
    }

    var crewHomeIncomingRequestCards: [CrewSocialRequestCardData] {
        incomingRequests.map { request in
            CrewSocialRequestCardData(
                id: request.id,
                title: requestDisplayName(for: request),
                subtitle: tr("cv_friend_request"),
                username: requestUsername(for: request),
                kind: .incoming
            )
        }
    }

    var crewHomeSentRequestCards: [CrewSocialRequestCardData] {
        sentRequests.map { request in
            CrewSocialRequestCardData(
                id: request.id,
                title: requestDisplayName(for: request),
                subtitle: tr("cv_request_sent"),
                username: requestUsername(for: request),
                kind: .sent
            )
        }
    }
}

// MARK: - Friend Requests

private extension CrewView {
    var incomingRequests: [FriendshipDTO] {
        guard let currentUserID else { return [] }

        return friendStore.friendships.filter {
            $0.status == "pending" &&
            $0.addressee_id == currentUserID
        }
    }

    var sentRequests: [FriendshipDTO] {
        guard let currentUserID else { return [] }

        return friendStore.friendships.filter {
            $0.status == "pending" &&
            $0.requester_id == currentUserID
        }
    }

    func otherUserID(for friendship: FriendshipDTO) -> UUID? {
        guard let currentUserID else { return nil }

        return friendship.requester_id == currentUserID
        ? friendship.addressee_id
        : friendship.requester_id
    }

    func requestDisplayName(for friendship: FriendshipDTO) -> String {
        guard
            let otherUserID = otherUserID(for: friendship),
            let profile = friendStore.profiles[otherUserID]
        else {
            return String(localized: "crew_unknown_user")
        }

        if let fullName = profile.full_name,
           !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fullName
        }

        if let username = profile.username,
           !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return username
        }

        return profile.email ?? String(localized: "crew_unknown_user")
    }

    func requestUsername(for friendship: FriendshipDTO) -> String {
        guard
            let otherUserID = otherUserID(for: friendship),
            let profile = friendStore.profiles[otherUserID]
        else {
            return String(localized: "crew_unknown_username")
        }

        return profile.username ??
        profile.email ??
        String(localized: "crew_unknown_username")
    }

    func acceptRequest(_ request: FriendshipDTO) async {
        do {
            try await friendStore.acceptFriendRequest(friendshipID: request.id)
            await reloadBackendFriends(force: true)
        } catch {
            Log.debug("ACCEPT FRIEND REQUEST ERROR:", error.localizedDescription)
        }
    }

    func removePendingRequest(_ request: FriendshipDTO) async {
        do {
            try await SupabaseManager.shared.client
                .from("friendships")
                .delete()
                .eq("id", value: request.id.uuidString)
                .execute()

            await reloadBackendFriends(force: true)
        } catch {
            Log.debug("REMOVE PENDING FRIEND REQUEST ERROR:", error.localizedDescription)
        }
    }
}

// MARK: - Focus / Presence

private extension CrewView {
    var activeFriendFocusCount: Int {
        activeFocusSessions.count
    }

    var activeFocusSessions: [FriendFocusSession] {
        guard let currentUserID else { return [] }

        let visibleFriendIDs = Set(backendFriends.map(\.id))

        return focusSessions.filter {
            $0.ownerUserID == currentUserID &&
            $0.isActive &&
            visibleFriendIDs.contains($0.friendID)
        }
    }

    func activeFocusSession(for friend: Friend) -> FriendFocusSession? {
        focusSessions.first {
            $0.friendID == friend.id &&
            $0.isActive
        }
    }

    func focusMinutesLeft(for session: FriendFocusSession) -> Int {
        let endDate = session.startedAt.addingTimeInterval(
            TimeInterval(session.durationMinute * 60)
        )

        let remaining = Int(endDate.timeIntervalSinceNow / 60.0)
        return max(0, remaining)
    }

    func resolvedOnlineState(for friend: Friend) -> Bool {
        guard
            let backendUserID = friend.backendUserID,
            let presence = friendStore.presenceByUserID[backendUserID]
        else {
            return friend.isOnline
        }

        return presence.is_online
    }
}

// MARK: - Loading / Sync

private extension CrewView {
    func initialLoadIfNeeded() async {
        guard session.currentUser?.id != nil else { return }

        

        await crewStore.loadCrews(force: true)
        await crewStore.loadStatsForAllCrews()
        await crewStore.loadCurrentUserMembershipsForHome()
        await crewStore.loadHomeCacheForAllCrews()

        await reloadBackendFriends(force: false)
    }

    func reloadAllCrewAndFriendData(forceCrews: Bool) async {

        if forceCrews {
            await crewStore.loadCrews(force: true)
        } else if crewStore.crews.isEmpty {
            await crewStore.loadCrews()
        }

        await crewStore.loadStatsForAllCrews()
        await crewStore.loadCurrentUserMembershipsForHome()
        await crewStore.loadHomeCacheForAllCrews()

        await reloadBackendFriends(force: forceCrews)
    }
    
    func reloadBackendFriends(force: Bool) async {
        guard let currentUserID = session.currentUser?.id else { return }

        if friendStore.isRefreshingFriends { return }

        if !force {
            if !friendStore.shouldRefreshFriends(force: false) { return }
            if !friendStore.shouldDoForegroundRefresh() { return }
        }

        friendStore.isRefreshingFriends = true

        defer {
            friendStore.isRefreshingFriends = false
            friendStore.markForegroundRefreshDone()
        }

        await friendStore.loadAllFriendships(currentUserID: currentUserID)

        let otherUserIDs = friendStore.friendships.compactMap { friendship -> UUID? in
            if friendship.requester_id == currentUserID {
                return friendship.addressee_id
            } else if friendship.addressee_id == currentUserID {
                return friendship.requester_id
            } else {
                return nil
            }
        }

        await friendStore.loadProfiles(for: otherUserIDs)
        await friendStore.loadPresence(for: otherUserIDs)

        friendStore.syncAcceptedFriendsToLocal(
            currentUserID: currentUserID,
            modelContext: modelContext
        )

        friendStore.subscribeToPresenceRealtime(for: otherUserIDs)

        friendStore.markFriendsCacheRefreshed()

        // Pro-only social stats layer (no request when the viewer isn't Pro).
        socialStats.refresh(
            userIDs: otherUserIDs,
            isPro: SubscriptionManager.shared.isPro,
            force: force
        )
    }
}

// MARK: - Loading View

private struct CrewRedesignLoadingView: View {
    let text: String

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.03, green: 0.03, blue: 0.08),
                    Color(red: 0.04, green: 0.02, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Skeleton layout mimicking a detail screen while it resolves
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    SkeletonView(width: 64, height: 64, radius: 20)

                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonView(width: 150, height: 18, radius: 6)
                        SkeletonView(width: 100, height: 12, radius: 6)
                    }

                    Spacer()
                }

                SkeletonView(height: 90, radius: 20)

                VStack(spacing: 10) {
                    SkeletonView(height: 56, radius: 16)
                    SkeletonView(height: 56, radius: 16)
                    SkeletonView(height: 56, radius: 16)
                }

                Spacer()

                Text(text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
