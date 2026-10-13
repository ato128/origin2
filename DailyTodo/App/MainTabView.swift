//
//  MainTabView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//


import SwiftUI
import SwiftData
import Foundation
import UIKit
import Combine

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
        case .insights: return "person.crop.circle.fill"
        }
    }
}

extension Notification.Name {
    static let openFocusTabFromHome = Notification.Name("openFocusTabFromHome")
    static let startFocusFromWidget = Notification.Name("startFocusFromWidget")
    static let openInsightsTab = Notification.Name("openInsightsTab")
    static let openCrewTab = Notification.Name("openCrewTab")
    static let openWeekTab = Notification.Name("openWeekTab")
}

// MARK: - Home dock (mini tab bar under the Home chat)

/// How much room the Home chat leaves under its composer for the tab bar
/// (0 while the keyboard is up — the bar hides then).
private struct HomeDockReserveKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var homeDockReserve: CGFloat {
        get { self[HomeDockReserveKey.self] }
        set { self[HomeDockReserveKey.self] = newValue }
    }
}

/// Keyboard up/down, published on the keyboard's own will-show/hide timing so
/// the Home tab bar can leave and come back in step with it.
@MainActor
final class KeyboardVisibility: ObservableObject {
    @Published private(set) var isVisible = false
    private var cancellables = Set<AnyCancellable>()

