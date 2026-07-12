//
//  CrewHomeView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 4.05.2026.
//



import SwiftUI

// MARK: - Crew Arena Palette

private enum CrewArenaPalette {
    static let backgroundTop = "#05060D"
    static let backgroundMid = "#070713"
    static let backgroundBottom = "#07040C"

    static let appBlue = "#1593FF"
    static let appBlueSoft = "#1E6BFF"
    static let appCyan = "#2DD4FF"
    static let appPurple = "#7C3AED"
    static let appViolet = "#8B5CF6"

    static let crewCoral = "#FF5A44"
    static let crewCoralSoft = "#FF7A66"

    static let gold = "#FBBF24"
    static let goldSoft = "#FFE4A3"

    static let liveGreen = "#A3E635"
    static let appleGreen = "#34D399"

    static let surface = "#101118"
    static let surface2 = "#171821"
    static let surface3 = "#20212B"

    static let mutedText = "#8C8C98"

    static var appGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(arenaHex: appBlueSoft),
                Color(arenaHex: appPurple)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var appSoftGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(arenaHex: appBlue).opacity(0.14),
                Color(arenaHex: appPurple).opacity(0.14),
                Color.white.opacity(0.035)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var hotGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(arenaHex: crewCoral),
                Color(arenaHex: "#FF8A4C")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var goldGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(arenaHex: gold),
                Color(arenaHex: goldSoft)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var crewCardGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(arenaHex: appBlueSoft).opacity(0.90),
                Color(arenaHex: appPurple).opacity(0.88),
                Color(arenaHex: crewCoral).opacity(0.60)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Crew Home

struct CrewHomeView: View {
    let initialTab: CrewTabMode

    let summary: CrewHomeSummary
    let studentContext: CrewArenaStudentContext
    @ObservedObject var arenaStore: ArenaStore

    let crews: [CrewSocialCrewCardData]
    let friends: [CrewSocialFriendCardData]
    let incomingRequests: [CrewSocialRequestCardData]
    let sentRequests: [CrewSocialRequestCardData]

    let onCreateCrew: () -> Void
    let onJoinCrew: () -> Void
    let onAddFriend: () -> Void
    let onOpenCrew: (UUID) -> Void
    let onOpenFriend: (UUID) -> Void
    let onAcceptRequest: (UUID) -> Void
    let onRemoveRequest: (UUID) -> Void

    @State private var mode: CrewHomeMode = .social
    @State private var socialTab: CrewSocialTab
    @State private var communityScope: CrewCommunityScope = .department
    @State private var leaderboardRange: CrewLeaderboardRange = .week
    @State private var showRequestsSheet: Bool = false

    init(
        initialTab: CrewTabMode,
        summary: CrewHomeSummary,
        studentContext: CrewArenaStudentContext = .empty,
        arenaStore: ArenaStore,
        crews: [CrewSocialCrewCardData],
        friends: [CrewSocialFriendCardData],
        incomingRequests: [CrewSocialRequestCardData],
        sentRequests: [CrewSocialRequestCardData],
        onCreateCrew: @escaping () -> Void,
        onJoinCrew: @escaping () -> Void,
        onAddFriend: @escaping () -> Void,
        onOpenCrew: @escaping (UUID) -> Void,
        onOpenFriend: @escaping (UUID) -> Void,
        onAcceptRequest: @escaping (UUID) -> Void,
        onRemoveRequest: @escaping (UUID) -> Void
    ) {
        self.initialTab = initialTab
        self.summary = summary
        self.studentContext = studentContext
        self.arenaStore = arenaStore
        self.crews = crews
        self.friends = friends
        self.incomingRequests = incomingRequests
        self.sentRequests = sentRequests
        self.onCreateCrew = onCreateCrew
        self.onJoinCrew = onJoinCrew
        self.onAddFriend = onAddFriend
        self.onOpenCrew = onOpenCrew
        self.onOpenFriend = onOpenFriend
        self.onAcceptRequest = onAcceptRequest
        self.onRemoveRequest = onRemoveRequest

        switch initialTab {
        case .crews:
            _socialTab = State(initialValue: .crews)
        case .friends:
            _socialTab = State(initialValue: .friends)
        }
    }

    var body: some View {
        ZStack {
            CrewArenaBackground()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    Color.clear.frame(height: 6)

                    CrewArenaHeader(
                        mode: mode,
                        scope: communityScope,
                        studentContext: studentContext,
                        liveCount: summary.liveCount,
                        requestCount: summary.requestCount,
                        onAddFriend: onAddFriend,
                        onOpenRequests: {
                            showRequestsSheet = true
                        },
                        onCreateCrew: onCreateCrew,
                        onScopeSelected: { newScope in
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                                communityScope = newScope
                            }
                        }
                    )

                    // Community is hidden pre-launch (FeatureFlags.communityEnabled).
                    // The mode switch only appears when Community is enabled; otherwise
                    // the screen stays locked to the social (crews & friends) experience.
                    if FeatureFlags.communityEnabled {
                        CrewModeSwitch(selectedMode: $mode)
                    }

                    if mode == .social || !FeatureFlags.communityEnabled {
                        CrewSocialContent(
                            selectedTab: $socialTab,
                            summary: summary,
                            crews: crews,
                            friends: friends,
                            incomingRequests: incomingRequests,
                            sentRequests: sentRequests,
                            onOpenCrew: onOpenCrew,
                            onOpenFriend: onOpenFriend,
                            onAcceptRequest: onAcceptRequest,
                            onRemoveRequest: onRemoveRequest,
                            onCreateCrew: onCreateCrew,
                            onJoinCrew: onJoinCrew,
                            onAddFriend: onAddFriend
                        )
                    } else {
                        CrewCommunityContent(
                            scope: $communityScope,
                            range: $leaderboardRange,
                            studentContext: studentContext,
                            arenaStore: arenaStore,
                            onStartFocus: {
                                NotificationCenter.default.post(
                                    name: .openFocusTabFromHome,
                                    object: nil
                                )
                            }
                        )
                    }

                    Color.clear.frame(height: 96)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 18)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showRequestsSheet) {
            CrewRequestsSheet(
                incomingRequests: incomingRequests,
                sentRequests: sentRequests,
                onAcceptRequest: onAcceptRequest,
                onRemoveRequest: onRemoveRequest
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
    }
}

// MARK: - Background

private struct CrewArenaBackground: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(arenaHex: CrewArenaPalette.backgroundTop),
                    Color(arenaHex: CrewArenaPalette.backgroundMid),
                    Color(arenaHex: CrewArenaPalette.backgroundBottom)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(arenaHex: CrewArenaPalette.appBlue).opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 96)
                .offset(x: 165, y: -245)

            Circle()
                .fill(Color(arenaHex: CrewArenaPalette.appPurple).opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 110)
                .offset(x: -175, y: 500)

            Circle()
                .fill(Color(arenaHex: CrewArenaPalette.crewCoral).opacity(0.08))
                .frame(width: 270, height: 270)
                .blur(radius: 100)
                .offset(x: 170, y: 280)

            Circle()
                .fill(Color(arenaHex: CrewArenaPalette.gold).opacity(0.055))
                .frame(width: 240, height: 240)
                .blur(radius: 95)
                .offset(x: -160, y: -170)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.16),
                    Color.black.opacity(0.00),
                    Color.black.opacity(0.42)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Header (yeniden tasarlandı)

