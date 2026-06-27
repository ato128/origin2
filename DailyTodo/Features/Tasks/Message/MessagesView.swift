//
//  MessagesView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 15.03.2026.
//

import SwiftUI
import SwiftData

struct MessagesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var friendStore: FriendStore
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var session: SessionStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var searchText = ""
    @State private var didLoadMessagesHubData = false
    @State private var rebuildSummariesTask: Task<Void, Never>?
    @State private var backendConversations: [ChatBackendConversationDTO] = []
    @State private var backendLiveRefreshTask: Task<Void, Never>?
    @State private var isRefreshingBackendConversations = false

    @Query(sort: \Friend.createdAt, order: .reverse)
    private var friends: [Friend]

    private let replyMarker = "[[reply]]"
    private let bodyMarker = "[[body]]"

    private var currentUserID: UUID? {
        session.currentUser?.id
    }

    private var backendFriends: [Friend] {
        guard let currentUserID else { return [] }

        return friends.filter {
            $0.ownerUserID == currentUserID.uuidString && $0.backendFriendshipID != nil
        }
    }

    private var backendCrews: [WeekCrewItem] {
        crewStore.crews.map {
            WeekCrewItem(
                id: $0.id,
                name: $0.name,
                icon: $0.icon,
                colorHex: $0.color_hex
            )
        }
    }

    private var onlineItems: [MessagesHubItem] {
        Array(
            allConversationItems
                .filter { $0.isOnline }
                .sorted { a, b in
                    (a.time ?? .distantPast) > (b.time ?? .distantPast)
                }
                .prefix(8)
        )
    }

    private var allConversationItems: [MessagesHubItem] {
        let friendItems: [MessagesHubItem] = backendFriends.compactMap { friend in
            guard let friendshipID = friend.backendFriendshipID else {
                return nil
            }

            let backendConversation = backendConversation(for: friend)

            if backendConversation?.isArchived == true {
                return nil
            }

            let title = friend.name
            let isTyping = friendStore.typingStatusByFriendship[friendshipID] == true

            let backendLastText = backendConversation?.lastMessageText?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let preview: String

            if isTyping {
                preview = tr("mv_typing")
            } else if let backendLastText, !backendLastText.isEmpty {
                preview = cleanedPreview(backendLastText)
            } else {
                preview = friend.subtitle.isEmpty ? tr("mv_no_messages") : friend.subtitle
            }

            let lastDate = backendDate(backendConversation?.lastMessageAt)
            let unread = backendConversation?.unreadCount ?? 0

            return MessagesHubItem(
                id: "friend-\(friendshipID.uuidString)",
                kind: .friend,
                payload: .friend(friend),
                title: title,
                shortTitle: firstWord(title),
                preview: preview,
                time: lastDate,
                unreadCount: unread,
                avatarText: initials(for: title),
                tint: hexColor(friend.colorHex),
                isOnline: isFriendOnline(friend),
                showsPresence: true,
                isPinned: backendConversation?.isPinned ?? false,
                isMuted: backendConversation?.isMuted ?? false
            )
        }

        let crewItems: [MessagesHubItem] = backendCrews.compactMap { crew -> MessagesHubItem? in
            let backendConversation = backendConversation(for: crew)

            if backendConversation?.isArchived == true {
                return nil
            }

            let backendLastText = backendConversation?.lastMessageText?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let preview: String

            if let backendLastText, !backendLastText.isEmpty {
                preview = cleanedPreview(backendLastText)
            } else {
                preview = "Crew conversation"
            }

            let lastDate = backendDate(backendConversation?.lastMessageAt)
            let unread = backendConversation?.unreadCount ?? 0

            return MessagesHubItem(
                id: "crew-\(crew.id.uuidString)",
                kind: .crew,
                payload: .crew(crew),
                title: crew.name,
                shortTitle: crew.name,
                preview: preview,
                time: lastDate,
                unreadCount: unread,
                avatarText: crew.icon,
                tint: tintForCrew(crew),
                isOnline: false,
                showsPresence: false,
                isPinned: backendConversation?.isPinned ?? false,
                isMuted: backendConversation?.isMuted ?? false
            )
        }

        let merged: [MessagesHubItem] = friendItems + crewItems
        return merged.sorted(by: conversationSort)
    }

    private func conversationSort(
        _ lhs: MessagesHubItem,
        _ rhs: MessagesHubItem
    ) -> Bool {
        if lhs.isPinned != rhs.isPinned {
            return lhs.isPinned && !rhs.isPinned
        }

        if lhs.unreadCount > 0 && rhs.unreadCount == 0 {
            return true
        }

        if lhs.unreadCount == 0 && rhs.unreadCount > 0 {
            return false
        }

        let leftDate = lhs.time ?? .distantPast
        let rightDate = rhs.time ?? .distantPast

        if leftDate != rightDate {
            return leftDate > rightDate
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private var filteredConversationItems: [MessagesHubItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return allConversationItems }

        return allConversationItems.filter {
            $0.title.localizedCaseInsensitiveContains(query)
            || $0.preview.localizedCaseInsensitiveContains(query)
        }
    }

    private var unreadTotalCount: Int {
        allConversationItems.reduce(0) { $0 + $1.unreadCount }
    }

    private var activeConversationCount: Int {
        allConversationItems.count
    }

    var body: some View {
        NavigationStack {
            messagesRoot
                .navigationBarBackButtonHidden(true)
                .toolbar(.hidden, for: .navigationBar)
                .task {
                    guard !didLoadMessagesHubData else { return }
                    didLoadMessagesHubData = true
                    await loadMessagesHubData()
                }
                .onAppear {
                    AppBadgeManager.shared.clearBadge()

                    guard didLoadMessagesHubData else {
                        return
                    }

                    Task {
                        await refreshBackendConversations()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }

                    Task {
                        await refreshBackendConversations()
                    }
                }
                
                .onReceive(friendStore.$friendMessagesByFriendship) { _ in
                    scheduleFriendSummaryRebuild()
                }
                .onReceive(friendStore.$typingStatusByFriendship) { _ in
                    scheduleFriendSummaryRebuild()
                }
                .onReceive(NotificationCenter.default.publisher(for: .chatBackendConversationUpdated)) { notification in
                    upsertBackendConversationFromNotification(notification)
                }
                .onReceive(NotificationCenter.default.publisher(for: .chatBackendMessageCreated)) { notification in
                    upsertBackendConversationFromNotification(notification)
                }
                .onReceive(NotificationCenter.default.publisher(for: .chatBackendMessageSeen)) { notification in
                    scheduleBackendConversationRefresh(
                        reason: "message_seen",
                        notification: notification
                    )
                }
                .onDisappear {
                    rebuildSummariesTask?.cancel()
                    rebuildSummariesTask = nil

                    backendLiveRefreshTask?.cancel()
                    backendLiveRefreshTask = nil
                }
        }
    }
}

