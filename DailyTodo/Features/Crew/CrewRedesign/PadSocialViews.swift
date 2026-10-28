//
//  PadSocialViews.swift
//  DailyTodo
//
//  iPad Social: a Messages-style sidebar (crews + friends with live presence)
//  and the "Social board" that fills the detail column when nothing is picked.
//  iPad only — CrewView shows these exclusively in its `padSplit`.
//

import SwiftUI
import SwiftData

// MARK: - Ink

private enum PadInk {
    static let cyan = Color(arenaHex: "#2DD4FF")
    static let blue = Color(arenaHex: "#1593FF")
    static let purple = Color(arenaHex: "#7C3AED")
    static let violet = Color(arenaHex: "#8B5CF6")
    static let coral = Color(arenaHex: "#FF5A44")
    static let gold = Color(arenaHex: "#FBBF24")
    static let lime = Color(arenaHex: "#A3E635")

    static var brand: LinearGradient {
        LinearGradient(colors: [cyan, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private func padCaps(_ text: String) -> String {
    text.uppercased(with: Locale(identifier: appLanguageIsEnglish() ? "en" : "tr"))
}

private func padMono(_ text: String, size: CGFloat = 11, weight: Font.Weight = .bold) -> Text {
    Text(text).font(.system(size: size, weight: weight, design: .monospaced))
}

/// "—— SOSYAL" — the mono eyebrow Updo sections open with.
private struct PadEyebrow: View {
    let text: String
    var tint: Color = UpdoTheme.cyan

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(PadInk.blue)
                .frame(width: 18, height: 1)
            Text(padCaps(text))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(2.2)
                .foregroundStyle(tint)
                .lineLimit(1)
        }
    }
}

/// Heavy word + serif italic accent ("Bugün *birlikte*").
private struct PadAccentTitle: View {
    let title: String
    let accent: String
    var size: CGFloat = 24

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(title)
                .font(.system(size: size, weight: .black))
                .foregroundStyle(UpdoTheme.textPrimary)
            Text(accent)
                .font(.system(size: size - 2, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(PadInk.brand)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

private struct PadCardBackground: View {
    let tint: Color
    var radius: CGFloat = 26

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape
            .fill(UpdoTheme.surface)
            .overlay(
                shape.fill(
                    LinearGradient(
                        colors: [tint.opacity(0.09), PadInk.purple.opacity(0.04), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
            .overlay(shape.stroke(tint.opacity(0.16), lineWidth: 1))
            .shadow(color: UpdoTheme.cardShadow(0.2), radius: 16, y: 9)
    }
}

private struct PadPresenceDot: View {
    let isFocusing: Bool
    let isOnline: Bool
    var size: CGFloat = 12

    var body: some View {
        if isFocusing || isOnline {
            Circle()
                .fill(PadInk.lime)
                .frame(width: size, height: size)
                .overlay(Circle().stroke(UpdoTheme.surface, lineWidth: 2.5))
        }
    }
}

private func crewMeta(_ crew: CrewSocialCrewCardData) -> String {
    tr(crew.memberCount == 1 ? "psx_crew_meta_one" : "psx_crew_meta",
       crew.memberCount, CrewHomeFormatters.focusTime(crew.thisWeekFocusMinutes))
}

private extension CrewSocialFriendCardData {
    /// Focusing first, then online, then the rest — alphabetical inside.
    var presenceRank: Int { isFocusing ? 0 : (isOnline ? 1 : 2) }

    var padStatus: String {
        if isFocusing {
            if let focusMinutes { return tr("psx_focusing_min", focusMinutes) }
            return tr("psx_focusing")
        }
        return isOnline ? tr("ch_online_caps") : tr("ch_offline_caps")
    }
}

// MARK: - Sidebar

/// iPad Social list column: compact, scannable rows like Messages — the
/// selected crew or friend opens in the detail column on the right.
struct PadSocialSidebar: View {
    let summary: CrewHomeSummary
    let crews: [CrewSocialCrewCardData]
    let friends: [CrewSocialFriendCardData]
    let incomingRequests: [CrewSocialRequestCardData]
    let sentRequests: [CrewSocialRequestCardData]
    let selectedCrewID: UUID?
    let selectedFriendID: UUID?

    let onOpenBoard: () -> Void
    let onCreateCrew: () -> Void
    let onJoinCrew: () -> Void
    let onAddFriend: () -> Void
    let onOpenCrew: (UUID) -> Void
    let onOpenFriend: (UUID) -> Void
    let onAcceptRequest: (UUID) -> Void
    let onRemoveRequest: (UUID) -> Void
    let onRefresh: () async -> Void

    @State private var query = ""
    @State private var showRequests = false
    @FocusState private var searchFocused: Bool

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func matches(_ text: String) -> Bool {
        trimmedQuery.isEmpty || text.localizedCaseInsensitiveContains(trimmedQuery)
    }

    private var visibleCrews: [CrewSocialCrewCardData] {
        crews.filter { matches($0.name) }
    }

    private var visibleFriends: [CrewSocialFriendCardData] {
        friends
            .filter { matches($0.displayName) || matches($0.subtitle) }
            .sorted {
                if $0.presenceRank != $1.presenceRank { return $0.presenceRank < $1.presenceRank }
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 4) {
                    header
                        .padding(.top, 14)
                        .padding(.bottom, 12)

                    searchField
                        .padding(.bottom, 12)

                    if trimmedQuery.isEmpty {
                        boardRow
                            .padding(.bottom, 10)
                    }

                    crewsSection
                    friendsSection

                    if !trimmedQuery.isEmpty && visibleCrews.isEmpty && visibleFriends.isEmpty {
                        padMono(tr("psx_no_results", trimmedQuery), size: 12, weight: .semibold)
                            .foregroundStyle(UpdoTheme.filmy(0.45))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 30)
                    }

                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, 14)
            }
            .scrollDismissesKeyboard(.immediately)
            .refreshable { await onRefresh() }
        }
        .sheet(isPresented: $showRequests) {
            Group {
                CrewRequestsSheet(
                    incomingRequests: incomingRequests,
                    sentRequests: sentRequests,
                    onAcceptRequest: onAcceptRequest,
                    onRemoveRequest: onRemoveRequest,
                    onAddFriend: {
                        showRequests = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { onAddFriend() }
                    }
                )
            }
            .updoPadSheet()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    PadEyebrow(text: tr("psx_social_caps"))
                    if summary.liveCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .symbolEffect(.pulse, options: .repeating)
                            Text(padCaps(tr("psx_live_n", summary.liveCount)))
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .tracking(1.2)
                        }
                        .foregroundStyle(UpdoTheme.lime)
                    }
                }
                PadAccentTitle(title: "The", accent: "Crew", size: 30)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Button { showRequests = true } label: {
                    chrome("person.crop.circle.badge.questionmark")
                        .overlay(alignment: .topTrailing) {
                            if !incomingRequests.isEmpty {
                                Text("\(incomingRequests.count)")
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundStyle(.black)
                                    .frame(minWidth: 18, minHeight: 18)
                                    .background(Capsule().fill(PadInk.coral))
                                    .offset(x: 5, y: -5)
                            }
                        }
                }
                .buttonStyle(.plain)
                .hoverEffect(.lift)
                .accessibilityLabel(tr("psx_requests"))

                Button(action: onAddFriend) {
                    chrome("person.badge.plus")
                }
                .buttonStyle(.plain)
                .hoverEffect(.lift)
                .accessibilityLabel(tr("ch_add_friend"))

                Menu {
                    Button(action: onCreateCrew) {
                        Label(tr("ch_create_crew"), systemImage: "person.3.fill")
                    }
                    Button(action: onJoinCrew) {
                        Label(tr("ch_join_code"), systemImage: "number")
                    }
                    Button(action: onAddFriend) {
                        Label(tr("ch_add_friend"), systemImage: "person.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.black)
                        .frame(width: 38, height: 38)
                        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(PadInk.blue))
                }
                .hoverEffect(.lift)
                .accessibilityLabel(tr("ch_create_crew"))
            }
        }
    }

    private func chrome(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(UpdoTheme.textPrimary)
            .frame(width: 38, height: 38)
            .liquidGlass(in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(UpdoTheme.filmy(0.45))
            TextField(tr("psx_search"), text: $query)
                .font(.system(size: 15, weight: .medium))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($searchFocused)
                .submitLabel(.search)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(UpdoTheme.filmy(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(UpdoTheme.filmy(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(searchFocused ? PadInk.blue.opacity(0.5) : UpdoTheme.filmy(0.06), lineWidth: 1)
                )
        )
        // ⌘F jumps into search, like Messages.
        .background {
            Button("") { searchFocused = true }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
        }
    }

    // MARK: Rows

    private var boardRow: some View {
        let selected = selectedCrewID == nil && selectedFriendID == nil

        return Button(action: onOpenBoard) {
            HStack(spacing: 12) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(colors: [PadInk.blue, PadInk.purple],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("psx_dashboard"))
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(UpdoTheme.textPrimary)
                    padMono(padCaps(tr("psx_dashboard_sub")), size: 10)
                        .tracking(0.4)
                        .foregroundStyle(UpdoTheme.filmy(0.45))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .background(PadRowBackground(selected: selected))
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
    }

    private func sectionHeader(_ title: String, count: Int, action: @escaping () -> Void, label: String) -> some View {
        HStack(spacing: 8) {
            padMono(padCaps(title), size: 10, weight: .black)
                .tracking(1.8)
                .foregroundStyle(UpdoTheme.filmy(0.5))
            padMono("\(count)", size: 10, weight: .black)
                .foregroundStyle(UpdoTheme.filmy(0.3))
            Spacer()
            Button(action: action) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(UpdoTheme.cyan)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .hoverEffect(.highlight)
            .accessibilityLabel(label)
        }
        .padding(.horizontal, 6)
        .padding(.top, 14)
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private var crewsSection: some View {
        if trimmedQuery.isEmpty || !visibleCrews.isEmpty {
            sectionHeader(tr("psx_crews_caps"), count: crews.count, action: onCreateCrew, label: tr("ch_create_crew"))

            if crews.isEmpty {
                PadDashedRow(icon: "person.3.fill", title: tr("ch_create_crew"), tint: PadInk.blue, action: onCreateCrew)
            }

            ForEach(visibleCrews) { crew in
                Button { onOpenCrew(crew.id) } label: {
                    PadSidebarCrewRow(crew: crew, selected: selectedCrewID == crew.id)
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
            }
        }
    }

    @ViewBuilder
    private var friendsSection: some View {
        if trimmedQuery.isEmpty || !visibleFriends.isEmpty {
            sectionHeader(tr("psx_friends_caps"), count: friends.count, action: onAddFriend, label: tr("ch_add_friend"))

            if friends.isEmpty {
                PadDashedRow(icon: "person.badge.plus", title: tr("ch_add_friend"), tint: PadInk.lime, action: onAddFriend)
            }

            ForEach(visibleFriends) { friend in
                Button { onOpenFriend(friend.id) } label: {
                    PadSidebarFriendRow(friend: friend, selected: selectedFriendID == friend.id)
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
            }
        }
    }
}

private struct PadRowBackground: View {
    let selected: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        shape
            .fill(selected ? PadInk.blue.opacity(0.16) : Color.clear)
            .overlay(shape.stroke(selected ? PadInk.blue.opacity(0.38) : Color.clear, lineWidth: 1))
    }
}

private struct PadDashedRow: View {
    let icon: String
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .black))
                Text(title)
                    .font(.system(size: 14, weight: .black))
                Spacer(minLength: 0)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(tint.opacity(0.45), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct PadSidebarCrewRow: View {
    let crew: CrewSocialCrewCardData
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                CrewAvatarView(crewID: crew.id, name: crew.name, colorHex: crew.colorHex, size: 44, corner: 14)
                PadPresenceDot(isFocusing: crew.isLive, isOnline: false, size: 12)
                    .offset(x: 3, y: 3)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(crew.name)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(UpdoTheme.textPrimary)
                        .lineLimit(1)
                    if crew.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(PadInk.gold)
                    }
                }
                subtitle
            }

            Spacer(minLength: 4)

            if crew.unreadCount > 0 {
                Text("\(crew.unreadCount)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(Capsule().fill(PadInk.gold))
            }
        }
        .padding(10)
        .background(PadRowBackground(selected: selected))
        .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var subtitle: some View {
        if crew.isLive {
            padMono(padCaps(tr("psx_crew_live")), size: 10, weight: .black)
                .tracking(0.8)
                .foregroundStyle(UpdoTheme.lime)
        } else if let last = crew.lastMessageText, !last.isEmpty {
            Text(last)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(UpdoTheme.filmy(0.5))
                .lineLimit(1)
        } else {
            padMono(padCaps(crewMeta(crew)), size: 10)
                .tracking(0.4)
                .foregroundStyle(UpdoTheme.filmy(0.42))
                .lineLimit(1)
        }
    }
}

private struct PadSidebarFriendRow: View {
    let friend: CrewSocialFriendCardData
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                UserAvatarView(userID: friend.userID, name: friend.displayName,
                               tint: Color(arenaHex: friend.colorHex), size: 44)
                    .overlay(
                        Circle().stroke(friend.isFocusing ? PadInk.lime : .clear, lineWidth: 2)
                            .padding(-3)
                    )
                PadPresenceDot(isFocusing: friend.isFocusing, isOnline: friend.isOnline, size: 12)
                    .offset(x: 2, y: 2)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(friend.displayName)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(UpdoTheme.textPrimary)
                    .lineLimit(1)
                padMono(padCaps(friend.padStatus), size: 10, weight: .black)
                    .tracking(0.8)
                    .foregroundStyle(friend.isFocusing ? UpdoTheme.lime
                                     : (friend.isOnline ? UpdoTheme.cyan : UpdoTheme.filmy(0.35)))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if let streak = friend.streak, streak > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10, weight: .black))
                    padMono("\(streak)", size: 11, weight: .black)
                }
                .foregroundStyle(PadInk.gold)
            }
        }
        .padding(10)
        .background(PadRowBackground(selected: selected))
        .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
    }
}