private struct CrewArenaHeader: View {
    let mode: CrewHomeMode
    let scope: CrewCommunityScope
    let studentContext: CrewArenaStudentContext
    let liveCount: Int
    let requestCount: Int

    // Yeni callback'ler
    let onAddFriend: () -> Void          // 👤+ arkadaş ekle (sosyal)
    let onOpenRequests: () -> Void       // 📬 istekler tab'ına geç (sosyal)
    let onCreateCrew: () -> Void         // + yeni crew (sosyal)
    let onScopeSelected: (CrewCommunityScope) -> Void  // 🎓 dropdown (arena)

    private var eyebrow: String {
        switch mode {
        case .social:
            return tr("crew_active_zone_live", liveCount)
        case .community:
            return scope.headerEyebrow(studentContext: studentContext)
        }
    }

    private var titleFirst: String {
        switch mode {
        case .social:
            return tr("crew_title_first")
        case .community:
            return scope.headerTitleFirst
        }
    }

    private var titleAccent: String {
        switch mode {
        case .social:
            return tr("crew_title_accent")
        case .community:
            return scope.headerTitleAccent
        }
    }

    private var accentStart: Color {
        mode == .social
        ? Color(arenaHex: CrewArenaPalette.appCyan)
        : Color(arenaHex: CrewArenaPalette.gold)
    }

    private var accentEnd: Color {
        mode == .social
        ? Color(arenaHex: CrewArenaPalette.appPurple)
        : Color(arenaHex: CrewArenaPalette.goldSoft)
    }

    private var animationKey: String {
        "\(mode.rawValue)-\(scope.rawValue)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(
                                mode == .social
                                ? Color(arenaHex: CrewArenaPalette.appBlue)
                                : Color(arenaHex: CrewArenaPalette.gold)
                            )
                            .frame(width: 20, height: 1)

                        Text(eyebrow)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .tracking(2.6)
                            .foregroundStyle(
                                mode == .social
                                ? Color(arenaHex: CrewArenaPalette.appCyan)
                                : Color(arenaHex: CrewArenaPalette.gold)
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                            .id("eyebrow-\(eyebrow)")
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .move(edge: .bottom))
                            ))
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: eyebrow)

                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text(titleFirst)
                            .font(.system(size: 39, weight: .black))
                            .foregroundStyle(.white)
                            .id("title-first-\(titleFirst)")
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .leading)),
                                removal: .opacity.combined(with: .move(edge: .trailing))
                            ))

                        Text(titleAccent)
                            .font(.system(size: 36, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [accentStart, accentEnd],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .id("title-accent-\(titleAccent)")
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: animationKey)
                }

                Spacer()

                // === Yeni Header Actions ===
                headerActions
            }
        }
    }

    @ViewBuilder
    private var headerActions: some View {
        if mode == .social {
            // SOSYAL: 👤+ arkadaş + 📬 istekler + + yeni crew
            HStack(spacing: 8) {
                CrewHeaderIconButton(
                    systemName: "person.badge.plus",
                    emphasized: false,
                    action: onAddFriend
                )

                CrewHeaderIconButton(
                    systemName: "tray.fill",
                    badge: requestCount > 0 ? "\(requestCount)" : nil,
                    emphasized: false,
                    action: onOpenRequests
                )

                CrewHeaderIconButton(
                    systemName: "plus",
                    emphasized: true,
                    action: onCreateCrew
                )
            }
        } else {
            // ARENA: 🎓 BÖLÜM ▾ dropdown
            CrewArenaScopeDropdown(
                selectedScope: scope,
                onScopeSelected: onScopeSelected
            )
        }
    }
}

private struct CrewHeaderIconButton: View {
    let systemName: String
    var badge: String? = nil
    var emphasized: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(emphasized ? .black : .white.opacity(0.82))
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(emphasized ? Color(arenaHex: CrewArenaPalette.appBlue) : Color.white.opacity(0.075))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(.white.opacity(0.10), lineWidth: 1)
                            )
                    )

                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(minWidth: 17, minHeight: 17)
                        .background(Circle().fill(Color(arenaHex: CrewArenaPalette.gold)))
                        .offset(x: 5, y: -5)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Arena Scope Dropdown (yeni)

private struct CrewArenaScopeDropdown: View {
    let selectedScope: CrewCommunityScope
    let onScopeSelected: (CrewCommunityScope) -> Void

    var body: some View {
        Menu {
            ForEach(CrewCommunityScope.allCases) { scope in
                Button {
                    onScopeSelected(scope)
                } label: {
                    HStack {
                        Image(systemName: scope.icon)
                        Text(scope.title)

                        if scope == selectedScope {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: selectedScope.icon)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color(arenaHex: CrewArenaPalette.gold))

                Text(selectedScope.title.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color(arenaHex: CrewArenaPalette.gold))
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(Color(arenaHex: CrewArenaPalette.gold))
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(arenaHex: CrewArenaPalette.gold).opacity(0.16),
                                Color(arenaHex: CrewArenaPalette.crewCoral).opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(arenaHex: CrewArenaPalette.gold).opacity(0.30), lineWidth: 1)
                    )
                    .shadow(color: Color(arenaHex: CrewArenaPalette.gold).opacity(0.15), radius: 10, y: 5)
            )
        }
    }
}

// MARK: - Mode Switch

private struct CrewModeSwitch: View {
    @Binding var selectedMode: CrewHomeMode

    var body: some View {
        HStack(spacing: 6) {
            ForEach(CrewHomeMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                        selectedMode = mode
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 12, weight: .bold))

                        Text(mode.title)
                            .font(.system(size: 13, weight: .black))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selectedMode == mode ? .white : .white.opacity(0.38))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background {
                        if selectedMode == mode {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(
                                    selectedMode == .social
                                    ? CrewArenaPalette.appGradient
                                    : CrewArenaPalette.hotGradient
                                )
                                .shadow(
                                    color: (
                                        selectedMode == .social
                                        ? Color(arenaHex: CrewArenaPalette.appBlue)
                                        : Color(arenaHex: CrewArenaPalette.crewCoral)
                                    ).opacity(0.18),
                                    radius: 10,
                                    y: 5
                                )
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .stroke(.white.opacity(0.075), lineWidth: 1)
                )
        )
    }
}

