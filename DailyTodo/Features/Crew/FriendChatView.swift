//
//  FriendChatView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI
import SwiftData

struct FriendChatView: View {
    let friend: Friend

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \FriendMessage.createdAt, order: .forward)
    private var allMessages: [FriendMessage]

    @State private var draftMessage: String = ""

    private var messages: [FriendMessage] {
        allMessages.filter { $0.friendID == friend.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            if messages.isEmpty {
                emptyState
            } else {
                messagesList
            }

            composerBar
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(friend.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            seedMessagesIfNeeded()
        }
    }
}

private extension FriendChatView {

    var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "message.fill")
                .font(.system(size: 34))
                .foregroundStyle(Color.accentColor)

            Text("No messages yet")
                .font(.headline)

            Text("Start the conversation with \(friend.name).")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(messages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    func messageBubble(_ message: FriendMessage) -> some View {
        let isSystemFocusMessage =
            message.text.contains("started a 25 min shared focus session") ||
            message.text.contains("ended the shared focus session") ||
            message.text.contains("joined") && message.text.contains("shared focus session")

        return HStack {
            if isSystemFocusMessage {
                Spacer()

                Text(message.text)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.10))
                    )
                    .foregroundStyle(.secondary)

                Spacer()
            } else {
                if message.isFromMe {
                    Spacer(minLength: 40)
                }

                VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 4) {
                    Text(message.text)
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(
                                    message.isFromMe
                                    ? Color.accentColor.opacity(0.16)
                                    : Color.white.opacity(0.08)
                                )
                        )
                        .foregroundStyle(.primary)

                    Text(message.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if !message.isFromMe {
                    Spacer(minLength: 40)
                }
            }
        }
    }

    var composerBar: some View {
        HStack(spacing: 10) {
            TextField("Message \(friend.name)...", text: $draftMessage, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.secondary
                        : Color.accentColor
                    )
            }
            .buttonStyle(.plain)
            .disabled(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    func sendMessage() {
        let clean = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        let message = FriendMessage(
            friendID: friend.id,
            senderName: "Me",
            text: clean,
            isFromMe: true
        )

        modelContext.insert(message)
        try? modelContext.save()

        draftMessage = ""
    }

    func seedMessagesIfNeeded() {
        guard messages.isEmpty else { return }

        let seed = [
            FriendMessage(friendID: friend.id, senderName: friend.name, text: "Hey! How does your week look?", isFromMe: false),
            FriendMessage(friendID: friend.id, senderName: "Me", text: "Pretty busy, especially Thursday.", isFromMe: true),
            FriendMessage(friendID: friend.id, senderName: friend.name, text: "Let's sync after class.", isFromMe: false)
        ]

        for item in seed {
            modelContext.insert(item)
        }

        try? modelContext.save()
    }

    func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastID = messages.last?.id else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }
}
