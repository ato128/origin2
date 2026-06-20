//
//  MainTabView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//


import SwiftUI
import SwiftData
import Foundation

enum AppTab: Hashable, CaseIterable {
    case tasks
    case week
    case crew
    case focus
    case insights

    var title: String {
        switch self {
        case .tasks:    return tr("tab_home")
        case .week:     return tr("tab_week")
        case .crew:     return tr("tab_crew")
        case .focus:    return tr("tab_focus")
        case .insights: return tr("tab_insights")
        }
    }

    var iconName: String {
        switch self {
        case .tasks:    return "house.fill"
        case .week:     return "calendar"
        case .crew:     return "person.3.fill"
        case .focus:    return "timer"
        case .insights: return "chart.bar.fill"
        }
    }
}

extension Notification.Name {
    static let openFocusTabFromHome = Notification.Name("openFocusTabFromHome")
}

private enum PendingChatRoute: Identifiable, Equatable {
    case friend(friendshipID: UUID)
    case crew(crewID: UUID)

    var id: String {
        switch self {
        case .friend(let friendshipID):
            return "friend-\(friendshipID.uuidString)"
        case .crew(let crewID):
            return "crew-\(crewID.uuidString)"
        }
    }
}

struct MainTabView: View {
    @Binding var openFocusFromNotification: Bool

    /// When set (during the onboarding spotlight tour), the displayed tab is
    /// forced to this value and the user's own tab taps are ignored.
    var forcedTab: AppTab? = nil

    @Environment(\.modelContext) private var modelContext

    @EnvironmentObject var store: TodoStore
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var friendStore: FriendStore

    @Query(sort: \Friend.createdAt, order: .reverse)
    private var friends: [Friend]

    @Query private var allTasks: [DTTaskItem]
    @Query private var allFocusRecords: [FocusSessionRecord]
    @Environment(\.scenePhase) private var scenePhase

    @State private var tab: AppTab = .tasks
    @State private var pendingChatRoute: PendingChatRoute?

    private var activeTab: AppTab { forcedTab ?? tab }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Aktif ekran
            screenForTab(activeTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)

            // Custom tab bar
            HomeTabBar(selectedTab: forcedTab != nil ? .constant(forcedTab!) : $tab)
                .padding(.horizontal, 22)
                .padding(.bottom, 6)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(item: $pendingChatRoute) { route in
            NavigationStack {
                pendingChatDestination(route)
            }
        }
        .onAppear {
            Log.debug("MAIN TAB CURRENT USER:", session.currentUser?.id.uuidString ?? "nil")

            store.setCurrentUserID(session.currentUser?.id.uuidString)
            crewStore.setCurrentUser(session.currentUser?.id)

            runProgressionEvaluate()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { runProgressionEvaluate() }
        }
        .onChange(of: allTasks.count) { _, _ in runProgressionEvaluate() }
        .onChange(of: completedTaskCount) { _, _ in runProgressionEvaluate() }
        .onChange(of: completedFocusCount) { _, _ in runProgressionEvaluate() }
        .onChange(of: session.currentUser?.id) { _, newUserID in
            Log.debug("MAIN TAB USER CHANGED:", newUserID?.uuidString ?? "nil")

            store.setCurrentUserID(newUserID?.uuidString)
            crewStore.setCurrentUser(newUserID)
            crewStore.resetForUserChange()
        }
        .onChange(of: openFocusFromNotification) { _, newValue in
            guard newValue else { return }

            tab = .focus

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                openFocusFromNotification = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openWeekFromWidget)) { _ in
            tab = .week
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFocusTabFromHome)) { _ in
            tab = .focus
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFriendChatFromNotification)) { output in
            guard let rawID = output.object as? String,
                  let friendshipID = UUID(uuidString: rawID)
            else {
                Log.debug("❌ OPEN FRIEND CHAT FAILED: invalid friendshipID")
                return
            }

            openFriendChatFromNotification(friendshipID: friendshipID)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCrewChatFromNotification)) { output in
            guard let rawID = output.object as? String,
                  let crewID = UUID(uuidString: rawID)
            else {
                Log.debug("❌ OPEN CREW CHAT FAILED: invalid crewID")
                return
            }

            openCrewChatFromNotification(crewID: crewID)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCrewFocusFromNotification)) { output in
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                tab = .focus
            }

            if let payload = output.object as? [AnyHashable: Any] {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    NotificationCenter.default.post(
                        name: .presentCrewFocusInviteSheet,
                        object: payload
                    )
                }
                return
            }

            // Önemli:
            // Notification/deep link yüzünden ActiveFocusView otomatik açılmasın.
            // Sadece Focus tabına geçsin. ActiveFocusView yalnızca join butonundan sonra açılmalı.
        }
    }
}

