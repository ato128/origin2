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

    @State private var selectedTab = 0

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

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        segmentedPicker

                        if selectedTab == 0 {
                            friendsSection
                        } else {
                            crewsSection
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await crewStore.loadCrews()

                for crew in crewStore.crews {
                    await crewStore.loadInitialChatMessages(
                        for: crew.id,
                        currentUserID: session.currentUser?.id
                    )
                }

                guard let currentUserID = session.currentUser?.id else { return }

                await friendStore.loadAllFriendships(currentUserID: currentUserID)

                let otherUserIDs = friendStore.friendships.compactMap {
                    $0.requester_id == currentUserID ? $0.addressee_id : $0.requester_id
                }

                await friendStore.loadProfiles(for: otherUserIDs)
                friendStore.syncAcceptedFriendsToLocal(
                    currentUserID: currentUserID,
                    modelContext: modelContext
                )

                for friend in backendFriends {
                    if let friendshipID = friend.backendFriendshipID {
                        await friendStore.loadInitialMessages(
                            for: friendshipID,
                            currentUserID: currentUserID
                        )
                    }
                }
            }
        }
    }
}

private extension MessagesView {
    var header: some View {
        HStack(alignment: .center) {
            Text("Messages")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 42)
                    .background(smallGlassCapsule)
            }
            .buttonStyle(.plain)
        }
    }

    var segmentedPicker: some View {
        HStack(spacing: 0) {
            segmentButton(title: "Friends", isSelected: selectedTab == 0) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    selectedTab = 0
                }
            }

            segmentButton(title: "Crews", isSelected: selectedTab == 1) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    selectedTab = 1
                }
            }
        }
        .padding(4)
        .background(largeGlassCapsule)
    }

    func segmentButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.62))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.white.opacity(0.16))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    }
                }
        }
        .buttonStyle(.plain)
    }

    var friendsSection: some View {
        VStack(spacing: 12) {
            if backendFriends.isEmpty {
                emptyState(
                    title: "No Friends Yet",
                    subtitle: "Your friend chats will appear here.",
                    systemImage: "person.2.slash"
                )
            } else {
                ForEach(backendFriends) { friend in
                    NavigationLink {
                        FriendChatView(friend: friend)
                            .environmentObject(friendStore)
                            .environmentObject(session)
                    } label: {
                        friendRow(friend)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    var crewsSection: some View {
        VStack(spacing: 12) {
            if backendCrews.isEmpty {
                emptyState(
                    title: "No Crews Yet",
                    subtitle: "Your crew chats will appear here.",
                    systemImage: "person.3.slash"
                )
            } else {
                ForEach(backendCrews) { crew in
                    NavigationLink {
                        CrewChatView(crew: crew)
                            .environmentObject(crewStore)
                            .environmentObject(session)
                    } label: {
                        crewRow(crew)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    func friendRow(_ friend: Friend) -> some View {
        let unreadCount = unreadFriendCount(for: friend)
        let hasUnread = unreadCount > 0

        return HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(hexColor(friend.colorHex).opacity(0.16))
                    .frame(width: 44, height: 44)

                Image(systemName: friend.avatarSymbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(hexColor(friend.colorHex))

                Circle()
                    .fill(friend.isOnline ? Color.green : Color.gray.opacity(0.45))
                    .frame(width: 9, height: 9)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.35), lineWidth: 1.2)
                    )
                    .offset(x: 1, y: 1)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(friend.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(lastPreviewText(for: friend))
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(hasUnread ? .white.opacity(0.86) : .white.opacity(0.62))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                if let lastDate = lastFriendMessageDate(for: friend) {
                    Text(lastDate, style: .time)
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(.white.opacity(0.70))
                }

                HStack(spacing: 8) {
                    if unreadCount > 0 {
                        unreadBadge(unreadCount)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.34))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(hasUnread ? Color.white.opacity(0.06) : Color.white.opacity(0.045))
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            hasUnread ? Color.white.opacity(0.13) : Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                )
        )
        .shadow(
            color: hasUnread ? Color.white.opacity(0.04) : .clear,
            radius: hasUnread ? 8 : 0,
            y: hasUnread ? 3 : 0
        )
    }

    func crewRow(_ crew: WeekCrewItem) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(hexColor(crew.colorHex).opacity(0.16))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: crew.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(hexColor(crew.colorHex))
                )
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(crew.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(lastPreviewText(for: crew))
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 8) {
                if let lastDate = lastCrewMessageDate(for: crew) {
                    Text(lastDate, style: .time)
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(.white.opacity(0.70))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.34))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    func emptyState(title: String, subtitle: String, systemImage: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white.opacity(0.80))

            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 20)
    }

    var smallGlassCapsule: some View {
        Capsule()
            .fill(Color.white.opacity(0.05))
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
            )
    }

    var largeGlassCapsule: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color.white.opacity(0.035))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
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

    private func lastPreviewText(for friend: Friend) -> String {
        guard
            let friendshipID = friend.backendFriendshipID,
            let last = friendStore.friendMessagesByFriendship[friendshipID]?.last
        else {
            return friend.subtitle
        }

        let cleaned = cleanedPreview(last.text)

        if last.isFromMe {
            return "You: \(cleaned)"
        } else {
            return cleaned
        }
    }

    private func lastFriendMessageDate(for friend: Friend) -> Date? {
        guard let friendshipID = friend.backendFriendshipID else { return nil }
        return friendStore.friendMessagesByFriendship[friendshipID]?.last?.createdAt
    }

    private func unreadFriendCount(for friend: Friend) -> Int {
        guard let friendshipID = friend.backendFriendshipID else { return 0 }

        let messages = friendStore.friendMessagesByFriendship[friendshipID] ?? []
        return messages.filter { !$0.isFromMe && $0.seenAt == nil }.count
    }

    private func crewChatMessages(for crew: WeekCrewItem) -> [CrewChatMessageItem] {
        crewStore.chatMessagesByCrew[crew.id] ?? []
    }

    private func lastPreviewText(for crew: WeekCrewItem) -> String {
        guard let last = crewChatMessages(for: crew).last else {
            return "Crew conversation"
        }

        if last.isSystemMessage {
            return last.displayText
        }

        return "\(last.senderName): \(last.displayText)"
    }

    private func lastCrewMessageDate(for crew: WeekCrewItem) -> Date? {
        crewChatMessages(for: crew).last?.createdAt
    }

    private func unreadBadge(_ count: Int) -> some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, count > 9 ? 8 : 7)
            .frame(height: 26)
            .background(
                Capsule()
                    .fill(Color.accentColor)
            )
    }
}
