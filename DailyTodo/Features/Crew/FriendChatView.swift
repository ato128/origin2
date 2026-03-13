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

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \FriendMessage.createdAt, order: .forward)
    private var allMessages: [FriendMessage]

    @State private var draftMessage: String = ""
    @State private var animateMessages = false
    @State private var sendPressed = false

    private var messages: [FriendMessage] {
        allMessages.filter { $0.friendID == friend.id }
    }

    var body: some View {
        ZStack(alignment: .top) {
            ambientBackground

            VStack(spacing: 0) {
                customHeader

                if messages.isEmpty {
                    emptyState
                } else {
                    messagesList
                }

                composerBar
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            seedMessagesIfNeeded()
        }
    }
}

private extension FriendChatView {

    var ambientBackground: some View {
        ZStack(alignment: .topLeading) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    hexColor(friend.colorHex).opacity(0.12),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 30,
                endRadius: 240
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.blue.opacity(0.07),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 60,
                endRadius: 280
            )
            .ignoresSafeArea()
        }
    }

    var customHeader: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 52, height: 52)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(hexColor(friend.colorHex).opacity(0.16))
                        .frame(width: 42, height: 42)

                    Image(systemName: friend.avatarSymbol)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(hexColor(friend.colorHex))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.name)
                        .font(.headline)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(friend.isOnline ? .green : Color.gray.opacity(0.5))
                            .frame(width: 7, height: 7)

                        Text(friend.isOnline ? "Online" : "Offline")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.35))
                .ignoresSafeArea(edges: .top)
        )
    }

    var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()

            ZStack {
                Circle()
                    .fill(hexColor(friend.colorHex).opacity(0.14))
                    .frame(width: 82, height: 82)

                Image(systemName: "message.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(hexColor(friend.colorHex))
            }

            Text("No messages yet")
                .font(.title3.weight(.bold))

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
                LazyVStack(spacing: 12) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        messageBubble(message)
                            .id(message.id)
                            .offset(y: animateMessages ? 0 : CGFloat(12 + index * 4))
                            .opacity(animateMessages ? 1 : 0)
                            .scaleEffect(animateMessages ? 1 : 0.985)
                            .animation(
                                .spring(response: 0.40, dampingFraction: 0.86)
                                    .delay(Double(index) * 0.03),
                                value: animateMessages
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                seedMessagesIfNeeded()

                animateMessages = false

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                        animateMessages = true
                    }
                }
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

                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption.weight(.bold))

                    Text(message.text)
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(Color.accentColor.opacity(0.10))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.accentColor.opacity(0.12), lineWidth: 1)
                )
                .foregroundStyle(.secondary)

                Spacer()
            } else {
                if message.isFromMe { Spacer(minLength: 42) }

                VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 5) {
                    Text(message.text)
                        .font(.subheadline)
                        .foregroundStyle(message.isFromMe ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    message.isFromMe
                                    ? Color.accentColor.opacity(0.24)
                                    : Color.white.opacity(0.07)
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(
                                    message.isFromMe
                                    ? Color.accentColor.opacity(0.18)
                                    : Color.white.opacity(0.06),
                                    lineWidth: 1
                                )
                        )

                    Text(message.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                }

                if !message.isFromMe { Spacer(minLength: 42) }
            }
        }
    }

    var composerBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message \(friend.name)...", text: $draftMessage, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                )

            Button {
                sendMessage()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.white.opacity(0.08)
                            : Color.accentColor
                        )
                        .frame(width: 46, height: 46)

                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(
                            draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.secondary
                            : .white
                        )
                }
                .scaleEffect(sendPressed ? 0.92 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.70), value: sendPressed)
            }
            .buttonStyle(.plain)
            .disabled(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        sendPressed = true
                    }
                    .onEnded { _ in
                        sendPressed = false
                    }
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
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
        animateMessages = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                animateMessages = true
            }
        }
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