// MARK: - Social Content

private struct CrewSocialContent: View {
    @Binding var selectedTab: CrewSocialTab

    let summary: CrewHomeSummary
    let crews: [CrewSocialCrewCardData]
    let friends: [CrewSocialFriendCardData]
    let incomingRequests: [CrewSocialRequestCardData]
    let sentRequests: [CrewSocialRequestCardData]

    let onOpenCrew: (UUID) -> Void
    let onOpenFriend: (UUID) -> Void
    let onAcceptRequest: (UUID) -> Void
    let onRemoveRequest: (UUID) -> Void

    let onCreateCrew: () -> Void
    let onJoinCrew: () -> Void
    let onAddFriend: () -> Void

    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var subscription = SubscriptionManager.shared
    @ObservedObject private var progression = ProgressionManager.shared
    @State private var showStatsPaywall = false
    @Namespace private var tabNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if subscription.isPro {
                statsSharingToggle
            } else {
                socialProBanner
            }

            // Tappable Crews / Friends switcher (Focus-style).
            crewTabSwitcher

            if selectedTab == .friends {
                CrewSocialFriendsSection(
                    friends: friends,
                    onOpenFriend: onOpenFriend,
                    onAddFriend: onAddFriend
                )
            } else {
                CrewSocialCrewSection(
                    crews: crews,
                    onOpenCrew: onOpenCrew,
                    onCreateCrew: onCreateCrew,
                    onJoinCrew: onJoinCrew
                )
            }
        }
        .sheet(isPresented: $showStatsPaywall) {
            PaywallView(context: "social_stats")
        }
    }

    private var crewTabSwitcher: some View {
        HStack(spacing: 0) {
            ForEach([CrewSocialTab.crews, .friends]) { tab in
                let isSelected = (tab == .crews && selectedTab != .friends) || selectedTab == tab

                Button {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 9) {
                        HStack(spacing: 6) {
                            Image(systemName: tab == .crews ? "person.3.fill" : "person.2.fill")
                                .font(.system(size: 12, weight: .black))
                            Text(tab.title)
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .tracking(0.2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.38))

                        ZStack {
                            Capsule().fill(Color.white.opacity(0.05)).frame(height: 2.5)
                            if isSelected {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(arenaHex: CrewArenaPalette.appBlue),
                                                     Color(arenaHex: CrewArenaPalette.appCyan)],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                    .frame(height: 2.5)
                                    .matchedGeometryEffect(id: "crew_tab_underline", in: tabNamespace)
                                    .shadow(color: Color(arenaHex: CrewArenaPalette.appBlue).opacity(0.5), radius: 5, y: 1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Non-Pro: attractive hook to unlock the social stats layer.
    private var socialProBanner: some View {
        Button {
            showStatsPaywall = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle().fill(
                            LinearGradient(
                                colors: [Color(arenaHex: CrewArenaPalette.gold), Color(arenaHex: CrewArenaPalette.appCyan)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("crew_see_friends_close"))
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.white)

                    Text(tr("crew_friends_locked_sub"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(arenaHex: CrewArenaPalette.gold).opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color(arenaHex: CrewArenaPalette.gold).opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    /// Pro: privacy switch to broadcast (or hide) my own stats.
    private var statsSharingToggle: some View {
        HStack(spacing: 12) {
            Image(systemName: progression.statsSharingEnabled ? "eye.fill" : "eye.slash.fill")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(progression.statsSharingEnabled
                                 ? Color(arenaHex: CrewArenaPalette.liveGreen)
                                 : .white.opacity(0.5))

            VStack(alignment: .leading, spacing: 1) {
                Text(tr("crew_share_my_stats"))
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.white)

                Text(progression.statsSharingEnabled
                     ? tr("crew_stats_shared_on")
                     : tr("crew_stats_shared_off"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Toggle("", isOn: Binding(
                get: { progression.statsSharingEnabled },
                set: { progression.setStatsSharing($0, context: modelContext) }
            ))
            .labelsHidden()
            .tint(Color(arenaHex: CrewArenaPalette.liveGreen))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }
}

// MARK: - Social Hero

private struct CrewSocialHero: View {
    let summary: CrewHomeSummary

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(arenaHex: CrewArenaPalette.appCyan),
                                Color(arenaHex: CrewArenaPalette.appPurple)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)

                Image(systemName: "person.3.fill")
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(Color(arenaHex: CrewArenaPalette.appCyan))
                        .frame(width: 7, height: 7)

                    Text(tr("ch_study_circle_caps"))
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(Color(arenaHex: CrewArenaPalette.appCyan))
                }

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(summary.crewCount)")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(.white)

                    Text("crew")
                        .font(.system(size: 24, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(arenaHex: CrewArenaPalette.appCyan),
                                    Color(arenaHex: CrewArenaPalette.appPurple)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("·")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white.opacity(0.24))

                    Text("\(summary.friendCount)")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(.white)

                    Text(tr("ch_friend_word"))
                        .font(.system(size: 24, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(.white.opacity(0.84))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.65)

                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(arenaHex: CrewArenaPalette.liveGreen))
                        .frame(width: 7, height: 7)

                    Text(tr("ch_people_focusing", summary.liveCount))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(arenaHex: CrewArenaPalette.liveGreen))
                        .lineLimit(1)

                    if summary.requestCount > 0 {
                        Text("· \(summary.requestCount) istek")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(arenaHex: CrewArenaPalette.gold))
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(summary.liveCount)")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)

                Text("LIVE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.38))
            }
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(arenaHex: CrewArenaPalette.appCyan).opacity(0.070),
                            Color(arenaHex: CrewArenaPalette.appPurple).opacity(0.055),
                            Color(arenaHex: CrewArenaPalette.surface).opacity(0.94),
                            Color.white.opacity(0.025)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.075), lineWidth: 1)
                )
        )
    }
}
private struct CrewCompactHeroMetric: View {
    let title: String
    let value: String
    let icon: String
    let accentHex: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(Color(arenaHex: accentHex))

                Spacer()
            }

            Text(value)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(.white.opacity(0.38))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .frame(height: 82)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(arenaHex: accentHex).opacity(0.075))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(arenaHex: accentHex).opacity(0.15), lineWidth: 1)
                )
        )
    }
}

private struct CrewHeroMetric: View {
    let value: String
    let title: String
    let accentHex: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.38))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 62)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(arenaHex: accentHex).opacity(0.080))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(arenaHex: accentHex).opacity(0.14), lineWidth: 1)
                )
        )
    }
}

// MARK: - Social Tab Bar

