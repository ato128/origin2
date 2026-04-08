//
//  FocusView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 8.04.2026.
//

import SwiftUI
import SwiftData
import Combine

struct FocusView: View {
    enum FocusMode: String, CaseIterable, Identifiable {
        case personal
        case crew
        case friend

        var id: String { rawValue }
    }

    enum InlineSessionState: String {
        case idle
        case running
        case paused
        case completed
    }

    struct FocusTheme {
        let smallTitle: String
        let title: String
        let subtitle: String
        let icon: String
        let edge: Color
        let accent: Color
        let accent2: Color
        let shadow: Color
    }

    struct SelectionItem: Identifiable {
        let id: String
        let title: String
    }

    enum StackPosition {
        case back
        case middle
        case front
    }

    @EnvironmentObject var session: SessionStore
    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue

    private var palette: ThemePalette { ThemePalette() }

    @Query(sort: \Friend.createdAt, order: .reverse) private var friends: [Friend]
    @Query(sort: \Crew.createdAt, order: .reverse) private var crews: [Crew]
    @Query(sort: \FriendFocusSession.startedAt, order: .reverse) private var friendFocusSessions: [FriendFocusSession]
    @Query(sort: \CrewFocusSession.startedAt, order: .reverse) private var crewFocusSessions: [CrewFocusSession]

    // MARK: - Card ordering
    @State private var selectedMode: FocusMode = .personal
    @State private var cardOrder: [FocusMode] = [.personal, .friend, .crew]

    // MARK: - Personal
    @State private var personalMinutes: Int = 25

    // MARK: - Crew
    @State private var crewMinutes: Int = 25
    @State private var selectedCrewID: String?
    @State private var crewTaskTitle: String = ""

    // MARK: - Friend
    @State private var friendMinutes: Int = 25
    @State private var selectedFriendID: String?
    @State private var friendTaskTitle: String = ""

    // MARK: - Live inline focus
    @State private var activeMode: FocusMode? = nil
    @State private var inlineState: InlineSessionState = .idle
    @State private var totalSeconds: Int = 25 * 60
    @State private var remainingSeconds: Int = 25 * 60
    @State private var endDate: Date? = nil
    @State private var liveTitle: String = ""
    @State private var liveSubtitle: String = ""

    // MARK: - Persistence
    @AppStorage("focus_tab_active_mode") private var persistedModeRaw: String = ""
    @AppStorage("focus_tab_inline_state") private var persistedStateRaw: String = "idle"
    @AppStorage("focus_tab_end_date") private var persistedEndDate: Double = 0
    @AppStorage("focus_tab_total_seconds") private var persistedTotalSeconds: Int = 0
    @AppStorage("focus_tab_title") private var persistedTitle: String = ""
    @AppStorage("focus_tab_subtitle") private var persistedSubtitle: String = ""

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Color.clear.frame(height: 34)

                    headerSection
                    stackedDeckSection

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            syncCardOrder(with: selectedMode, animated: false)
            bootstrapSelections()
            restoreInlineSession()
        }
        .onReceive(timer) { _ in
            tickTimer()
        }
    }
}

private extension FocusView {

    // MARK: - Layout

    var frontCardHeight: CGFloat {
        min(max(UIScreen.main.bounds.height * 0.60, 460), 560)
    }

    var deckHeight: CGFloat {
        frontCardHeight + 74
    }

    // MARK: - Data

    var currentUserIDString: String? {
        session.currentUser?.id.uuidString
    }

    var userScopedFriends: [Friend] {
        guard let currentUserIDString else { return [] }
        return friends.filter { String(describing: $0.ownerUserID) == currentUserIDString }
    }

    var userScopedCrews: [Crew] {
        guard let currentUser = session.currentUser?.id else { return [] }
        return crews.filter { String(describing: $0.ownerUserID) == String(describing: currentUser) }
    }

    var selectedCrew: Crew? {
        guard let selectedCrewID else { return nil }
        return userScopedCrews.first { idString($0.id) == selectedCrewID }
    }

    var selectedFriend: Friend? {
        guard let selectedFriendID else { return nil }
        return userScopedFriends.first { idString($0.id) == selectedFriendID }
    }

    var activeFriendSession: FriendFocusSession? {
        let visibleFriendIDs = userScopedFriends.map(\.id)

        return friendFocusSessions.first { focusSession in
            focusSession.isActive &&
            visibleFriendIDs.contains(where: { idsEqual($0, focusSession.friendID) })
        }
    }