// MARK: - Main UI

private extension MessagesView {

    var messagesRoot: some View {
        ZStack {
            ArenaBackground(
                primaryGlow: Color(arenaHex: AppArenaPalette.blue),
                secondaryGlow: Color(arenaHex: AppArenaPalette.purple),
                warmGlow: Color(arenaHex: AppArenaPalette.coral),
                intensity: 0.96
            )

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 16) {
                    header
                    searchBar
                    summaryStrip

                    if !onlineItems.isEmpty {
                        onlineSection
                    }

                    conversationsSection

                    Color.clear.frame(height: 42)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
    }

    var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(Color(arenaHex: AppArenaPalette.cyan))
                        .frame(width: 20, height: 1)

                    Text(tr("mv_social_hub_caps"))
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(2.4)
                        .foregroundStyle(Color(arenaHex: AppArenaPalette.cyan))
                }

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(tr("mv_title"))
                        .font(.system(size: 39, weight: .black))
                        .foregroundStyle(.white)

                    Text(tr("mv_title_italic"))
                        .font(.system(size: 36, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(Color(arenaHex: AppArenaPalette.cyan))
                }
                .lineLimit(1)
                .minimumScaleFactor(0.72)

                Text(tr("mv_sub"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark").accessibilityLabel(tr("event_close"))
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(headerCircleBackground)
            }
            .buttonStyle(.plain)
        }
    }

    var searchBar: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(Color(arenaHex: AppArenaPalette.cyan))