private struct CrewSocialTabBar: View {
    @Binding var selectedTab: CrewSocialTab

    let crewCount: Int
    let friendCount: Int
    let requestCount: Int

    private var visibleTabs: [CrewSocialTab] {
        [.crews, .friends]
    }

    private func count(for tab: CrewSocialTab) -> Int {
        switch tab {
        case .crews:
            return crewCount
        case .friends:
            return friendCount
        case .requests:
            return requestCount
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(visibleTabs) { tab in
                Button {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 7) {
                        Text(tab.title)
                            .font(.system(size: 15, weight: .black))
                            .lineLimit(1)

                        Text("\(count(for: tab))")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(selectedTab == tab ? .black : .white.opacity(0.45))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(selectedTab == tab ? .white.opacity(0.92) : .white.opacity(0.07))
                            )
                    }
                    .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.36))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(arenaHex: CrewArenaPalette.appBlue).opacity(0.18))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color(arenaHex: CrewArenaPalette.appBlue).opacity(0.32), lineWidth: 1)
                                )
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.07), lineWidth: 1)
                )
        )
    }
}

// MARK: - Social Crew Section

private struct CrewSocialCrewSection: View {
    let crews: [CrewSocialCrewCardData]
    let onOpenCrew: (UUID) -> Void
    let onCreateCrew: () -> Void
    let onJoinCrew: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if crews.isEmpty {
                CrewEmptyStateCard(
                    icon: "person.3.fill",
                    title: tr("ch_no_crew"),
                    subtitle: tr("ch_no_crew_sub"),
                    primaryTitle: tr("ch_create_crew"),
                    secondaryTitle: tr("ch_join_code"),
                    onPrimary: onCreateCrew,
                    onSecondary: onJoinCrew
                )
            } else {
                ForEach(crews) { crew in
                    Button {
                        onOpenCrew(crew.id)
                    } label: {
                        CrewSocialCrewCard(crew: crew)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct CrewSocialCrewCard: View {
    let crew: CrewSocialCrewCardData

    @State private var barFilled = false

    private var progressValue: CGFloat {
        max(crew.progress, crew.isLive ? 0.72 : 0.18)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(arenaHex: crew.colorHex).opacity(0.95),
                                    Color(arenaHex: CrewArenaPalette.appPurple).opacity(0.82)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)

                    Text(String(crew.name.prefix(1)))
                        .font(.system(size: 25, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 7) {
                        Text(crew.name)
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)

                        if crew.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(Color(arenaHex: CrewArenaPalette.gold))
                        }
                    }

                    HStack(spacing: 8) {
                        if let rank = crew.rankText {
                            Text(rank)
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(Color(arenaHex: CrewArenaPalette.appCyan))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(arenaHex: CrewArenaPalette.appCyan).opacity(0.12))
                                )
                        }

                        Text(crew.memberText)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.42))
                            .lineLimit(1)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(crew.focusTimeText)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(
                                crew.isLive
                                ? Color(arenaHex: CrewArenaPalette.crewCoral)
                                : Color(arenaHex: CrewArenaPalette.liveGreen)
                            )
                            .frame(width: 7, height: 7)

                        Text(crew.statusText)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(
                                crew.isLive
                                ? Color(arenaHex: CrewArenaPalette.crewCoral)
                                : Color(arenaHex: CrewArenaPalette.liveGreen)
                            )
                            .lineLimit(1)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(tr("wv_today_caps"))
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.34))

                    if crew.streakDays > 0 {
                        Text("·")
                            .foregroundStyle(.white.opacity(0.22))

                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 9, weight: .bold))

                            Text(tr("ch_streak_days_n", crew.streakDays))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(Color(arenaHex: CrewArenaPalette.gold))
                    }

                    Text("·")
                        .foregroundStyle(.white.opacity(0.22))

                    Text(crew.taskCount > 0 ? crew.progressText : "aktif")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(arenaHex: CrewArenaPalette.appCyan))
                        .lineLimit(1)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.075))
                            .frame(height: 5)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(arenaHex: CrewArenaPalette.appCyan),
                                        Color(arenaHex: CrewArenaPalette.appPurple),
                                        Color(arenaHex: crew.colorHex)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: barFilled ? max(28, geo.size.width * progressValue) : 28,
                                height: 5
                            )
                    }
                }
                .frame(height: 5)
                .onAppear {
                    guard !barFilled else { return }
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.74).delay(0.15)) {
                        barFilled = true
                    }
                }
            }

            if crew.weeklyGoalMinutes > 0 {
                weeklyGoalRow
            }

            HStack(spacing: 10) {
                CrewMiniAvatarStack(count: crew.memberCount, accentHex: crew.colorHex)

                Text(
                    crew.lastMessageText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    ? (crew.lastMessageText ?? tr("ch_crew_chat_ready"))
                    : tr("ch_crew_chat_ready")
                )
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.42))
                .lineLimit(1)

                Spacer()

                if crew.unreadCount > 0 {
                    Text("\(crew.unreadCount)")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(
                            Capsule()
                                .fill(Color(arenaHex: CrewArenaPalette.gold))
                        )
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white.opacity(0.22))
            }
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(arenaHex: crew.colorHex).opacity(0.060),
                            Color(arenaHex: CrewArenaPalette.appPurple).opacity(0.045),
                            Color(arenaHex: CrewArenaPalette.surface).opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.070), lineWidth: 1)
                )
        )
    }

    /// Weekly focus goal: real this-week minutes vs the crew's target.
    private var weeklyGoalRow: some View {
        let reached = crew.goalProgress >= 1

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(tr("crew_goal_caps"))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.34))

                Spacer()

                if reached {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10, weight: .black))
                        Text(tr("crew_goal_reached"))
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                    }
                    .foregroundStyle(Color(arenaHex: CrewArenaPalette.liveGreen))
                } else {
                    Text(crew.goalProgressText)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.52))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.075))
                        .frame(height: 5)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: reached
                                ? [
                                    Color(arenaHex: CrewArenaPalette.liveGreen),
                                    Color(arenaHex: CrewArenaPalette.gold)
                                ]
                                : [
                                    Color(arenaHex: CrewArenaPalette.gold),
                                    Color(arenaHex: crew.colorHex)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: barFilled
                            ? max(10, geo.size.width * crew.goalProgress)
                            : 10,
                            height: 5
                        )
                }
            }
            .frame(height: 5)
        }
    }
}

private struct CrewMiniAvatarStack: View {
    let count: Int
    let accentHex: String