// MARK: - Tab screens

private extension MainTabView {
    @ViewBuilder
    func screenForTab(_ tab: AppTab) -> some View {
        switch tab {
        case .tasks:
            NavigationStack {
                HomeView(
                    onAddTask: { setTab(.week) },
                    onOpenWeek: { setTab(.week) },
                    onOpenInsights: { setTab(.insights) },
                    onOpenFocus: { setTab(.focus) },
                    onOpenCrew: { setTab(.crew) },
                    onOpenChat: { setTab(.crew) },
                    onOpenTasks: { setTab(.week) }
                )
            }

        case .week:
            NavigationStack {
                WeekView()
            }

        case .crew:
            NavigationStack {
                CrewView(initialTab: .crews)
            }

        case .focus:
            NavigationStack {
                FocusView()
                    .environmentObject(session)
                    .environmentObject(crewStore)
            }

        case .insights:
            NavigationStack {
                InsightsView()
                    .environmentObject(store)
            }
        }
    }

    func setTab(_ newTab: AppTab) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
            tab = newTab
        }
    }

    // MARK: - Unified progression hub

    var completedTaskCount: Int {
        allTasks.filter(\.isDone).count
    }

    var completedFocusCount: Int {
        allFocusRecords.filter { $0.isCompleted && $0.completedSeconds >= 60 }.count
    }

    func runProgressionEvaluate() {
        ProgressionManager.shared.evaluate(
            context: modelContext,
            ownerUserID: session.currentUser?.id.uuidString,
            tasks: allTasks,
            focusRecords: allFocusRecords,
            isPro: SubscriptionManager.shared.isPro
        )
    }
}

// MARK: - Routing helpers

private extension MainTabView {

    @ViewBuilder
    func pendingChatDestination(_ route: PendingChatRoute) -> some View {
        switch route {
        case .friend(let friendshipID):
            if let friend = localFriend(for: friendshipID) {
                FriendChatView(friend: friend)
                    .environmentObject(friendStore)
                    .environmentObject(session)
            } else {
                loadingChatView(tr("mt_chat_preparing"))
                    .task {
                        await prepareFriendRoute(friendshipID: friendshipID)
                    }
            }

        case .crew(let crewID):
            if let crew = weekCrewItem(for: crewID) {
                CrewChatView(crew: crew)
                    .environmentObject(crewStore)
                    .environmentObject(session)
            } else {
                loadingChatView(tr("mt_crew_chat_preparing"))
                    .task {
                        await prepareCrewRoute(crewID: crewID)
                    }
            }
        }
    }

    func loadingChatView(_ text: String) -> some View {
        ZStack {
            AppBackground()

            // Skeleton chat bubbles while the conversation resolves
            VStack(spacing: 14) {
                VStack(spacing: 12) {
                    HStack {
                        SkeletonView(width: 200, height: 40, radius: 18)
                        Spacer()
                    }
                    HStack {
                        Spacer()
                        SkeletonView(width: 160, height: 40, radius: 18)
                    }
                    HStack {
                        SkeletonView(width: 230, height: 40, radius: 18)
                        Spacer()
                    }
                    HStack {
                        Spacer()
                        SkeletonView(width: 120, height: 40, radius: 18)
                    }
                }
                .padding(.horizontal, 20)

                Text(text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.top, 8)
            }
        }
    }

    func openFriendChatFromNotification(friendshipID: UUID) {
        tab = .crew

        Task {
            await prepareFriendRoute(friendshipID: friendshipID)

            await MainActor.run {
                pendingChatRoute = .friend(friendshipID: friendshipID)
            }
        }
    }

    func openCrewChatFromNotification(crewID: UUID) {
        tab = .crew

        Task {
            await prepareCrewRoute(crewID: crewID)

            await MainActor.run {
                pendingChatRoute = .crew(crewID: crewID)
            }
        }
    }

    func prepareFriendRoute(friendshipID: UUID) async {
        guard let currentUserID = session.currentUser?.id else { return }

        if localFriend(for: friendshipID) != nil {
            return
        }

        await friendStore.loadAllFriendships(currentUserID: currentUserID)

        let otherUserIDs = friendStore.friendships.compactMap { friendship -> UUID? in
            if friendship.requester_id == currentUserID { return friendship.addressee_id }
            if friendship.addressee_id == currentUserID { return friendship.requester_id }
            return nil
        }

        await friendStore.loadProfiles(for: otherUserIDs)

        friendStore.syncAcceptedFriendsToLocal(
            currentUserID: currentUserID,
            modelContext: modelContext
        )
    }