// MARK: - Social board

/// iPad detail column before anything is picked: who's live right now, the
/// streak race among friends, your crews' week and anything waiting on you.
struct PadSocialBoard: View {
    let crews: [CrewSocialCrewCardData]
    let friends: [CrewSocialFriendCardData]
    let incomingRequests: [CrewSocialRequestCardData]

    let onOpenCrew: (UUID) -> Void
    let onOpenFriend: (UUID) -> Void
    let onAcceptRequest: (UUID) -> Void
    let onRemoveRequest: (UUID) -> Void
    let onAddFriend: () -> Void
    let onCreateCrew: () -> Void
    let onJoinCrew: () -> Void

    @EnvironmentObject private var session: SessionStore
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var subscription = SubscriptionManager.shared
    @ObservedObject private var progression = ProgressionManager.shared

    @State private var width: CGFloat = 0
    @State private var showPaywall = false
    @State private var showReferral = false
    @State private var appeared = false

    private var focusingFriends: [CrewSocialFriendCardData] { friends.filter(\.isFocusing) }
    private var onlineFriends: [CrewSocialFriendCardData] { friends.filter { $0.isOnline && !$0.isFocusing } }
    private var liveCrews: [CrewSocialCrewCardData] { crews.filter(\.isLive) }

    var body: some View {
        ZStack {
            ArenaBackground(
                primaryGlow: PadInk.purple,
                secondaryGlow: PadInk.cyan,
                warmGlow: PadInk.coral,
                intensity: 0.6
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    liveCard
                        .boardReveal(appeared, delay: 0.04)

                    if width >= 760 {
                        HStack(alignment: .top, spacing: 20) {
                            leftColumn.frame(maxWidth: .infinity, alignment: .top)
                            rightColumn.frame(maxWidth: .infinity, alignment: .top)
                        }
                    } else {
                        leftColumn
                        rightColumn
                    }

                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, 30)
                .padding(.top, 26)
                .frame(maxWidth: 1120)
                .frame(maxWidth: .infinity)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { appeared = true }
        }
        .sheet(isPresented: $showPaywall) {
            Group { PaywallView(context: "social_stats") }
                .updoPadSheet()
        }
        .fullScreenCover(isPresented: $showReferral) {
            OnboardingInviteView(onFinish: { showReferral = false })
                .updoReadableColumn()
        }
    }