    var body: some View {
        HStack(spacing: -7) {
            ForEach(0..<min(max(count, 1), 4), id: \.self) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(arenaHex: CrewArenaPalette.appBlue).opacity(0.85),
                                Color(arenaHex: CrewArenaPalette.appPurple).opacity(0.85),
                                Color(arenaHex: accentHex).opacity(0.60)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 27, height: 27)
                    .overlay(
                        Circle()
                            .stroke(Color(arenaHex: CrewArenaPalette.surface2), lineWidth: 2)
                    )
                    .overlay(
                        Text(String(["A", "M", "B", "C"][index]))
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.white.opacity(0.92))
                    )
            }
        }
    }
}

// MARK: - Friends Section

private struct CrewSocialFriendsSection: View {
    let friends: [CrewSocialFriendCardData]
    let onOpenFriend: (UUID) -> Void
    let onAddFriend: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CrewSectionTitle(
                eyebrow: tr("ch_suggested_friends_caps"),
                titleFirst: "Senin",
                titleItalic: tr("ch_for_word"),
                trailing: friends.isEmpty ? nil : tr("ch_all_caps")
            )

            if friends.isEmpty {
                CrewEmptyStateCard(
                    icon: "person.2.fill",
                    title: tr("ch_no_friends"),
                    subtitle: tr("ch_no_friends_sub"),
                    primaryTitle: tr("ch_add_friend"),
                    secondaryTitle: nil,
                    onPrimary: onAddFriend,
                    onSecondary: nil
                )
            } else {
                ForEach(friends) { friend in
                    Button {
                        onOpenFriend(friend.id)
                    } label: {
                        CrewFriendRow(friend: friend)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Online/focusing presence indicator — slow opacity pulse (GPU composited),
/// only animates while the friend is actually live.
private struct CrewPresenceDot: View {
    let isLive: Bool
    @State private var glow = false

    var body: some View {
        Circle()
            .fill(isLive ? Color(arenaHex: CrewArenaPalette.liveGreen) : Color.gray.opacity(0.55))
            .frame(width: 12, height: 12)
            .overlay(Circle().stroke(Color(arenaHex: CrewArenaPalette.surface), lineWidth: 2))
            .opacity(isLive ? (glow ? 1.0 : 0.6) : 1.0)
            .onAppear {
                guard isLive else { return }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }
            .onDisappear { glow = false }
    }
}

private struct CrewFriendRow: View {
    let friend: CrewSocialFriendCardData

    @ObservedObject private var subscription = SubscriptionManager.shared

    /// Social stats (currently-focusing, focus minutes, streak, level) are a
    /// Pro-only layer. Non-Pro viewers only see plain online presence.
    private var showStats: Bool { subscription.isPro }

    var body: some View {
        HStack(spacing: 13) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(arenaHex: friend.colorHex),
                                Color(arenaHex: CrewArenaPalette.appPurple)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)
                    .overlay(
                        Text(String(friend.displayName.prefix(1)))
                            .font(.system(size: 23, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(.white.opacity(0.90))
                    )

                CrewPresenceDot(isLive: showStats ? (friend.isOnline || friend.isFocusing) : friend.isOnline)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Text(friend.displayName)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if friend.isOnline {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(arenaHex: CrewArenaPalette.appBlue))
                    }
                }

                Text(friend.subtitle)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.36))
                    .lineLimit(1)

                if showStats {
                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            if !friend.isFocusing {
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 8, weight: .bold))
                            }

                            Text(friend.isFocusing ? friend.focusText : tr("ch_in_social_circle"))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .lineLimit(1)
                        }
                        .foregroundStyle(friend.isFocusing ? Color(arenaHex: CrewArenaPalette.liveGreen) : Color(arenaHex: CrewArenaPalette.appBlue))

                        if let streak = friend.streak, streak > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 9, weight: .black))
                                Text("\(streak)")
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                            }
                            .foregroundStyle(Color(arenaHex: CrewArenaPalette.gold))
                        }

                        if let level = friend.level {
                            Text("LV\(level)")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8, weight: .black))
                        Text(tr("crew_stats_pro_caps"))
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(0.6)
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color(arenaHex: CrewArenaPalette.gold).opacity(0.85))
                }
            }

            Spacer()

            Text(showStats && friend.isFocusing ? "JOIN" : "MESAJ")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color(arenaHex: CrewArenaPalette.appBlue))
                )
        }
        .padding(14)
        .background(CrewSurface(cornerRadius: 22))
    }
}
private struct CrewRequestsSheet: View {
    let incomingRequests: [CrewSocialRequestCardData]
    let sentRequests: [CrewSocialRequestCardData]
    let onAcceptRequest: (UUID) -> Void
    let onRemoveRequest: (UUID) -> Void

    var body: some View {
        ZStack {
            CrewArenaBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tr("ch_requests"))
                            .font(.system(size: 31, weight: .black))
                            .foregroundStyle(.white)

                        Text(tr("ch_requests_sub"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.48))
                    }
                    .padding(.top, 18)

                    CrewSocialRequestsSection(
                        incomingRequests: incomingRequests,
                        sentRequests: sentRequests,
                        onAcceptRequest: onAcceptRequest,
                        onRemoveRequest: onRemoveRequest
                    )

                    Color.clear.frame(height: 22)
                }
                .padding(.horizontal, 18)
            }
        }
    }
}
// MARK: - Requests Section

private struct CrewSocialRequestsSection: View {
    let incomingRequests: [CrewSocialRequestCardData]
    let sentRequests: [CrewSocialRequestCardData]
    let onAcceptRequest: (UUID) -> Void
    let onRemoveRequest: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if incomingRequests.isEmpty && sentRequests.isEmpty {
                CrewEmptyStateCard(
                    icon: "bell.badge.fill",
                    title: "Bekleyen istek yok",
                    subtitle: tr("ch_no_requests"),
                    primaryTitle: nil,
                    secondaryTitle: nil,
                    onPrimary: nil,
                    onSecondary: nil
                )
            }

            if !incomingRequests.isEmpty {
                CrewSectionTitle(
                    eyebrow: tr("ch_incoming_caps"),
                    titleFirst: "Cevap",
                    titleItalic: "bekliyor",
                    trailing: "\(incomingRequests.count)"
                )

                ForEach(incomingRequests) { request in
                    CrewRequestRow(
                        request: request,
                        primaryTitle: "KABUL",
                        secondaryTitle: tr("ch_delete_caps"),
                        onPrimary: {
                            onAcceptRequest(request.id)
                        },
                        onSecondary: {
                            onRemoveRequest(request.id)
                        }
                    )
                }
            }

            if !sentRequests.isEmpty {
                CrewSectionTitle(
                    eyebrow: tr("ch_sent_caps"),
                    titleFirst: "Bekleyen",
                    titleItalic: "istekler",
                    trailing: "\(sentRequests.count)"
                )

                ForEach(sentRequests) { request in
                    CrewRequestRow(
                        request: request,
                        primaryTitle: nil,
                        secondaryTitle: tr("ch_cancel_caps"),
                        onPrimary: nil,
                        onSecondary: {
                            onRemoveRequest(request.id)
                        }
                    )
                }
            }
        }
    }
}

