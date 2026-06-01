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
                Color(crewHex: appBlueSoft),
                Color(crewHex: appPurple)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var appSoftGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(crewHex: appBlue).opacity(0.14),
                Color(crewHex: appPurple).opacity(0.14),
                Color.white.opacity(0.035)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var hotGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(crewHex: crewCoral),
                Color(crewHex: "#FF8A4C")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var goldGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(crewHex: gold),
                Color(crewHex: goldSoft)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var crewCardGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(crewHex: appBlueSoft).opacity(0.90),
                Color(crewHex: appPurple).opacity(0.88),
                Color(crewHex: crewCoral).opacity(0.60)
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
    
    private var headerPrimaryIcon: String {
        if mode == .social {
            switch socialTab {
            case .crews:
                return "plus"
            case .friends:
                return "person.badge.plus"
            case .requests:
                return "person.2.badge.gearshape"
            }
        }

        return "star.fill"
    }
    
    private var headerPrimaryBadge: String? {
        if mode == .social {
            switch socialTab {
            case .crews:
                return nil

            case .friends:
                return nil

            case .requests:
                return summary.requestCount > 0 ? "\(summary.requestCount)" : nil
            }
        }

        return nil
    }

    private var headerPrimaryAction: () -> Void {
        {
            if mode == .social {
                switch socialTab {
                case .crews:
                    onCreateCrew()
                case .friends:
                    onAddFriend()
                case .requests:
                    onAddFriend()
                }
            } else {
                onCreateCrew()
            }
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
                        primaryIcon: headerPrimaryIcon,
                        primaryBadge: headerPrimaryBadge,
                        onSearch: { },
                        onPrimaryAction: headerPrimaryAction
                    )

                    CrewModeSwitch(selectedMode: $mode)

                    if mode == .social {
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
    }
}

// MARK: - Background

private struct CrewArenaBackground: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(crewHex: CrewArenaPalette.backgroundTop),
                    Color(crewHex: CrewArenaPalette.backgroundMid),
                    Color(crewHex: CrewArenaPalette.backgroundBottom)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(crewHex: CrewArenaPalette.appBlue).opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 96)
                .offset(x: 165, y: -245)

            Circle()
                .fill(Color(crewHex: CrewArenaPalette.appPurple).opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 110)
                .offset(x: -175, y: 500)

            Circle()
                .fill(Color(crewHex: CrewArenaPalette.crewCoral).opacity(0.08))
                .frame(width: 270, height: 270)
                .blur(radius: 100)
                .offset(x: 170, y: 280)

            Circle()
                .fill(Color(crewHex: CrewArenaPalette.gold).opacity(0.055))
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

// MARK: - Header

private struct CrewArenaHeader: View {
    let mode: CrewHomeMode
    let scope: CrewCommunityScope
    let studentContext: CrewArenaStudentContext
    let liveCount: Int
    let requestCount: Int
    let primaryIcon: String
    let primaryBadge: String?

    let onSearch: () -> Void
    let onPrimaryAction: () -> Void

    private var eyebrow: String {
        switch mode {
        case .social:
            return "AKTİF ALAN · \(liveCount) LIVE"
        case .community:
            return scope.headerEyebrow(studentContext: studentContext)
        }
    }

    private var titleFirst: String {
        switch mode {
        case .social:
            return "The"
        case .community:
            return scope.headerTitleFirst
        }
    }

    private var titleAccent: String {
        switch mode {
        case .social:
            return "Crew"
        case .community:
            return scope.headerTitleAccent
        }
    }

    private var accentStart: Color {
        mode == .social
        ? Color(crewHex: CrewArenaPalette.appCyan)
        : Color(crewHex: CrewArenaPalette.gold)
    }

    private var accentEnd: Color {
        mode == .social
        ? Color(crewHex: CrewArenaPalette.appPurple)
        : Color(crewHex: CrewArenaPalette.goldSoft)
    }