            TextField("Sohbet ara...", text: $searchText)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .tint(Color(arenaHex: AppArenaPalette.cyan))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.white.opacity(0.40))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 15)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(arenaHex: AppArenaPalette.blue).opacity(0.060),
                            Color(arenaHex: AppArenaPalette.purple).opacity(0.046),
                            Color.white.opacity(0.038)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.085), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 12, y: 6)
        )
    }

    var summaryStrip: some View {
        HStack(spacing: 10) {
            messageMetricPill(
                value: "\(activeConversationCount)",
                title: tr("mv_chats_caps"),
                tint: Color(arenaHex: AppArenaPalette.blue)
            )

            messageMetricPill(
                value: "\(onlineItems.count)",
                title: tr("mv_online_caps"),
                tint: Color(arenaHex: AppArenaPalette.green)
            )

            messageMetricPill(
                value: "\(unreadTotalCount)",
                title: tr("mv_unread_caps"),
                tint: unreadTotalCount > 0
                ? Color(arenaHex: AppArenaPalette.gold)
                : Color(arenaHex: AppArenaPalette.cyan)
            )
        }
    }

    var onlineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                eyebrow: tr("mv_live_now_caps"),
                title: tr("mv_now"),
                italic: "online",
                tint: Color(arenaHex: AppArenaPalette.green)
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(onlineItems) { item in
                        NavigationLink {
                            destinationView(for: item)
                        } label: {
                            onlineCard(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    var conversationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                eyebrow: tr("mv_all_chats_caps"),
                title: tr("mv_all"),
                italic: "sohbetler",
                tint: Color(arenaHex: AppArenaPalette.cyan)
            )

            if filteredConversationItems.isEmpty {
                emptyState(
                    title: searchText.isEmpty ? tr("mv_no_chats") : tr("mv_no_results"),
                    subtitle: searchText.isEmpty
                    ? tr("mv_empty_sub")
                    : tr("mv_search_retry"),
                    systemImage: "bubble.left.and.bubble.right"
                )
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredConversationItems) { item in
                        NavigationLink {
                            destinationView(for: item)
                        } label: {
                            conversationRow(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Components

private extension MessagesView {

    func sectionTitle(
        eyebrow: String,
        title: String,
        italic: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("— \(eyebrow) —")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(2.2)
                .foregroundStyle(.white.opacity(0.34))

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)

                Text(italic)
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(tint)
            }
        }
    }

    func messageMetricPill(value: String, title: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)

            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.38))
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(0.080))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(0.15), lineWidth: 1)
                )
        )
    }

    func onlineCard(_ item: MessagesHubItem) -> some View {
        VStack(spacing: 9) {
            ZStack(alignment: .bottomTrailing) {
                onlineAvatar(for: item, size: 64)

                Circle()
                    .fill(Color(arenaHex: AppArenaPalette.green))
                    .frame(width: 15, height: 15)
                    .overlay(
                        Circle()
                            .stroke(Color(arenaHex: AppArenaPalette.surface), lineWidth: 3)
                    )
                    .shadow(color: Color(arenaHex: AppArenaPalette.green).opacity(0.34), radius: 8)
            }

            Text(item.shortTitle)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            if item.unreadCount > 0 {
                Text("\(item.unreadCount)")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 7)
                    .frame(height: 20)
                    .background(
                        Capsule()
                            .fill(Color(arenaHex: AppArenaPalette.gold))
                    )
            } else {
                Text(item.kind == .crew ? "CREW" : "LIVE")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(item.kind == .crew ? item.tint : Color(arenaHex: AppArenaPalette.green))
                    .frame(height: 20)
            }
        }
        .frame(width: 82)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            item.tint.opacity(0.075),
                            Color.white.opacity(0.035)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(item.tint.opacity(0.14), lineWidth: 1)
                )
        )
    }

    func conversationRow(_ item: MessagesHubItem) -> some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                rowAvatar(for: item, size: 56)

                if item.showsPresence {
                    Circle()
                        .fill(item.isOnline ? Color(arenaHex: AppArenaPalette.green) : Color.gray.opacity(0.75))
                        .frame(width: 13, height: 13)
                        .overlay(
                            Circle()
                                .stroke(Color(arenaHex: AppArenaPalette.surface), lineWidth: 2.5)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(Color(arenaHex: AppArenaPalette.gold).opacity(0.86))
                    }

                    if item.isMuted {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.white.opacity(0.34))
                    }

                    Spacer(minLength: 4)

                    if let time = item.time {
                        Text(time, style: .time)
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(
                                item.unreadCount > 0
                                ? Color(arenaHex: AppArenaPalette.gold)
                                : .white.opacity(0.38)
                            )
                    }
                }

                HStack(spacing: 6) {
                    if item.kind == .crew {
                        Text("CREW")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(item.tint)
                            .padding(.horizontal, 7)
                            .frame(height: 20)
                            .background(
                                Capsule()
                                    .fill(item.tint.opacity(0.12))
                            )
                    }

                    Text(item.preview)
                        .font(.system(size: 13, weight: item.unreadCount > 0 ? .bold : .semibold))
                        .foregroundStyle(item.unreadCount > 0 ? .white.opacity(0.82) : .white.opacity(0.48))
                        .lineLimit(1)
                }
            }

            VStack(alignment: .trailing, spacing: 8) {
                if item.unreadCount > 0 {
                    unreadBadge(item.unreadCount)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white.opacity(0.24))
                }
            }
            .frame(width: 30)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(rowBackground(item: item))
        .contextMenu {
            contextMenuContent(for: item)
        }
    }

    @ViewBuilder
    func contextMenuContent(for item: MessagesHubItem) -> some View {
        switch item.payload {
        case .friend(let friend):
            let backendConversation = backendConversation(for: friend)

            let isPinned = backendConversation?.isPinned ?? false
            let isMuted = backendConversation?.isMuted ?? false

            Button {
                togglePinFriendChat(friend)
            } label: {
                Label(
                    isPinned ? tr("mv_unpin") : "Sohbeti sabitle",
                    systemImage: isPinned ? "pin.slash" : "pin"
                )
            }

            Button {
                toggleMuteFriendChat(friend)
            } label: {
                Label(
                    isMuted ? tr("mv_unmute") : tr("mv_mute"),
                    systemImage: isMuted ? "bell" : "bell.slash"
                )
            }

            Button(role: .destructive) {
                archiveFriendChat(friend)
            } label: {
                Label(tr("mv_archive"), systemImage: "archivebox")
            }

        case .friendSummary(let summary):
            Button {
                togglePinFriendChat(summary)
            } label: {
                Label(
                    summary.isPinned ? tr("mv_unpin") : "Sohbeti sabitle",
                    systemImage: summary.isPinned ? "pin.slash" : "pin"
                )
            }

            Button {
                toggleMuteFriendChat(summary)
            } label: {
                Label(
                    summary.isMuted ? tr("mv_unmute") : tr("mv_mute"),
                    systemImage: summary.isMuted ? "bell" : "bell.slash"
                )
            }

            Button(role: .destructive) {
                archiveFriendChat(summary)
            } label: {
                Label(tr("mv_archive"), systemImage: "archivebox")
            }

        case .crew(let crew):
            let backendConversation = backendConversation(for: crew)
            let pinned = backendConversation?.isPinned ?? false
            let muted = backendConversation?.isMuted ?? false

            Button {
                togglePinCrewChat(crew)
            } label: {
                Label(
                    pinned ? tr("mv_unpin") : "Sohbeti sabitle",
                    systemImage: pinned ? "pin.slash" : "pin"
                )
            }

            Button {
                toggleMuteCrewChat(crew)
            } label: {
                Label(
                    muted ? tr("mv_unmute") : tr("mv_mute"),
                    systemImage: muted ? "bell" : "bell.slash"
                )
            }

            Button(role: .destructive) {
                archiveCrewChat(crew)
            } label: {
                Label(tr("mv_archive"), systemImage: "archivebox")
            }
        }
    }

    func rowBackground(item: MessagesHubItem) -> some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        item.tint.opacity(item.unreadCount > 0 ? 0.090 : 0.060),
                        Color(arenaHex: AppArenaPalette.purple).opacity(0.035),
                        Color.white.opacity(0.035)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        item.unreadCount > 0
                        ? item.tint.opacity(0.18)
                        : Color.white.opacity(0.075),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.18), radius: 10, y: 5)
    }

    var headerCircleBackground: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.100),
                        Color.black.opacity(0.26),
                        Color.white.opacity(0.050)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.28), radius: 14, y: 7)
    }

    func emptyState(title: String, subtitle: String, systemImage: String) -> some View {
        VStack(spacing: 13) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(Color(arenaHex: AppArenaPalette.cyan))

            Text(title)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.52))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(arenaHex: AppArenaPalette.blue).opacity(0.060),
                            Color.white.opacity(0.035)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.075), lineWidth: 1)
                )
        )
    }
}