private struct CrewRequestRow: View {
    let request: CrewSocialRequestCardData
    let primaryTitle: String?
    let secondaryTitle: String?
    let onPrimary: (() -> Void)?
    let onSecondary: (() -> Void)?

    var body: some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color(arenaHex: request.kind.accentHex).opacity(0.16))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Color(arenaHex: request.kind.accentHex))
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(request.kind.title)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color(arenaHex: request.kind.accentHex))

                Text(request.title)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("@\(request.username) · \(request.subtitle)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.46))
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 8) {
                if let primaryTitle, let onPrimary {
                    Button(action: onPrimary) {
                        Text(primaryTitle)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color(arenaHex: CrewArenaPalette.liveGreen)))
                    }
                    .buttonStyle(.plain)
                }

                if let secondaryTitle, let onSecondary {
                    Button(action: onSecondary) {
                        Text(secondaryTitle)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(arenaHex: request.kind.accentHex))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(arenaHex: request.kind.accentHex).opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(CrewSurface(cornerRadius: 22))
    }
}

// MARK: - Community Content (CrewCommunityScopeSwitch kaldırıldı)

private struct CrewCommunityContent: View {
    @Binding var scope: CrewCommunityScope
    @Binding var range: CrewLeaderboardRange

    let studentContext: CrewArenaStudentContext
    @ObservedObject var arenaStore: ArenaStore
    let onStartFocus: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // HERO — scope değişince fade + slide animasyon
            CrewCommunityHero(
                summary: arenaStore.summary ?? CrewCommunityMockFactory.summary(
                    for: scope,
                    studentContext: studentContext
                )
            )
            .id("hero-\(scope.rawValue)")
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .top)),
                removal: .opacity.combined(with: .move(edge: .bottom))
            ))
            .opacity(arenaStore.isLoading ? 0.65 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: scope)
            .animation(.easeInOut(duration: 0.25), value: arenaStore.isLoading)

            // WEEKLY CHALLENGE
            Group {
                if let weeklyChallenge = arenaStore.weeklyChallenge {
                    CrewWeeklyBattleCard(challenge: weeklyChallenge)
                } else {
                    CrewArenaPreparingCard(
                        title: tr("crew_weekly_challenge_prep"),
                        subtitle: tr("crew_weekly_challenge_prep_sub")
                    )
                }
            }
            .opacity(arenaStore.isLoading ? 0.65 : 1.0)
            .animation(.easeInOut(duration: 0.25), value: arenaStore.isLoading)

            HStack(alignment: .center) {
                CrewSectionTitle(
                    eyebrow: "ARENA RANKING",
                    titleFirst: "Liderlik",
                    titleItalic: "tablosu",
                    trailing: nil
                )

                Spacer()

                CrewRangePicker(selectedRange: $range)
            }

            // LEADERBOARD
            Group {
                if arenaStore.leaderboard.isEmpty {
                    CrewArenaEmptyLeaderboardCard(
                        onStartFocus: onStartFocus
                    )
                } else {
                    CrewPodiumCard(entries: arenaStore.leaderboard)
                }
            }
            .id("leaderboard-\(scope.rawValue)-\(range.rawValue)")
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .opacity(arenaStore.isLoading ? 0.65 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: scope)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: range)
            .animation(.easeInOut(duration: 0.25), value: arenaStore.isLoading)

            // TOP CREWS
            Group {
                if arenaStore.topCrews.isEmpty {
                    CrewArenaPreparingCard(
                        title: tr("crew_top_crews_soon"),
                        subtitle: tr("crew_top_crews_soon_sub")
                    )
                } else {
                    CrewTopCrewsSection(crews: arenaStore.topCrews)
                }
            }
            .id("topcrews-\(scope.rawValue)-\(range.rawValue)")
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .opacity(arenaStore.isLoading ? 0.65 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: scope)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: range)
            .animation(.easeInOut(duration: 0.25), value: arenaStore.isLoading)
        }
        .task {
            await arenaStore.load(
                scope: scope,
                range: range
            )
        }
        .onChange(of: scope) { newScope in
            Task {
                await arenaStore.load(
                    scope: newScope,
                    range: range,
                    force: true
                )
            }
        }
        .onChange(of: range) { newRange in
            Task {
                await arenaStore.load(
                    scope: scope,
                    range: newRange,
                    force: true
                )
            }
        }
    }
}

private struct CrewCommunityHero: View {
    let summary: CrewCommunityScopeSummary

    private var shortMetrics: [CrewMetricData] {
        Array(summary.metrics.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center, spacing: 14) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(CrewArenaPalette.goldGradient)
                    .frame(width: 54, height: 54)
                    .overlay(
                        Image(systemName: summary.icon)
                            .font(.system(size: 23, weight: .black))
                            .foregroundStyle(.black.opacity(0.72))
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(summary.label)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(2.2)
                        .foregroundStyle(Color(arenaHex: CrewArenaPalette.gold))

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(summary.title)
                            .font(.system(size: 25, weight: .black))
                            .foregroundStyle(Color(arenaHex: CrewArenaPalette.gold))

                        Text(summary.italicTitle)
                            .font(.system(size: 22, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)
                    }

                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(arenaHex: CrewArenaPalette.liveGreen))
                            .frame(width: 7, height: 7)

                        Text(summary.primaryLiveText)
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(arenaHex: CrewArenaPalette.liveGreen))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                }

                Spacer()

                Text(summary.rankDeltaText)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(arenaHex: CrewArenaPalette.gold))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color(arenaHex: CrewArenaPalette.gold).opacity(0.12))
                            .overlay(
                                Capsule()
                                    .stroke(Color(arenaHex: CrewArenaPalette.gold).opacity(0.22), lineWidth: 1)
                            )
                    )
            }

            HStack(spacing: 9) {
                ForEach(shortMetrics) { metric in
                    CrewCommunityMetric(metric: metric)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(arenaHex: CrewArenaPalette.gold).opacity(0.11),
                            Color(arenaHex: CrewArenaPalette.appPurple).opacity(0.07),
                            Color(arenaHex: CrewArenaPalette.surface).opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color(arenaHex: CrewArenaPalette.gold).opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 18, y: 10)
        )
    }
}

private struct CrewCommunityMetric: View {
    let metric: CrewMetricData

    var body: some View {
        VStack(spacing: 4) {
            Text(metric.value)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            Text(metric.title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(0.9)
                .foregroundStyle(.white.opacity(0.35))
                .lineLimit(1)
                .minimumScaleFactor(0.50)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(Color(arenaHex: metric.accentHex).opacity(0.13), lineWidth: 1)
                )
        )
    }
}

