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
    /// iPad: room for the floating tab rail on the left.
    @Environment(\.padRailInset) private var padRailInset
    @ObservedObject private var arenaStore = ArenaStore.shared
    @ObservedObject private var socialStats = SocialStatsStore.shared

    init(initialTab: CrewTabMode = .crews) {
        self.initialTab = initialTab
    }

    var body: some View {
        GeometryReader { geo in
            if UIDevice.current.userInterfaceIdiom == .pad && geo.size.width >= Self.splitMinWidth {
                padSplit
            } else {
                phoneStack
            }
        }
        .sheet(isPresented: $showCreateCrewBackend) {
            Group {
                CreateCrewBackendView()
                    .environmentObject(session)
                    .environmentObject(crewStore)
            }
            .updoPadSheet()
        }
        .sheet(isPresented: $showJoinCrewSheet) {
            Group {
                JoinCrewSheet(code: pendingInviteCode)
                    .environmentObject(crewStore)
                    .environmentObject(session)
            }
            .updoPadSheet()
        }
        .sheet(isPresented: $showAddFriendSheet) {
            Group {
                AddFriendSheetView()
                    .environmentObject(friendStore)
                    .environmentObject(session)
            }
            .updoPadSheet()
        }
        // A crew nudge push (or another tab) asked for a crew's page.
        .onAppear {
            if let crewID = CrewDeepLink.takeDetailCrew() {
                selectedFriendIDForDetail = nil
                selectedCrewIDForDetail = crewID
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCrewDetail)) { output in
            guard let raw = output.object as? String, let crewID = UUID(uuidString: raw) else { return }
            CrewDeepLink.pendingDetailCrewID = nil
            selectedFriendIDForDetail = nil
            selectedCrewIDForDetail = crewID
        }
        .task {
            guard !didLoad else { return }
            guard let userID = session.currentUser?.id else { return }

            didLoad = true

            // Cache-first: son bilinen crew listesini + arkadaşlıkları diskten
            // ANINDA göster; ağ tazelemesi (aşağıda) SWR olarak sessizce üzerine
            // yazar. Böylece Sosyal sekmesine her girişte liste boşalıp geri
            // gelmez (kendi kendine yüklenip gitme / flicker fix). Her ikisi de
            // yalnız boşken hidrate eder → taze veriyi eski cache ile ezmez.
            crewStore.hydrateCrewListCacheIfNeeded()
            if friendStore.friendships.isEmpty {
                friendStore.loadFriendshipsFromCache(currentUserID: userID)
            }

            // Heavy hydrate at most once per TTL window — realtime covers
            // the gaps, so tab-hopping doesn't spam the backend.
            if crewStore.shouldRunCrewTabHydrate() {
                await initialLoadIfNeeded()
                await crewStore.loadCrews()
                await crewStore.loadCrewHomeSnapshot()
            }

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

            #if DEBUG
            // QA/screenshot hook: `-debugSocialFriend 1` opens that friend.
            if let raw = UserDefaults.standard.string(forKey: "debugSocialFriend"),
               let index = Int(raw), backendFriends.indices.contains(index) {
                selectedFriendIDForDetail = backendFriends[index].id
            }
            // `-debugSocialCrew 0` opens that crew's detail.
            if UserDefaults.standard.string(forKey: "debugSocialCrew") != nil, crewStore.crews.isEmpty {
                await crewStore.loadCrews(force: true)
            }
            if let raw = UserDefaults.standard.string(forKey: "debugSocialCrew"),
               let index = Int(raw), crewStore.crews.indices.contains(index) {
                selectedCrewIDForDetail = crewStore.crews[index].id
            }
            #endif
        }
        .onChange(of: session.currentUser?.id) { _, newID in
            Task {
                if newID == nil {
                    crewStore.resetForUserChange()
                    ArenaStore.shared.resetForUserChange()
                    friendStore.unsubscribeFriendshipsRealtime()
                    friendStore.unsubscribePresenceRealtime()
                    didLoad = false
                    return
                }

                crewStore.resetForUserChange()
                ArenaStore.shared.resetForUserChange()
                friendStore.unsubscribeFriendshipsRealtime()
                friendStore.unsubscribePresenceRealtime()
                didLoad = false

                await reloadAllCrewAndFriendData(forceCrews: true)

                if let newID {
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

    /// iPad: below this the list + detail split gets too tight → phone stack.
    static let splitMinWidth: CGFloat = 900
    static let listWidth: CGFloat = 420

    var crewHome: some View {
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
                selectedFriendIDForDetail = nil
                selectedCrewIDForDetail = crewID
            },
            onOpenFriend: { friendID in
                selectedCrewIDForDetail = nil
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
            },
            onRefresh: {
                await reloadBackendFriends(force: true)
            }
        )
    }

    /// iPhone (and narrow iPad windows): the list, pushing crew/friend screens.
    var phoneStack: some View {
        NavigationStack {
            crewHome
                .updoReadableColumn()
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
                    .updoReadableColumn()
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
                    .updoReadableColumn()
            } else {
                CrewRedesignLoadingView(text: tr("cv_friend_preparing"))
            }
        }
        }
    }

    // MARK: iPad split (Messages-style)

    /// iPad: the list stays on the left; the selected crew or friend opens in
    /// the detail column on the right (with its own navigation), like Messages.
    var padSplit: some View {
        HStack(spacing: 0) {
            NavigationStack {
                crewHome
                    // The list's background runs under the rail; its cards don't.
                    .safeAreaPadding(.leading, padRailInset)
                    .navigationBarHidden(true)
            }
            .frame(width: Self.listWidth + padRailInset)
            .environment(\.crewHomeSelectedID, selectedCrewIDForDetail ?? selectedFriendIDForDetail)

            Rectangle()
                .fill(UpdoTheme.border)
                .frame(width: 1)
                .ignoresSafeArea()

            NavigationStack {
                padDetail
            }
            // A new selection is a fresh detail stack (no stale pushes).
            .id(selectedCrewIDForDetail ?? selectedFriendIDForDetail)
            .environment(\.socialSplitClose, {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedCrewIDForDetail = nil
                    selectedFriendIDForDetail = nil
                }
            })
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    var padDetail: some View {
        if selectedCrewIDForDetail != nil {
            if let crew = selectedCrewForDetail {
                BackendCrewDetailView(crew: crew)
                    .environmentObject(crewStore)
                    .environmentObject(session)
                    .updoReadableColumn()
            } else {
                CrewRedesignLoadingView(text: tr("cv_crew_preparing"))
            }
        } else if selectedFriendIDForDetail != nil {
            if let friend = selectedFriendForDetail {
                FriendDetailView(friend: friend)
                    .environmentObject(friendStore)
                    .environmentObject(session)
                    .updoReadableColumn()
            } else {
                CrewRedesignLoadingView(text: tr("cv_friend_preparing"))
            }
        } else {
            SocialSplitPlaceholder(
                onAddFriend: { showAddFriendSheet = true },
                onCreateCrew: { showCreateCrewBackend = true }
            )
        }
    }
}

