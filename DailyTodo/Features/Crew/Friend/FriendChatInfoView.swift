//
//  FriendChatInfoView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 15.03.2026.
//

import SwiftUI
import SwiftData

private enum FriendChatInfoArenaPalette {
    static let backgroundTop = Color(arenaHex: "#05060D")
    static let backgroundMid = Color(arenaHex: "#070713")
    static let backgroundBottom = Color(arenaHex: "#07040C")

    static let blue = Color(arenaHex: "#1593FF")
    static let cyan = Color(arenaHex: "#2DD4FF")
    static let purple = Color(arenaHex: "#7C3AED")
    static let coral = Color(arenaHex: "#FF5A44")
    static let gold = Color(arenaHex: "#FBBF24")
    static let green = Color(arenaHex: "#A3E635")
    static let surface = Color(arenaHex: "#101118")

    static var appGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(arenaHex: "#1E6BFF"),
                Color(arenaHex: "#7C3AED")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct FriendChatInfoView: View {
    @Bindable var friend: Friend

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @EnvironmentObject var friendStore: FriendStore
    @EnvironmentObject var session: SessionStore
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \EventItem.startMinute, order: .forward)
    private var allEvents: [EventItem]

    @State private var showSharedWeek = false
    @State private var showAvatarZoom = false
    @State private var isSavingShare = false
    @State private var shareMyWeek = false
    @State private var infoMessage: String?
    @State private var isLoadingShareState = true

    private var friendshipID: UUID? {
        friend.backendFriendshipID
    }

    private var friendUserID: UUID? {
        friend.backendUserID
    }

    private var friendAccent: Color {
        Color(arenaHex: friend.colorHex)
    }

    private var canOpenSharedWeek: Bool {
        guard let friendshipID else { return false }
        return friendStore.incomingWeekSharesByFriendship[friendshipID]?.is_enabled == true
    }

    private var friendPresence: FriendPresenceDTO? {
        guard let friendUserID else { return nil }
        return friendStore.presenceByUserID[friendUserID]
    }

    private var isFriendReallyOnline: Bool {
        FriendPresenceEngine.isOnline(friendPresence)
    }

    private var friendStatusText: String {
        FriendPresenceEngine.statusText(
            presence: friendPresence,
            locale: locale
        )
    }

    private var friendSummary: FriendChatThreadSummary? {
        guard let friendshipID else { return nil }

        return friendStore.friendChatSummaries.first {
            $0.friendshipID == friendshipID
        }
    }

    private var isMutedFromBackend: Bool {
        friendSummary?.isMuted ?? false
    }

    private var currentUserEvents: [EventItem] {
        guard let currentUserID = session.currentUser?.id.uuidString else { return [] }

        return allEvents.filter {
            $0.ownerUserID == currentUserID
        }
    }

    var body: some View {
        ZStack {
            background

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    Color.clear.frame(height: 4)

                    topHeader

                    profileCard

                    actionsCard

                    settingsCard

                    Color.clear.frame(height: 30)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await loadInitialShareState()
        }
        .onChange(of: allEvents.count) { _, _ in
            guard shareMyWeek else { return }
            guard !isSavingShare, !isLoadingShareState else { return }
            guard
                let friendshipID,
                let currentUserID = session.currentUser?.id,
                let friendUserID
            else { return }

            Task {
                await friendStore.setWeekShareEnabled(
                    friendshipID: friendshipID,
                    currentUserID: currentUserID,
                    friendUserID: friendUserID,
                    isEnabled: true,
                    events: currentUserEvents
                )

                await MainActor.run {
                    shareMyWeek =
                        friendStore.outgoingWeekSharesByFriendship[friendshipID]?.is_enabled == true
                }
            }
        }
        .sheet(isPresented: $showSharedWeek) {
            NavigationStack {
                SharedWeekView(friend: friend)
                    .environmentObject(friendStore)
                    .environmentObject(session)
            }
        }
        .alert(
            "friend_info_alert_title",
            isPresented: Binding(
                get: { infoMessage != nil },
                set: { if !$0 { infoMessage = nil } }
            )
        ) {
            Button("focus_ok", role: .cancel) { }
        } message: {
            Text(infoMessage ?? "")
        }
    }
}

// MARK: - UI

private extension FriendChatInfoView {
    var background: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    FriendChatInfoArenaPalette.backgroundTop,
                    FriendChatInfoArenaPalette.backgroundMid,
                    FriendChatInfoArenaPalette.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(friendAccent.opacity(0.16))
                .frame(width: 300, height: 300)
                .blur(radius: 105)
                .offset(x: -170, y: 480)

            Circle()
                .fill(FriendChatInfoArenaPalette.blue.opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 96)
                .offset(x: 165, y: -245)