    /// Animasyon trigger için kullanılan composite key.
    /// scope veya mode değişince animasyon tetiklenir.
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
                                ? Color(crewHex: CrewArenaPalette.appBlue)
                                : Color(crewHex: CrewArenaPalette.gold)
                            )
                            .frame(width: 20, height: 1)

                        // Eyebrow — scope/mode değişince fade + slide
                        Text(eyebrow)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .tracking(2.6)
                            .foregroundStyle(
                                mode == .social
                                ? Color(crewHex: CrewArenaPalette.appCyan)
                                : Color(crewHex: CrewArenaPalette.gold)
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

                    // Title — scope/mode değişince fade + slide
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

                HStack(spacing: 9) {
                    CrewHeaderIconButton(
                        systemName: "magnifyingglass",
                        emphasized: false,
                        action: onSearch
                    )

                    if mode == .social {
                        CrewHeaderIconButton(
                            systemName: "bell.fill",
                            badge: requestCount > 0 ? "\(requestCount)" : nil,
                            emphasized: false,
                            action: { }
                        )

                        CrewHeaderIconButton(
                            systemName: primaryIcon,
                            badge: primaryBadge,
                            emphasized: true,
                            action: onPrimaryAction
                        )
                    } else {
                        CrewHeaderIconButton(
                            systemName: primaryIcon,
                            badge: primaryBadge,
                            emphasized: true,
                            action: onPrimaryAction
                        )
                    }
                }
            }
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
                            .fill(emphasized ? Color(crewHex: CrewArenaPalette.appBlue) : Color.white.opacity(0.075))
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
                        .background(Circle().fill(Color(crewHex: CrewArenaPalette.gold)))
                        .offset(x: 5, y: -5)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mode Switch

private struct CrewModeSwitch: View {
    @Binding var selectedMode: CrewHomeMode

    var body: some View {
        HStack(spacing: 6) {
            ForEach(CrewHomeMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        selectedMode = mode
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 15, weight: .bold))

                        Text(mode.title)
                            .font(.system(size: 16, weight: .black))
                    }
                    .foregroundStyle(selectedMode == mode ? .black : .white.opacity(0.38))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background {
                        if selectedMode == mode {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(selectedMode == .social ? CrewArenaPalette.appGradient : CrewArenaPalette.hotGradient)
                                .shadow(
                                    color: (
                                        selectedMode == .social
                                        ? Color(crewHex: CrewArenaPalette.appPurple)
                                        : Color(crewHex: CrewArenaPalette.crewCoral)
                                    ).opacity(0.22),
                                    radius: 14,
                                    y: 7
                                )
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(Color.white.opacity(0.070))
                .overlay(
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CrewSocialHero(summary: summary)

            CrewSocialTabBar(
                selectedTab: $selectedTab,
                crewCount: summary.crewCount,
                friendCount: summary.friendCount,
                requestCount: summary.requestCount
            )

            switch selectedTab {
            case .crews:
                CrewSocialCrewSection(
                    crews: crews,
                    onOpenCrew: onOpenCrew,
                    onCreateCrew: onCreateCrew,
                    onJoinCrew: onJoinCrew
                )

            case .friends:
                CrewSocialFriendsSection(
                    friends: friends,
                    onOpenFriend: onOpenFriend,
                    onAddFriend: onAddFriend
                )

            case .requests:
                CrewSocialRequestsSection(
                    incomingRequests: incomingRequests,
                    sentRequests: sentRequests,
                    onAcceptRequest: onAcceptRequest,
                    onRemoveRequest: onRemoveRequest
                )
            }
        }
    }
}

// MARK: - Social Hero

private struct CrewSocialHero: View {
    let summary: CrewHomeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(CrewArenaPalette.appGradient)
                        .frame(width: 54, height: 54)

                    Image(systemName: "bolt.fill")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("SENİN ÇEVREN")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(2.7)
                        .foregroundStyle(Color(crewHex: CrewArenaPalette.appCyan))

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(summary.crewCount)")
                            .font(.system(size: 27, weight: .black))
                            .foregroundStyle(Color(crewHex: CrewArenaPalette.appBlue))

