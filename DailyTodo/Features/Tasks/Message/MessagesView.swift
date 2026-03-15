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

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(friend.name)
                                                .font(.headline)

                                            Text(friend.subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Circle()
                                            .fill(friend.isOnline ? Color.green : Color.gray.opacity(0.4))
                                            .frame(width: 8, height: 8)
                                    }
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

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(crew.name)
                                                .font(.headline)

                                            Text("Crew conversation")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()
                                    }
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
}