// MARK: - Avatars

private extension MessagesView {

    func onlineAvatar(for item: MessagesHubItem, size: CGFloat) -> some View {
        switch item.kind {
        case .friend:
            return AnyView(friendInitialAvatar(item.avatarText, tint: item.tint, size: size))
        case .crew:
            return AnyView(crewIconAvatar(symbol: item.avatarText, tint: item.tint, size: size))
        }
    }

    func rowAvatar(for item: MessagesHubItem, size: CGFloat) -> some View {
        switch item.kind {
        case .friend:
            return AnyView(friendInitialAvatar(item.avatarText, tint: item.tint, size: size))
        case .crew:
            return AnyView(crewIconAvatar(symbol: item.avatarText, tint: item.tint, size: size))
        }
    }

    func friendInitialAvatar(_ initials: String, tint: Color, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.24),
                            Color(arenaHex: AppArenaPalette.purple).opacity(0.15),
                            Color.white.opacity(0.040)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .stroke(tint.opacity(0.26), lineWidth: 1.1)
                )
                .frame(width: size, height: size)

            Text(initials)
                .font(.system(size: size * 0.30, weight: .black))
                .foregroundStyle(.white)
        }
    }

    func crewIconAvatar(symbol: String, tint: Color, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.24),
                            Color(arenaHex: AppArenaPalette.purple).opacity(0.15),
                            Color.white.opacity(0.040)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                        .stroke(tint.opacity(0.24), lineWidth: 1.1)
                )
                .frame(width: size, height: size)

            Image(systemName: symbol)
                .font(.system(size: size * 0.28, weight: .black))
                .foregroundStyle(.white)
        }
    }

    private func unreadBadge(_ count: Int) -> some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(.black)
            .padding(.horizontal, count > 9 ? 7 : 6)
            .frame(height: 24)
            .background(
                Capsule()
                    .fill(Color(arenaHex: AppArenaPalette.gold))
            )
    }
}