                        Text("Crew")
                            .font(.system(size: 24, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(.white)

                        Text("·")
                            .foregroundStyle(.white.opacity(0.48))

                        Text("\(summary.friendCount)")
                            .font(.system(size: 27, weight: .black))
                            .foregroundStyle(Color(crewHex: CrewArenaPalette.appBlue))

                        Text("Arkadaş")
                            .font(.system(size: 24, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(.white)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(crewHex: CrewArenaPalette.liveGreen))
                            .frame(width: 8, height: 8)

                        Text("\(summary.liveCount) kişi")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(crewHex: CrewArenaPalette.liveGreen))

                        Text("· şimdi odakta")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.42))
                    }
                }

                Spacer()
            }

            HStack(spacing: 9) {
                CrewHeroMetric(value: "\(summary.crewCount)", title: "CREW", accentHex: CrewArenaPalette.appBlue)
                CrewHeroMetric(value: "\(summary.friendCount)", title: "ARKADAŞ", accentHex: CrewArenaPalette.appPurple)
                CrewHeroMetric(value: "\(summary.requestCount)", title: "İSTEK", accentHex: CrewArenaPalette.gold)
                CrewHeroMetric(value: "\(summary.liveCount)", title: "LIVE", accentHex: CrewArenaPalette.liveGreen)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(crewHex: CrewArenaPalette.appBlue).opacity(0.10),
                            Color(crewHex: CrewArenaPalette.appPurple).opacity(0.12),
                            Color(crewHex: CrewArenaPalette.surface).opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color(crewHex: CrewArenaPalette.appBlue).opacity(0.16), lineWidth: 1)
                )
                .shadow(color: Color(crewHex: CrewArenaPalette.appPurple).opacity(0.08), radius: 18, y: 10)
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
                .fill(Color(crewHex: accentHex).opacity(0.080))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(crewHex: accentHex).opacity(0.14), lineWidth: 1)
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
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(CrewSocialTab.allCases) { tab in
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 8) {
                            HStack(spacing: 7) {
                                Text(tab.title)
                                    .font(.system(size: 17, weight: .black))
                                    .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.32))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.62)

                                Text("\(count(for: tab))")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundStyle(
                                        selectedTab == tab
                                        ? Color(crewHex: CrewArenaPalette.appBlue)
                                        : .white.opacity(0.42)
                                    )
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(
                                                selectedTab == tab
                                                ? Color(crewHex: CrewArenaPalette.appBlue).opacity(0.18)
                                                : Color.white.opacity(0.07)
                                            )
                                    )
                            }
                            .frame(maxWidth: .infinity)

                            Rectangle()
                                .fill(selectedTab == tab ? Color(crewHex: CrewArenaPalette.appBlue) : .clear)
                                .frame(height: 3)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)
                .offset(y: -1)
        }
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
                    title: "Henüz crew yok",
                    subtitle: "Kendi çalışma takımını kur veya davet koduyla bir crew’e katıl.",
                    primaryTitle: "Crew oluştur",
                    secondaryTitle: "Koda katıl",
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

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text(crew.name)
                        .font(.system(size: 24, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                    if crew.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(Color(crewHex: CrewArenaPalette.gold))
                    }
                    Text(crew.rankText)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.90))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(.black.opacity(0.22))
                        )
                }

                Spacer()

                Text(crew.focusTimeText)
                    .font(.system(size: 25, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(crewHex: CrewArenaPalette.appBlueSoft).opacity(0.90),
                            Color(crewHex: CrewArenaPalette.appPurple).opacity(0.88),
                            Color(crewHex: CrewArenaPalette.crewCoral).opacity(0.60),
                            Color(crewHex: crew.colorHex).opacity(0.48)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    DottedPattern()
                        .opacity(0.13)
                }
            )

            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 9) {
                    Text(crew.memberText)
                    Text("·")
                    Text("🔥 \(crew.streakDays) GÜN SERİ")
                    Text("·")
                    Text("⚡ \(crew.taskCount > 0 ? crew.progressText : "ACTIVE")")
                }
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.44))
                .lineLimit(1)
                .minimumScaleFactor(0.58)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.085))
                            .frame(height: 5)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(crewHex: CrewArenaPalette.appCyan).opacity(0.95),
                                        Color(crewHex: CrewArenaPalette.appPurple).opacity(0.95),
                                        Color(crewHex: CrewArenaPalette.crewCoral).opacity(0.80)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: max(28, geo.size.width * max(crew.progress, crew.isLive ? 0.76 : 0.22)),
                                height: 5
                            )
                    }
                }
                .frame(height: 5)

                HStack {
                    CrewMiniAvatarStack(count: crew.memberCount, accentHex: crew.colorHex)

                    Spacer()

                    if let lastMessageText = crew.lastMessageText,
                       !lastMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: crew.isMuted ? "bell.slash.fill" : "bubble.left.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.38))

                            Text(lastMessageText)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.52))
                                .lineLimit(1)

                            Spacer()

                            if crew.unreadCount > 0 {
                                Text("\(crew.unreadCount)")
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundStyle(.black)
                                    .frame(minWidth: 19, minHeight: 19)
                                    .background(
                                        Capsule()
                                            .fill(Color(crewHex: CrewArenaPalette.gold))
                                    )
                            }
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(crew.isLive ? Color(crewHex: CrewArenaPalette.crewCoral) : Color(crewHex: CrewArenaPalette.liveGreen))
                            .frame(width: 8, height: 8)

                        Text(crew.statusText)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(crew.isLive ? Color(crewHex: CrewArenaPalette.crewCoral) : Color(crewHex: CrewArenaPalette.liveGreen))
                    }
                }
            }
            .padding(16)
            .background(Color(crewHex: CrewArenaPalette.surface2))
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.20), radius: 18, y: 10)
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
                                Color(crewHex: CrewArenaPalette.appBlue).opacity(0.85),
                                Color(crewHex: CrewArenaPalette.appPurple).opacity(0.85),
                                Color(crewHex: accentHex).opacity(0.60)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 27, height: 27)
                    .overlay(
                        Circle()
                            .stroke(Color(crewHex: CrewArenaPalette.surface2), lineWidth: 2)
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
                eyebrow: "ÖNERİLEN ARKADAŞLAR",
                titleFirst: "Senin",
                titleItalic: "için",
                trailing: friends.isEmpty ? nil : "TÜMÜ"
            )

            if friends.isEmpty {
                CrewEmptyStateCard(
                    icon: "person.2.fill",
                    title: "Henüz arkadaş yok",
                    subtitle: "Arkadaş ekleyerek program paylaşabilir, sohbet edebilir ve birlikte odaklanabilirsin.",
                    primaryTitle: "Arkadaş ekle",
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

private struct CrewFriendRow: View {
    let friend: CrewSocialFriendCardData

    var body: some View {
        HStack(spacing: 13) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(crewHex: friend.colorHex),
                                Color(crewHex: CrewArenaPalette.appPurple)
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

                Circle()
                    .fill(friend.isOnline || friend.isFocusing ? Color(crewHex: CrewArenaPalette.liveGreen) : Color.gray.opacity(0.55))
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color(crewHex: CrewArenaPalette.surface), lineWidth: 2))
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
                            .foregroundStyle(Color(crewHex: CrewArenaPalette.appBlue))
                    }
                }

                Text(friend.subtitle)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.36))
                    .lineLimit(1)

                Text(friend.isFocusing ? friend.focusText : "↗ sosyal çevrende")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(friend.isFocusing ? Color(crewHex: CrewArenaPalette.liveGreen) : Color(crewHex: CrewArenaPalette.appBlue))
                    .lineLimit(1)
            }

            Spacer()

            Text(friend.isFocusing ? "JOIN" : "MESAJ")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color(crewHex: CrewArenaPalette.appBlue))
                )
        }
        .padding(14)
        .background(CrewSurface(cornerRadius: 22))
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
                    subtitle: "Yeni arkadaşlık veya crew istekleri burada görünecek.",
                    primaryTitle: nil,
                    secondaryTitle: nil,
                    onPrimary: nil,
                    onSecondary: nil
                )
            }

            if !incomingRequests.isEmpty {
                CrewSectionTitle(
                    eyebrow: "GELEN İSTEKLER",
                    titleFirst: "Cevap",
                    titleItalic: "bekliyor",
                    trailing: "\(incomingRequests.count)"
                )

                ForEach(incomingRequests) { request in
                    CrewRequestRow(
                        request: request,
                        primaryTitle: "KABUL",
                        secondaryTitle: "SİL",
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
                    eyebrow: "GÖNDERİLEN İSTEKLER",
                    titleFirst: "Bekleyen",
                    titleItalic: "istekler",
                    trailing: "\(sentRequests.count)"
                )

                ForEach(sentRequests) { request in
                    CrewRequestRow(
                        request: request,
                        primaryTitle: nil,
                        secondaryTitle: "İPTAL",
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
                .fill(Color(crewHex: request.kind.accentHex).opacity(0.16))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Color(crewHex: request.kind.accentHex))
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(request.kind.title)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color(crewHex: request.kind.accentHex))

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
                            .background(Capsule().fill(Color(crewHex: CrewArenaPalette.liveGreen)))
                    }
                    .buttonStyle(.plain)
                }

                if let secondaryTitle, let onSecondary {
                    Button(action: onSecondary) {
                        Text(secondaryTitle)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(crewHex: request.kind.accentHex))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(crewHex: request.kind.accentHex).opacity(0.12))
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

