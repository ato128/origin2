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
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var friendStore: FriendStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    
    

    @State private var showCreateCrewBackend = false

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue

    private let palette = ThemePalette()

    let initialTab: CrewTabMode

    @Query(sort: \Friend.createdAt, order: .reverse)
    private var friends: [Friend]
    
    var currentUserID: UUID? {
        session.currentUser?.id
    }
    
    var backendFriends: [Friend] {
        guard let currentUserID else { return [] }
        return friends.filter {
            $0.ownerUserID == currentUserID.uuidString && $0.backendFriendshipID != nil
        }
    }

    @Query(sort: \FriendFocusSession.startedAt, order: .reverse)
    private var focusSessions: [FriendFocusSession]
    
    

    @State private var crewTabMode: CrewTabMode
    @State private var showJoinFocusSheet = false
    @State private var selectedFocusSession: FriendFocusSession?
    @State private var pulseLiveIndicator = false
    @State private var showJoinCrewSheet = false
    @State private var pendingInviteCode = ""
    @State private var didLoad = false
    @State private var didLoadFriends = false
    @State private var showAddFriendSheet = false
    @State private var selectedFriendForMenu: Friend?
    @State private var showRemoveFriendConfirm = false
    @State private var isRemovingFriend = false
    
   
    

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
                    crewStore.subscribeToCrewsListRealtime(for: newID!)
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
            .alert("crew_remove_friend_confirm_title", isPresented: $showRemoveFriendConfirm) {
                Button("crew_keep_friend", role: .cancel)  { }

                Button("crew_remove", role: .destructive) {
                    Task {
                        guard let friend = selectedFriendForMenu,
                              let friendshipID = friend.backendFriendshipID,
                              let currentUserID = session.currentUser?.id else { return }

                        isRemovingFriend = true

                        do {
                            try await friendStore.removeFriendship(
                                friendshipID: friendshipID,
                                currentUserID: currentUserID,
                                modelContext: modelContext
                            )

                            selectedFriendForMenu = nil
                        } catch {
                            print("REMOVE FRIEND FROM CREW VIEW ERROR:", error.localizedDescription)
                        }

                        isRemovingFriend = false
                    }
                }
            } message: {
                Text("crew_remove_friend_confirm_message")
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
                    Text("crew_title")
                        .font(.system(size: 56, weight: .black, design: .rounded))
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
                        .blur(radius: 2)
                        .opacity(0.34)
                        .offset(x: 2, y: -4)
                }

                Text("crew_title")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(palette.primaryText)
            }

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("crew_your_space")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Text("crew_header_subtitle")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)

                        Text("Aktif alan")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.secondaryText)
                    }
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
                        showAddFriendSheet = true
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
                    Text(localizedCrewTabTitle(mode))
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
                                            Color.blue.opacity(0.40),
                                            Color.purple.opacity(0.28)
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
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
    func localizedCrewTabTitle(_ mode: CrewTabMode) -> String {
        switch mode {
        case .crews:
            return String(localized: "crew_tab_crews")
        case .friends:
            return String(localized: "crew_tab_friends")
        }
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

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Genel Bakış")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Text("Takım üretkenliğine hızlı bakış")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.14))
                        .frame(width: 42, height: 42)

                    Image(systemName: "person.3.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.blue)
                }
            }

            HStack(spacing: 12) {
                premiumOverviewStatPill(
                    value: "\(totalCrews)",
                    title: "Crewler",
                    tint: Color.blue
                )

                premiumOverviewStatPill(
                    value: "\(totalMembers)",
                    title: "Üyeler",
                    tint: Color.purple
                )

                premiumOverviewStatPill(
                    value: "\(totalTasks)",
                    title: "Görevler",
                    tint: Color.orange
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(overviewCardBackground(iconTint: Color.blue))
    }
    func localizedCrewMembersTasks(memberCount: Int, taskCount: Int) -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "\(memberCount) üye • \(taskCount) görev"
        } else {
            return "\(memberCount) members • \(taskCount) tasks"
        }
    }

    func localizedDoneLeft(done: Int, left: Int) -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "\(done) tamamlandı • \(left) kaldı"
        } else {
            return "\(done) done • \(left) left"
        }
    }

    func localizedCompletedTasksText(done: Int, total: Int) -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "\(done)/\(total) görev"
        } else {
            return "\(done)/\(total) tasks"
        }
    }

    func localizedMembersOnly(_ count: Int) -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "\(count) üye"
        } else {
            return "\(count) members"
        }
    }

    func localizedFocusSessionLeft(title: String, minutes: Int) -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "\(title) • \(minutes) dk kaldı"
        } else {
            return "\(title) • \(minutes) min left"
        }
    }

    func localizedFriendsStudyingNow(_ count: Int) -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "\(count) arkadaş şu an çalışıyor"
        } else {
            return "\(count) friend\(count == 1 ? "" : "s") studying now"
        }
    }

    func localizedPendingFriendRequests(_ count: Int) -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "\(count) bekleyen arkadaşlık isteği"
        } else {
            return "\(count) pending friend request"
        }
    }

    func localizedFocusingMinutes(_ minutes: Int) -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "Odaklanıyor • \(minutes) dk"
        } else {
            return "Focusing • \(minutes) min"
        }
    }

    func backendCrewCard(for crew: CrewDTO) -> some View {
        let memberCount = crewStore.memberCountByCrew[crew.id] ?? 0
        let taskCount = crewStore.taskCountByCrew[crew.id] ?? 0
        let completedTasks = crewStore.completedTaskCountByCrew[crew.id] ?? 0
        let pendingCount = max(0, taskCount - completedTasks)
        let progress = taskCount == 0 ? 0.0 : Double(completedTasks) / Double(taskCount)

        let accent = hexColor(crew.color_hex)
        let warmTint = crewWarmTint(for: accent)
        let coolTint = crewCoolTint(for: accent)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accent.opacity(0.18))
                        .frame(width: 48, height: 48)

                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        .frame(width: 48, height: 48)

                    Image(systemName: crew.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(crew.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.98))
                        .lineLimit(1)

                    Text(localizedCrewMembersTasks(memberCount: memberCount, taskCount: taskCount))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.70))
                        .lineLimit(1)
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 3) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.36))

                    Spacer(minLength: 8)

                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()

                    Text("tamamlandı")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                }
            }

            Spacer(minLength: 11)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 9) {
                    backendAvatarStack(memberCount: memberCount, tint: accent)

                    Text("İlerleme")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.74))
                }

                Spacer()

                Text(localizedDoneLeft(done: completedTasks, left: pendingCount))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.trailing)
            }

            Spacer(minLength: 10)

            if progress == 1 {
                Text("Tüm görevler tamamlandı")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.14))
                            .frame(height: 9)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        warmTint,
                                        accent,
                                        coolTint
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: max(36, geo.size.width * progress),
                                height: 9
                            )
                    }
                }
                .frame(height: 9)
            }
            Spacer(minLength: 10)

            HStack(spacing: 10) {
                miniPill(
                    icon: "checkmark.circle.fill",
                    text: localizedCompletedTasksText(done: completedTasks, total: taskCount),
                    tint: accent
                )

                miniPill(
                    icon: "person.crop.circle.fill",
                    text: memberCount > 0 ? localizedMembersOnly(memberCount) : String(localized: "crew_no_members"),
                    tint: .white.opacity(0.72)
                )
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                Image(systemName: "bolt.horizontal.circle.fill")
                    .foregroundStyle(accent)

                Text(taskCount > 0 ? "Paylaşılan görevler aktif" : "Crew hazır")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(1)

                Spacer()

                Text("Şimdi")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.44))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 17)
        .padding(.bottom, 15)
        .frame(maxWidth: .infinity, minHeight: 214, alignment: .topLeading)
        .background(
            crewPremiumCardBackground(
                accent: accent,
                warmTint: warmTint,
                coolTint: coolTint
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }
    
    func initialLoadIfNeeded() async {
        guard session.currentUser?.id != nil else { return }

        await crewStore.loadCrews(force: true)
        await crewStore.loadStatsForAllCrews()

        await reloadBackendFriends(force: false)
    }

    func backendAvatarStack(memberCount: Int, tint: Color) -> some View {
        HStack(spacing: -10) {
            ForEach(0..<min(memberCount, 3), id: \.self) { _ in
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 30, height: 30)

                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        .frame(width: 30, height: 30)

                    Image(systemName: "person.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(tint)
                }
            }

            if memberCount > 3 {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 30, height: 30)

                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        .frame(width: 30, height: 30)

                    Text("+\(memberCount - 3)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.88))
                }
            }
        }
    }

    var backendCrewsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("crew_your_crews")
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

            if backendFriends.isEmpty {
                friendsEmptyStateCard
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text("crew_your_friends")
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)
                        .padding(.top, 6)
                        .padding(.bottom, 4)

                    ForEach(backendFriends) { friend in
                        friendRow(friend)
                    }
                }

                friendsEmptyHintCard
            }
        }
    }
    
    var incomingRequests: [FriendshipDTO] {
        guard let currentUserID else { return [] }
        return friendStore.friendships.filter {
            $0.status == "pending" && $0.addressee_id == currentUserID
        }
    }

    var sentRequests: [FriendshipDTO] {
        guard let currentUserID else { return [] }
        return friendStore.friendships.filter {
            $0.status == "pending" && $0.requester_id == currentUserID
        }
    }

    func otherUserID(for friendship: FriendshipDTO) -> UUID? {
        guard let currentUserID else { return nil }
        return friendship.requester_id == currentUserID
            ? friendship.addressee_id
            : friendship.requester_id
    }

    func requestDisplayName(for friendship: FriendshipDTO) -> String {
        guard let otherUserID = otherUserID(for: friendship),
              let profile = friendStore.profiles[otherUserID]
        else { return String(localized: "crew_unknown_user") }

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
        guard let otherUserID = otherUserID(for: friendship),
              let profile = friendStore.profiles[otherUserID]
        else { return String(localized: "crew_unknown_username") }
        
        return profile.username ?? profile.email ?? String(localized: "crew_unknown_username")
    }
    
    var incomingRequestsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("crew_incoming_requests")
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

    var sentRequestsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("crew_sent_requests")
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
    
    func incomingRequestRow(_ request: FriendshipDTO) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.16))
                    .frame(width: 42, height: 42)

                Image(systemName: "person.fill")
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(requestDisplayName(for: request))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)

                Text("@\(requestUsername(for: request))")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    Task {
                        await acceptRequest(request)
                    }
                } label: {
                    Text("crew_accept")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.green.opacity(0.14))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        await removePendingRequest(request)
                    }
                } label: {
                    Text("crew_decline")
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

    func sentRequestRow(_ request: FriendshipDTO) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.16))
                    .frame(width: 42, height: 42)

                Image(systemName: "person.fill")
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(requestDisplayName(for: request))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)

                Text("@\(requestUsername(for: request))")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }

            Spacer()

            Button {
                Task {
                    await removePendingRequest(request)
                }
            } label: {
                Text("week_cancel")
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
    func resolvedOnlineState(for friend: Friend) -> Bool {
        guard let backendUserID = friend.backendUserID,
              let presence = friendStore.presenceByUserID[backendUserID] else {
            return friend.isOnline
        }

        return presence.is_online
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

    func reloadAllCrewAndFriendData(forceCrews: Bool) async {
        if forceCrews {
            await crewStore.loadCrews(force: true)
        } else if crewStore.crews.isEmpty {
            await crewStore.loadCrews()
        }

        await crewStore.loadStatsForAllCrews()
        await reloadBackendFriends(force: forceCrews)
    }

    var friendsFocusActivityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("crew_focus_activity")
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)

                    Text("crew_focus_activity_subtitle")
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

                                Text(localizedFocusSessionLeft(title: session.title, minutes: focusMinutesLeft(for: session)))
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

                                Text("week_live")
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
                    Text("crew_join_focus")
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Arkadaşlar")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Text("Paylaşılan programlar ve direkt iş birliği")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.14))
                        .frame(width: 42, height: 42)

                    Image(systemName: "person.2.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.blue)
                }
            }

            HStack(spacing: 12) {
                premiumOverviewStatPill(
                    value: "\(backendFriends.count)",
                    title: "Arkadaşlar",
                    tint: Color.blue
                )

                premiumOverviewStatPill(
                    value: "\(incomingRequests.count + sentRequests.count)",
                    title: "İstekler",
                    tint: Color.orange
                )

                premiumOverviewStatPill(
                    value: "\(activeFriendFocusCount)",
                    title: "Odakta",
                    tint: Color.green
                )
            }

            if activeFriendFocusCount > 0 {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.green)
                        .frame(width: 7, height: 7)

                    Text(localizedFriendsStudyingNow(activeFriendFocusCount))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.secondaryText)

                    Spacer()
                }
                .padding(.top, 2)
            } else if !incomingRequests.isEmpty {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 7, height: 7)

                    Text(localizedPendingFriendRequests(incomingRequests.count))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.secondaryText)

                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(overviewCardBackground(iconTint: Color.blue))
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

            Text("crew_no_friends_yet")
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            Text("crew_no_friends_subtitle")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)

            Button {
                showAddFriendSheet = true
            } label: {
                Text("crew_add_first_friend")
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

    func premiumOverviewStatPill(value: String, title: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)
                .monospacedDigit()

            Text(title)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.10),
                            tint.opacity(0.05),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(tint.opacity(0.10), lineWidth: 1)
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

            Text("crew_no_crew_yet")
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            Text("crew_no_crew_subtitle")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)

            Button {
                showCreateCrewBackend = true
            } label: {
                Text("crew_create_first_crew")
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
        activeFocusSessions.count
    }

    var friendsEmptyHintCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "message.badge.waveform.fill")
                .font(.system(size: 26))
                .foregroundStyle(Color.accentColor)

            Text("crew_friends_chat_schedule")
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            Text("crew_friends_next_step")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(cardBackground)
    }
    func friendRow(_ friend: Friend) -> some View {
        let activeSession = activeFocusSession(for: friend)
        let isOnline = resolvedOnlineState(for: friend)

        return NavigationLink {
            FriendDetailView(friend: friend)
                .environmentObject(friendStore)
                .environmentObject(session)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.45),
                                    Color.purple.opacity(0.30)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
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
                        Text(localizedFocusingMinutes(session.durationMinute))
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
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)

                        Text("week_live")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                } else {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isOnline ? Color.green : Color.gray.opacity(0.5))
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.85), lineWidth: 2)
                            )

                        Text(isOnline ? String(localized: "chat_online") : String(localized: "friend_info_offline"))
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
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35)
                .onEnded { _ in
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
        )
        .contextMenu {
            NavigationLink {
                FriendChatView(friend: friend)
                    .environmentObject(friendStore)
                    .environmentObject(session)
            } label: {
                Label("crew_chat", systemImage: "message.fill")
            }

            Button(role: .destructive) {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()

                Task {
                    guard let friendshipID = friend.backendFriendshipID,
                          let currentUserID = session.currentUser?.id else { return }

                    do {
                        try await friendStore.removeFriendship(
                            friendshipID: friendshipID,
                            currentUserID: currentUserID,
                            modelContext: modelContext
                        )
                    } catch {
                        print("LONG PRESS REMOVE FRIEND ERROR:", error.localizedDescription)
                    }
                }
            } label: {
                Label("crew_remove_friend", systemImage: "person.crop.circle.badge.xmark")
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        print("LONG PRESS OK")
                    }
            )
        }
    }

    func activeFocusSession(for friend: Friend) -> FriendFocusSession? {
        focusSessions.first(where: { $0.friendID == friend.id && $0.isActive })
    }

    func miniPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
        .foregroundStyle(tint)
    }

    func weekdayIndexToday() -> Int {
        let w = Calendar.current.component(.weekday, from: Date())
        return (w + 5) % 7
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

    func friendForFocusSession(_ session: FriendFocusSession) -> Friend? {
        backendFriends.first(where: { $0.id == session.friendID })
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
    func crewWarmTint(for accent: Color) -> Color {
        Color(red: 0.98, green: 0.52, blue: 0.34)
    }

    func crewCoolTint(for accent: Color) -> Color {
        Color(red: 0.46, green: 0.22, blue: 0.88)
    }

    func crewPremiumCardBackground(
        accent: Color,
        warmTint: Color,
        coolTint: Color
    ) -> some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        warmTint.opacity(0.20),
                        accent.opacity(0.14),
                        coolTint.opacity(0.20),
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
                                Color.white.opacity(0.11),
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
                                warmTint.opacity(0.14),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 8,
                            endRadius: 120
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                coolTint.opacity(0.18),
                                Color.clear
                            ],
                            center: .bottomTrailing,
                            startRadius: 8,
                            endRadius: 160
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
    func overviewCardBackground(iconTint: Color) -> some View {
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
                                iconTint.opacity(0.03),
                                Color.clear
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
}