// MARK: - Data Loading

private extension MessagesView {
    
    
    func sortedBackendConversations(
        _ conversations: [ChatBackendConversationDTO]
    ) -> [ChatBackendConversationDTO] {
        conversations.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }

            if lhs.unreadCount > 0 && rhs.unreadCount == 0 {
                return true
            }

            if lhs.unreadCount == 0 && rhs.unreadCount > 0 {
                return false
            }

            let leftDate = lhs.lastMessageDate ?? lhs.updatedDate ?? .distantPast
            let rightDate = rhs.lastMessageDate ?? rhs.updatedDate ?? .distantPast

            if leftDate != rightDate {
                return leftDate > rightDate
            }

            return (lhs.title ?? "").localizedCaseInsensitiveCompare(rhs.title ?? "") == .orderedAscending
        }
    }

    func loadCachedBackendConversations() {
        guard let currentUserID else { return }

        do {
            let descriptor = FetchDescriptor<ChatCachedConversation>(
                sortBy: [
                    SortDescriptor(\ChatCachedConversation.cachedAt, order: .reverse)
                ]
            )

            let cached = try modelContext.fetch(descriptor)
                .filter { $0.ownerUserID == currentUserID }

            let conversations = cached.map { $0.toDTO() }

            guard !conversations.isEmpty else {
                Log.debug("⚪️ MESSAGES HUB CONVERSATION CACHE EMPTY")
                return
            }

            backendConversations = sortedBackendConversations(conversations)

            Log.debug("🟢 MESSAGES HUB CONVERSATION CACHE LOADED:", conversations.count)
        } catch {
            Log.debug("❌ MESSAGES HUB CONVERSATION CACHE LOAD ERROR:", error.localizedDescription)
        }
    }

    func upsertCachedBackendConversation(_ conversation: ChatBackendConversationDTO) {
        guard let currentUserID else { return }

        let cacheKey = "\(currentUserID.uuidString)-\(conversation.id.uuidString)"

        do {
            let descriptor = FetchDescriptor<ChatCachedConversation>()
            let cached = try modelContext.fetch(descriptor)

            if let existing = cached.first(where: { $0.cacheKey == cacheKey }) {
                existing.update(from: conversation)
            } else {
                let created = ChatCachedConversation(
                    ownerUserID: currentUserID,
                    conversation: conversation
                )
                modelContext.insert(created)
            }

            try modelContext.save()
        } catch {
            Log.debug("❌ MESSAGES HUB CONVERSATION CACHE UPSERT ERROR:", error.localizedDescription)
        }
    }

    func upsertCachedBackendConversations(_ conversations: [ChatBackendConversationDTO]) {
        for conversation in conversations {
            upsertCachedBackendConversation(conversation)
        }
    }

    func scheduleFriendSummaryRebuild() {
        rebuildSummariesTask?.cancel()

        rebuildSummariesTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)

            guard !Task.isCancelled else { return }
            rebuildFriendSummariesIfPossible()
        }
    }

    func rebuildFriendSummariesIfPossible() {
        guard let currentUserID else { return }

        friendStore.rebuildFriendChatSummaries(
            currentUserID: currentUserID,
            localFriends: backendFriends
        )
    }

    func loadMessagesHubData() async {
        await crewStore.loadCrews()

        for crew in crewStore.crews {
            await crewStore.loadMembers(for: crew.id)

            _ = await ChatBackendClient.shared.syncCrew(
                crewID: crew.id,
                crewName: crew.name,
                memberUserIDs: crewStore.crewMembers
                    .filter { $0.crew_id == crew.id }
                    .map(\.user_id)
            )
        }
        

        guard let currentUserID = session.currentUser?.id else { return }

        await friendStore.loadAllFriendships(currentUserID: currentUserID)
        friendStore.subscribeToFriendshipsRealtime(currentUserID: currentUserID)

        let otherUserIDs = friendStore.friendships.compactMap {
            $0.requester_id == currentUserID ? $0.addressee_id : $0.requester_id
        }

        await friendStore.loadProfiles(for: otherUserIDs)

        friendStore.syncAcceptedFriendsToLocal(
            currentUserID: currentUserID,
            modelContext: modelContext
        )

        loadCachedBackendConversations()

        await refreshBackendConversations(reason: "initial_load")
        
        friendStore.rebuildFriendChatSummaries(
            currentUserID: currentUserID,
            localFriends: backendFriends
        )
    }
    func refreshBackendConversations(reason: String = "manual") async {
        guard !isRefreshingBackendConversations else {
            Log.debug("⚪️ MESSAGES HUB BACKEND REFRESH SKIPPED: already refreshing")
            return
        }

        await MainActor.run {
            isRefreshingBackendConversations = true
        }

        let conversations = await ChatBackendClient.shared.listConversations()
        let sorted = sortedBackendConversations(conversations)

        await MainActor.run {
            backendConversations = sorted
            upsertCachedBackendConversations(sorted)
            isRefreshingBackendConversations = false

            let totalUnread = sorted.reduce(0) { $0 + $1.unreadCount }

            if totalUnread <= 0 {
                AppBadgeManager.shared.clearBadge()
            } else {
                AppBadgeManager.shared.setBadge(totalUnread)
            }
        }

        Log.debug("🟢 MESSAGES HUB BACKEND REFRESHED:", reason, conversations.count)
    }
    
    func scheduleBackendConversationRefresh(
        reason: String,
        notification: Notification? = nil
    ) {
        backendLiveRefreshTask?.cancel()

        backendLiveRefreshTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 280_000_000)

            guard !Task.isCancelled else { return }

            await refreshBackendConversations(reason: reason)
        }
    }
}

