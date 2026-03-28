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
    @Environment(\.locale) private var locale
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
                if messages.isEmpty {
                    emptyState
                } else {
                    messagesList
                }
            }

            floatingTopControls

            VStack {
                Spacer()
                composerBar
            }
        }
        .contentShape(Rectangle())
        .hideKeyboardOnTap()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard let friendshipID else { return }

            friendStore.activeChatFriendshipID = friendshipID

            if friendStore.friendMessagesByFriendship[friendshipID] == nil {
                await friendStore.loadInitialMessages(
                    for: friendshipID,
                    currentUserID: session.currentUser?.id
                )
            }

            let pushStore = PushTokenStore()
            await pushStore.saveCurrentToken(currentUserID: session.currentUser?.id)

            await friendStore.markMessagesSeen(
                friendshipID: friendshipID,
                currentUserID: session.currentUser?.id
            )

            friendStore.unsubscribeFriendMessagesRealtime()
            friendStore.subscribeToFriendMessagesRealtime(
                friendshipID: friendshipID,
                currentUserID: session.currentUser?.id
            )

            friendStore.subscribeToTypingRealtime(
                friendshipID: friendshipID,
                currentUserID: session.currentUser?.id
            )

            if let friendUserID = friend.backendUserID {
                await friendStore.loadPresence(for: [friendUserID])
                friendStore.subscribeToPresenceRealtime(for: [friendUserID])
            }

            await friendStore.setPresence(
                currentUserID: session.currentUser?.id,
                isOnline: true
            )

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await friendStore.loadNewMessages(
                    for: friendshipID,
                    currentUserID: session.currentUser?.id
                )
            }
        }
        .onDisappear {
            friendStore.activeChatFriendshipID = nil
            friendStore.unsubscribeFriendMessagesRealtime()
            friendStore.unsubscribeTypingRealtime()
            friendStore.unsubscribePresenceRealtime()

            Task {
                await friendStore.setPresence(
                    currentUserID: session.currentUser?.id,
                    isOnline: false
                )
            }

            if let friendshipID {
                let senderName: String
                if let email = session.currentUser?.email, !email.isEmpty {
                    senderName = email.components(separatedBy: "@").first ?? email
                } else {
                    senderName = locale.language.languageCode?.identifier == "tr" ? "Sen" : "You"
                }

                Task {
                    await friendStore.setTyping(
                        friendshipID: friendshipID,
                        currentUserID: session.currentUser?.id,
                        currentUserName: senderName,
                        isTyping: false
                    )
                }
            }
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
                    colors: [hexColor(friend.colorHex).opacity(0.16), Color.clear],
                    center: .topLeading,
                    startRadius: 30,
                    endRadius: 260
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [Color.blue.opacity(0.08), Color.clear],
                    center: .topTrailing,
                    startRadius: 60,
                    endRadius: 320
                )
                .ignoresSafeArea()
            }
        }
    }

    var floatingTopControls: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(glassCircleBackground)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            Button {
                showFriendInfo = true
            } label: {
                HStack(spacing: 10) {
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .fill(hexColor(friend.colorHex).opacity(0.16))
                            .frame(width: 34, height: 34)

                        Image(systemName: friend.avatarSymbol)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(hexColor(friend.colorHex))

                        if isFriendOnline {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black.opacity(0.28), lineWidth: 1.5)
                                )
                                .offset(x: 1, y: 1)
                        }
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(friend.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        if isTypingNow {
                            HStack(spacing: 5) {
                                Text(headerStatusText)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.green)

                                TypingDotsView()
                                    .foregroundStyle(.green)
                            }
                        } else {
                            Text(headerStatusText)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.68))
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(glassCapsuleBackground)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            Button {
                showFriendInfo = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(glassCircleBackground)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var friendPresence: FriendPresenceDTO? {
        guard let userID = friend.backendUserID else { return nil }
        return friendStore.presenceByUserID[userID]
    }

    private var isTypingNow: Bool {
        guard let friendshipID else { return false }
        return friendStore.typingStatusByFriendship[friendshipID] == true
    }

    private var isFriendOnline: Bool {
        friendPresence?.is_online == true
    }

    private var headerStatusText: String {
        if let friendshipID,
           friendStore.typingStatusByFriendship[friendshipID] == true {
            return locale.language.languageCode?.identifier == "tr"
                ? "\(friend.name) yazıyor..."
                : "\(friend.name) is typing..."
        }

        guard let friendPresence else { return String(localized: "chat_direct_chat") }

        if friendPresence.is_online {
            return String(localized: "chat_online")
        } else {
            let date = CrewDateParser.parse(friendPresence.last_seen_at) ?? Date()
            return locale.language.languageCode?.identifier == "tr"
                ? "Son görülme \(relativeLastSeen(date))"
                : "Last seen \(relativeLastSeen(date))"
        }
    }

    func relativeLastSeen(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = locale
        return formatter.localizedString(for: date, relativeTo: Date())
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

            Text("chat_no_messages_yet")
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            Text(localizedStartConversationText(friend.name))
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
                LazyVStack(spacing: 9) {
                    ForEach(messages) { message in
                        ChatMessageRow(
                            message: message,
                            palette: palette
                        )
                        .id(message.id)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("chat-bottom-anchor")
                }
                .padding(.horizontal, 16)
                .padding(.top, 54)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                scrollToBottom(proxy: proxy, animated: false)
            }
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy, animated: true)
            }
        }
    }

    var composerBar: some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(width: 42, height: 42)
                    .background(glassCircleBackground)
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                TextField("Mesaj • SMS", text: $draftMessage)
                    .focused($isComposerFocused)
                    .onChange(of: draftMessage) { _, newValue in
                        guard let friendshipID else { return }
                        let clean = newValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                        let senderName = senderDisplayName()

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            Task {
                                await friendStore.setTyping(
                                    friendshipID: friendshipID,
                                    currentUserID: session.currentUser?.id,
                                    currentUserName: senderName,
                                    isTyping: !clean.isEmpty
                                )
                            }
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .tint(Color.accentColor)

                Button {
                    if !draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        sendMessage()
                    }
                } label: {
                    Image(systemName:
                        draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "mic.fill"
                        : "arrow.up.circle.fill"
                    )
                    .font(.system(size: draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 18 : 24, weight: .semibold))
                    .foregroundStyle(
                        draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.white.opacity(0.78)
                        : Color.accentColor
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .frame(height: 46)
            .background(glassCapsuleBackground)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    var glassCircleBackground: some View {
        Circle()
            .fill(.clear)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
            )
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.20),
                                Color.clear,
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }

    var glassCapsuleBackground: some View {
        Capsule()
            .fill(.clear)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.22),
                                Color.clear,
                                Color.white.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }

    func senderDisplayName() -> String {
        if let email = session.currentUser?.email, !email.isEmpty {
            return email.components(separatedBy: "@").first ?? email
        }
        return locale.language.languageCode?.identifier == "tr" ? "Sen" : "You"
    }

    func localizedStartConversationText(_ name: String) -> String {
        locale.language.languageCode?.identifier == "tr"
            ? "\(name) ile konuşmayı başlat."
            : "Start the conversation with \(name)."
    }

    func sendMessage() {
        let clean = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        guard let friendshipID else { return }
        guard let toUserId = friend.backendUserID?.uuidString else { return }

        draftMessage = ""

        Task {
            await friendStore.sendMessage(
                text: clean,
                friendshipID: friendshipID,
                senderID: session.currentUser?.id,
                senderName: senderDisplayName()
            )
            triggerPush(toUserId: toUserId, message: clean)
        }
    }

    func triggerPush(toUserId: String, message: String) {
        guard let url = URL(string: "https://srzvzaczgydwtopnlrvx.supabase.co/functions/v1/send-message-push") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNyenZ6YWN6Z3lkd3RvcG5scnZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4NjIzNjAsImV4cCI6MjA4OTQzODM2MH0.8eSacyni-OQZEU6wbMZwjSPhLdQthZFGvUwHlCiaaF4",
            forHTTPHeaderField: "Authorization"
        )

        guard let body = try? JSONSerialization.data(withJSONObject: ["toUserId": toUserId, "message": message]) else { return }
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse {
                print("🟡 PUSH HTTP STATUS:", http.statusCode)
            }
        }.resume()
    }

    func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        DispatchQueue.main.async {
            if animated {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
                    proxy.scrollTo("chat-bottom-anchor", anchor: .bottom)
                }
            } else {
                proxy.scrollTo("chat-bottom-anchor", anchor: .bottom)
            }
        }
    }

    struct TypingDotsView: View {
        var body: some View {
            TimelineView(.animation(minimumInterval: 0.35)) { context in
                let tick = Int(context.date.timeIntervalSinceReferenceDate / 0.35) % 3

                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .frame(width: 5, height: 5)
                            .opacity(tick == i ? 1 : 0.28)
                            .scaleEffect(tick == i ? 1.0 : 0.8)
                    }
                }
            }
        }
    }
}