    private var leftColumn: some View {
        VStack(spacing: 20) {
            crewsCard
                .boardReveal(appeared, delay: 0.08)
            if !incomingRequests.isEmpty {
                requestsCard
                    .boardReveal(appeared, delay: 0.12)
            }
            inviteCard
                .boardReveal(appeared, delay: 0.14)
        }
    }

    private var rightColumn: some View {
        VStack(spacing: 20) {
            raceCard
                .boardReveal(appeared, delay: 0.1)
            if subscription.isPro {
                sharingCard
                    .boardReveal(appeared, delay: 0.16)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                PadEyebrow(text: tr("psx_board_caps"))
                PadAccentTitle(title: tr("psx_board_title"), accent: tr("psx_board_accent"), size: 40)
                padMono(padCaps(tr("psx_board_meta", focusingFriends.count, onlineFriends.count, crews.count)), size: 12)
                    .tracking(0.6)
                    .foregroundStyle(UpdoTheme.filmy(0.5))
            }

            Spacer(minLength: 12)

            Button {
                NotificationCenter.default.post(name: .openFocusTabFromHome, object: nil)
            } label: {
                Label(tr("psx_start_focus"), systemImage: "bolt.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .frame(height: 46)
                    .background(
                        Capsule()
                            .fill(PadInk.blue)
                            .shadow(color: PadInk.blue.opacity(0.4), radius: 14, y: 6)
                    )
                    .contentShape(.hoverEffect, Capsule())
            }
            .buttonStyle(.plain)
            .hoverEffect(.lift)
        }
    }

    private func cardHeader<Trailing: View>(
        eyebrow: String,
        title: String,
        accent: String,
        tint: Color = UpdoTheme.cyan,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                PadEyebrow(text: eyebrow, tint: tint)
                PadAccentTitle(title: title, accent: accent)
            }
            Spacer(minLength: 8)
            trailing()
        }
    }

    // MARK: Live now

    private var liveCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            cardHeader(eyebrow: tr("psx_live_caps"), title: tr("psx_live_t1"), accent: tr("psx_live_word"), tint: UpdoTheme.lime) {
                if !focusingFriends.isEmpty || !liveCrews.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .symbolEffect(.pulse, options: .repeating)
                        padMono(padCaps(tr("psx_live_n", focusingFriends.count + liveCrews.count)), size: 10, weight: .black)
                            .tracking(1.2)
                    }
                    .foregroundStyle(UpdoTheme.lime)
                }
            }

            if focusingFriends.isEmpty && liveCrews.isEmpty && onlineFriends.isEmpty {
                liveEmpty
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(liveCrews) { crew in
                            PadLiveCrewTile(crew: crew) { onOpenCrew(crew.id) }
                        }
                        ForEach(focusingFriends + onlineFriends) { friend in
                            PadLiveFriendTile(friend: friend) { onOpenFriend(friend.id) }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .padding(.horizontal, -20)
            }
        }
        .padding(20)
        .background(PadCardBackground(tint: PadInk.lime, radius: 28))
    }

    private var liveEmpty: some View {
        HStack(spacing: 14) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(PadInk.violet)
                .frame(width: 48, height: 48)
                .background(Circle().fill(PadInk.violet.opacity(0.14)))

            VStack(alignment: .leading, spacing: 3) {
                Text(tr("psx_live_empty_title"))
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(UpdoTheme.textPrimary)
                Text(tr("psx_live_empty_sub"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(UpdoTheme.filmy(0.55))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(UpdoTheme.filmy(0.12), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
    }

    // MARK: Crews

    private var crewsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader(eyebrow: tr("psx_crews_caps"), title: tr("psx_crews_t1"), accent: tr("psx_crews_word")) {
                Menu {
                    Button(action: onCreateCrew) { Label(tr("ch_create_crew"), systemImage: "person.3.fill") }
                    Button(action: onJoinCrew) { Label(tr("ch_join_code"), systemImage: "number") }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.black)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(PadInk.blue))
                }
                .accessibilityLabel(tr("ch_create_crew"))
            }

            if crews.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(tr("psx_crews_empty"))
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(UpdoTheme.textPrimary)
                    Text(tr("psx_crews_empty_sub"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(UpdoTheme.filmy(0.55))
                    HStack(spacing: 10) {
                        PadPillButton(title: tr("ch_create_crew"), icon: "person.3.fill", fill: PadInk.blue, action: onCreateCrew)
                        PadPillButton(title: tr("ch_join_code"), icon: "number", fill: nil, action: onJoinCrew)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(crews) { crew in
                        Button { onOpenCrew(crew.id) } label: {
                            PadBoardCrewRow(crew: crew)
                        }
                        .buttonStyle(.plain)
                        .hoverEffect(.highlight)
                    }
                }
            }
        }
        .padding(20)
        .background(PadCardBackground(tint: PadInk.blue))
    }

    // MARK: Streak race

    private struct RaceEntry: Identifiable {
        let id: UUID
        let friendID: UUID?
        let name: String
        let tint: Color
        let streak: Int
        let isMe: Bool
    }

    private var raceEntries: [RaceEntry] {
        var entries = friends.compactMap { friend -> RaceEntry? in
            // Only live streaks race; "0 days" rows are just noise.
            guard let streak = friend.streak, streak > 0 else { return nil }
            return RaceEntry(id: friend.userID ?? friend.id, friendID: friend.id, name: friend.displayName,
                             tint: Color(arenaHex: friend.colorHex), streak: streak, isMe: false)
        }
        if let me = session.currentUser?.id {
            entries.append(RaceEntry(id: me, friendID: nil, name: tr("cdx_you"), tint: PadInk.cyan,
                                     streak: progression.currentStreak, isMe: true))
        }
        return Array(entries.sorted {
            $0.streak != $1.streak ? $0.streak > $1.streak : $0.isMe
        }.prefix(6))
    }

    private var raceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader(eyebrow: tr("psx_race_caps"), title: tr("psx_race_t1"), accent: tr("psx_race_word"), tint: PadInk.gold) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [PadInk.gold, PadInk.coral], startPoint: .top, endPoint: .bottom))
            }

            if !subscription.isPro {
                Button { showPaywall = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(.black)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(LinearGradient(colors: [PadInk.gold, PadInk.cyan],
                                                                     startPoint: .topLeading, endPoint: .bottomTrailing)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("crew_see_friends_close"))
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(UpdoTheme.textPrimary)
                            Text(tr("crew_friends_locked_sub"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(UpdoTheme.filmy(0.55))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(UpdoTheme.filmy(0.4))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                let entries = raceEntries
                let best = max(entries.map(\.streak).max() ?? 1, 1)

                VStack(spacing: 10) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        raceRow(rank: index + 1, entry: entry, best: best)
                    }
                }

                if entries.count <= 1 {
                    Text(tr("psx_race_empty"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(UpdoTheme.filmy(0.5))
                }
            }
        }
        .padding(20)
        .background(PadCardBackground(tint: PadInk.gold))
    }

    private func raceRow(rank: Int, entry: RaceEntry, best: Int) -> some View {
        HStack(spacing: 10) {
            Group {
                if rank == 1 && entry.streak > 0 {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(PadInk.gold)
                } else {
                    padMono("#\(rank)", size: 11, weight: .black)
                        .foregroundStyle(UpdoTheme.filmy(0.4))
                }
            }
            .frame(width: 24)

            UserAvatarView(userID: entry.isMe ? session.currentUser?.id : entry.id, name: entry.name, tint: entry.tint, size: 32)

            VStack(alignment: .leading, spacing: 5) {
                Text(entry.name)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(entry.isMe ? PadInk.cyan : UpdoTheme.textPrimary)
                    .lineLimit(1)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(UpdoTheme.filmy(0.07))
                        Capsule()
                            .fill(LinearGradient(colors: [PadInk.gold, PadInk.coral], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(6, geo.size.width * CGFloat(entry.streak) / CGFloat(best)))
                    }
                }
                .frame(height: 5)
            }

            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10, weight: .black))
                padMono(tr("psx_days_n", entry.streak), size: 12, weight: .black)
            }
            .foregroundStyle(entry.streak > 0 ? PadInk.gold : UpdoTheme.filmy(0.35))
            .frame(minWidth: 62, alignment: .trailing)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let friendID = entry.friendID { onOpenFriend(friendID) }
        }
    }

    // MARK: Requests

    private var requestsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardHeader(eyebrow: tr("psx_requests_caps"), title: tr("psx_req_t1"), accent: tr("psx_req_word"), tint: PadInk.coral) {
                padMono("\(incomingRequests.count)", size: 13, weight: .black)
                    .foregroundStyle(.black)
                    .frame(minWidth: 26, minHeight: 26)
                    .background(Capsule().fill(PadInk.coral))
            }

            VStack(spacing: 10) {
                ForEach(incomingRequests) { request in
                    HStack(spacing: 12) {
                        UserAvatarView(userID: request.userID, name: request.title, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(request.title)
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(UpdoTheme.textPrimary)
                                .lineLimit(1)
                            padMono(request.subtitle, size: 11, weight: .semibold)
                                .foregroundStyle(UpdoTheme.filmy(0.45))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 6)
                        Button { onRemoveRequest(request.id) } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .black))
                                .foregroundStyle(UpdoTheme.filmy(0.6))
                                .frame(width: 34, height: 34)
                                .background(Circle().fill(UpdoTheme.filmy(0.07)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tr("ipad_req_decline"))
                        Button { onAcceptRequest(request.id) } label: {
                            Text(tr("ipad_req_accept"))
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 14)
                                .frame(height: 34)
                                .background(Capsule().fill(PadInk.lime))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(20)
        .background(PadCardBackground(tint: PadInk.coral))
    }

    // MARK: Invite + sharing

    private var inviteCard: some View {
        Button {
            HapticManager.shared.action()
            showReferral = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(PadInk.gold)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(PadInk.gold.opacity(0.16)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("ob_invite_title"))
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(UpdoTheme.textPrimary)
                    Text(tr("ob_invite_accent"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(UpdoTheme.filmy(0.55))
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(UpdoTheme.filmy(0.35))
            }
            .padding(18)
            .background(PadCardBackground(tint: PadInk.gold, radius: 22))
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
    }

    private var sharingCard: some View {
        HStack(spacing: 12) {
            Image(systemName: progression.statsSharingEnabled ? "eye.fill" : "eye.slash.fill")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(progression.statsSharingEnabled ? PadInk.lime : UpdoTheme.filmy(0.5))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("crew_share_my_stats"))
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(UpdoTheme.textPrimary)
                Text(progression.statsSharingEnabled ? tr("crew_stats_shared_on") : tr("crew_stats_shared_off"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(UpdoTheme.filmy(0.5))
                    .lineLimit(2)
            }
            Spacer(minLength: 6)
            Toggle("", isOn: Binding(
                get: { progression.statsSharingEnabled },
                set: { progression.setStatsSharing($0, context: modelContext) }
            ))
            .labelsHidden()
            .tint(PadInk.lime)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(PadCardBackground(tint: PadInk.lime, radius: 22))
    }
}

private struct PadPillButton: View {
    let title: String
    let icon: String
    let fill: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(fill == nil ? UpdoTheme.textPrimary : .black)
                .padding(.horizontal, 16)
                .frame(height: 42)
                .background {
                    if let fill {
                        Capsule().fill(fill)
                    } else {
                        Capsule().fill(UpdoTheme.filmy(0.07))
                            .overlay(Capsule().stroke(UpdoTheme.border, lineWidth: 1))
                    }
                }
                .contentShape(.hoverEffect, Capsule())
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
    }
}

private struct PadBoardCrewRow: View {
    let crew: CrewSocialCrewCardData

    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                CrewAvatarView(crewID: crew.id, name: crew.name, colorHex: crew.colorHex, size: 50, corner: 16)
                PadPresenceDot(isFocusing: crew.isLive, isOnline: false, size: 13)
                    .offset(x: 3, y: 3)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(crew.name)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(UpdoTheme.textPrimary)
                        .lineLimit(1)
                    if crew.isLive {
                        padMono(padCaps(tr("ch_live_caps")), size: 9, weight: .black)
                            .tracking(1)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(PadInk.lime))
                    }
                    Spacer(minLength: 4)
                    padMono(goalText, size: 11, weight: .black)
                        .foregroundStyle(UpdoTheme.filmy(0.55))
                        .lineLimit(1)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(UpdoTheme.filmy(0.07))
                        Capsule()
                            .fill(LinearGradient(colors: [PadInk.cyan, Color(arenaHex: crew.colorHex)],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(6, geo.size.width * barValue))
                    }
                }
                .frame(height: 6)

                padMono(padCaps(crewMeta(crew)), size: 10)
                    .tracking(0.4)
                    .foregroundStyle(UpdoTheme.filmy(0.42))
                    .lineLimit(1)
            }

            if crew.unreadCount > 0 {
                Text("\(crew.unreadCount)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(minWidth: 22, minHeight: 22)
                    .background(Capsule().fill(PadInk.gold))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(UpdoTheme.filmy(0.3))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(UpdoTheme.filmy(0.035))
        )
        .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(Rectangle())
    }

    /// Goal progress when the crew has a weekly goal, else a share of a
    /// 5-hour week so the bar still reads as "how much this week".
    private var barValue: CGFloat {
        if crew.weeklyGoalMinutes > 0 { return CGFloat(crew.goalProgress) }
        return min(CGFloat(crew.thisWeekFocusMinutes) / 300, 1)
    }

    private var goalText: String {
        if crew.weeklyGoalMinutes > 0 {
            return "\(Int((crew.goalProgress * 100).rounded()))%"
        }
        return CrewHomeFormatters.focusTime(crew.thisWeekFocusMinutes)
    }
}

