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
    // State olarak ekle
    @State private var composerBarHeight: CGFloat = 90
    
    // View'e bu state'i ekle
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isComposerFocused: Bool

    private var friendshipID: UUID? { friend.backendFriendshipID }

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
        .onTapGesture { isComposerFocused = false }
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
                Task {
                    await friendStore.setTyping(
                        friendshipID: friendshipID,
                        currentUserID: session.currentUser?.id,
                        currentUserName: senderDisplayName(),
                        isTyping: false
                    )
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notif in
            let frame = notif.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
            keyboardHeight = frame.height
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .sheet(isPresented: $showFriendInfo) {
            NavigationStack {
                FriendChatInfoView(friend: friend)
            }
        }
    }
}

// MARK: - Background
private extension FriendChatView {
    var ambientBackground: some View {
        ZStack(alignment: .topLeading) {
            AppBackground()

            if appTheme == AppTheme.gradient.rawValue {
                RadialGradient(
                    colors: [hexColor(friend.colorHex).opacity(0.16), Color.clear],
                    center: .topLeading, startRadius: 30, endRadius: 260
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [Color.blue.opacity(0.08), Color.clear],
                    center: .topTrailing, startRadius: 60, endRadius: 320
                )
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Top Controls
private extension FriendChatView {
    var floatingTopControls: some View {
        HStack(alignment: .center, spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(glassCircleBackground)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            Button { showFriendInfo = true } label: {
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
                                .overlay(Circle().stroke(Color.black.opacity(0.28), lineWidth: 1.5))
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

            Button { showFriendInfo = true } label: {
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

    private var isFriendOnline: Bool { friendPresence?.is_online == true }

    private var headerStatusText: String {
        if let friendshipID,
           friendStore.typingStatusByFriendship[friendshipID] == true {
            return tr("chat_typing_suffix")
        }
        guard let friendPresence else { return tr("chat_direct_chat") }
        if friendPresence.is_online { return tr("chat_online") }
        let date = CrewDateParser.parse(friendPresence.last_seen_at) ?? Date()
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = locale
        let relative = formatter.localizedString(for: date, relativeTo: Date())
        return tr("chat_last_seen_format", relative)
    }
}

// MARK: - Empty State
private extension FriendChatView {
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
            Text(tr("chat_no_messages_yet"))
                .font(.headline)
                .foregroundStyle(palette.primaryText)
            Text(tr("chat_start_conversation_format", friend.name))
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Messages List
private extension FriendChatView {
    var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(groupedMessages, id: \.date) { group in
                        DaySeparatorView(date: group.date)
                            .padding(.vertical, 8)

                        ForEach(group.messages) { message in
                            ChatMessageRow(
                                message: message,
                                palette: palette,
                                onDelete: {
                                    guard let friendshipID else { return }
                                    Task {
                                        await friendStore.deleteMessage(
                                            message,
                                            friendshipID: friendshipID
                                        )
                                    }
                                }
                            )
                            .id(message.id)
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("chat-bottom-anchor")
                }
                .padding(.horizontal, 16)
                .padding(.top, 64)
                .padding(.bottom, keyboardHeight > 0 ? keyboardHeight + composerBarHeight + 16 : composerBarHeight + 34)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively) // ✅ ScrollView'e taşındı
            .onAppear { scrollToBottom(proxy: proxy, animated: false) }
            .onChange(of: messages.count) { _, _ in scrollToBottom(proxy: proxy, animated: true) }
            .onChange(of: keyboardHeight) { _, newHeight in // ✅ klavye açılınca scroll
                if newHeight > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        scrollToBottom(proxy: proxy, animated: true)
                    }
                }
            }
        }
    }

    // Mesajları güne göre grupla
    var groupedMessages: [MessageGroup] {
        let calendar = Calendar.current
        var groups: [MessageGroup] = []
        var currentDate: Date?
        var currentMessages: [FriendChatMessageItem] = []

        for message in messages {
            let day = calendar.startOfDay(for: message.createdAt)
            if let cd = currentDate, calendar.isDate(cd, inSameDayAs: day) {
                currentMessages.append(message)
            } else {
                if !currentMessages.isEmpty, let cd = currentDate {
                    groups.append(MessageGroup(date: cd, messages: currentMessages))
                }
                currentDate = day
                currentMessages = [message]
            }
        }

        if !currentMessages.isEmpty, let cd = currentDate {
            groups.append(MessageGroup(date: cd, messages: currentMessages))
        }

        return groups
    }

    struct MessageGroup {
        let date: Date
        let messages: [FriendChatMessageItem]
    }
}

// MARK: - Composer
private extension FriendChatView {
    var composerBar: some View {
        HStack(alignment: .center, spacing: 10) {
            Button {} label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(width: 42, height: 42)
                    .background(glassCircleBackground)
            }
            .buttonStyle(.plain)
            
            HStack(spacing: 10) {
                TextField(tr("chat_message_placeholder"), text: $draftMessage)
                    .focused($isComposerFocused)
                    .onChange(of: draftMessage) { _, newValue in
                        guard let friendshipID else { return }
                        let clean = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            Task {
                                await friendStore.setTyping(
                                    friendshipID: friendshipID,
                                    currentUserID: session.currentUser?.id,
                                    currentUserName: senderDisplayName(),
                                    isTyping: !clean.isEmpty
                                )
                            }
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .tint(Color.accentColor)
                    .submitLabel(.send)
                    .onSubmit { sendMessage() }
                
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
                    .font(.system(
                        size: draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 18 : 24,
                        weight: .semibold
                    ))
                    .foregroundStyle(
                        draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.white.opacity(0.78)
                        : Color.accentColor
                    )
                    .animation(.spring(response: 0.25), value: draftMessage.isEmpty)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .frame(height: 46)
            .background(glassCapsuleBackground)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .background(
            GeometryReader { geo in
                Color.clear.onAppear {
                    composerBarHeight = geo.size.height
                }
            }
        )
    }
}

// MARK: - Helpers
private extension FriendChatView {
    var glassCircleBackground: some View {
        Circle()
            .fill(.clear)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 0.8))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }

    var glassCapsuleBackground: some View {
        Capsule()
            .fill(.clear)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 0.8))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }

    func senderDisplayName() -> String {
        if let email = session.currentUser?.email, !email.isEmpty {
            return email.components(separatedBy: "@").first ?? email
        }
        return tr("chat_you")
    }

    func sendMessage() {
        let clean = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let friendshipID else { return }
        guard let toUserId = friend.backendUserID?.uuidString else { return }

        draftMessage = ""
        

        Task {
            await friendStore.sendMessage(
                text: clean,
                friendshipID: friendshipID,
                senderID: session.currentUser?.id,
                senderName: senderDisplayName()
            )
            PushService.shared.send(toUserId: toUserId, message: clean)
        }
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
}

// MARK: - Subviews
private extension FriendChatView {
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

// MARK: - Day Separator
private struct DaySeparatorView: View {
    let date: Date

    private var label: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return tr("chat_today") }
        if calendar.isDateInYesterday(date) { return tr("chat_yesterday") }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    var body: some View {
        HStack {
            line
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.horizontal, 10)
            line
        }
    }

    private var line: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(height: 0.5)
    }
}

// MARK: - Message Row
private struct ChatMessageRow: View {
    let message: FriendChatMessageItem
    let palette: ThemePalette
    let onDelete: () -> Void

    @State private var showTime = false

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: message.createdAt)
    }

