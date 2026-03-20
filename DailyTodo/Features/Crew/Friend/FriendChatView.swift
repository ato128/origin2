//
//  FriendChatView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI


struct FriendChatView: View {
    let friend: Friend

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var friendStore: FriendStore
    @EnvironmentObject var session: SessionStore
    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue

    private let palette = ThemePalette()

    @State private var draftMessage: String = ""
    @State private var showFriendInfo = false
    @FocusState private var isComposerFocused: Bool

    private var friendshipID: UUID? {
        friend.backendFriendshipID
    }

    private var messages: [FriendChatMessageItem] {
        guard let friendshipID else { return [] }
        return friendStore.friendMessagesByFriendship[friendshipID] ?? []
    }

    var body: some View {
        ZStack(alignment: .top) {
            ambientBackground

            VStack(spacing: 0) {
                customHeader
                
              
                .padding()

                if messages.isEmpty {
                    emptyState
                } else {
                    messagesList
                }

                composerBar
            }
        }
        .contentShape(Rectangle())
        .hideKeyboardOnTap()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            print("CHAT FRIEND NAME:", friend.name)
            print("CHAT FRIENDSHIP ID:", friendshipID as Any)

            if let id = friendshipID {
                await friendStore.loadMessages(
                    for: id,
                    currentUserID: session.currentUser?.id
                )
            }
        }
        .onDisappear {
            
        }
        .sheet(isPresented: $showFriendInfo) {
            NavigationStack {
                FriendChatInfoView(friend: friend)
            }
        }
    }
}

private extension FriendChatView {
    var ambientBackground: some View {
        ZStack(alignment: .topLeading) {
            AppBackground()

            if appTheme == AppTheme.gradient.rawValue {
                RadialGradient(
                    colors: [
                        hexColor(friend.colorHex).opacity(0.16),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 30,
                    endRadius: 260
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        Color.blue.opacity(0.08),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 60,
                    endRadius: 320
                )
                .ignoresSafeArea()
            }
        }
    }

    var customHeader: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(palette.primaryText)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(palette.cardFill)
                            .overlay(
                                Circle()
                                    .stroke(palette.cardStroke, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                showFriendInfo = true
            } label: {
                VStack(spacing: 2) {
                    Text(friend.name)
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)

                    Text("Direct Chat")
                        .font(.caption2)
                        .foregroundStyle(palette.secondaryText)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Color.clear.frame(width: 56, height: 56)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 72, height: 72)

                Image(systemName: "message.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)
            }

            Text("No messages yet")
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            Text("Start the conversation with \(friend.name).")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(messages) { message in
                        HStack {
                            if message.isFromMe { Spacer(minLength: 40) }

                            Text(message.text)
                                .font(.subheadline)
                                .foregroundStyle(message.isFromMe ? .white : palette.primaryText)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(
                                            message.isFromMe
                                            ? Color.accentColor.opacity(appTheme == AppTheme.light.rawValue ? 0.90 : 0.24)
                                            : palette.secondaryCardFill
                                        )
                                )

                            if !message.isFromMe { Spacer(minLength: 40) }
                        }
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
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

    var composerBar: some View {
        HStack(spacing: 10) {
            TextField("Message...", text: $draftMessage)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(palette.secondaryCardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(palette.cardStroke.opacity(0.7), lineWidth: 1)
                        )
                )
                .focused($isComposerFocused)

            Button {
                sendMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(
                        Circle()
                            .fill(Color.accentColor)
                    )
            }
            .buttonStyle(.plain)
            .disabled(
                draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .background(.ultraThinMaterial.opacity(0.001))
    }

    func sendMessage() {
        let clean = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        print("SEND TAP")
        print("CLEAN TEXT:", clean)
        print("FRIENDSHIP ID IN SEND:", friendshipID as Any)

        guard !clean.isEmpty else { return }
        guard let friendshipID else {
            print("SEND STOPPED: friendshipID nil")
            return
        }

        let senderName =
            session.currentUser?.email.components(separatedBy: "@").first ??
            session.currentUser?.email ??
            "You"

        draftMessage = ""

        Task {
            await friendStore.sendMessage(
                text: clean,
                friendshipID: friendshipID,
                senderID: session.currentUser?.id,
                senderName: senderName
            )
        }
    }

    func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastID = messages.last?.id else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }
}