private struct CrewWeeklyBattleCard: View {
    let challenge: CrewWeeklyChallengeData

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .center, spacing: 13) {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color(arenaHex: CrewArenaPalette.crewCoral))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "bolt.shield.fill")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("LIVE")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color(arenaHex: CrewArenaPalette.crewCoral))
                            )

                        Text(tr("crew_week_challenge_title"))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(Color(arenaHex: CrewArenaPalette.crewCoralSoft))
                            .lineLimit(1)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(challenge.title)
                            .font(.system(size: 19, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(.white)

                        Text("· \(challenge.italicTitle)")
                            .font(.system(size: 19, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(.white)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                    Text("\(challenge.timeLeftText) · \(challenge.participantText)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }

                Spacer()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.08))
                        .frame(height: 6)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(arenaHex: CrewArenaPalette.crewCoral),
                                    Color(arenaHex: CrewArenaPalette.appPurple)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * challenge.progress, height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text(tr("crew_reward"))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.34))

                Spacer()

                Text("💎 Diamond Badge")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(Color(arenaHex: CrewArenaPalette.gold))
                    .lineLimit(1)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(arenaHex: CrewArenaPalette.crewCoral).opacity(0.14),
                            Color(arenaHex: CrewArenaPalette.appPurple).opacity(0.08),
                            Color(arenaHex: CrewArenaPalette.surface).opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color(arenaHex: CrewArenaPalette.crewCoral).opacity(0.22), lineWidth: 1)
                )
        )
    }
}

// MARK: - Podium

private struct CrewPodiumCard: View {
    let entries: [CrewStudentLeaderboardEntry]

    private var topEntries: [CrewStudentLeaderboardEntry] {
        Array(entries.prefix(3))
    }

    private var currentUser: CrewStudentLeaderboardEntry? {
        entries.first(where: { $0.isCurrentUser })
    }

    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Top 3")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)

                Text("LIVE RANK")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(arenaHex: CrewArenaPalette.gold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color(arenaHex: CrewArenaPalette.gold).opacity(0.12))
                    )

                Spacer()
            }

            HStack(alignment: .top, spacing: 10) {
                ForEach(topEntries) { entry in
                    CrewPodiumPerson(entry: entry)
                }
            }

            if let currentUser {
                CrewYourRankStrip(entry: currentUser)
            }
        }
        .padding(16)
        .background(CrewSurface(cornerRadius: 28))
    }
}

private struct CrewPodiumPerson: View {
    let entry: CrewStudentLeaderboardEntry

    var body: some View {
        VStack(spacing: 7) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color(arenaHex: entry.colorHex))
                    .frame(width: entry.rank == 1 ? 64 : 56, height: entry.rank == 1 ? 64 : 56)
                    .shadow(color: Color(arenaHex: entry.colorHex).opacity(entry.rank == 1 ? 0.22 : 0.06), radius: 12, y: 6)
                    .overlay(
                        Text(String(entry.displayName.prefix(1)))
                            .font(.system(size: 25, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(.black.opacity(0.85))
                    )

                Text("\(entry.rank)")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 21, height: 21)
                    .background(Circle().fill(Color.black.opacity(0.84)))
                    .offset(x: 4, y: 4)
            }

            Text(entry.displayName)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.70)

            Text(entry.universityShort)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(.white.opacity(0.32))

            Text(entry.focusTimeText)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(entry.rank == 1 ? Color(arenaHex: CrewArenaPalette.gold) : .white.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CrewYourRankStrip: View {
    let entry: CrewStudentLeaderboardEntry

    var body: some View {
        HStack(spacing: 11) {
            Text("#\(entry.rank)")
                .font(.system(size: 25, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Color(arenaHex: CrewArenaPalette.crewCoral))

            VStack(alignment: .leading, spacing: 2) {
                Text(tr("crew_your_rank"))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color(arenaHex: CrewArenaPalette.crewCoralSoft))

                Text("\(entry.displayName) · \(entry.universityShort)")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(entry.focusTimeText)
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(arenaHex: CrewArenaPalette.crewCoral))
                    .lineLimit(1)

                Text("↑ \(entry.deltaRank)")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(arenaHex: CrewArenaPalette.liveGreen))
                    .lineLimit(1)
            }
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(arenaHex: CrewArenaPalette.crewCoral).opacity(0.12),
                            Color(arenaHex: CrewArenaPalette.appPurple).opacity(0.07),
                            Color.black.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(arenaHex: CrewArenaPalette.crewCoral).opacity(0.22), lineWidth: 1)
                )
        )
    }
}

// MARK: - Top Crews

private struct CrewTopCrewsSection: View {
    let crews: [CrewCommunityCrewEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                CrewSectionTitle(
                    eyebrow: "CREW RANKING",
                    titleFirst: "Top",
                    titleItalic: "crews",
                    trailing: nil
                )

                Spacer()

                HStack(spacing: 7) {
                    Circle()
                        .fill(Color(arenaHex: CrewArenaPalette.liveGreen))
                        .frame(width: 8, height: 8)

                    Text("LIVE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(arenaHex: CrewArenaPalette.liveGreen))
                }
            }

            ForEach(Array(crews.prefix(5))) { crew in
                CrewCommunityLeaderboardRow(crew: crew)
            }
        }
    }
}

private struct CrewCommunityLeaderboardRow: View {
    let crew: CrewCommunityCrewEntry

    private var focusLabel: String {
        if crew.focusMinutes <= 0 {
            return tr("ch_no_focus_yet")
        }

        return "\(crew.focusTimeText) focus"
    }

    private var memberLabel: String {
        tr("ch_member_count", crew.memberCount)
    }

    private var rankColor: Color {
        if crew.rank == 1 {
            return Color(arenaHex: CrewArenaPalette.gold)
        }

        if crew.rank == 2 {
            return Color(arenaHex: CrewArenaPalette.liveGreen)
        }

        return Color(arenaHex: CrewArenaPalette.crewCoral)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text("#\(crew.rank)")
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(rankColor)

                if crew.deltaRank != 0 {
                    Text(crew.deltaRank > 0 ? "↑\(crew.deltaRank)" : "↓\(abs(crew.deltaRank))")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(crew.deltaRank > 0 ? Color(arenaHex: CrewArenaPalette.liveGreen) : Color(arenaHex: CrewArenaPalette.crewCoral))
                }
            }
            .frame(width: 38)

            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(arenaHex: crew.colorHex).opacity(0.24),
                                Color(arenaHex: CrewArenaPalette.appPurple).opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .overlay(
                        Text(crew.icon)
                            .font(.system(size: 24))
                    )

