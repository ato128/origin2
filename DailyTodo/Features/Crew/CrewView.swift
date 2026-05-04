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

    init(initialTab: CrewTabMode = .crews) {
        self.initialTab = initialTab
    }

    var body: some View {
        NavigationStack {
            CrewHomeView(
                initialTab: initialTab,
                summary: crewHomeSummary,
                studentContext: crewArenaStudentContext,
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
                    CrewRedesignLoadingView(text: "Crew hazırlanıyor...")
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
                    CrewRedesignLoadingView(text: "Arkadaş hazırlanıyor...")
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

                await initialLoadIfNeeded()
                crewStore.subscribeToCrewsListRealtime(for: userID)

                didLoad = true
            }
            .onChange(of: session.currentUser?.id) { newID in
                Task {
                    if newID == nil {
                        crewStore.resetForUserChange()
                        didLoad = false
                        return
                    }

                    crewStore.resetForUserChange()
                    didLoad = false

                    await reloadAllCrewAndFriendData(forceCrews: true)

                    if let newID {
                        crewStore.subscribeToCrewsListRealtime(for: newID)
                    }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }

                Task {
                    await reloadBackendFriends(force: false)
                }
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
            crewCount: crewStore.crews.count,
            friendCount: backendFriends.count,
            requestCount: incomingRequests.count + sentRequests.count,
            liveCount: activeFriendFocusCount + crewStore.activeFocusSessionByCrew.count
        )
    }

    var crewHomeCrewCards: [CrewSocialCrewCardData] {
        crewStore.crews.enumerated().map { index, crew in
            let memberCount = crewStore.memberCountByCrew[crew.id] ?? 0
            let taskCount = crewStore.taskCountByCrew[crew.id] ?? 0
            let completedTaskCount = crewStore.completedTaskCountByCrew[crew.id] ?? 0
            let isLive = crewStore.activeFocusSessionByCrew[crew.id] != nil

            let weeklyFocusMinutes = CrewHomeFormatters.pseudoFocusMinutes(
                memberCount: memberCount,
                completedTaskCount: completedTaskCount,
                taskCount: taskCount,
                isLive: isLive
            )

            let streakDays = CrewHomeFormatters.pseudoStreakDays(
                memberCount: memberCount,
                completedTaskCount: completedTaskCount,
                isLive: isLive
            )

            return CrewSocialCrewCardData(
                id: crew.id,
                name: crew.name,
                icon: crew.icon,
                colorHex: crew.color_hex,
                memberCount: memberCount,
                taskCount: taskCount,
                completedTaskCount: completedTaskCount,
                isLive: isLive,
                weeklyFocusMinutes: weeklyFocusMinutes,
                rankText: CrewHomeFormatters.pseudoRankText(index: index),
                streakDays: streakDays
            )
        }
    }

    var crewHomeFriendCards: [CrewSocialFriendCardData] {
        backendFriends.map { friend in
            let activeSession = activeFocusSession(for: friend)
            let resolvedOnline = resolvedOnlineState(for: friend)

            return CrewSocialFriendCardData(
                id: friend.id,
                displayName: friend.name,
                subtitle: friend.subtitle,
                avatarSymbol: friend.avatarSymbol,
                colorHex: friend.colorHex,
                isOnline: resolvedOnline,
                isFocusing: activeSession != nil,
                focusMinutes: activeSession.map { focusMinutesLeft(for: $0) }
            )
        }
    }

    var crewHomeIncomingRequestCards: [CrewSocialRequestCardData] {
        incomingRequests.map { request in
            CrewSocialRequestCardData(
                id: request.id,
                title: requestDisplayName(for: request),
                subtitle: "Arkadaşlık isteği",
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
                subtitle: "İstek gönderildi",
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
            print("ACCEPT FRIEND REQUEST ERROR:", error.localizedDescription)
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
            print("REMOVE PENDING FRIEND REQUEST ERROR:", error.localizedDescription)
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
        await reloadBackendFriends(force: false)
    }

    func reloadAllCrewAndFriendData(forceCrews: Bool) async {
        if forceCrews {
            await crewStore.loadCrews(force: true)
        } else if crewStore.crews.isEmpty {
            await crewStore.loadCrews()
        }

        await crewStore.loadStatsForAllCrews()
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

        friendStore.markFriendsCacheRefreshed()
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

            VStack(spacing: 14) {
                ProgressView()
                    .tint(.white)

                Text(text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
