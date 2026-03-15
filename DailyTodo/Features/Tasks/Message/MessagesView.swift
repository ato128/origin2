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
    @State private var selectedTab = 0

    @Query(sort: \Friend.createdAt, order: .reverse)
    private var friends: [Friend]

    @Query(sort: \Crew.createdAt, order: .reverse)
    private var crews: [Crew]

    @Query(sort: \FriendMessage.createdAt, order: .reverse)
    private var friendMessages: [FriendMessage]

    @Query(sort: \CrewMessage.createdAt, order: .reverse)
    private var crewMessages: [CrewMessage]

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
                        if crews.isEmpty {
                            ContentUnavailableView(
                                "No Crews Yet",
                                systemImage: "person.3.slash",
                                description: Text("Your crew chats will appear here.")
                            )
                        } else {
                            ForEach(crews) { crew in
                                NavigationLink {
                                    CrewChatView(crew: crew)
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

                                            if crew.isMuted {
                                                Text("Muted")
                                                    .font(.caption2.weight(.semibold))
                                                    .foregroundStyle(.orange)
                                            }
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 8) {
                                            if let lastDate = lastCrewMessageDate(for: crew) {
                                                Text(lastDate, style: .time)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }

                                            HStack(spacing: 8) {
                                                if unreadCrewCount(for: crew) > 0 {
                                                    unreadBadge(unreadCrewCount(for: crew))
                                                }

                                                if crew.isMuted {
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
        }
    }

    private func lastPreviewText(for friend: Friend) -> String {
        guard let last = friendMessages.first(where: { $0.friendID == friend.id }) else {
            return friend.subtitle
        }

        if last.isFromMe {
            return "You: \(last.text)"
        } else {
            return last.text
        }
    }

    private func lastFriendMessageDate(for friend: Friend) -> Date? {
        friendMessages.first(where: { $0.friendID == friend.id })?.createdAt
    }

    private func unreadFriendCount(for friend: Friend) -> Int {
        friendMessages.filter { $0.friendID == friend.id && !$0.isRead && !$0.isFromMe }.count
    }

    private func lastPreviewText(for crew: Crew) -> String {
        guard let last = crewMessages.first(where: { $0.crewID == crew.id }) else {
            return "Crew conversation"
        }

        return "\(last.senderName): \(last.text)"
    }

    private func lastCrewMessageDate(for crew: Crew) -> Date? {
        crewMessages.first(where: { $0.crewID == crew.id })?.createdAt
    }

    private func unreadCrewCount(for crew: Crew) -> Int {
        crewMessages.filter { $0.crewID == crew.id && !$0.isRead && !$0.isFromMe }.count
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