    func prepareCrewRoute(crewID: UUID) async {
        crewStore.setCurrentUser(session.currentUser?.id)

        if crewStore.crews.contains(where: { $0.id == crewID }) {
            return
        }

        await crewStore.loadCrews(force: true)
    }

    func localFriend(for friendshipID: UUID) -> Friend? {
        guard let currentUserID = session.currentUser?.id else { return nil }

        return friends.first {
            $0.ownerUserID == currentUserID.uuidString &&
            $0.backendFriendshipID == friendshipID
        }
    }

    func weekCrewItem(for crewID: UUID) -> WeekCrewItem? {
        guard let crew = crewStore.crews.first(where: { $0.id == crewID }) else {
            return nil
        }

        return WeekCrewItem(
            id: crew.id,
            name: crew.name,
            icon: crew.icon,
            colorHex: crew.color_hex
        )
    }
}



// MARK: - Custom Tab Bar

struct HomeTabBar: View {
    @Binding var selectedTab: AppTab

    @Namespace private var namespace
    @State private var pressedTab: AppTab?

    private let barHeight: CGFloat = 66

    private var cyan: Color { Color(arenaHex: "#2DD4FF") }
    private var blue: Color { Color(arenaHex: "#1593FF") }
    private var violet: Color { Color(arenaHex: "#7C3AED") }

    var body: some View {
        HStack(spacing: 5) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: barHeight)
        .background(barBackground)
        .overlay(barBorder)
        .clipShape(RoundedRectangle(cornerRadius: 33, style: .continuous))
        .shadow(color: Color.black.opacity(0.54), radius: 26, y: 16)
        .shadow(color: Color.black.opacity(0.28), radius: 10, y: 5)
        .compositingGroup()
    }

    private var barBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 33, style: .continuous)
                .fill(Color(arenaHex: "#050611").opacity(0.96))

            RoundedRectangle(cornerRadius: 33, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.075),
                            Color.white.opacity(0.030),
                            Color.black.opacity(0.28)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: 33, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            cyan.opacity(0.026),
                            blue.opacity(0.020),
                            violet.opacity(0.024),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 33, style: .continuous)
                .stroke(Color.black.opacity(0.44), lineWidth: 1.2)
                .blur(radius: 0.2)
        }
    }

    private var barBorder: some View {
        RoundedRectangle(cornerRadius: 33, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.135),
                        Color.white.opacity(0.050),
                        blue.opacity(0.075)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    @ViewBuilder
    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selectedTab == tab
        let isPressed = pressedTab == tab

        Button {
            select(tab)
        } label: {
            HStack(spacing: isSelected ? 8 : 0) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        cyan.opacity(0.20),
                                        blue.opacity(0.10),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 2,
                                    endRadius: 20
                                )
                            )
                            .frame(width: 34, height: 34)
                            .blur(radius: 1)
                    }

                    Image(systemName: tab.iconName)
                        .font(.system(size: 16, weight: .black))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(
                            isSelected
                            ? AnyShapeStyle(activeIconGradient)
                            : AnyShapeStyle(Color.white.opacity(0.40))
                        )
                        .scaleEffect(isPressed ? 0.84 : (isSelected ? 1.04 : 1.0))
                        .animation(.spring(response: 0.25, dampingFraction: 0.72), value: isPressed)
                }
                .frame(width: 34, height: 34)

                if isSelected {
                    Text(tab.title)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(activeTextGradient)
                        .lineLimit(1)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity
                            )
                        )
                }
            }
            .frame(maxWidth: isSelected ? 112 : 48)
            .frame(height: 49)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 24.5, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(arenaHex: "#0A1220").opacity(0.98),
                                    Color(arenaHex: "#0A1020").opacity(0.96),
                                    Color(arenaHex: "#0B0716").opacity(0.98)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24.5, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            cyan.opacity(0.135),
                                            blue.opacity(0.080),
                                            violet.opacity(0.060)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24.5, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.14),
                                            cyan.opacity(0.14),
                                            violet.opacity(0.09)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: cyan.opacity(0.10), radius: 12, y: 5)
                        .matchedGeometryEffect(id: "selected-tab-bg", in: namespace)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard pressedTab != tab else { return }
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.70)) {
                        pressedTab = tab
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
                        pressedTab = nil
                    }
                }
        )
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: selectedTab)
        .onboardingTabAnchor(tab)
    }

    private var activeIconGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white,
                cyan.opacity(0.98),
                blue.opacity(0.94),
                violet.opacity(0.88)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var activeTextGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.98),
                cyan.opacity(0.94),
                blue.opacity(0.82)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func select(_ tab: AppTab) {
        if tab == selectedTab {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.prepare()
            generator.impactOccurred(intensity: 0.45)
            return
        }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 0.65)

        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            selectedTab = tab
        }
    }
}