// MARK: - Navigation / Data Helpers

private extension MessagesView {

    private func backendConversation(for friend: Friend) -> ChatBackendConversationDTO? {
        guard let friendshipID = friend.backendFriendshipID else {
            return nil
        }

        return backendConversations.first {
            $0.supabaseFriendshipId == friendshipID
        }
    }
    
    private func backendConversation(for crew: WeekCrewItem) -> ChatBackendConversationDTO? {
        backendConversations.first {
            $0.supabaseCrewId == crew.id
        }
    }

    private func backendCrewConversationID(for crewID: UUID) -> UUID? {
        backendConversations.first {
            $0.supabaseCrewId == crewID
        }?.id
    }

    private func backendDate(_ value: String?) -> Date? {
        ChatBackendDateParser.parse(value)
    }
    
    @ViewBuilder
    func destinationView(for item: MessagesHubItem) -> some View {
        switch item.payload {
        case .friend(let friend):
            FriendChatView(friend: friend)
                .environmentObject(friendStore)
                .environmentObject(session)

        case .friendSummary(let summary):
            if let friend = backendFriends.first(where: { $0.backendFriendshipID == summary.friendshipID }) {
                FriendChatView(friend: friend)
                    .environmentObject(friendStore)
                    .environmentObject(session)
            } else {
                EmptyView()
            }

        case .crew(let crew):
            CrewChatView(crew: crew)
                .environmentObject(crewStore)
                .environmentObject(session)
        }
    }
    
    func upsertBackendConversationFromNotification(_ notification: Notification) {
        guard let conversation = notification.userInfo?["conversation"] as? ChatBackendConversationDTO else {
            scheduleBackendConversationRefresh(
                reason: "conversation_notification_without_payload",
                notification: notification
            )
            return
        }

        if let index = backendConversations.firstIndex(where: { $0.id == conversation.id }) {
            backendConversations[index] = conversation
        } else {
            backendConversations.append(conversation)
        }

        backendConversations = sortedBackendConversations(backendConversations)

        upsertCachedBackendConversation(conversation)

        Log.debug("🟢 MESSAGES HUB LIVE UPSERT:", conversation.id.uuidString)
        Log.debug("🟢 MESSAGES HUB LIVE LAST:", conversation.lastMessageText ?? "nil")
        Log.debug("🟢 MESSAGES HUB LIVE UNREAD:", conversation.unreadCount)
    }

    private func cleanedPreview(_ text: String) -> String {
        guard
            text.hasPrefix(replyMarker),
            let bodyRange = text.range(of: bodyMarker)
        else {
            return text
        }

        let bodyStart = bodyRange.upperBound
        return String(text[bodyStart...])
    }

    

    private func isCrewActiveToday(_ crew: WeekCrewItem) -> Bool {
        guard let lastDate = backendDate(backendConversation(for: crew)?.lastMessageAt) else {
            return false
        }

        return Calendar.current.isDateInToday(lastDate)
    }
    
    private func firstWord(_ value: String) -> String {
        value.split(separator: " ").first.map(String.init) ?? value
    }

    private func initials(for name: String) -> String {
        let parts = name
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }

        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        } else if let first = parts.first {
            return String(first.prefix(2)).uppercased()
        } else {
            return "?"
        }
    }

    private func tintForFriend(_ friend: Friend) -> Color {
        hexColor(friend.colorHex)
    }

    private func tintForCrew(_ crew: WeekCrewItem) -> Color {
        hexColor(crew.colorHex)
    }
    
    private func friendPresence(for friend: Friend) -> FriendPresenceDTO? {
        guard let userID = friend.backendUserID else {
            return nil
        }

        return friendStore.presenceByUserID[userID]
    }

    private func isFriendOnline(_ friend: Friend) -> Bool {
        FriendPresenceEngine.isOnline(friendPresence(for: friend))
    }
}