    init() {
        let center = NotificationCenter.default
        center.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { _ in true }
            .merge(with: center.publisher(for: UIResponder.keyboardWillHideNotification).map { _ in false })
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] visible in
                withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                    self?.isVisible = visible
                }
            }
            .store(in: &cancellables)
    }
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
    @State private var showReferralReward = false
    /// Home shows a mini tab bar under the chat; a tap grows it to full size.
    @State private var homeBarExpanded = false
    @State private var homeBarCollapseTask: Task<Void, Never>?
    @StateObject private var keyboard = KeyboardVisibility()

    private var activeTab: AppTab { forcedTab ?? tab }

    private var isOnHome: Bool { activeTab == .tasks }
    private var tabBarCompact: Bool { isOnHome && !homeBarExpanded }
    /// On Home the keyboard belongs to the chat composer: the bar steps aside.
    private var tabBarHidden: Bool { isOnHome && keyboard.isVisible }

    private var homeDockReserve: CGFloat {
        guard !tabBarHidden else { return 0 }
        return (tabBarCompact ? HomeTabBar.compactHeight : HomeTabBar.fullHeight) + 10
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Aktif ekran
            screenForTab(activeTab)
                .environment(\.homeDockReserve, homeDockReserve)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)

            // Custom tab bar
            HomeTabBar(
                selectedTab: forcedTab != nil ? .constant(forcedTab!) : $tab,
                isCompact: tabBarCompact,
                onExpand: expandHomeBar,
                onReselect: { reselected in
                    if reselected == .tasks { collapseHomeBar() }
                }
            )
            .padding(.horizontal, tabBarCompact ? 0 : 22)
            .padding(.bottom, 6)
            .offset(y: tabBarHidden ? 120 : 0)
            .opacity(tabBarHidden ? 0 : 1)
            .allowsHitTesting(!tabBarHidden)
        }
        // Home: the chat composer rides the keyboard (bar hides). Other tabs keep
        // their old behavior — the layout ignores the keyboard.
        .ignoresSafeArea(.keyboard, edges: isOnHome ? [] : .bottom)
        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: tabBarCompact)
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: tabBarHidden)
        .onChange(of: activeTab) { _, newTab in
            // Back on Home → the bar shrinks again (animated).
            if newTab == .tasks { collapseHomeBar() }
        }
        .fullScreenCover(item: $pendingChatRoute) { route in
            NavigationStack {
                pendingChatDestination(route)
            }
        }
        // Referral reward earned (3 new-install friends) → refresh Premium and
        // celebrate + upsell Premium AI. Extracted to a modifier to keep this
        // (already large) body type-checkable.
        .modifier(ReferralRewardPresenter(isPresented: $showReferralReward, session: session))
        .onAppear {
            Log.debug("MAIN TAB CURRENT USER:", session.currentUser?.id.uuidString ?? "nil")

            store.setCurrentUserID(session.currentUser?.id.uuidString)
            crewStore.setCurrentUser(session.currentUser?.id)

            // Tab bar profil sekmesi Instagram tarzı avatarı gösterebilsin diye
            // kullanıcının fotoğrafını erkenden yükle (lokal cache anında, backend sync arka planda).
            ProfileAvatarStore.shared.load(for: session.currentUser?.id.uuidString)

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

            ProfileAvatarStore.shared.load(for: newUserID?.uuidString)
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
        .onReceive(NotificationCenter.default.publisher(for: .openInsightsTab)) { _ in
            tab = .insights
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCrewTab)) { _ in
            tab = .crew
        }
        .onReceive(NotificationCenter.default.publisher(for: .openWeekTab)) { _ in
            tab = .week
        }
        .onReceive(NotificationCenter.default.publisher(for: .openUpdoAIFromNotification)) { _ in
            // Updo AI lives on Home; HomeView presents the chat with the opener.
            tab = .tasks
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                NotificationCenter.default.post(name: .presentUpdoAIWithOpener, object: nil)
            }
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
            // Home IS the Updo AI chat now (the old dashboard is HomeView).
            NavigationStack {
                HomeAIChatScreen(
                    onOpenWeek: { setTab(.week) },
                    onAddTask: { setTab(.week) }
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

    /// Mini bar tapped on Home → full size; shrinks back by itself if the
    /// user stays on Home.
    func expandHomeBar() {
        homeBarCollapseTask?.cancel()
        homeBarExpanded = true
        homeBarCollapseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled, activeTab == .tasks else { return }
            homeBarExpanded = false
        }
    }

    func collapseHomeBar() {
        homeBarCollapseTask?.cancel()
        homeBarCollapseTask = nil
        homeBarExpanded = false
    }

    // MARK: - Unified progression hub

    var completedTaskCount: Int {
        allTasks.filter(\.isDone).count
    }

    var completedFocusCount: Int {
        allFocusRecords.filter { $0.countsTowardStats }.count
    }

    func runProgressionEvaluate() {
        ProgressionManager.shared.evaluate(
            context: modelContext,
            ownerUserID: session.currentUser?.id.uuidString,
            tasks: allTasks,
            focusRecords: allFocusRecords,
            isPro: SubscriptionManager.shared.isPro
        )

        // Mirror unified stats into widgets / live activities (icon, Pro, streak…).
        let cal = Calendar.current
        let uid = session.currentUser?.id.uuidString
        let taskDoneToday = allTasks.contains {
            ($0.ownerUserID == uid || $0.ownerUserID == nil) && $0.isDone
            && $0.completedAt.map { cal.isDateInToday($0) } == true
        }
        let focusDoneToday = allFocusRecords.contains {
            ($0.ownerUserID == uid || $0.ownerUserID == nil)
            && $0.countsTowardStats && cal.isDateInToday($0.endedAt)
        }

        // Same ring the Insights hero shows — progress toward the next level.
        let scopedTasks = allTasks.filter { $0.ownerUserID == uid || $0.ownerUserID == nil }
        let scopedFocus = allFocusRecords.filter { $0.ownerUserID == uid || $0.ownerUserID == nil }
        let levelProgress = IdentityXPLevelEngine.snapshot(
            currentLevel: ProgressionManager.shared.level,
            tasks: scopedTasks,
            focusSessions: scopedFocus,
            streakDays: ProgressionManager.shared.currentStreak
        ).progress

        // Pro widget'ların veri seti: haftalık odak dizisi, önceki hafta toplamı,
        // ay içi seri günleri ve en verimli saat — hepsi gerçek kayıtlardan.
        let completedFocus = scopedFocus.filter(\.countsTowardStats)
        let today = cal.startOfDay(for: Date())

        func focusMinutes(on day: Date) -> Int {
            completedFocus
                .filter { cal.isDate($0.endedAt, inSameDayAs: day) }
                .reduce(0) { $0 + $1.completedSeconds } / 60
        }

        let last7 = (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
        let weekFocusMinutes = last7.map(focusMinutes(on:))

        var prevWeekTotal = 0
        if let windowEnd = cal.date(byAdding: .day, value: -6, to: today),
           let windowStart = cal.date(byAdding: .day, value: -13, to: today) {
            prevWeekTotal = completedFocus
                .filter { $0.endedAt >= windowStart && $0.endedAt < windowEnd }
                .reduce(0) { $0 + $1.completedSeconds } / 60
        }

        var taskDays = Set<Date>()
        for task in scopedTasks where task.isDone {
            if let done = task.completedAt { taskDays.insert(cal.startOfDay(for: done)) }
        }
        var focusDays = Set<Date>()
        for rec in completedFocus { focusDays.insert(cal.startOfDay(for: rec.endedAt)) }

        var monthFullDays: [Int] = []
        var monthHalfDays: [Int] = []
        if let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: today)) {
            let dayCount = cal.range(of: .day, in: .month, for: monthStart)?.count ?? 30
            for offset in 0..<dayCount {
                guard let day = cal.date(byAdding: .day, value: offset, to: monthStart), day <= today else { break }
                let hasTask = taskDays.contains(day)
                let hasFocus = focusDays.contains(day)
                if hasTask && hasFocus { monthFullDays.append(offset + 1) }
                else if hasTask || hasFocus { monthHalfDays.append(offset + 1) }
            }
        }

        var peakHour: Int?
        if let cutoff = cal.date(byAdding: .day, value: -30, to: Date()) {
            let recent = completedFocus.filter { $0.startedAt >= cutoff }
            if recent.count >= 5 {
                var byHour = Array(repeating: 0, count: 24)
                for s in recent { byHour[cal.component(.hour, from: s.startedAt)] += s.completedSeconds / 60 }
                if let peak = byHour.enumerated().max(by: { $0.element < $1.element }), peak.element > 0 {
                    peakHour = peak.offset
                }
            }
        }

        WidgetAppSync.writeUserState(
            iconName: UIApplication.shared.alternateIconName,
            isPro: SubscriptionManager.shared.isPro,
            streak: ProgressionManager.shared.currentStreak,
            level: ProgressionManager.shared.level,
            todayFocusMinutes: FocusStats.todayMinutes(allFocusRecords, for: session.currentUser?.id.uuidString),
            statsShared: ProgressionManager.shared.statsSharingEnabled,
            longestStreak: ProgressionManager.shared.longestStreak,
            todayTaskDone: taskDoneToday,
            todayFocusDone: focusDoneToday,
            levelProgress: levelProgress,
            weekFocusMinutes: weekFocusMinutes,
            prevWeekFocusMinutes: prevWeekTotal,
            monthFullDays: monthFullDays,
            monthHalfDays: monthHalfDays,
            peakHour: peakHour
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
                    .environmentObject(friendStore)
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
                    .foregroundStyle(UpdoTheme.filmy(0.45))
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
    /// Mini form under the Home chat: icons only, smaller; a tap anywhere on it
    /// asks the host to grow it (`onExpand`) instead of switching tabs.
    var isCompact: Bool = false
    var onExpand: () -> Void = {}
    var onReselect: (AppTab) -> Void = { _ in }

    static let fullHeight: CGFloat = 66
    static let compactHeight: CGFloat = 44

    @Namespace private var namespace

    /// Instagram tarzı: profil sekmesinde kullanıcının fotoğrafı varsa avatarı,
    /// yoksa normal SF Symbol. Mevcut kullanıcının fotoğrafının tek kaynağı.
    @ObservedObject private var avatarStore = ProfileAvatarStore.shared

    private var barHeight: CGFloat { isCompact ? Self.compactHeight : Self.fullHeight }
    private var barRadius: CGFloat { barHeight / 2 }

    private var cyan: Color { Color(arenaHex: "#2DD4FF") }
    private var blue: Color { Color(arenaHex: "#1593FF") }
    private var violet: Color { Color(arenaHex: "#7C3AED") }

    var body: some View {
        HStack(spacing: isCompact ? 2 : 5) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, isCompact ? 6 : 8)
        .frame(height: barHeight)
        .overlay {
            // Mini bar: one tap grows it; the tabs themselves aren't hit yet.
            if isCompact {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let generator = UIImpactFeedbackGenerator(style: .soft)
                        generator.impactOccurred(intensity: 0.55)
                        onExpand()
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(tr("tabbar_expand_a11y"))
            }
        }
        // Eski bar, artık GERÇEK Liquid Glass üstünde: TEK cam yüzey = navigasyon
        // katmanı (iOS 26 .glassEffect / altında .ultraThinMaterial). Seçili "pill"
        // camın üstünde aurora tint — cam-üstüne-cam YOK (hem skill kuralı hem akıcı:
        // kayan materyal yerine kayan hafif tint → geçişte backdrop yeniden örneklenmez).
        .background(
            ZStack {
                // 1) Liquid glass (materyal derinliği/kırılması)
                RoundedRectangle(cornerRadius: barRadius, style: .continuous)
                    .fill(.clear)
                    .liquidGlass(in: RoundedRectangle(cornerRadius: barRadius, style: .continuous))

                // 2) Koyu mavi scrim — camı eski barın koyuluğunda LACİVERT'e boyar.
                RoundedRectangle(cornerRadius: barRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.adaptive(light: Color(arenaHex: "#C9D8F0").opacity(0.55), dark: Color(arenaHex: "#0A1A33").opacity(0.80)),
                                Color.adaptive(light: Color(arenaHex: "#DCE6F5").opacity(0.55), dark: Color(arenaHex: "#081228").opacity(0.84))
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        )
        .overlay(barBorder)
        .clipShape(RoundedRectangle(cornerRadius: barRadius, style: .continuous))
        .shadow(color: UpdoTheme.cardShadow(0.30), radius: 22, y: 13)
    }

    private var barBorder: some View {
        RoundedRectangle(cornerRadius: barRadius, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        UpdoTheme.filmy(0.135),
                        UpdoTheme.filmy(0.050),
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

        Button {
            select(tab)
        } label: {
            HStack(spacing: isSelected && !isCompact ? 8 : 0) {
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
                    }

                    tabGlyph(tab, isSelected: isSelected)
                }
                .frame(width: 34, height: 34)
                .scaleEffect(isCompact ? 0.8 : 1)

                if isSelected && !isCompact {
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
            .frame(maxWidth: isCompact ? 38 : (isSelected ? 112 : 48))
            .frame(height: isCompact ? 34 : 49)
            .background {
                if isSelected {
                    // Seçili "pill" = camın ÜSTÜNDE aurora tint (ikinci bir materyal DEĞİL).
                    // matchedGeometry ile sekmeler arası kayar — "geçiş" bu ışıklı pill.
                    RoundedRectangle(cornerRadius: isCompact ? 17 : 24.5, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    cyan.opacity(0.22),
                                    blue.opacity(0.14),
                                    violet.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: isCompact ? 17 : 24.5, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            UpdoTheme.filmy(0.22),
                                            cyan.opacity(0.12),
                                            UpdoTheme.filmy(0.06)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .matchedGeometryEffect(id: "selected-tab-bg", in: namespace)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: selectedTab)
        .onboardingTabAnchor(tab)
    }

    /// Profil (insights) sekmesi: kullanıcının fotoğrafı varsa daire avatar,
    /// yoksa normal SF Symbol (Instagram tarzı). Diğer sekmeler her zaman symbol.
    @ViewBuilder
    private func tabGlyph(_ tab: AppTab, isSelected: Bool) -> some View {
        if tab == .insights, let avatar = avatarStore.image {
            Image(uiImage: avatar)
                .resizable()
                .scaledToFill()
                .frame(width: 26, height: 26)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(
                            isSelected
                            ? AnyShapeStyle(activeIconGradient)
                            : AnyShapeStyle(UpdoTheme.filmy(0.35)),
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )
                .scaleEffect(isSelected ? 1.04 : 1.0)
                .animation(.spring(response: 0.34, dampingFraction: 0.78), value: isSelected)
        } else {
            Image(systemName: tab.iconName)
                .font(.system(size: 16, weight: .black))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(
                    isSelected
                    ? AnyShapeStyle(activeIconGradient)
                    : AnyShapeStyle(UpdoTheme.filmy(0.40))
                )
                .scaleEffect(isSelected ? 1.04 : 1.0)
                .animation(.spring(response: 0.34, dampingFraction: 0.78), value: isSelected)
        }
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
                UpdoTheme.filmy(0.98),
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
            onReselect(tab)
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

// MARK: - Social Banner
//
// Lightweight in-app banner shown when a social event lands live over the backend
// inbox socket (incoming friend request, request accepted). Foreground only —
// pushes cover the background case. Apple/Updo styled, CPU-light (a single spring
// in/out, auto-dismiss; no continuous animation). Lives here (not its own file) —
// this project's synchronized Xcode target doesn't reliably pick up brand-new
// source files added outside Xcode.

struct SocialBannerData: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
}

@MainActor
final class SocialBannerCenter: ObservableObject {
    static let shared = SocialBannerCenter()

    @Published var current: SocialBannerData?

    private var dismissTask: Task<Void, Never>?

    private init() {}

    func show(title: String, subtitle: String, systemImage: String) {
        let banner = SocialBannerData(title: title, subtitle: subtitle, systemImage: systemImage)

        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            current = banner
        }

        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)

        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_600_000_000)
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        withAnimation(.spring(response: 0.40, dampingFraction: 0.9)) {
            current = nil
        }
    }
}

private struct SocialBannerView: View {
    let data: SocialBannerData
    let onTap: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(UpdoTheme.cyan.opacity(0.16))
                Image(systemName: data.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(UpdoTheme.cyan)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(data.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(UpdoTheme.textPrimary)
                    .lineLimit(1)
                Text(data.subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(UpdoTheme.textMuted)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(UpdoTheme.border, lineWidth: 1)
        )
        .shadow(color: UpdoTheme.cardShadow(0.18), radius: 18, x: 0, y: 8)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .gesture(
            DragGesture(minimumDistance: 12)
                .onEnded { value in
                    if value.translation.height < -8 { onClose() }
                }
        )
    }
}

private struct SocialBannerHostModifier: ViewModifier {
    @ObservedObject private var center = SocialBannerCenter.shared

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let data = center.current {
                SocialBannerView(
                    data: data,
                    onTap: {
                        center.dismiss()
                        // The social hub IS the crew tab.
                        NotificationCenter.default.post(name: .openCrewTab, object: nil)
                    },
                    onClose: { center.dismiss() }
                )
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(999)
            }
        }
    }
}

extension View {
    /// Attach at the app root so social banners float above all content.
    func socialBannerOverlay() -> some View {
        modifier(SocialBannerHostModifier())
    }
}

// MARK: - Referral reward presenter

/// Presents the referral celebration (+ Premium AI upsell) when the backend
/// grants the free month, and refreshes the RevenueCat entitlement. Kept in a
/// modifier so MainTabView's body stays type-checkable.
private struct ReferralRewardPresenter: ViewModifier {
    @Binding var isPresented: Bool
    let session: SessionStore

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented) {
                OnboardingInviteView(onFinish: { isPresented = false })
                    .environmentObject(session)
            }
            .onReceive(NotificationCenter.default.publisher(for: .referralRewardGranted)) { _ in
                Task { await SubscriptionManager.shared.refresh() }
                isPresented = true
            }
    }
}