// MARK: - Community Content

private struct CrewCommunityContent: View {
    @Binding var scope: CrewCommunityScope
    @Binding var range: CrewLeaderboardRange

    let studentContext: CrewArenaStudentContext
    @ObservedObject var arenaStore: ArenaStore
    let onStartFocus: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CrewCommunityScopeSwitch(selectedScope: $scope)

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

            // WEEKLY CHALLENGE — sadece loading opacity
            Group {
                if let weeklyChallenge = arenaStore.weeklyChallenge {
                    CrewWeeklyBattleCard(challenge: weeklyChallenge)
                } else {
                    CrewArenaPreparingCard(
                        title: "Haftalık challenge hazırlanıyor",
                        subtitle: "Arena backend bağlı. Gerçek challenge verileri geldiğinde burada görünecek."
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

            // LEADERBOARD — scope/range değişince fade
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

            // TOP CREWS — scope değişince fade
            Group {
                if arenaStore.topCrews.isEmpty {
                    CrewArenaPreparingCard(
                        title: "Top crews yakında",
                        subtitle: "Bölüm, kampüs ve ülke crew sıralamaları backend’den geldikçe burada listelenecek."
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

private struct CrewCommunityScopeSwitch: View {
    @Binding var selectedScope: CrewCommunityScope

    var body: some View {
        HStack(spacing: 6) {
            ForEach(CrewCommunityScope.allCases) { scope in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        selectedScope = scope
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: scope.icon)
                            .font(.system(size: 12, weight: .black))

                        Text(scope.title.uppercased())
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1)
                    }
                    .foregroundStyle(selectedScope == scope ? Color(crewHex: CrewArenaPalette.gold) : .white.opacity(0.34))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background {
                        if selectedScope == scope {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(crewHex: CrewArenaPalette.gold).opacity(0.16),
                                            Color(crewHex: CrewArenaPalette.appPurple).opacity(0.08)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.070))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                )
        )
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
                        .foregroundStyle(Color(crewHex: CrewArenaPalette.gold))

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(summary.title)
                            .font(.system(size: 25, weight: .black))
                            .foregroundStyle(Color(crewHex: CrewArenaPalette.gold))

                        Text(summary.italicTitle)
                            .font(.system(size: 22, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)
                    }

                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(crewHex: CrewArenaPalette.liveGreen))
                            .frame(width: 7, height: 7)

                        Text(summary.primaryLiveText)
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(Color(crewHex: CrewArenaPalette.liveGreen))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                }

                Spacer()

                Text(summary.rankDeltaText)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(crewHex: CrewArenaPalette.gold))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(Color(crewHex: CrewArenaPalette.gold).opacity(0.12))
                            .overlay(
                                Capsule()
                                    .stroke(Color(crewHex: CrewArenaPalette.gold).opacity(0.22), lineWidth: 1)
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
                            Color(crewHex: CrewArenaPalette.gold).opacity(0.11),
                            Color(crewHex: CrewArenaPalette.appPurple).opacity(0.07),
                            Color(crewHex: CrewArenaPalette.surface).opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color(crewHex: CrewArenaPalette.gold).opacity(0.18), lineWidth: 1)
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
                        .stroke(Color(crewHex: metric.accentHex).opacity(0.13), lineWidth: 1)
                )
        )
    }
}