// MARK: - Mutations

private extension MessagesView {
    
    private func backendConversationID(for friendshipID: UUID) -> UUID? {
        backendConversations.first {
            $0.supabaseFriendshipId == friendshipID
        }?.id
    }

    private func applyBackendMemberState(
        _ state: ChatBackendMemberStateDTO
    ) {
        backendConversations = backendConversations.map { conversation in
            guard conversation.id == state.conversationID else {
                return conversation
            }

            return ChatBackendConversationDTO(
                id: conversation.id,
                type: conversation.type,
                supabaseFriendshipId: conversation.supabaseFriendshipId,
                supabaseCrewId: conversation.supabaseCrewId,
                title: conversation.title,
                lastMessageText: conversation.lastMessageText,
                lastMessageAt: conversation.lastMessageAt,
                unreadCount: state.unreadCount,
                isMuted: state.isMuted,
                isArchived: state.isArchived,
                isPinned: state.isPinned,
                updatedAt: state.updatedAt ?? conversation.updatedAt
            )
        }
        backendConversations = sortedBackendConversations(backendConversations)

        if let updated = backendConversations.first(where: { $0.id == state.conversationID }) {
            upsertCachedBackendConversation(updated)
        }
    }

    private func friendSummary(for friend: Friend) -> FriendChatThreadSummary? {
        guard let friendshipID = friend.backendFriendshipID else { return nil }

        return friendStore.friendChatSummaries.first {
            $0.friendshipID == friendshipID
        }
    }

    private func summaryFromPayload(_ payload: MessagesHubItem.Payload) -> FriendChatThreadSummary? {
        switch payload {
        case .friend(let friend):
            return friendSummary(for: friend)

        case .friendSummary(let summary):
            return summary

        case .crew:
            return nil
        }
    }

    private func togglePinFriendChat(_ summary: FriendChatThreadSummary) {
        guard let conversationID = backendConversationID(for: summary.friendshipID) else {
            Log.debug("❌ MEMBER STATE PIN SKIPPED: backend conversation not found")
            return
        }

        Task {
            let state = await ChatBackendClient.shared.updateConversationMemberState(
                conversationID: conversationID,
                isPinned: !summary.isPinned
            )

            if let state {
                await MainActor.run {
                    applyBackendMemberState(state)
                }
            }
        }
    }

    private func toggleMuteFriendChat(_ summary: FriendChatThreadSummary) {
        guard let conversationID = backendConversationID(for: summary.friendshipID) else {
            Log.debug("❌ MEMBER STATE MUTE SKIPPED: backend conversation not found")
            return
        }

        Task {
            let state = await ChatBackendClient.shared.updateConversationMemberState(
                conversationID: conversationID,
                isMuted: !summary.isMuted
            )

            if let state {
                await MainActor.run {
                    applyBackendMemberState(state)
                }
            }
        }
    }

    private func archiveFriendChat(_ summary: FriendChatThreadSummary) {
        guard let conversationID = backendConversationID(for: summary.friendshipID) else {
            Log.debug("❌ MEMBER STATE ARCHIVE SKIPPED: backend conversation not found")
            return
        }

        Task {
            let state = await ChatBackendClient.shared.updateConversationMemberState(
                conversationID: conversationID,
                isArchived: true
            )

            if let state {
                await MainActor.run {
                    applyBackendMemberState(state)
                }
            }
        }
    }

    private func togglePinFriendChat(_ friend: Friend) {
        guard let friendshipID = friend.backendFriendshipID else { return }

        guard let conversationID = backendConversationID(for: friendshipID) else {
            Log.debug("❌ MEMBER STATE PIN SKIPPED: backend conversation not found")
            return
        }

        let current = backendConversations.first {
            $0.supabaseFriendshipId == friendshipID
        }?.isPinned ?? false

        Task {
            let state = await ChatBackendClient.shared.updateConversationMemberState(
                conversationID: conversationID,
                isPinned: !current
            )

            if let state {
                await MainActor.run {
                    applyBackendMemberState(state)
                }
            }
        }
    }

    private func toggleMuteFriendChat(_ friend: Friend) {
        guard let friendshipID = friend.backendFriendshipID else { return }

        guard let conversationID = backendConversationID(for: friendshipID) else {
            Log.debug("❌ MEMBER STATE MUTE SKIPPED: backend conversation not found")
            return
        }

        let current = backendConversations.first {
            $0.supabaseFriendshipId == friendshipID
        }?.isMuted ?? false

        Task {
            let state = await ChatBackendClient.shared.updateConversationMemberState(
                conversationID: conversationID,
                isMuted: !current
            )

            if let state {
                await MainActor.run {
                    applyBackendMemberState(state)
                }
            }
        }
    }