/// A live friend on the board: focusing → join request, otherwise message.
private struct PadLiveFriendTile: View {
    let friend: CrewSocialFriendCardData
    let onOpen: () -> Void

    @EnvironmentObject private var session: SessionStore
    @ObservedObject private var focusSession = FocusSessionManager.shared
    @State private var joinRequested = false

    private var canJoin: Bool {
        friend.isFocusing && friend.userID != nil && !focusSession.hasBlockingActiveSession
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                UserAvatarView(userID: friend.userID, name: friend.displayName,
                               tint: Color(arenaHex: friend.colorHex), size: 58)
                    .padding(3)
                    .overlay(Circle().stroke(friend.isFocusing ? PadInk.lime : PadInk.cyan.opacity(0.35),
                                             lineWidth: friend.isFocusing ? 2.5 : 1))
                if friend.isFocusing {
                    Image(systemName: "timer")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.black)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(PadInk.lime))
                        .overlay(Circle().stroke(UpdoTheme.surface, lineWidth: 2))
                } else {
                    PadPresenceDot(isFocusing: false, isOnline: true, size: 13)
                        .offset(x: -2, y: -2)
                }
            }

            Text(friend.displayName)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(UpdoTheme.textPrimary)
                .lineLimit(1)

            padMono(padCaps(friend.padStatus), size: 9, weight: .black)
                .foregroundStyle(friend.isFocusing ? UpdoTheme.lime : UpdoTheme.cyan)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Button {
                if canJoin { requestJoin() } else { onOpen() }
            } label: {
                Text(canJoin ? (joinRequested ? tr("ch_join_sent_caps") : tr("ch_join_caps")) : tr("ch_message_caps"))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(Capsule().fill(canJoin ? PadInk.lime : PadInk.blue))
                    .contentTransition(.opacity)
            }
            .buttonStyle(.plain)
            .disabled(joinRequested)
        }
        .frame(width: 112)
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(UpdoTheme.filmy(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(friend.isFocusing ? PadInk.lime.opacity(0.25) : UpdoTheme.filmy(0.06), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .onChange(of: friend.isFocusing) { _, focusing in
            if !focusing { joinRequested = false }
        }
    }

    private func requestJoin() {
        guard let hostID = friend.userID, !joinRequested else { return }
        HapticManager.shared.selection()
        withAnimation(.snappy) { joinRequested = true }
        let name = session.focusDisplayName
        Task {
            let ok = await FriendFocusBackendClient.shared.requestJoin(hostID: hostID, requesterName: name)
            try? await Task.sleep(for: .seconds(ok ? 45 : 1.5))
            withAnimation(.snappy) { joinRequested = false }
        }
    }
}

private struct PadLiveCrewTile: View {
    let crew: CrewSocialCrewCardData
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 8) {
                CrewAvatarView(crewID: crew.id, name: crew.name, colorHex: crew.colorHex, size: 58, corner: 18)
                    .padding(3)
                    .overlay(RoundedRectangle(cornerRadius: 21, style: .continuous).stroke(PadInk.lime, lineWidth: 2.5))

                Text(crew.name)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(UpdoTheme.textPrimary)
                    .lineLimit(1)

                padMono(padCaps(tr("psx_crew_live")), size: 9, weight: .black)
                    .foregroundStyle(UpdoTheme.lime)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(tr("ch_join_caps"))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .background(Capsule().fill(PadInk.lime))
            }
            .frame(width: 112)
            .padding(.vertical, 14)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(PadInk.lime.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(PadInk.lime.opacity(0.3), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    func boardReveal(_ shown: Bool, delay: Double) -> some View {
        opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .animation(.spring(response: 0.55, dampingFraction: 0.86).delay(delay), value: shown)
    }
}