private struct CrewCommunityQuickChips: View {
    @Binding var selectedScope: CrewCommunityScope

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                CrewChip(text: "🔥 Bu Hafta", isSelected: true) { }
                CrewChip(text: "🌍 Türkiye", isSelected: selectedScope == .country) {
                    selectedScope = .country
                }
                CrewChip(text: "🎓 Bölüm", isSelected: selectedScope == .department) {
                    selectedScope = .department
                }
                CrewChip(text: "⚡ Boost", isSelected: false) { }
            }
        }
    }
}

private struct CrewChip: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(isSelected ? .black : .white.opacity(0.55))
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(
                    Capsule()
                        .fill(isSelected ? Color(crewHex: CrewArenaPalette.crewCoral) : Color.white.opacity(0.08))
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(isSelected ? 0.0 : 0.10), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

private struct CrewWeeklyBattleCard: View {
    let challenge: CrewWeeklyChallengeData

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .center, spacing: 13) {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color(crewHex: CrewArenaPalette.crewCoral))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text("⚔️")
                            .font(.system(size: 23))
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
                                    .fill(Color(crewHex: CrewArenaPalette.crewCoral))
                            )

                        Text("Haftanın meydan okuması")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(Color(crewHex: CrewArenaPalette.crewCoralSoft))
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
                                    Color(crewHex: CrewArenaPalette.crewCoral),
                                    Color(crewHex: CrewArenaPalette.appPurple)
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
                Text("Ödül")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.34))

                Spacer()

                Text("💎 Diamond Badge")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(Color(crewHex: CrewArenaPalette.gold))
                    .lineLimit(1)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(crewHex: CrewArenaPalette.crewCoral).opacity(0.14),
                            Color(crewHex: CrewArenaPalette.appPurple).opacity(0.08),
                            Color(crewHex: CrewArenaPalette.surface).opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color(crewHex: CrewArenaPalette.crewCoral).opacity(0.22), lineWidth: 1)
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
                    .foregroundStyle(Color(crewHex: CrewArenaPalette.gold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color(crewHex: CrewArenaPalette.gold).opacity(0.12))
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
                    .fill(Color(crewHex: entry.colorHex))
                    .frame(width: entry.rank == 1 ? 64 : 56, height: entry.rank == 1 ? 64 : 56)
                    .shadow(color: Color(crewHex: entry.colorHex).opacity(entry.rank == 1 ? 0.22 : 0.06), radius: 12, y: 6)
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
                .foregroundStyle(entry.rank == 1 ? Color(crewHex: CrewArenaPalette.gold) : .white.opacity(0.82))
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
                .foregroundStyle(Color(crewHex: CrewArenaPalette.crewCoral))

            VStack(alignment: .leading, spacing: 2) {
                Text("Senin sıra")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color(crewHex: CrewArenaPalette.crewCoralSoft))

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
                    .foregroundStyle(Color(crewHex: CrewArenaPalette.crewCoral))
                    .lineLimit(1)

                Text("↑ \(entry.deltaRank)")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(Color(crewHex: CrewArenaPalette.liveGreen))
                    .lineLimit(1)
            }
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(crewHex: CrewArenaPalette.crewCoral).opacity(0.12),
                            Color(crewHex: CrewArenaPalette.appPurple).opacity(0.07),
                            Color.black.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(crewHex: CrewArenaPalette.crewCoral).opacity(0.22), lineWidth: 1)
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
                        .fill(Color(crewHex: CrewArenaPalette.liveGreen))
                        .frame(width: 8, height: 8)

                    Text("LIVE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(crewHex: CrewArenaPalette.liveGreen))
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
            return "Henüz focus yok"
        }

        return "\(crew.focusTimeText) focus"
    }

    private var memberLabel: String {
        "\(crew.memberCount) üye"
    }

    private var rankColor: Color {
        if crew.rank == 1 {
            return Color(crewHex: CrewArenaPalette.gold)
        }

        if crew.rank == 2 {
            return Color(crewHex: CrewArenaPalette.liveGreen)
        }

        return Color(crewHex: CrewArenaPalette.crewCoral)
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
                        .foregroundStyle(crew.deltaRank > 0 ? Color(crewHex: CrewArenaPalette.liveGreen) : Color(crewHex: CrewArenaPalette.crewCoral))
                }
            }
            .frame(width: 38)

            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(crewHex: crew.colorHex).opacity(0.24),
                                Color(crewHex: CrewArenaPalette.appPurple).opacity(0.12)
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
                        .fill(Color(crewHex: CrewArenaPalette.liveGreen))
                        .frame(width: 11, height: 11)
                        .overlay(
                            Circle()
                                .stroke(Color(crewHex: CrewArenaPalette.surface), lineWidth: 2)
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
                        Text(crew.badges.joined())
                            .font(.system(size: 12))
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 7) {
                    Text(focusLabel)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(
                            crew.focusMinutes > 0
                            ? Color(crewHex: CrewArenaPalette.crewCoral)
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
                .foregroundStyle(crew.joinState == .join ? .black : Color(crewHex: crew.colorHex))
                .padding(.horizontal, 11)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(
                            crew.joinState == .join
                            ? Color(crewHex: CrewArenaPalette.crewCoral)
                            : Color.white.opacity(0.07)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(Color(crewHex: crew.colorHex).opacity(0.22), lineWidth: 1)
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
                .fill(Color(crewHex: CrewArenaPalette.gold).opacity(0.14))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(Color(crewHex: CrewArenaPalette.gold))
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
                                Color(crewHex: CrewArenaPalette.gold).opacity(0.22),
                                Color(crewHex: CrewArenaPalette.crewCoral).opacity(0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)
                    .overlay(
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 21, weight: .black))
                            .foregroundStyle(Color(crewHex: CrewArenaPalette.gold))
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text("İlk sıraya sen çık")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.white)

                    Text("Focus oturumu tamamlayınca bölüm, kampüs ve ülke sıralamasında görünürsün.")
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

                    Text("Focus başlat")
                        .font(.system(size: 13, weight: .black))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color(crewHex: CrewArenaPalette.gold))
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
                .fill(Color(crewHex: CrewArenaPalette.appBlue).opacity(0.14))
                .frame(width: 66, height: 66)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(Color(crewHex: CrewArenaPalette.appBlue))
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
                            .background(Capsule().fill(Color(crewHex: CrewArenaPalette.appBlue)))
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
                        Color(crewHex: CrewArenaPalette.appBlue).opacity(0.035),
                        Color(crewHex: CrewArenaPalette.appPurple).opacity(0.045),
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

private extension Color {
    init(crewHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64

        switch cleaned.count {
        case 3:
            a = 255
            r = (int >> 8) * 17
            g = ((int >> 4) & 0xF) * 17
            b = (int & 0xF) * 17

        case 6:
            a = 255
            r = int >> 16
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        case 8:
            a = int >> 24
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        default:
            a = 255
            r = 255
            g = 255
            b = 255
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