            Circle()
                .fill(FriendChatInfoArenaPalette.purple.opacity(0.14))
                .frame(width: 300, height: 300)
                .blur(radius: 110)
                .offset(x: 180, y: 260)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.16),
                    Color.clear,
                    Color.black.opacity(0.42)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    var topHeader: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left").accessibilityLabel(tr("a11y_back"))
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(circleButtonBackground)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 3) {
                Text("FRIEND INFO")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(FriendChatInfoArenaPalette.cyan)

                Text("friend_info_title")
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(.white)
            }

            Spacer()

            Color.clear
                .frame(width: 46, height: 46)
        }
    }

    var profileCard: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                Button {
                    if RemoteAvatarStore.shared.image(for: friend.backendUserID) != nil {
                        showAvatarZoom = true
                    }
                } label: {
                    UserAvatarView(
                        userID: friend.backendUserID,
                        name: friend.name,
                        tint: friendAccent,
                        size: 92
                    )
                    .shadow(color: friendAccent.opacity(0.20), radius: 18, y: 8)
                }
                .buttonStyle(.plain)

                Circle()
                    .fill(isFriendReallyOnline ? FriendChatInfoArenaPalette.green : Color.gray.opacity(0.65))
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(FriendChatInfoArenaPalette.surface, lineWidth: 3)
                    )
                    .offset(x: -4, y: -4)
            }
            .fullScreenCover(isPresented: $showAvatarZoom) {
                if let image = RemoteAvatarStore.shared.image(for: friend.backendUserID) {
                    AvatarZoomViewer(image: image, name: friend.name)
                }
            }

            VStack(spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(friend.name)
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                    Text("friend")
                        .font(.system(size: 25, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(FriendChatInfoArenaPalette.cyan)
                }

                HStack(spacing: 8) {
                    Circle()
                        .fill(isFriendReallyOnline ? FriendChatInfoArenaPalette.green : Color.gray.opacity(0.60))
                        .frame(width: 8, height: 8)

                    Text(friendStatusText)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(isFriendReallyOnline ? FriendChatInfoArenaPalette.green : .white.opacity(0.48))
                }

                Text(friend.subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.50))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.top, 2)
            }

            HStack(spacing: 9) {
                profilePill(
                    text: isFriendReallyOnline ? "ONLINE" : "OFFLINE",
                    tint: isFriendReallyOnline ? FriendChatInfoArenaPalette.green : Color.gray
                )

                profilePill(
                    text: isMutedFromBackend ? "MUTED" : "ACTIVE",
                    tint: isMutedFromBackend ? FriendChatInfoArenaPalette.coral : FriendChatInfoArenaPalette.blue
                )

                profilePill(
                    text: canOpenSharedWeek ? "WEEK" : "SOCIAL",
                    tint: canOpenSharedWeek ? FriendChatInfoArenaPalette.gold : friendAccent
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            friendAccent.opacity(0.13),
                            FriendChatInfoArenaPalette.purple.opacity(0.11),
                            FriendChatInfoArenaPalette.surface.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(friendAccent.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.24), radius: 20, y: 12)
        )
    }

    var actionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                eyebrow: "SOCIAL ACTIONS",
                title: tr("bctd_quick_w"),
                italic: tr("bctd_actions_w")
            )

            VStack(spacing: 10) {
                Button {
                    if canOpenSharedWeek {
                        showSharedWeek = true
                    } else {
                        infoMessage = localizedFriendNotSharedWeek(friend.name)
                    }
                } label: {
                    actionRow(
                        title: String(localized: "friend_info_open_shared_week"),
                        subtitle: canOpenSharedWeek
                        ? String(localized: "friend_info_see_weekly_plan_together")
                        : String(localized: "friend_info_waiting_for_share"),
                        icon: "calendar",
                        tint: canOpenSharedWeek ? FriendChatInfoArenaPalette.green : FriendChatInfoArenaPalette.cyan
                    )
                }
                .buttonStyle(.plain)

                actionRow(
                    title: String(localized: "friend_info_start_focus_together"),
                    subtitle: String(localized: "friend_info_launch_shared_focus"),
                    icon: "timer",
                    tint: FriendChatInfoArenaPalette.gold
                )
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    var settingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                eyebrow: "CHAT SETTINGS",
                title: "Sohbet",
                italic: tr("fci_settings_w")
            )

            VStack(spacing: 10) {
                shareWeekToggleRow

                muteToggleRow

                clearChatRow
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    var shareWeekToggleRow: some View {
        HStack(spacing: 13) {
            iconBox(
                icon: "calendar.badge.plus",
                tint: FriendChatInfoArenaPalette.green
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("friend_info_share_my_week")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)

                Text("friend_info_let_friend_view_week")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.44))
                    .lineLimit(2)
            }

            Spacer()

            if isSavingShare || isLoadingShareState {
                ProgressView()
                    .tint(FriendChatInfoArenaPalette.green)
            } else {
                Toggle("", isOn: Binding(
                    get: { shareMyWeek },
                    set: { newValue in
                        updateShareMyWeek(newValue)
                    }
                ))
                .labelsHidden()
                .tint(FriendChatInfoArenaPalette.green)
            }
        }
        .padding(14)
        .background(detailSurface(cornerRadius: 22, tint: FriendChatInfoArenaPalette.green))
    }

    var muteToggleRow: some View {
        HStack(spacing: 13) {
            iconBox(
                icon: isMutedFromBackend ? "bell.slash.fill" : "bell.fill",
                tint: isMutedFromBackend ? FriendChatInfoArenaPalette.coral : FriendChatInfoArenaPalette.blue
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("friend_info_mute_notifications")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)

                Text("friend_info_stop_alerts_from_friend")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.44))
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isMutedFromBackend },
                set: { newValue in
                    guard
                        let friendshipID,
                        let currentUserID = session.currentUser?.id
                    else { return }

                    Task {
                        await friendStore.setFriendChatMuted(
                            friendshipID: friendshipID,
                            currentUserID: currentUserID,
                            isMuted: newValue
                        )
                    }
                }
            ))
            .labelsHidden()
            .tint(FriendChatInfoArenaPalette.blue)
        }
        .padding(14)
        .background(
            detailSurface(
                cornerRadius: 22,
                tint: isMutedFromBackend ? FriendChatInfoArenaPalette.coral : FriendChatInfoArenaPalette.blue
            )
        )
    }

    var clearChatRow: some View {
        Button(role: .destructive) {
            infoMessage = !appLanguageIsEnglish()
            ? tr("fci_clear_soon")
            : "Clear chat will be added soon."
        } label: {
            HStack(spacing: 13) {
                iconBox(
                    icon: "trash.fill",
                    tint: FriendChatInfoArenaPalette.coral
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("friend_info_clear_chat_later")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(FriendChatInfoArenaPalette.coral)

                    Text(!appLanguageIsEnglish()
                         ? tr("fci_not_active")
                         : "This action is not active yet.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.44))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white.opacity(0.30))
            }
            .padding(14)
            .background(detailSurface(cornerRadius: 22, tint: FriendChatInfoArenaPalette.coral))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Components

private extension FriendChatInfoView {
    func sectionTitle(eyebrow: String, title: String, italic: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("— \(eyebrow) —")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2.4)
                .foregroundStyle(.white.opacity(0.34))
                .lineLimit(1)
                .minimumScaleFactor(0.60)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)

                Text(italic)
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(.white)
            }
        }
    }

    func actionRow(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 13) {
            iconBox(icon: icon, tint: tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.44))
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white.opacity(0.30))
        }
        .padding(14)
        .background(detailSurface(cornerRadius: 22, tint: tint))
    }

    func iconBox(icon: String, tint: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 17, weight: .black))
            .foregroundStyle(tint)
            .frame(width: 42, height: 42)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(tint.opacity(0.13))
            )
    }

    func profilePill(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.20), lineWidth: 1)
                    )
            )
            .lineLimit(1)
    }

    var circleButtonBackground: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.090),
                        Color.white.opacity(0.055)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.11), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.24), radius: 12, y: 6)
    }

    func detailSurface(cornerRadius: CGFloat, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.055),
                        FriendChatInfoArenaPalette.purple.opacity(0.040),
                        Color.white.opacity(0.038)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tint.opacity(0.13), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 14, y: 8)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        FriendChatInfoArenaPalette.blue.opacity(0.035),
                        FriendChatInfoArenaPalette.purple.opacity(0.045),
                        Color.white.opacity(0.040)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 16, y: 9)
    }
}

