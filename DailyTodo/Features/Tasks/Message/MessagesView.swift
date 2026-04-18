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

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue

    @State private var searchText = ""

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
        let onlineFriendsItems = backendFriends
            .filter(\.isOnline)
            .map { friend in
                MessagesHubItem(
                    id: "friend-online-\(friend.id.uuidString)",
                    kind: .friend,
                    payload: .friend(friend),
                    title: firstWord(friend.name),
                    shortTitle: firstWord(friend.name),
                    preview: lastPreviewText(for: friend),
                    time: lastFriendMessageDate(for: friend),
                    unreadCount: unreadFriendCount(for: friend),
                    avatarText: initials(for: friend.name),
                    tint: tintForFriend(friend),
                    isOnline: true,
                    showsPresence: true
                )
            }

        let onlineCrewItems = backendCrews
            .filter { crew in
                guard let lastDate = lastCrewMessageDate(for: crew) else { return false }
                return Calendar.current.isDateInToday(lastDate)
            }
            .map { crew in
                MessagesHubItem(
                    id: "crew-online-\(crew.id.uuidString)",
                    kind: .crew,
                    payload: .crew(crew),
                    title: crew.name,
                    shortTitle: crew.name,
                    preview: lastPreviewText(for: crew),
                    time: lastCrewMessageDate(for: crew),
                    unreadCount: 0,
                    avatarText: crew.icon,
                    tint: tintForCrew(crew),
                    isOnline: true,
                    showsPresence: true
                )
            }

        return Array((onlineFriendsItems + onlineCrewItems)
            .sorted { ($0.time ?? .distantPast) > ($1.time ?? .distantPast) }
            .prefix(8))
    }

    private var allConversationItems: [MessagesHubItem] {
        let friendItems = backendFriends.map { friend in
            MessagesHubItem(
                id: "friend-\(friend.id.uuidString)",
                kind: .friend,
                payload: .friend(friend),
                title: friend.name,
                shortTitle: firstWord(friend.name),
                preview: lastPreviewText(for: friend),
                time: lastFriendMessageDate(for: friend),
                unreadCount: unreadFriendCount(for: friend),
                avatarText: initials(for: friend.name),
                tint: tintForFriend(friend),
                isOnline: friend.isOnline,
                showsPresence: true
            )
        }

        let crewItems = backendCrews.map { crew in
            MessagesHubItem(
                id: "crew-\(crew.id.uuidString)",
                kind: .crew,
                payload: .crew(crew),
                title: crew.name,
                shortTitle: crew.name,
                preview: lastPreviewText(for: crew),
                time: lastCrewMessageDate(for: crew),
                unreadCount: 0,
                avatarText: crew.icon,
                tint: tintForCrew(crew),
                isOnline: isCrewActiveToday(crew),
                showsPresence: true
            )
        }

        return (friendItems + crewItems)
            .sorted { lhs, rhs in
                let l = lhs.time ?? .distantPast
                let r = rhs.time ?? .distantPast
                if l != r { return l > r }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private var filteredConversationItems: [MessagesHubItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return allConversationItems }

        return allConversationItems.filter {
            $0.title.localizedCaseInsensitiveContains(query)
            || $0.preview.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if appTheme == AppTheme.gradient.rawValue {
                    ambientBackground
                        .ignoresSafeArea()
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        searchBar

                        if !onlineItems.isEmpty {
                            onlineSection
                        }

                        conversationsSection

                        Spacer(minLength: 70)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
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
    var ambientBackground: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color.blue.opacity(0.16),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 280
            )
            .offset(x: 90, y: -80)

            RadialGradient(
                colors: [
                    Color.purple.opacity(0.14),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 40,
                endRadius: 260
            )
            .offset(x: -120, y: 260)
        }
    }

    var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Mesajlar")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Friend & Crew Sohbetleri")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.52))
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 46)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }

    var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.38))

            TextField("Sohbet ara...", text: $searchText)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }

    var onlineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 11, height: 11)

                Text("ŞU AN ONLINE")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.54))
                    .tracking(1.0)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(onlineItems) { item in
                        NavigationLink {
                            destinationView(for: item)
                        } label: {
                            VStack(spacing: 8) {
                                ZStack(alignment: .bottomTrailing) {
                                    onlineAvatar(for: item, size: 64)

                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 14, height: 14)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.black, lineWidth: 2.5)
                                        )
                                }

                                Text(item.shortTitle)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.84))
                                    .lineLimit(1)
                            }
                            .frame(width: 76)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    var conversationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TÜM SOHBETLER")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.54))
                .tracking(1.0)

            if filteredConversationItems.isEmpty {
                emptyState(
                    title: searchText.isEmpty ? "Henüz sohbet yok" : "Sonuç bulunamadı",
                    subtitle: searchText.isEmpty
                    ? "Friend ve crew sohbetlerin burada görünecek."
                    : "Aramayı değiştirip tekrar dene.",
                    systemImage: "bubble.left.and.bubble.right"
                )
            } else {
                VStack(spacing: 12) {
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

    func conversationRow(_ item: MessagesHubItem) -> some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                rowAvatar(for: item, size: 56)

                if item.showsPresence {
                    Circle()
                        .fill(item.isOnline ? Color.green : Color.gray.opacity(0.75))
                        .frame(width: 13, height: 13)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 2.5)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if let time = item.time {
                        Text(time, style: .time)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(item.unreadCount > 0 ? .white.opacity(0.82) : .white.opacity(0.42))
                    }
                }

                HStack(spacing: 6) {
                    if item.kind == .crew {
                        Text("Crew")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(item.tint)

                        Text("•")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.28))
                    }

                    Text(item.preview)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(item.unreadCount > 0 ? .white.opacity(0.78) : .white.opacity(0.52))
                        .lineLimit(1)
                }
            }

            VStack(alignment: .trailing, spacing: 8) {
                if item.unreadCount > 0 {
                    unreadBadge(item.unreadCount)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.24))
                }
            }
            .frame(width: 28)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(rowBackground(highlighted: item.unreadCount > 0))
    }

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
                .fill(tint.opacity(0.10))
                .overlay(
                    Circle()
                        .stroke(tint.opacity(0.24), lineWidth: 1.1)
                )
                .frame(width: size, height: size)

            Text(initials)
                .font(.system(size: size * 0.30, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
        }
    }

    func crewIconAvatar(symbol: String, tint: Color, size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(tint.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                        .stroke(tint.opacity(0.22), lineWidth: 1.1)
                )
                .frame(width: size, height: size)

            Image(systemName: symbol)
                .font(.system(size: size * 0.28, weight: .medium))
                .foregroundStyle(tint)
        }
    }

    func rowBackground(highlighted: Bool) -> some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(highlighted ? Color.white.opacity(0.050) : Color.white.opacity(0.032))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        highlighted ? Color.white.opacity(0.10) : Color.white.opacity(0.06),
                        lineWidth: 1
                    )
            )
    }

    func emptyState(title: String, subtitle: String, systemImage: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
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

    @ViewBuilder
    func destinationView(for item: MessagesHubItem) -> some View {
        switch item.payload {
        case .friend(let friend):
            FriendChatView(friend: friend)
                .environmentObject(friendStore)
                .environmentObject(session)

        case .crew(let crew):
            CrewChatView(crew: crew)
                .environmentObject(crewStore)
                .environmentObject(session)
        }
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
        return last.isFromMe ? "You: \(cleaned)" : cleaned
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

    private func isCrewActiveToday(_ crew: WeekCrewItem) -> Bool {
        guard let lastDate = lastCrewMessageDate(for: crew) else { return false }
        return Calendar.current.isDateInToday(lastDate)
    }

    private func unreadBadge(_ count: Int) -> some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, count > 9 ? 7 : 6)
            .frame(height: 24)
            .background(
                Capsule()
                    .fill(Color.accentColor)
            )
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

    private func hexColor(_ hex: String?) -> Color {
        guard let hex else { return .accentColor }
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3:
            (a, r, g, b) = (255,
                            ((int >> 8) & 0xF) * 17,
                            ((int >> 4) & 0xF) * 17,
                            (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255,
                            (int >> 16) & 0xFF,
                            (int >> 8) & 0xFF,
                            int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF,
                            (int >> 16) & 0xFF,
                            (int >> 8) & 0xFF,
                            int & 0xFF)
        default:
            return .accentColor
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

private struct MessagesHubItem: Identifiable {
    enum Kind {
        case friend
        case crew
    }

    enum Payload {
        case friend(Friend)
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
}