    var activeCrewSession: CrewFocusSession? {
        let visibleCrewIDs = userScopedCrews.map(\.id)

        return crewFocusSessions.first { focusSession in
            focusSession.isActive &&
            visibleCrewIDs.contains(where: { idsEqual($0, focusSession.crewID) })
        }
    }

    func bootstrapSelections() {
        if selectedCrewID == nil {
            selectedCrewID = userScopedCrews.first.map { idString($0.id) }
        }
        if selectedFriendID == nil {
            selectedFriendID = userScopedFriends.first.map { idString($0.id) }
        }
    }

    func idString(_ value: Any) -> String {
        String(describing: unwrapID(value) ?? value)
    }

    func unwrapID(_ value: Any) -> Any? {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle != .optional { return value }
        return mirror.children.first?.value
    }

    func idsEqual(_ lhs: Any, _ rhs: Any) -> Bool {
        guard let left = unwrapID(lhs), let right = unwrapID(rhs) else { return false }
        return String(describing: left) == String(describing: right)
    }

    func displayName(for crew: Crew?) -> String? {
        guard let crew else { return nil }
        let raw = String(describing: crew.name).trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty || raw == "nil" ? nil : raw
    }

    func displayName(for friend: Friend?) -> String? {
        guard let friend else { return nil }
        let raw = String(describing: friend.name).trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty || raw == "nil" ? nil : raw
    }

    // MARK: - Ordering

    var frontMode: FocusMode { cardOrder[0] }
    var middleMode: FocusMode { cardOrder[1] }
    var backMode: FocusMode { cardOrder[2] }