                if crew.isLive {
                    Circle()
                        .fill(Color(arenaHex: CrewArenaPalette.liveGreen))
                        .frame(width: 11, height: 11)
                        .overlay(
                            Circle()
                                .stroke(Color(arenaHex: CrewArenaPalette.surface), lineWidth: 2)
                        )
                        .offset(x: 2, y: 2)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(crew.name)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if !crew.badges.isEmpty {
                        HStack(spacing: 2) {
                            ForEach(Array(crew.badges.prefix(3).enumerated()), id: \.offset) { _, badge in
                                Image(systemName: crewBadgeSymbol(badge))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(crewBadgeTint(badge))
                            }
                        }
                    }
                }

                HStack(spacing: 7) {
                    Text(focusLabel)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(
                            crew.focusMinutes > 0
                            ? Color(arenaHex: CrewArenaPalette.crewCoral)
                            : .white.opacity(0.38)
                        )
                        .lineLimit(1)

                    Text("·")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.24))

                    Text("\(crew.universityShort) · \(memberLabel)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)
                }
            }

            Spacer(minLength: 8)

            Text(crew.joinState.title)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(crew.joinState == .join ? .black : Color(arenaHex: crew.colorHex))
                .padding(.horizontal, 11)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(
                            crew.joinState == .join
                            ? Color(arenaHex: CrewArenaPalette.crewCoral)
                            : Color.white.opacity(0.07)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(Color(arenaHex: crew.colorHex).opacity(0.22), lineWidth: 1)
                        )
                )
        }
        .padding(13)
        .background(CrewSurface(cornerRadius: 22))
    }
}

// MARK: - Shared UI

private struct CrewSectionTitle: View {
    let eyebrow: String
    let titleFirst: String
    let titleItalic: String
    let trailing: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("— \(eyebrow) —")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(2.6)
                    .foregroundStyle(.white.opacity(0.33))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                Spacer()

                if let trailing {
                    Text(trailing)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.38))
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(titleFirst)
                    .font(.system(size: 25, weight: .black))
                    .foregroundStyle(.white)

                Text(titleItalic)
                    .font(.system(size: 24, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(.white)
            }
        }
    }
}

private struct CrewRangePicker: View {
    @Binding var selectedRange: CrewLeaderboardRange

    var body: some View {
        HStack(spacing: 4) {
            ForEach(CrewLeaderboardRange.allCases) { range in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selectedRange = range
                    }
                } label: {
                    Text(range.title.uppercased())
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(selectedRange == range ? .white : .white.opacity(0.35))
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background {
                            if selectedRange == range {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(Color.black.opacity(0.75))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

private struct CrewArenaPreparingCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color(arenaHex: CrewArenaPalette.gold).opacity(0.14))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(Color(arenaHex: CrewArenaPalette.gold))
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.46))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(14)
        .background(CrewSurface(cornerRadius: 22))
    }
}

private struct CrewArenaEmptyLeaderboardCard: View {
    let onStartFocus: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 13) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(arenaHex: CrewArenaPalette.gold).opacity(0.22),
                                Color(arenaHex: CrewArenaPalette.crewCoral).opacity(0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)
                    .overlay(
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 21, weight: .black))
                            .foregroundStyle(Color(arenaHex: CrewArenaPalette.gold))
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(tr("crew_be_first"))
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.white)

                    Text(tr("crew_be_first_sub"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                        .lineLimit(2)
                }

                Spacer()
            }

            Button {
                onStartFocus()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.system(size: 13, weight: .black))

                    Text(tr("tv_start_focus"))
                        .font(.system(size: 13, weight: .black))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color(arenaHex: CrewArenaPalette.gold))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(15)
        .background(CrewSurface(cornerRadius: 24))
    }
}

private struct CrewEmptyStateCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let primaryTitle: String?
    let secondaryTitle: String?
    let onPrimary: (() -> Void)?
    let onSecondary: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(arenaHex: CrewArenaPalette.appBlue).opacity(0.14))
                .frame(width: 66, height: 66)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(Color(arenaHex: CrewArenaPalette.appBlue))
                )

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                if let primaryTitle, let onPrimary {
                    Button(action: onPrimary) {
                        Text(primaryTitle)
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 16)
                            .frame(height: 42)
                            .background(Capsule().fill(Color(arenaHex: CrewArenaPalette.appBlue)))
                    }
                    .buttonStyle(.plain)
                }

                if let secondaryTitle, let onSecondary {
                    Button(action: onSecondary) {
                        Text(secondaryTitle)
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(.white.opacity(0.82))
                            .padding(.horizontal, 16)
                            .frame(height: 42)
                            .background(Capsule().fill(Color.white.opacity(0.09)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(CrewSurface(cornerRadius: 26))
    }
}

private struct CrewSurface: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(arenaHex: CrewArenaPalette.appBlue).opacity(0.035),
                        Color(arenaHex: CrewArenaPalette.appPurple).opacity(0.045),
                        Color.white.opacity(0.040)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.075), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 16, y: 9)
    }
}

private struct DottedPattern: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 14
            let radius: CGFloat = 1.05

            var y: CGFloat = 8
            while y < size.height {
                var x: CGFloat = 8

                while x < size.width {
                    let rect = CGRect(x: x, y: y, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.36)))
                    x += spacing
                }

                y += spacing
            }
        }
    }
}

// MARK: - Color Hex

// MARK: - Badge Mapping (emoji keys from backend → SF Symbols)

/// Backend rozet anahtarları emoji string olarak gelir; UI'da SF Symbol kullanılır.
private func crewBadgeSymbol(_ badge: String) -> String {
    switch badge {
    case "👑": return "crown.fill"
    case "🏆": return "trophy.fill"
    case "💎": return "diamond.fill"
    case "⚡️", "⚡": return "bolt.fill"
    case "🔥": return "flame.fill"
    case "🥇": return "medal.fill"
    case "🥈": return "medal.fill"
    case "🥉": return "medal.fill"
    case "🚀": return "paperplane.fill"
    default:   return "star.fill"
    }
}

private func crewBadgeTint(_ badge: String) -> Color {
    switch badge {
    case "👑", "🏆", "🥇": return Color(arenaHex: CrewArenaPalette.gold)
    case "💎":             return Color(arenaHex: CrewArenaPalette.appCyan)
    case "⚡️", "⚡":       return Color(arenaHex: CrewArenaPalette.appCyan)
    case "🔥":             return Color(arenaHex: CrewArenaPalette.crewCoral)
    case "🥈":             return Color.white.opacity(0.7)
    case "🥉":             return Color(arenaHex: CrewArenaPalette.crewCoral).opacity(0.8)
    default:               return Color(arenaHex: CrewArenaPalette.gold)
    }
}