    var body: some View {
        VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 2) {
            HStack(alignment: .bottom, spacing: 0) {
                if message.isFromMe { Spacer(minLength: 56) }

                VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 4) {
                    Text(message.text)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(message.isFromMe ? .white : .white.opacity(0.96))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(messageBubbleBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = message.text
                            } label: {
                                Label(tr("common_copy"), systemImage: "doc.on.doc")
                            }

                            if message.isFromMe {
                                Button(role: .destructive) {
                                    onDelete()
                                } label: {
                                    Label(tr("common_delete"), systemImage: "trash")
                                }
                            }
                        }

                    // Saat
                    if showTime {
                        Text(timeText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                            .padding(.horizontal, 4)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }

                    // Seen indicator
                    if message.isFromMe {
                        HStack(spacing: 4) {
                            Image(systemName:
                                message.isPending ? "clock"
                                : (message.seenAt == nil ? "checkmark" : "checkmark.circle.fill")
                            )
                            .font(.system(size: 10, weight: .medium))

                            Text(
                                message.isPending ? tr("chat_sending")
                                : (message.seenAt == nil ? tr("chat_sent") : tr("chat_seen"))
                            )
                            .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(
                            message.seenAt != nil
                            ? Color(red: 0.33, green: 0.62, blue: 1.0)
                            : Color.white.opacity(0.45)
                        )
                        .padding(.horizontal, 4)
                    }
                }

                if !message.isFromMe { Spacer(minLength: 56) }
            }
        }
        .padding(.vertical, 3)
        .onTapGesture {
            withAnimation(.spring(response: 0.28)) {
                showTime.toggle()
            }
        }
    }

    @ViewBuilder
    private var messageBubbleBackground: some View {
        if message.isFromMe {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.33, green: 0.62, blue: 1.0), Color(red: 0.24, green: 0.55, blue: 0.99)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        } else {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }
    }
}
