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
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var session: SessionStore

    @State private var selectedTab = 0

    @Query(sort: \Friend.createdAt, order: .reverse)
    private var friends: [Friend]

    @Query(sort: \FriendMessage.createdAt, order: .reverse)
    private var friendMessages: [FriendMessage]

    private let replyMarker = "[[reply]]"
    private let bodyMarker = "[[body]]"

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
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Friends").tag(0)
                    Text("Crews").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if selectedTab == 0 {
                    List {
                        if friends.isEmpty {
                            ContentUnavailableView(
                                "No Friends Yet",
                                systemImage: "person.2.slash",
                                description: Text("Your friend chats will appear here.")
                            )
                        } else {
                            ForEach(friends) { friend in
                                NavigationLink {
                                    FriendChatView(friend: friend)
                                } label: {
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(hexColor(friend.colorHex).opacity(0.16))
                                            .frame(width: 42, height: 42)
                                            .overlay(
                                                Image(systemName: friend.avatarSymbol)
                                                    .foregroundStyle(hexColor(friend.colorHex))
                                            )

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(friend.name)
                                                .font(.headline)

                                            Text(lastPreviewText(for: friend))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)

                                            if friend.isMuted {
                                                Text("Muted")
                                                    .font(.caption2.weight(.semibold))
                                                    .foregroundStyle(.orange)
                                            }
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 8) {
                                            if let lastDate = lastFriendMessageDate(for: friend) {
                                                Text(lastDate, style: .time)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }

                                            HStack(spacing: 8) {
                                                if unreadFriendCount(for: friend) > 0 {
                                                    unreadBadge(unreadFriendCount(for: friend))
                                                }

                                                Circle()
                                                    .fill(friend.isOnline ? Color.green : Color.gray.opacity(0.4))
                                                    .frame(width: 8, height: 8)

                                                if friend.isMuted {
                                                    Image(systemName: "bell.slash.fill")
                                                        .font(.caption.weight(.semibold))
                                                        .foregroundStyle(.orange)
                                                }

                                                Image(systemName: "chevron.right")
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)

                } else {
                    List {
                        if backendCrews.isEmpty {
                            ContentUnavailableView(
                                "No Crews Yet",
                                systemImage: "person.3.slash",
                                description: Text("Your crew chats will appear here.")
                            )
                        } else {
                            ForEach(backendCrews) { crew in
                                NavigationLink {
                                    CrewChatView(crew: crew)
                                        .environmentObject(crewStore)
                                        .environmentObject(session)
                                } label: {
                                    HStack(spacing: 12) {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(hexColor(crew.colorHex).opacity(0.16))
                                            .frame(width: 42, height: 42)
                                            .overlay(
                                                Image(systemName: crew.icon)
                                                    .foregroundStyle(hexColor(crew.colorHex))
                                            )

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(crew.name)
                                                .font(.headline)

                                            Text(lastPreviewText(for: crew))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 8) {
                                            if let lastDate = lastCrewMessageDate(for: crew) {
                                                Text(lastDate, style: .time)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }

                                            HStack(spacing: 8) {
                                                Image(systemName: "chevron.right")
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await crewStore.loadCrews()

                for crew in crewStore.crews {
                    await crewStore.loadInitialChatMessages(
                        for: crew.id,
                        currentUserID: session.currentUser?.id
                    )
                }
            }
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
        guard let last = friendMessages.first(where: { $0.friendID == friend.id }) else {
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
        friendMessages.first(where: { $0.friendID == friend.id })?.createdAt
    }

    private func unreadFriendCount(for friend: Friend) -> Int {
        friendMessages.filter { $0.friendID == friend.id && !$0.isRead && !$0.isFromMe }.count
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
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, count > 9 ? 7 : 6)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.accentColor)
            )
    }
}