    func syncCardOrder(with mode: FocusMode, animated: Bool = true) {
        let newOrder: [FocusMode]
        switch mode {
        case .personal:
            newOrder = [.personal, .friend, .crew]
        case .crew:
            newOrder = [.crew, .friend, .personal]
        case .friend:
            newOrder = [.friend, .crew, .personal]
        }

        if animated {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                selectedMode = mode
                cardOrder = newOrder
            }
        } else {
            selectedMode = mode
            cardOrder = newOrder
        }
    }

    // MARK: - Header

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Focus")
                .font(.system(size: 31, weight: .black, design: .rounded))
                .foregroundStyle(palette.primaryText)

            Text(headerSubtitle)
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(2)
        }
    }

    var headerSubtitle: String {
        switch selectedMode {
        case .personal:
            return "Kendi ritmini başlat ve tek dokunuşla odakta kal"
        case .crew:
            return "Crew ile ortak odak başlat ve birlikte ilerle"
        case .friend:
            return "Arkadaşınla focus akışını buradan yönet"
        }
    }

    // MARK: - Themes

    func theme(for mode: FocusMode) -> FocusTheme {
        switch mode {
        case .personal:
            return .init(
                smallTitle: "Personal",
                title: "Kişisel Focus",
                subtitle: "Sessiz bir odak oturumu başlat",
                icon: "timer",
                edge: Color(red: 0.12, green: 0.37, blue: 1.00),
                accent: Color(red: 0.66, green: 0.84, blue: 1.00),
                accent2: Color(red: 0.42, green: 0.28, blue: 0.95),
                shadow: .blue
            )
        case .crew:
            return .init(
                smallTitle: "Crew",
                title: "Crew Focus",
                subtitle: "Crew ile ortak odak başlat",
                icon: "person.3.fill",
                edge: Color(red: 0.96, green: 0.44, blue: 0.18),
                accent: Color(red: 1.00, green: 0.81, blue: 0.46),
                accent2: Color(red: 0.78, green: 0.14, blue: 0.10),
                shadow: .orange
            )
        case .friend:
            return .init(
                smallTitle: "Friend",
                title: "Arkadaş Focus",
                subtitle: "Arkadaş ile birlikte odaklan",
                icon: "person.2.fill",
                edge: Color(red: 0.18, green: 0.70, blue: 0.36),
                accent: Color(red: 0.72, green: 0.97, blue: 0.76),
                accent2: Color(red: 0.08, green: 0.36, blue: 0.16),
                shadow: .green
            )
        }
    }

    // MARK: - Deck

    var stackedDeckSection: some View {
        ZStack(alignment: .top) {
            stackCard(for: backMode, position: .back)
            stackCard(for: middleMode, position: .middle)
            stackCard(for: frontMode, position: .front)
        }
        .frame(height: deckHeight)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: cardOrder)
        .animation(.spring(response: 0.36, dampingFraction: 0.88), value: inlineState)
        .animation(.spring(response: 0.36, dampingFraction: 0.88), value: remainingSeconds)
    }

    @ViewBuilder
    func stackCard(for mode: FocusMode, position: StackPosition) -> some View {
        switch position {
        case .back:
            collapsedBandCard(for: mode)
                .offset(y: 0)
                .scaleEffect(0.986)
                .opacity(0.74)
                .zIndex(10)

        case .middle:
            collapsedBandCard(for: mode)
                .offset(y: 26)
                .scaleEffect(0.993)
                .opacity(0.90)
                .zIndex(20)

        case .front:
            expandedCard(for: mode)
                .offset(y: 50)
                .zIndex(30)
        }
    }

    // MARK: - Collapsed Cards

    func collapsedBandCard(for mode: FocusMode) -> some View {
        let theme = theme(for: mode)

        return Button {
            syncCardOrder(with: mode)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.smallTitle)
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.74))

                    Text(theme.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 44, height: 44)

                    Circle()
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                        .frame(width: 44, height: 44)

                    Image(systemName: theme.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.90))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .frame(height: 78)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black.opacity(0.86))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        theme.edge.opacity(0.56),
                                        Color.clear,
                                        theme.accent2.opacity(0.16)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expanded Cards

    @ViewBuilder
    func expandedCard(for mode: FocusMode) -> some View {
        switch mode {
        case .personal:
            personalExpandedCard
        case .crew:
            crewExpandedCard
        case .friend:
            friendExpandedCard
        }
    }

    var personalExpandedCard: some View {
        let theme = theme(for: .personal)
        let isLive = activeMode == .personal && inlineState != .idle

        return VStack(alignment: .leading, spacing: 0) {
            topArea(theme: theme)

            Spacer(minLength: 10)

            if isLive {
                liveTimerHero(theme: theme)
            } else {
                idleHero(
                    title: "\(personalMinutes) dk",
                    subtitle: modeCaption(for: personalMinutes),
                    theme: theme
                )
            }

            Spacer(minLength: 10)

            HStack(spacing: 12) {
                durationChip(minutes: 15, selectedMinutes: $personalMinutes, accent: theme.accent)
                durationChip(minutes: 25, selectedMinutes: $personalMinutes, accent: theme.accent)
                durationChip(minutes: 45, selectedMinutes: $personalMinutes, accent: theme.accent)
            }

            Spacer(minLength: 10)

            HStack(spacing: 12) {
                compactInfoCard(
                    title: "KISA",
                    value: "15",
                    suffix: "dk",
                    caption: "hızlı başlangıç",
                    accent: theme.accent
                )
                compactInfoCard(
                    title: "DERİN",
                    value: "45",
                    suffix: "dk",
                    caption: "uzun odak",
                    accent: theme.accent
                )
            }

            Spacer(minLength: 10)

            infoLine(
                icon: "sparkles",
                text: isLive ? stateTextForInlineSession() : "Tek dokunuşla başlat",
                accent: theme.accent
            )

            Spacer(minLength: 10)

            if isLive {
                liveActionRow(mode: .personal, accent: theme.accent)
            } else {
                Button {
                    startInlineFocus(
                        mode: .personal,
                        minutes: personalMinutes,
                        title: "Kişisel Focus",
                        subtitle: modeCaption(for: personalMinutes)
                    )
                } label: {
                    bottomCTA(
                        title: "Odak Başlat",
                        icon: "timer",
                        colors: [
                            Color(red: 0.23, green: 0.52, blue: 0.98),
                            Color(red: 0.47, green: 0.82, blue: 0.98)
                        ]
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, minHeight: frontCardHeight, alignment: .topLeading)
        .background(premiumExpandedBackground(theme: theme))
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    var crewExpandedCard: some View {
        let theme = theme(for: .crew)
        let isLive = activeMode == .crew && inlineState != .idle

        return VStack(alignment: .leading, spacing: 0) {
            topArea(theme: theme)

            Spacer(minLength: 10)

            if isLive {
                liveTimerHero(theme: theme)
            } else {
                premiumInfoPanel(
                    title: "DURUM",
                    headline: selectedCrew.map { displayName(for: $0) ?? "Crew seç" } ?? "Crew seç",
                    emphasis: "\(crewMinutes) dk",
                    body: "Crew ile ortak focus başlatabilir, görev başlığını opsiyonel girebilirsin.",
                    accent: theme.accent
                )

                Spacer(minLength: 10)

                horizontalSelectionStrip(
                    items: userScopedCrews.map {
                        SelectionItem(id: idString($0.id), title: displayName(for: $0) ?? "Crew")
                    },
                    selectedID: $selectedCrewID,
                    accent: theme.accent
                )

                Spacer(minLength: 10)

                premiumInputPanel(
                    eyebrow: "GÖREV",
                    title: displayName(for: selectedCrew) ?? "Crew seç",
                    subtitle: "İstersen görev başlığı gir",
                    text: $crewTaskTitle,
                    placeholder: "Örn. Sprint planı / Matematik tekrar",
                    accent: theme.accent
                )

                Spacer(minLength: 10)

                HStack(spacing: 12) {
                    durationChip(minutes: 15, selectedMinutes: $crewMinutes, accent: theme.accent)
                    durationChip(minutes: 25, selectedMinutes: $crewMinutes, accent: theme.accent)
                    durationChip(minutes: 45, selectedMinutes: $crewMinutes, accent: theme.accent)
                }

                Spacer(minLength: 10)

                HStack(spacing: 12) {
                    compactInfoCard(
                        title: "SÜRE",
                        value: "\(crewMinutes)",
                        suffix: "dk",
                        caption: "ortak odak",
                        accent: theme.accent
                    )

                    compactInfoCard(
                        title: "CREW",
                        value: selectedCrew == nil ? "Seç" : "Hazır",
                        suffix: "",
                        caption: displayName(for: selectedCrew) ?? "crew bekleniyor",
                        accent: theme.accent
                    )
                }

                Spacer(minLength: 10)

                infoLine(
                    icon: "person.3.fill",
                    text: "Crew ile birlikte başlat",
                    accent: theme.accent
                )

                Spacer(minLength: 10)

                Button {
                    let trimmed = crewTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    let crewName = displayName(for: selectedCrew)
                    let resolvedTitle = trimmed.isEmpty ? "\(crewName ?? "Crew") Focus" : trimmed
                    let resolvedSubtitle = crewName ?? "Crew seansı"

                    startInlineFocus(
                        mode: .crew,
                        minutes: crewMinutes,
                        title: resolvedTitle,
                        subtitle: resolvedSubtitle
                    )
                } label: {
                    bottomCTA(
                        title: "Crew Focus Başlat",
                        icon: "person.3.fill",
                        accent: theme.accent
                    )
                }
                .buttonStyle(.plain)
                .disabled(selectedCrew == nil)
                .opacity(selectedCrew == nil ? 0.72 : 1)
            }

            if isLive {
                Spacer(minLength: 10)

                HStack(spacing: 12) {
                    compactInfoCard(
                        title: "KATILIMCI",
                        value: "1",
                        suffix: "",
                        caption: displayName(for: selectedCrew) ?? "aktif ekip",
                        accent: theme.accent
                    )

                    compactInfoCard(
                        title: "GÖREV",
                        value: liveTitle.isEmpty ? "Focus" : liveTitle,
                        suffix: "",
                        caption: "şu an sürüyor",
                        accent: theme.accent
                    )
                }

                Spacer(minLength: 10)

                infoLine(
                    icon: "bolt.horizontal.circle.fill",
                    text: stateTextForInlineSession(),
                    accent: theme.accent
                )

                Spacer(minLength: 10)

                liveActionRow(mode: .crew, accent: theme.accent)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, minHeight: frontCardHeight, alignment: .topLeading)
        .background(premiumExpandedBackground(theme: theme))
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    var friendExpandedCard: some View {
        let theme = theme(for: .friend)
        let isLive = activeMode == .friend && inlineState != .idle

        return VStack(alignment: .leading, spacing: 0) {
            topArea(theme: theme)

            Spacer(minLength: 10)

            if isLive {
                liveTimerHero(theme: theme)
            } else {
                premiumInfoPanel(
                    title: "DURUM",
                    headline: displayName(for: selectedFriend) ?? "Arkadaş seç",
                    emphasis: "\(friendMinutes) dk",
                    body: "Arkadaş seçip birlikte focus başlatabilir, başlık girebilir ya da direkt başlayabilirsin.",
                    accent: theme.accent
                )

                Spacer(minLength: 10)

                horizontalSelectionStrip(
                    items: userScopedFriends.map {
                        SelectionItem(id: idString($0.id), title: displayName(for: $0) ?? "Arkadaş")
                    },
                    selectedID: $selectedFriendID,
                    accent: theme.accent
                )

                Spacer(minLength: 10)

                premiumInputPanel(
                    eyebrow: "HEDEF",
                    title: displayName(for: selectedFriend) ?? "Arkadaş seç",
                    subtitle: "İstersen focus başlığı gir",
                    text: $friendTaskTitle,
                    placeholder: "Örn. Beraber çalışma / Sessiz odak",
                    accent: theme.accent
                )

                Spacer(minLength: 10)

                HStack(spacing: 12) {
                    durationChip(minutes: 15, selectedMinutes: $friendMinutes, accent: theme.accent)
                    durationChip(minutes: 25, selectedMinutes: $friendMinutes, accent: theme.accent)
                    durationChip(minutes: 45, selectedMinutes: $friendMinutes, accent: theme.accent)
                }

                Spacer(minLength: 10)

                HStack(spacing: 12) {
                    compactInfoCard(
                        title: "SÜRE",
                        value: "\(friendMinutes)",
                        suffix: "dk",
                        caption: "eş zamanlı odak",
                        accent: theme.accent
                    )

                    compactInfoCard(
                        title: "ARKADAŞ",
                        value: selectedFriend == nil ? "Seç" : "Hazır",
                        suffix: "",
                        caption: displayName(for: selectedFriend) ?? "arkadaş bekleniyor",
                        accent: theme.accent
                    )
                }

                Spacer(minLength: 10)

                infoLine(
                    icon: "waveform.path.ecg",
                    text: "Arkadaş ile focus başlat",
                    accent: theme.accent
                )

                Spacer(minLength: 10)

                Button {
                    let trimmed = friendTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    let friendName = displayName(for: selectedFriend)
                    let resolvedTitle = trimmed.isEmpty ? "\(friendName ?? "Arkadaş") ile Focus" : trimmed
                    let resolvedSubtitle = friendName ?? "Arkadaş seansı"

                    startInlineFocus(
                        mode: .friend,
                        minutes: friendMinutes,
                        title: resolvedTitle,
                        subtitle: resolvedSubtitle
                    )
                } label: {
                    bottomCTA(
                        title: "Arkadaş ile Başlat",
                        icon: "person.2.fill",
                        accent: theme.accent
                    )
                }
                .buttonStyle(.plain)
                .disabled(selectedFriend == nil)
                .opacity(selectedFriend == nil ? 0.72 : 1)
            }

            if isLive {
                Spacer(minLength: 10)

                HStack(spacing: 12) {
                    compactInfoCard(
                        title: "DURUM",
                        value: "Canlı",
                        suffix: "",
                        caption: displayName(for: selectedFriend) ?? "arkadaş focus",
                        accent: theme.accent
                    )

                    compactInfoCard(
                        title: "GÖREV",
                        value: liveTitle.isEmpty ? "Focus" : liveTitle,
                        suffix: "",
                        caption: "şu an sürüyor",
                        accent: theme.accent
                    )
                }

                Spacer(minLength: 10)

                infoLine(
                    icon: "waveform.path.ecg",
                    text: stateTextForInlineSession(),
                    accent: theme.accent
                )

                Spacer(minLength: 10)

                liveActionRow(mode: .friend, accent: theme.accent)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, minHeight: frontCardHeight, alignment: .topLeading)
        .background(premiumExpandedBackground(theme: theme))
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    // MARK: - Persistence

    func persistInlineSession() {
        persistedModeRaw = activeMode?.rawValue ?? ""
        persistedStateRaw = inlineState.rawValue
        persistedEndDate = endDate?.timeIntervalSince1970 ?? 0
        persistedTotalSeconds = totalSeconds
        persistedTitle = liveTitle
        persistedSubtitle = liveSubtitle
    }

    func clearPersistedInlineSession() {
        persistedModeRaw = ""
        persistedStateRaw = InlineSessionState.idle.rawValue
        persistedEndDate = 0
        persistedTotalSeconds = 0
        persistedTitle = ""
        persistedSubtitle = ""
    }

    func restoreInlineSession() {
        guard let mode = FocusMode(rawValue: persistedModeRaw) else { return }
        guard let state = InlineSessionState(rawValue: persistedStateRaw) else { return }

        activeMode = mode
        inlineState = state
        totalSeconds = max(persistedTotalSeconds, 1)
        liveTitle = persistedTitle
        liveSubtitle = persistedSubtitle

        if persistedEndDate > 0 {
            let restoredEndDate = Date(timeIntervalSince1970: persistedEndDate)
            let remain = max(0, Int(restoredEndDate.timeIntervalSinceNow.rounded(.down)))

            if state == .running && remain > 0 {
                remainingSeconds = remain
                endDate = restoredEndDate
            } else if state == .running && remain <= 0 {
                remainingSeconds = 0
                inlineState = .completed
                endDate = nil
                persistInlineSession()
            } else {
                remainingSeconds = max(0, totalSeconds)
                endDate = nil
            }
        } else {
            remainingSeconds = max(0, totalSeconds)
            endDate = nil
        }

        if let mode = activeMode {
            syncCardOrder(with: mode)
        }
    }

    // MARK: - Timer Logic

    func startInlineFocus(mode: FocusMode, minutes: Int, title: String, subtitle: String) {
        syncCardOrder(with: mode)

        totalSeconds = minutes * 60
        remainingSeconds = totalSeconds
        endDate = Date().addingTimeInterval(TimeInterval(totalSeconds))
        activeMode = mode
        liveTitle = title
        liveSubtitle = subtitle
        inlineState = .running
        persistInlineSession()
    }

    func tickTimer() {
        guard inlineState == .running else { return }
        guard let endDate else { return }

        let newRemaining = max(0, Int(endDate.timeIntervalSinceNow.rounded(.down)))
        remainingSeconds = newRemaining

        if newRemaining <= 0 {
            inlineState = .completed
            self.endDate = nil
        }

        persistInlineSession()
    }

    func togglePauseResume() {
        switch inlineState {
        case .running:
            inlineState = .paused
            endDate = nil

        case .paused:
            inlineState = .running
            endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))

        case .idle, .completed:
            break
        }

        persistInlineSession()
    }

    func resetInlineFocus(for mode: FocusMode) {
        guard activeMode == mode else { return }

        inlineState = .idle
        activeMode = nil
        endDate = nil
        remainingSeconds = totalSeconds
        liveTitle = ""
        liveSubtitle = ""
        clearPersistedInlineSession()
    }

    func progressValue(for mode: FocusMode) -> Double {
        guard activeMode == mode else { return 0.72 }
        guard totalSeconds > 0 else { return 0.0 }

        let elapsed = totalSeconds - remainingSeconds
        return max(0.02, min(1.0, Double(elapsed) / Double(totalSeconds)))
    }

    func timeText(_ value: Int) -> String {
        let m = value / 60
        let s = value % 60
        return String(format: "%02d:%02d", m, s)
    }

    func modeCaption(for minutes: Int) -> String {
        switch minutes {
        case 15: return "Hızlı odak başlangıcı"
        case 25: return "Derin odak başlangıcı"
        case 45: return "Uzun odak modu"
        default: return "Odak seansı"
        }
    }

    func stateTextForInlineSession() -> String {
        switch inlineState {
        case .idle:
            return "Hazır"
        case .running:
            return "Odak akışı sürüyor"
        case .paused:
            return "Duraklatıldı"
        case .completed:
            return "Seans tamamlandı"
        }
    }

    // MARK: - Visual Components

    func premiumExpandedBackground(theme: FocusTheme) -> some View {
        RoundedRectangle(cornerRadius: 34, style: .continuous)
            .fill(Color(red: 0.05, green: 0.06, blue: 0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.edge.opacity(0.90),
                                Color(red: 0.07, green: 0.09, blue: 0.16).opacity(0.96),
                                theme.accent2.opacity(0.56)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.clear,
                                Color.black.opacity(0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: theme.edge.opacity(0.14), radius: 24, y: 10)
    }

    func topArea(theme: FocusTheme) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(theme.smallTitle)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))

                Text(theme.title)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(theme.subtitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 78, height: 78)

                Circle()
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    .frame(width: 78, height: 78)

                Image(systemName: theme.icon)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
    }

    func idleHero(title: String, subtitle: String, theme: FocusTheme) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hazır Mod")
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.64))

                Text(title)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.70))
            }

            Spacer()

            premiumProgressRing(progress: 0.72, accent: theme.accent)
                .frame(width: 92, height: 92)
        }
    }

    func liveTimerHero(theme: FocusTheme) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(inlineState == .running ? "Aktif Oturum" : inlineState == .paused ? "Duraklatıldı" : "Tamamlandı")
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.64))

                Text(timeText(remainingSeconds))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(liveTitle.isEmpty ? "Focus" : liveTitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(2)
            }

            Spacer()

            premiumProgressRing(progress: progressValue(for: activeMode ?? .personal), accent: theme.accent)
                .frame(width: 92, height: 92)
        }
    }

    func premiumProgressRing(progress: Double, accent: Color) -> some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 12)

            Circle()
                .trim(from: 0.06, to: max(0.12, progress))
                .stroke(
                    AngularGradient(
                        colors: [
                            accent.opacity(0.35),
                            accent,
                            .white.opacity(0.92),
                            accent
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accent.opacity(0.18),
                            .clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 32
                    )
                )

            VStack(spacing: 1) {
                Text("\(Int(max(1, progress * 100)))%")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(inlineState == .running ? "aktif" : inlineState == .paused ? "bekliyor" : "hazır")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.66))
            }
        }
    }

    func premiumInfoPanel(
        title: String,
        headline: String,
        emphasis: String,
        body: String,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))

            Text(headline)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(emphasis)
                .font(.system(size: 26, weight: .medium, design: .rounded))
                .foregroundStyle(accent)

            Text(body)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(3)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    func compactInfoCard(
        title: String,
        value: String,
        suffix: String,
        caption: String,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if !suffix.isEmpty {
                    Text(suffix)
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                }
            }

            Text(caption)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }

    func premiumInputPanel(
        eyebrow: String,
        title: String,
        subtitle: String,
        text: Binding<String>,
        placeholder: String,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.58))

            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(subtitle)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.66))
                .lineLimit(2)

            TextField(placeholder, text: text)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(accent.opacity(0.14), lineWidth: 1)
                        )
                )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }

    func durationChip(minutes: Int, selectedMinutes: Binding<Int>, accent: Color) -> some View {
        let selected = selectedMinutes.wrappedValue == minutes

        return Button {
            withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                selectedMinutes.wrappedValue = minutes
            }
        } label: {
            Text("\(minutes) dk")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(selected ? 0.98 : 0.88))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(selected ? Color.white.opacity(0.12) : Color.white.opacity(0.06))
                        .overlay(
                            Capsule()
                                .stroke(
                                    selected ? accent.opacity(0.24) : Color.white.opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
    }

    func horizontalSelectionStrip(
        items: [SelectionItem],
        selectedID: Binding<String?>,
        accent: Color
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(items) { item in
                    let selected = selectedID.wrappedValue == item.id

                    Button {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                            selectedID.wrappedValue = item.id
                        }
                    } label: {
                        Text(item.title)
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(selected ? 0.98 : 0.82))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(selected ? Color.white.opacity(0.12) : Color.white.opacity(0.06))
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                selected ? accent.opacity(0.24) : Color.white.opacity(0.08),
                                                lineWidth: 1
                                            )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    func infoLine(icon: String, text: String, accent: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.88))

            Text(text)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.84))
        }
    }

    func bottomCTA(title: String, icon: String, colors: [Color]) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))

            Text(title)
                .font(.system(size: 15.5, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: colors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
        .shadow(color: colors.first?.opacity(0.18) ?? .clear, radius: 10, y: 6)
    }

    func bottomCTA(title: String, icon: String, accent: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))

            Text(title)
                .font(.system(size: 15.5, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.58),
                            accent.opacity(0.34)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    func liveActionRow(mode: FocusMode, accent: Color) -> some View {
        HStack(spacing: 12) {
            Button {
                togglePauseResume()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: inlineState == .running ? "pause.fill" : "play.fill")
                    Text(inlineState == .running ? "Duraklat" : "Devam Et")
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.black.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(accent.opacity(0.20), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            Button {
                resetInlineFocus(for: mode)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Sıfırla")
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.black.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
}