    private func archiveFriendChat(_ friend: Friend) {
        guard let friendshipID = friend.backendFriendshipID else { return }

        guard let conversationID = backendConversationID(for: friendshipID) else {
            Log.debug("❌ MEMBER STATE ARCHIVE SKIPPED: backend conversation not found")
            return
        }

        Task {
            let state = await ChatBackendClient.shared.updateConversationMemberState(
                conversationID: conversationID,
                isArchived: true
            )

            if let state {
                await MainActor.run {
                    applyBackendMemberState(state)
                }
            }
        }
    }

    private func togglePinCrewChat(_ crew: WeekCrewItem) {
        let current = backendConversation(for: crew)?.isPinned ?? false

        Task {
            let conversationID: UUID?

            if let existingID = backendCrewConversationID(for: crew.id) {
                conversationID = existingID
            } else {
                conversationID = await ChatBackendClient.shared.syncCrew(
                    crewID: crew.id,
                    crewName: crew.name,
                    memberUserIDs: crewStore.crewMembers
                        .filter { $0.crew_id == crew.id }
                        .map(\.user_id)
                )?.id
            }

            guard let conversationID else {
                Log.debug("❌ CREW MEMBER STATE PIN SKIPPED: backend conversation not found")
                return
            }

            let state = await ChatBackendClient.shared.updateConversationMemberState(
                conversationID: conversationID,
                isPinned: !current
            )

            if let state {
                await MainActor.run {
                    applyBackendMemberState(state)
                }
            }
        }
    }

    private func toggleMuteCrewChat(_ crew: WeekCrewItem) {
        let current = backendConversation(for: crew)?.isMuted ?? false

        Task {
            let conversationID: UUID?

            if let existingID = backendCrewConversationID(for: crew.id) {
                conversationID = existingID
            } else {
                conversationID = await ChatBackendClient.shared.syncCrew(
                    crewID: crew.id,
                    crewName: crew.name,
                    memberUserIDs: crewStore.crewMembers
                        .filter { $0.crew_id == crew.id }
                        .map(\.user_id)
                )?.id
            }

            guard let conversationID else {
                Log.debug("❌ CREW MEMBER STATE MUTE SKIPPED: backend conversation not found")
                return
            }

            let state = await ChatBackendClient.shared.updateConversationMemberState(
                conversationID: conversationID,
                isMuted: !current
            )

            if let state {
                await MainActor.run {
                    applyBackendMemberState(state)
                }
            }
        }
    }

    private func archiveCrewChat(_ crew: WeekCrewItem) {
        Task {
            let conversationID: UUID?

            if let existingID = backendCrewConversationID(for: crew.id) {
                conversationID = existingID
            } else {
                conversationID = await ChatBackendClient.shared.syncCrew(
                    crewID: crew.id,
                    crewName: crew.name,
                    memberUserIDs: crewStore.crewMembers
                        .filter { $0.crew_id == crew.id }
                        .map(\.user_id)
                )?.id
            }

            guard let conversationID else {
                Log.debug("❌ CREW MEMBER STATE ARCHIVE SKIPPED: backend conversation not found")
                return
            }

            let state = await ChatBackendClient.shared.updateConversationMemberState(
                conversationID: conversationID,
                isArchived: true
            )

            if let state {
                await MainActor.run {
                    applyBackendMemberState(state)
                }
            }
        }
    }}

// MARK: - Color

private extension MessagesView {

    private func hexColor(_ hex: String?) -> Color {
        guard let hex else { return Color(arenaHex: AppArenaPalette.blue) }

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
            r = ((int >> 8) & 0xF) * 17
            g = ((int >> 4) & 0xF) * 17
            b = (int & 0xF) * 17

        case 6:
            a = 255
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        case 8:
            a = (int >> 24) & 0xFF
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        default:
            return Color(arenaHex: AppArenaPalette.blue)
        }

        return Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Item Model

struct MessagesHubItem: Identifiable {
    enum Kind {
        case friend
        case crew
    }

    enum Payload {
        case friend(Friend)
        case friendSummary(FriendChatThreadSummary)
        case crew(WeekCrewItem)
    }

    let id: String
    let kind: Kind
    let payload: Payload
    let title: String
    let shortTitle: String
    let preview: String
    let time: Date?
    let unreadCount: Int
    let avatarText: String
    let tint: Color
    let isOnline: Bool
    let showsPresence: Bool
    let isPinned: Bool
    let isMuted: Bool
}