private struct ChatMessageRow: View {
    let message: FriendChatMessageItem
    let palette: ThemePalette

    var body: some View {
        VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 4) {
            HStack(alignment: .bottom, spacing: 0) {
                if message.isFromMe {
                    Spacer(minLength: 56)
                }

                VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 4) {
                    Text(message.text)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(message.isFromMe ? .white : .white.opacity(0.96))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(messageBubbleBackground)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                        )

                    if message.isFromMe {
                        HStack(spacing: 4) {
                            Image(systemName:
                                message.isPending
                                ? "clock"
                                : (message.seenAt == nil ? "checkmark" : "checkmark.circle.fill")
                            )
                            .font(.system(size: 10, weight: .medium))

                            Text(
                                message.isPending
                                ? String(localized: "chat_sending")
                                : (message.seenAt == nil ? String(localized: "chat_sent") : String(localized: "chat_seen"))
                            )
                            .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(
                            message.seenAt == nil
                            ? Color.white.opacity(0.56)
                            : Color.white.opacity(0.72)
                        )
                        .padding(.horizontal, 4)
                    }
                }

                if !message.isFromMe {
                    Spacer(minLength: 56)
                }
            }
        }
    }

    @ViewBuilder
    private var messageBubbleBackground: some View {
        if message.isFromMe {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.33, green: 0.62, blue: 1.0),
                            Color(red: 0.24, green: 0.55, blue: 0.99)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
    }
}