// MARK: - Logic

private extension FriendChatInfoView {
    @MainActor
    func loadInitialShareState() async {
        guard
            let friendshipID,
            let currentUserID = session.currentUser?.id,
            let friendUserID
        else { return }

        isLoadingShareState = true

        await friendStore.loadWeekShareStatus(
            friendshipID: friendshipID,
            currentUserID: currentUserID,
            friendUserID: friendUserID
        )

        let initialShareState =
            friendStore.outgoingWeekSharesByFriendship[friendshipID]?.is_enabled == true

        shareMyWeek = initialShareState
        isLoadingShareState = false

        if initialShareState {
            await friendStore.setWeekShareEnabled(
                friendshipID: friendshipID,
                currentUserID: currentUserID,
                friendUserID: friendUserID,
                isEnabled: true,
                events: currentUserEvents
            )

            shareMyWeek =
                friendStore.outgoingWeekSharesByFriendship[friendshipID]?.is_enabled == true
        }
    }

    func updateShareMyWeek(_ newValue: Bool) {
        guard
            let friendshipID,
            let currentUserID = session.currentUser?.id,
            let friendUserID
        else { return }

        if isSavingShare || isLoadingShareState { return }

        shareMyWeek = newValue
        isSavingShare = true

        Task {
            await friendStore.setWeekShareEnabled(
                friendshipID: friendshipID,
                currentUserID: currentUserID,
                friendUserID: friendUserID,
                isEnabled: newValue,
                events: currentUserEvents
            )

            await MainActor.run {
                shareMyWeek =
                    friendStore.outgoingWeekSharesByFriendship[friendshipID]?.is_enabled == true
                isSavingShare = false
            }
        }
    }

    func localizedFriendNotSharedWeek(_ name: String) -> String {
        if !appLanguageIsEnglish() {
            return "\(name) henüz haftasını seninle paylaşmadı."
        } else {
            return "\(name) has not shared their week with you yet."
        }
    }
}

// MARK: - Color Hex
