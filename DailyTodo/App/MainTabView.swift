//
//  MainTabView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//


import SwiftUI
import SwiftData
import Foundation

enum AppTab: Hashable {
    case tasks
    case week
    case crew
    case focus
    case insights
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

    @Environment(\.modelContext) private var modelContext

    @EnvironmentObject var store: TodoStore
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var friendStore: FriendStore

    @Query(sort: \Friend.createdAt, order: .reverse)
    private var friends: [Friend]

    @State private var tab: AppTab = .tasks
    @State private var pendingChatRoute: PendingChatRoute?
    @State private var showTasksSheet: Bool = false

    var body: some View {
        TabView(selection: $tab) {

            NavigationStack {
                HomeView(
                    onAddTask: {
                        showTasksSheet = true
                    },
                    onOpenWeek: {
                        tab = .week
                    },
                    onOpenInsights: {
                        tab = .insights
                    },
                    onOpenFocus: {
                        tab = .focus
                    },
                    onOpenCrew: {
                        tab = .crew
                    },
                    onOpenChat: {
                        tab = .crew
                    },
                    onOpenTasks: {
                        showTasksSheet = true
                    }
                )
            }
            .tabItem { Label("Tasks", systemImage: "checklist") }
            .tag(AppTab.tasks)

            NavigationStack {
                WeekView()
            }
            .tabItem { Label("Week", systemImage: "calendar") }
            .tag(AppTab.week)

            NavigationStack {
                CrewView(initialTab: .crews)
            }
            .tabItem { Label("Crew", systemImage: "person.3.fill") }
            .tag(AppTab.crew)

            NavigationStack {
                FocusView()
                    .environmentObject(session)
                    .environmentObject(crewStore)
            }
            .tabItem { Label("Focus", systemImage: "timer") }
            .tag(AppTab.focus)

            NavigationStack {
                InsightsView()
                    .environmentObject(store)
            }
            .tabItem { Label("Insights", systemImage: "chart.bar") }
            .tag(AppTab.insights)
        }
        .sheet(item: $pendingChatRoute) { route in
            NavigationStack {
                pendingChatDestination(route)
            }
        }
        .sheet(isPresented: $showTasksSheet) {
            NavigationStack {
                TasksView()
                    .environmentObject(store)
                    .environmentObject(session)
            }
        }
        .onAppear {
            print("MAIN TAB CURRENT USER:", session.currentUser?.id.uuidString ?? "nil")

            store.setCurrentUserID(session.currentUser?.id.uuidString)
            crewStore.setCurrentUser(session.currentUser?.id)
            crewStore.resetForUserChange()
        }
        .onChange(of: session.currentUser?.id) { _, newUserID in
            print("MAIN TAB USER CHANGED:", newUserID?.uuidString ?? "nil")

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
                print("❌ OPEN FRIEND CHAT FAILED: invalid friendshipID")
                return
            }

            openFriendChatFromNotification(friendshipID: friendshipID)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCrewChatFromNotification)) { output in
            guard let rawID = output.object as? String,
                  let crewID = UUID(uuidString: rawID)
            else {
                print("❌ OPEN CREW CHAT FAILED: invalid crewID")
                return
            }

            openCrewChatFromNotification(crewID: crewID)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCrewFocusFromNotification)) { output in
            tab = .focus

            if let payload = output.object as? [AnyHashable: Any] {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    NotificationCenter.default.post(
                        name: .presentCrewFocusInviteSheet,
                        object: payload
                    )
                }
            } else if let crewID = output.object as? String {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    NotificationCenter.default.post(
                        name: .presentActiveCrewFocusFromNotification,
                        object: crewID
                    )
                }
            }
        }
    }
}

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
                loadingChatView("Sohbet hazırlanıyor...")
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
                loadingChatView("Crew sohbeti hazırlanıyor...")
                    .task {
                        await prepareCrewRoute(crewID: crewID)
                    }
            }
        }
    }

    func loadingChatView(_ text: String) -> some View {
        ZStack {
            AppBackground()

            VStack(spacing: 14) {
                ProgressView()
                    .tint(.white)

                Text(text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
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
