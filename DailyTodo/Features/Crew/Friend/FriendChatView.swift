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
                customHeader

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
            guard let friendshipID else { return }

            friendStore.activeChatFriendshipID = friendshipID

            // İlk yükleme
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

            // Realtime subscription
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

            // ✅ Realtime fallback polling - sadece yeni mesajları çeker, CPU dostu
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 saniye
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

    var customHeader: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(palette.primaryText)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(palette.cardFill)
                            .overlay(Circle().stroke(palette.cardStroke, lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Button { showFriendInfo = true } label: {
                VStack(spacing: 2) {
                    Text(friend.name)
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)

                    if headerStatusText.contains(String(localized: "chat_typing_suffix")) {
                        HStack(spacing: 6) {
                            Text(headerStatusText)
                                .font(.caption)
                                .foregroundStyle(.green)
                            TypingDotsView()
                                .foregroundStyle(.green)
                        }
                    } else {
                        Text(headerStatusText)
                            .font(.caption)
                            .foregroundStyle(palette.secondaryText)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: headerStatusText)
            }
            .buttonStyle(.plain)

            Spacer()

            Color.clear.frame(width: 56, height: 56)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var friendPresence: FriendPresenceDTO? {
        guard let userID = friend.backendUserID else { return nil }
        return friendStore.presenceByUserID[userID]
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
                LazyVStack(spacing: 10) {
                    ForEach(messages) { message in
                        VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 4) {
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
                                                ? Color.accentColor.opacity(palette.primaryText == .black ? 0.90 : 0.24)
                                                : palette.secondaryCardFill
                                            )
                                    )

                                if !message.isFromMe { Spacer(minLength: 40) }
                            }

                            if message.isFromMe {
                                HStack(spacing: 4) {
                                    Image(systemName:
                                        message.isPending ? "clock"
                                        : (message.seenAt == nil ? "checkmark" : "checkmark.circle.fill")
                                    )
                                    .font(.caption2)

                                    Text(
                                        message.isPending ? String(localized: "chat_sending")
                                        : (message.seenAt == nil ? String(localized: "chat_sent") : String(localized: "chat_seen"))
                                    )
                                    .font(.caption2)
                                }
                                .foregroundStyle(message.seenAt == nil ? palette.secondaryText : Color.blue)
                                .padding(.horizontal, 6)
                            }
                        }
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .onAppear { scrollToBottom(proxy: proxy) }
            .onChange(of: messages.count) { _, _ in scrollToBottom(proxy: proxy) }
        }
    }

    var composerBar: some View {
        HStack(spacing: 10) {
            TextField(String(localized: "chat_message_placeholder"), text: $draftMessage)
                .focused($isComposerFocused)
                .onChange(of: draftMessage) { _, newValue in
                    guard let friendshipID else { return }
                    let clean = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
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

            Button { sendMessage() } label: {
                Image(systemName: "paperplane.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Color.accentColor))
            }
            .buttonStyle(.plain)
            .disabled(draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .background(.ultraThinMaterial.opacity(0.001))
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

        URLSession.shared.dataTask(with: request) { data, response, _ in
            if let http = response as? HTTPURLResponse {
                print("🟡 PUSH HTTP STATUS:", http.statusCode)
            }
        }.resume()
    }

    func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastID = messages.last?.id else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }

    private struct TypingDotsView: View {
        @State private var phase = 0

        var body: some View {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .frame(width: 5, height: 5)
                        .opacity(phase == i ? 1 : 0.3)
                }
            }
            .onAppear {
                Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
                    phase = (phase + 1) % 3
                }
            }
        }
    }
}