/// iPad Social detail column before anything is picked: never a blank pane.
private struct SocialSplitPlaceholder: View {
    let onAddFriend: () -> Void
    let onCreateCrew: () -> Void

    private var blue: Color { Color(arenaHex: "#1593FF") }
    private var violet: Color { Color(arenaHex: "#7C3AED") }

    var body: some View {
        ZStack {
            ArenaBackground(
                primaryGlow: violet,
                secondaryGlow: Color(arenaHex: "#2DD4FF"),
                warmGlow: Color(arenaHex: "#FF5A44"),
                intensity: 0.7
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [blue.opacity(0.22), violet.opacity(0.18)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 104, height: 104)
                        .overlay(Circle().strokeBorder(UpdoTheme.filmy(0.12), lineWidth: 1))
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: [Color(arenaHex: "#2DD4FF"), violet],
                                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                }

                VStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text(tr("ipad_social_empty_title"))
                            .font(.system(size: 30, weight: .black))
                            .foregroundStyle(UpdoTheme.textPrimary)
                        Text(tr("ipad_social_empty_accent"))
                            .font(.system(size: 28, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(LinearGradient(colors: [Color(arenaHex: "#2DD4FF"), violet],
                                                            startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    Text(tr("ipad_social_empty_sub"))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }

                HStack(spacing: 12) {
                    Button(action: onAddFriend) {
                        Label(tr("ch_add_friend"), systemImage: "person.badge.plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(UpdoTheme.onAccent)
                            .padding(.horizontal, 20)
                            .frame(height: 46)
                            .background(Capsule().fill(LinearGradient(colors: [blue, violet],
                                                                      startPoint: .leading, endPoint: .trailing)))
                            .contentShape(.hoverEffect, Capsule())
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.lift)

                    Button(action: onCreateCrew) {
                        Label(tr("ch_create_crew"), systemImage: "person.3.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(UpdoTheme.textPrimary)
                            .padding(.horizontal, 20)
                            .frame(height: 46)
                            .liquidGlass(in: Capsule())
                            .overlay(Capsule().strokeBorder(UpdoTheme.border, lineWidth: 1))
                            .contentShape(.hoverEffect, Capsule())
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.lift)
                }
                .padding(.top, 6)
            }
            .padding(40)
        }
        .toolbar(.hidden, for: .navigationBar)
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
            let presence = friend.backendUserID.flatMap { friendStore.presenceByUserID[$0] }

            return CrewSocialFriendCardData(
                id: friend.id,
                displayName: friend.name,
                subtitle: friend.subtitle,
                avatarSymbol: friend.avatarSymbol,
                colorHex: friend.colorHex,
                isOnline: resolvedOnline,
                isFocusing: (sharedStat?.isFocusing ?? false) || presence?.is_focusing == true || activeSession != nil,
                // How long they've been focusing (live presence), not minutes left.
                focusMinutes: FriendPresenceEngine.focusMinutes(presence),
                userID: friend.backendUserID,
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
                kind: .incoming,
                userID: request.requester_id
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
                kind: .sent,
                userID: request.addressee_id
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
            // Backend deletes the edge + fans out "friend_removed" to both sides.
            try await FriendBackendClient.shared.decline(edgeID: request.id)
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
                    .foregroundStyle(UpdoTheme.filmy(0.45))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
